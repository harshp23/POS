import { Hono } from 'hono';
import { z } from 'zod';
import { requireCan, type RequestContext } from '../context.js';
import { TextArray } from '../db/sql.js';
import type { Row } from '../db/types.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { mountTableResource } from './crud.js';
import { audit, money, normalizePhone, num, phoneKey, sectionGuard } from './section.js';

/// Customers & CRM (/v1/crm): customer profiles linked to their orders by
/// phone, segments, loyalty points, the store-credit wallet, feedback, and
/// ideas computed from the restaurant's own sales.
///
///   /dashboard · /customers (+ /import) · /segments (+ /:key/customers)
///   /loyalty (+ /ledger, /entries) · /wallet (+ /ledger, /entries)
///   /feedback · /ideas

const PAID = `('paid', 'delivered')`;
const DAY = 86_400_000;

export interface CustomerRow extends Row {
  id: string;
  first_name: string;
  last_name: string;
  phone: string;
  tags: string[];
  created_at: string;
  date_of_birth: string | null;
  anniversary: string | null;
  allow_whatsapp: boolean;
  allow_sms: boolean;
  allow_email: boolean;
  allow_push: boolean;
  orders: number;
  spent: number;
  cancelled: number;
  last_order_at: string | null;
  channels: string[];
  points: number;
  wallet: number;
}

export interface LoyaltySettings {
  enabled: boolean;
  earn_per_amount: number;
  points_per_earn: number;
  point_value: number;
  min_redeem_points: number;
  max_redeem_pct: number;
  expiry_days: number;
  tiers: { name: string; min_spend: number }[];
}

const DEFAULT_LOYALTY: LoyaltySettings = {
  enabled: true,
  earn_per_amount: 100,
  points_per_earn: 5,
  point_value: 1,
  min_redeem_points: 100,
  max_redeem_pct: 20,
  expiry_days: 365,
  tiers: [
    { name: 'Silver', min_spend: 0 },
    { name: 'Gold', min_spend: 10000 },
    { name: 'Platinum', min_spend: 50000 },
  ],
};

export async function loyaltySettings(ctx: RequestContext): Promise<LoyaltySettings> {
  const [row] = await ctx.db.query<Row>(`select * from pos_loyalty_settings where organization_id = $1`, [ctx.m.organization_id]);
  if (!row) return DEFAULT_LOYALTY;
  return {
    enabled: row.enabled as boolean,
    earn_per_amount: num(row.earn_per_amount),
    points_per_earn: num(row.points_per_earn),
    point_value: num(row.point_value),
    min_redeem_points: num(row.min_redeem_points),
    max_redeem_pct: num(row.max_redeem_pct),
    expiry_days: num(row.expiry_days),
    tiers: (row.tiers as LoyaltySettings['tiers']) ?? DEFAULT_LOYALTY.tiers,
  };
}

export const tierFor = (spent: number, tiers: LoyaltySettings['tiers']) =>
  [...tiers].sort((a, b) => a.min_spend - b.min_spend).filter((t) => spent >= t.min_spend).pop()?.name ?? '';

/// Credits loyalty points for every paid bill of a known customer that has
/// not been credited yet (one ledger row per order; the unique index makes
/// this safe to run from several requests at once).
export async function creditBillPoints(ctx: RequestContext): Promise<number> {
  const s = await loyaltySettings(ctx);
  if (!s.enabled || s.points_per_earn <= 0) return 0;
  const bills = await ctx.db.query<{ order_id: string; customer_id: string; total: string; label: string }>(
    `select o.id as order_id, c.id as customer_id, o.total, coalesce(o.display_no::text, o.order_no::text, '') as label
       from orders o
       join pos_customers c on c.organization_id = o.organization_id and c.deleted_at is null
                           and ${phoneKey('c.phone')} = ${phoneKey('o.customer_phone')}
      where o.organization_id = $1 and o.status in ${PAID} and o.customer_phone is not null
        and o.created_at >= c.created_at - interval '1 day'
        and not exists (select 1 from pos_loyalty_ledger l
                         where l.organization_id = o.organization_id and l.entry_type = 'earn' and l.order_ref = o.id::text)
      order by o.created_at
      limit 500`,
    [ctx.m.organization_id],
  );
  let credited = 0;
  for (const b of bills) {
    const points = Math.floor(num(b.total) / s.earn_per_amount) * s.points_per_earn;
    if (points <= 0) continue;
    const rows = await ctx.db.query(
      `insert into pos_loyalty_ledger (organization_id, customer_id, entry_type, points, balance_after, note, order_ref)
       select $1::uuid, $2::uuid, 'earn', $3::int,
              (coalesce((select sum(points) from pos_loyalty_ledger where customer_id = $2::uuid), 0) + $3::int)::int,
              $4::text, $5::text
       on conflict (organization_id, order_ref) where entry_type = 'earn' and order_ref is not null do nothing
       returning id`,
      [ctx.m.organization_id, b.customer_id, points, `Earned on POS bill ${b.label}`.trim(), b.order_id],
    );
    credited += rows.length;
  }
  return credited;
}

/// Every customer with their order figures (paid bills matched by phone,
/// limited to the caller's branch for a branch-bound account), loyalty
/// points and wallet balance.
export async function customerRows(ctx: RequestContext, extraWhere = '', extraParams: unknown[] = []): Promise<CustomerRow[]> {
  const rows = await ctx.db.query<Row>(
    `with stats as (
       select ${phoneKey('o.customer_phone')} as pk,
              count(*) filter (where o.status in ${PAID})::int as orders,
              coalesce(sum(o.total) filter (where o.status in ${PAID}), 0) as spent,
              count(*) filter (where o.status = 'cancelled')::int as cancelled,
              max(o.created_at) filter (where o.status in ${PAID}) as last_order_at,
              array_remove(array_agg(distinct o.channel) filter (where o.status in ${PAID}), null) as channels
         from orders o
        where o.organization_id = $1 and o.customer_phone is not null
          and ($2::uuid is null or o.location_id = $2::uuid)
        group by 1)
     select c.*, coalesce(s.orders, 0) as orders, coalesce(s.spent, 0) as spent, coalesce(s.cancelled, 0) as cancelled,
            s.last_order_at, coalesce(s.channels, '{}') as channels,
            coalesce((select sum(l.points) from pos_loyalty_ledger l where l.customer_id = c.id), 0)::int as points,
            coalesce((select sum(w.amount) from pos_wallet_ledger w where w.customer_id = c.id), 0) as wallet
       from pos_customers c
       left join stats s on s.pk = ${phoneKey('c.phone')}
      where c.organization_id = $1 and c.deleted_at is null ${extraWhere}
      order by c.created_at desc`,
    [ctx.m.organization_id, ctx.m.branch_scope, ...extraParams],
  );
  return rows.map((r) => ({
    ...r,
    orders: num(r.orders),
    spent: money(r.spent),
    cancelled: num(r.cancelled),
    points: num(r.points),
    wallet: money(r.wallet),
    tags: (r.tags as string[]) ?? [],
    channels: (r.channels as string[]) ?? [],
  })) as CustomerRow[];
}

// ── segments ───────────────────────────────────────────────────────────────

const monthOf = (d: string | null) => (d ? Number(String(d).slice(5, 7)) : 0);
const daysSince = (iso: string | null, now: number) => (iso ? (now - Date.parse(iso)) / DAY : Infinity);
const DELIVERY = new Set(['delivery', 'swiggy', 'zomato']);

/// Order channels as people say them.
const CHANNEL_NAMES: Record<string, string> = {
  dine_in: 'Dine-in',
  takeaway: 'Takeaway',
  pickup: 'Pickup',
  delivery: 'Delivery',
  qr: 'QR ordering',
  online: 'Online ordering',
  swiggy: 'Swiggy',
  zomato: 'Zomato',
  other: 'Other',
};
export const channelName = (c: string) => CHANNEL_NAMES[c] ?? c.replace(/_/g, ' ').replace(/^./, (x) => x.toUpperCase());

/// Customer fields as the import sheet and the form name them.
const FIELD_LABELS: Record<string, string> = {
  first_name: 'First name',
  last_name: 'Last name',
  phone: 'Phone',
  email: 'Email',
  date_of_birth: 'Date of birth',
  anniversary: 'Anniversary',
  gender: 'Gender',
  city: 'City',
  address: 'Address',
  tags: 'Tags',
  notes: 'Notes',
  location_id: 'Branch',
};
const fieldLabel = (path: PropertyKey[]) => {
  const key = String(path[0] ?? '');
  const label = FIELD_LABELS[key] ?? (key.replace(/_/g, ' ').replace(/^./, (x) => x.toUpperCase()) || 'Row');
  return path.length > 1 && typeof path[1] === 'number' ? `${label} ${path[1] + 1}` : label;
};

/// Names of every segment a campaign or offer can target: all customers,
/// the system groups and this restaurant's own (deleted ones included, so
/// callers can say "Deleted segment").
export async function segmentNames(ctx: RequestContext): Promise<Map<string, string>> {
  const rows = await ctx.db.query<Row>(
    `select id, name, deleted_at from pos_customer_segments where organization_id = $1`,
    [ctx.m.organization_id],
  );
  const out = new Map<string, string>([['all', 'All customers'], ['', 'All customers']]);
  for (const s of SYSTEM_SEGMENTS) out.set(s.key, s.name);
  for (const r of rows) out.set(String(r.id), r.deleted_at ? 'Deleted segment' : String(r.name));
  return out;
}

export const SYSTEM_SEGMENTS: { key: string; name: string; rule: string; test: (c: CustomerRow, now: number) => boolean }[] = [
  { key: 'vip', name: 'VIP', rule: 'Lifetime spend ≥ ₹15,000', test: (c) => c.spent >= 15000 },
  { key: 'high_spend', name: 'High spend', rule: 'Lifetime spend ≥ ₹10,000', test: (c) => c.spent >= 10000 },
  { key: 'frequent', name: 'Frequent visitors', rule: '5+ orders', test: (c) => c.orders >= 5 },
  { key: 'inactive', name: 'Inactive', rule: 'No visit in 60+ days', test: (c, now) => c.orders > 0 && daysSince(c.last_order_at, now) >= 60 },
  { key: 'new', name: 'New', rule: 'Created in the last 30 days', test: (c, now) => daysSince(c.created_at, now) <= 30 },
  { key: 'birthday', name: 'Birthday this month', rule: 'Date of birth in the current month', test: (c, now) => monthOf(c.date_of_birth) === new Date(now).getMonth() + 1 },
  { key: 'anniversary', name: 'Anniversary this month', rule: 'Anniversary in the current month', test: (c, now) => monthOf(c.anniversary) === new Date(now).getMonth() + 1 },
  { key: 'cancellations', name: 'Frequent cancellations', rule: '2+ cancelled orders', test: (c) => c.cancelled >= 2 },
  { key: 'delivery_only', name: 'Delivery only', rule: 'Ordered only via delivery', test: (c) => c.channels.length > 0 && c.channels.every((ch) => DELIVERY.has(ch)) },
  { key: 'dine_in_only', name: 'Dine-in only', rule: 'Ordered only dine-in', test: (c) => c.channels.length > 0 && c.channels.every((ch) => ch === 'dine_in') },
  { key: 'online', name: 'QR / online ordering', rule: 'Used QR or online self-ordering', test: (c) => c.channels.includes('online') },
  { key: 'aggregator', name: 'Aggregator', rule: 'Ordered via Swiggy / Zomato', test: (c) => c.channels.some((ch) => ch === 'swiggy' || ch === 'zomato') },
];

const segmentRules = z
  .object({
    tags: z.array(z.string().trim().min(1).max(40)).max(20).optional(),
    min_spend: z.number().min(0).optional(),
    min_orders: z.number().int().min(0).optional(),
    inactive_days: z.number().int().min(1).optional(),
    channel: z.enum(['dine_in', 'delivery', 'pickup', 'online', 'swiggy', 'zomato', 'other']).optional(),
  })
  .strict();
type SegmentRules = z.infer<typeof segmentRules>;

export function matchesRules(c: CustomerRow, r: SegmentRules, now: number): boolean {
  if (r.tags?.length && !r.tags.some((t) => c.tags.map((x) => x.toLowerCase()).includes(t.toLowerCase()))) return false;
  if (r.min_spend !== undefined && c.spent < r.min_spend) return false;
  if (r.min_orders !== undefined && c.orders < r.min_orders) return false;
  if (r.inactive_days !== undefined && !(c.orders > 0 && daysSince(c.last_order_at, now) >= r.inactive_days)) return false;
  if (r.channel !== undefined && !c.channels.includes(r.channel)) return false;
  return true;
}

/// Members of a segment: 'all', a system key, or a custom segment's id.
export async function segmentMembers(ctx: RequestContext, key: string, customers?: CustomerRow[]): Promise<CustomerRow[]> {
  const all = customers ?? (await customerRows(ctx));
  const now = Date.now();
  if (key === 'all' || key === '') return all;
  const sys = SYSTEM_SEGMENTS.find((s) => s.key === key);
  if (sys) return all.filter((c) => sys.test(c, now));
  if (!isUuid(key)) throw notFound('This customer group was not found.');
  const [seg] = await ctx.db.query<Row>(
    `select rules from pos_customer_segments where id = $1 and organization_id = $2 and deleted_at is null`,
    [key, ctx.m.organization_id],
  );
  if (!seg) throw notFound('This customer group was not found. It may have been deleted.');
  const rules = segmentRules.parse(seg.rules ?? {});
  return all.filter((c) => matchesRules(c, rules, now));
}

// ── bodies ─────────────────────────────────────────────────────────────────

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected YYYY-MM-DD');
const customerFields = {
  first_name: z.string().trim().min(1, 'First name is required.').max(80),
  last_name: z.string().trim().max(80),
  phone: z.string().trim().min(1, 'Phone number is required.').max(20),
  email: z.union([z.string().trim().email(), z.literal('')]).nullable(),
  gst_number: z.string().trim().max(20).nullable(),
  date_of_birth: date.nullable(),
  anniversary: date.nullable(),
  preferred_dining: z.enum(['dine_in', 'takeaway', 'delivery']),
  location_id: z.string().uuid().nullable(),
  address: z.string().trim().max(500),
  tags: z.array(z.string().trim().min(1).max(40)).max(20),
  notes: z.string().trim().max(2000),
  allow_whatsapp: z.boolean(),
  allow_sms: z.boolean(),
  allow_email: z.boolean(),
  allow_push: z.boolean(),
};
const customerCreate = z.object(customerFields).partial().required({ first_name: true, phone: true }).strict();
const customerPatch = z.object(customerFields).partial().strict();

function cleanCustomer(ctx: RequestContext, body: Row): Row {
  const row: Row = { ...body };
  if (typeof row.phone === 'string') row.phone = normalizePhone(row.phone);
  if (row.email === '') row.email = null;
  if (row.gst_number === '') row.gst_number = null;
  if (Array.isArray(row.tags)) row.tags = new TextArray([...new Set((row.tags as string[]).map((t) => t.trim()).filter(Boolean))]);
  if (row.location_id && !ctx.m.locations.some((l) => l.id === row.location_id)) {
    throw unprocessable('That outlet is not a branch of this restaurant.');
  }
  return row;
}

async function assertPhoneFree(ctx: RequestContext, phone: string, exceptId?: string) {
  const [dup] = await ctx.db.query<Row>(
    `select id, first_name, last_name from pos_customers
      where organization_id = $1 and phone = $2 and deleted_at is null and ($3::uuid is null or id <> $3::uuid)`,
    [ctx.m.organization_id, phone, exceptId ?? null],
  );
  if (dup) throw conflict(`${dup.first_name} ${dup.last_name}`.trim() + ` already has the phone number ${phone}.`);
}

async function oneCustomer(ctx: RequestContext, id: string): Promise<CustomerRow> {
  if (!isUuid(id)) throw notFound('This customer was not found.');
  const [c] = await customerRows(ctx, 'and c.id = $3', [id]);
  if (!c) throw notFound('This customer was not found.');
  return c;
}

const walletEntry = z
  .object({
    customer_id: z.string().uuid(),
    entry_type: z.enum(['topup', 'redeem', 'refund', 'adjust']),
    amount: z.number().refine((v) => v !== 0, 'Amount cannot be zero.'),
    method: z.enum(['cash', 'upi', 'card', 'bank', 'adjustment']).default('cash'),
    note: z.string().trim().max(300).default(''),
  })
  .strict();

const loyaltyEntry = z
  .object({
    customer_id: z.string().uuid(),
    entry_type: z.enum(['earn', 'redeem', 'adjust']),
    points: z.number().int().refine((v) => v !== 0, 'Points cannot be zero.'),
    note: z.string().trim().max(300).default(''),
    order_ref: z.string().trim().max(80).optional(),
  })
  .strict();

const loyaltyBody = z
  .object({
    enabled: z.boolean(),
    earn_per_amount: z.number().positive(),
    points_per_earn: z.number().int().min(0),
    point_value: z.number().min(0),
    min_redeem_points: z.number().int().min(0),
    max_redeem_pct: z.number().min(0).max(100),
    expiry_days: z.number().int().min(0),
    tiers: z.array(z.object({ name: z.string().trim().min(1).max(40), min_spend: z.number().min(0) }).strict()).min(1).max(6),
  })
  .partial()
  .strict();

// ── routes ─────────────────────────────────────────────────────────────────

export function crmRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('customers'));

  app.get('/dashboard', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    await creditBillPoints(ctx);
    const loyalty = await loyaltySettings(ctx);
    const all = await customerRows(ctx);
    const now = Date.now();
    const buyers = all.filter((x) => x.orders > 0);
    const revenue = money(buyers.reduce((s, x) => s + x.spent, 0));
    const bills = buyers.reduce((s, x) => s + x.orders, 0);
    const repeat = buyers.filter((x) => x.orders >= 2);
    const pct = (n: number, d: number) => (d ? Math.round((n / d) * 1000) / 10 : 0);
    const channelRows = await ctx.db.query<{ channel: string; amount: string }>(
      `select channel, sum(total) as amount from orders
        where organization_id = $1 and status in ${PAID} and created_at >= now() - interval '180 days'
          and ($2::uuid is null or location_id = $2::uuid)
        group by channel order by 2 desc`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    const channelTotal = channelRows.reduce((s, r) => s + num(r.amount), 0);
    const brief = (x: CustomerRow) => ({
      id: x.id,
      name: `${x.first_name} ${x.last_name}`.trim(),
      phone: x.phone,
      orders: x.orders,
      spent: x.spent,
      tier: tierFor(x.spent, loyalty.tiers),
      last_order_at: x.last_order_at,
    });
    return c.json({
      data: {
        profiles: all.length,
        lifetime_revenue: revenue,
        customer_lifetime_value: buyers.length ? money(revenue / buyers.length) : 0,
        average_bill: bills ? money(revenue / bills) : 0,
        repeat_rate: pct(repeat.length, buyers.length),
        churn_rate_30d: pct(buyers.filter((x) => daysSince(x.last_order_at, now) > 30).length, buyers.length),
        total_customers: all.length,
        added_30d: all.filter((x) => daysSince(x.created_at, now) <= 30).length,
        repeat_customers: repeat.length,
        vip_customers: all.filter((x) => x.spent >= 15000).length,
        at_risk_90d: buyers.filter((x) => daysSince(x.last_order_at, now) >= 90).length,
        loyalty_members: loyalty.enabled ? all.length : 0,
        wallet_float: money(all.reduce((s, x) => s + x.wallet, 0)),
        birthdays_this_month: all.filter((x) => monthOf(x.date_of_birth) === new Date(now).getMonth() + 1).length,
        top_customers: [...buyers].sort((a, b) => b.spent - a.spent).slice(0, 5).map(brief),
        win_back: repeat.filter((x) => daysSince(x.last_order_at, now) > 45).slice(0, 5).map(brief),
        channel_mix: channelRows.map((r) => ({
          channel: r.channel,
          amount: money(r.amount),
          share: channelTotal ? Math.round((num(r.amount) / channelTotal) * 100) : 0,
        })),
      },
    });
  });

  // ── customers ──
  app.get('/customers', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    await creditBillPoints(ctx);
    const loyalty = await loyaltySettings(ctx);
    let rows = await segmentMembers(ctx, c.req.query('segment') ?? 'all');
    const q = (c.req.query('q') ?? '').trim().toLowerCase();
    if (q) {
      rows = rows.filter((x) =>
        [x.first_name, x.last_name, x.phone, (x.email as string) ?? '', ...x.tags].some((v) => String(v).toLowerCase().includes(q)),
      );
    }
    return c.json({ data: rows.map((x) => ({ ...x, tier: tierFor(x.spent, loyalty.tiers) })) });
  });

  app.post('/customers', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const row = cleanCustomer(ctx, await readJson(c, customerCreate));
    await assertPhoneFree(ctx, row.phone as string);
    const [created] = await ctx.db.insert<Row>('pos_customers', [
      { ...row, organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id },
    ]);
    await audit(ctx, 'Added customer', 'Customer', created!.id as string, { phone: row.phone });
    return c.json({ data: await oneCustomer(ctx, created!.id as string) }, 201);
  });

  app.post('/customers/import', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const body = await readJson(c, z.object({ customers: z.array(z.record(z.string(), z.unknown())).min(1).max(1000) }).strict());
    const added: string[] = [];
    const skipped: { row: number; reason: string }[] = [];
    for (const [i, raw] of body.customers.entries()) {
      try {
        const parsed = customerCreate.parse(raw);
        const row = cleanCustomer(ctx, parsed);
        await assertPhoneFree(ctx, row.phone as string);
        const [created] = await ctx.db.insert<Row>('pos_customers', [
          { ...row, organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id },
        ]);
        added.push(created!.id as string);
      } catch (e) {
        const reason =
          e instanceof z.ZodError ? e.issues.map((x) => `${fieldLabel(x.path)}: ${x.message}`).join('; ') : e instanceof Error ? e.message : String(e);
        skipped.push({ row: i + 1, reason });
      }
    }
    if (added.length) await audit(ctx, 'Imported customers', 'Customer', null, { added: added.length, skipped: skipped.length });
    return c.json({ data: { added: added.length, skipped } });
  });

  app.get('/customers/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    await creditBillPoints(ctx);
    const loyalty = await loyaltySettings(ctx);
    const cust = await oneCustomer(ctx, c.req.param('id'));
    const [orders, points, wallet] = await Promise.all([
      ctx.db.query<Row>(
        `select id, coalesce(display_no::text, order_no::text) as number, channel, status, total, payment_method, created_at
           from orders
          where organization_id = $1 and ${phoneKey('customer_phone')} = ${phoneKey('$2')}
            and ($3::uuid is null or location_id = $3::uuid)
          order by created_at desc limit 50`,
        [ctx.m.organization_id, cust.phone, ctx.m.branch_scope],
      ),
      ctx.db.query<Row>(`select * from pos_loyalty_ledger where customer_id = $1 order by created_at desc limit 50`, [cust.id]),
      ctx.db.query<Row>(`select * from pos_wallet_ledger where customer_id = $1 order by created_at desc limit 50`, [cust.id]),
    ]);
    return c.json({ data: { ...cust, tier: tierFor(cust.spent, loyalty.tiers), recent_orders: orders, loyalty_ledger: points, wallet_ledger: wallet } });
  });

  app.patch('/customers/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const cust = await oneCustomer(ctx, c.req.param('id'));
    const patch = cleanCustomer(ctx, await readJson(c, customerPatch));
    if (patch.phone && patch.phone !== cust.phone) await assertPhoneFree(ctx, patch.phone as string, cust.id);
    if (Object.keys(patch).length) {
      await ctx.db.query(
        `update pos_customers set ${Object.keys(patch)
          .map((k, i) => `${k} = $${i + 3}`)
          .join(', ')} where id = $1 and organization_id = $2`,
        [cust.id, ctx.m.organization_id, ...Object.values(patch)],
      );
      await audit(ctx, 'Updated customer', 'Customer', cust.id, { fields: Object.keys(patch) });
    }
    return c.json({ data: await oneCustomer(ctx, cust.id) });
  });

  app.delete('/customers/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'delete');
    const cust = await oneCustomer(ctx, c.req.param('id'));
    await ctx.db.query(`update pos_customers set deleted_at = now() where id = $1 and organization_id = $2`, [cust.id, ctx.m.organization_id]);
    await audit(ctx, 'Deleted customer', 'Customer', cust.id, { phone: cust.phone });
    return c.body(null, 204);
  });

  // ── segments ──
  app.get('/segments', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    const all = await customerRows(ctx);
    const now = Date.now();
    const custom = await ctx.db.query<Row>(
      `select * from pos_customer_segments where organization_id = $1 and deleted_at is null order by created_at`,
      [ctx.m.organization_id],
    );
    return c.json({
      data: {
        profiles: all.length,
        system: SYSTEM_SEGMENTS.map((s) => ({ key: s.key, name: s.name, rule: s.rule, count: all.filter((x) => s.test(x, now)).length })),
        custom: custom.map((s) => ({
          ...s,
          count: all.filter((x) => matchesRules(x, segmentRules.parse(s.rules ?? {}), now)).length,
        })),
      },
    });
  });

  const segmentBody = z
    .object({ name: z.string().trim().min(1).max(80), description: z.string().trim().max(300).default(''), rules: segmentRules })
    .strict();

  app.post('/segments', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const body = await readJson(c, segmentBody);
    const [row] = await ctx.db.insert<Row>('pos_customer_segments', [
      { organization_id: ctx.m.organization_id, name: body.name, description: body.description, rules: body.rules, created_by: ctx.identity.user_id },
    ]);
    return c.json({ data: row }, 201);
  });

  app.patch('/segments/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This customer group was not found.');
    const body = await readJson(c, segmentBody.partial().strict());
    const [row] = await ctx.db.query<Row>(
      `update pos_customer_segments set name = coalesce($3, name), description = coalesce($4, description), rules = coalesce($5, rules)
        where id = $1 and organization_id = $2 and deleted_at is null returning *`,
      [id, ctx.m.organization_id, body.name ?? null, body.description ?? null, body.rules ?? null],
    );
    if (!row) throw notFound('This customer group was not found.');
    return c.json({ data: row });
  });

  app.delete('/segments/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'delete');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This customer group was not found.');
    const rows = await ctx.db.query(
      `update pos_customer_segments set deleted_at = now() where id = $1 and organization_id = $2 and deleted_at is null returning id`,
      [id, ctx.m.organization_id],
    );
    if (!rows.length) throw notFound('This customer group was not found.');
    return c.body(null, 204);
  });

  app.get('/segments/:key/customers', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    return c.json({ data: await segmentMembers(ctx, c.req.param('key')) });
  });

  // ── loyalty ──
  app.get('/loyalty', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    await creditBillPoints(ctx);
    const settings = await loyaltySettings(ctx);
    const all = await customerRows(ctx);
    const [totals] = await ctx.db.query<Row>(
      `select coalesce(sum(points) filter (where points > 0), 0)::int as issued,
              coalesce(-sum(points) filter (where entry_type = 'redeem'), 0)::int as redeemed
         from pos_loyalty_ledger where organization_id = $1`,
      [ctx.m.organization_id],
    );
    const outstanding = all.reduce((s, x) => s + x.points, 0);
    return c.json({
      data: {
        settings,
        members: settings.enabled ? all.length : 0,
        profiles: all.length,
        points_issued: num(totals?.issued),
        points_redeemed: num(totals?.redeemed),
        points_outstanding: outstanding,
        liability: money(outstanding * settings.point_value),
        tier_pools: [...settings.tiers]
          .sort((a, b) => a.min_spend - b.min_spend)
          .map((t) => ({ ...t, customers: all.filter((x) => tierFor(x.spent, settings.tiers) === t.name).length })),
      },
    });
  });

  app.put('/loyalty', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const body = await readJson(c, loyaltyBody);
    const next = { ...(await loyaltySettings(ctx)), ...body };
    await ctx.db.query(
      `insert into pos_loyalty_settings (organization_id, enabled, earn_per_amount, points_per_earn, point_value, min_redeem_points,
                                         max_redeem_pct, expiry_days, tiers, updated_by)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       on conflict (organization_id) do update set enabled = excluded.enabled, earn_per_amount = excluded.earn_per_amount,
         points_per_earn = excluded.points_per_earn, point_value = excluded.point_value,
         min_redeem_points = excluded.min_redeem_points, max_redeem_pct = excluded.max_redeem_pct,
         expiry_days = excluded.expiry_days, tiers = excluded.tiers, updated_by = excluded.updated_by`,
      [
        ctx.m.organization_id,
        next.enabled,
        next.earn_per_amount,
        next.points_per_earn,
        next.point_value,
        next.min_redeem_points,
        next.max_redeem_pct,
        next.expiry_days,
        JSON.stringify(next.tiers),
        ctx.identity.user_id,
      ],
    );
    await audit(ctx, 'Saved loyalty rules', 'Loyalty', null, body);
    return c.json({ data: await loyaltySettings(ctx) });
  });

  app.get('/loyalty/ledger', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    await creditBillPoints(ctx);
    const rows = await ctx.db.query<Row>(
      `select l.*, trim(c.first_name || ' ' || c.last_name) as customer_name
         from pos_loyalty_ledger l join pos_customers c on c.id = l.customer_id
        where l.organization_id = $1 order by l.created_at desc limit 200`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows });
  });

  app.post('/loyalty/entries', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const body = await readJson(c, loyaltyEntry);
    const cust = await oneCustomer(ctx, body.customer_id);
    const settings = await loyaltySettings(ctx);
    const delta = body.entry_type === 'redeem' ? -Math.abs(body.points) : body.entry_type === 'earn' ? Math.abs(body.points) : body.points;
    if (body.entry_type === 'redeem' && Math.abs(body.points) < settings.min_redeem_points) {
      throw unprocessable(`At least ${settings.min_redeem_points} points must be redeemed at a time.`);
    }
    if (cust.points + delta < 0) throw unprocessable(`${cust.first_name} has only ${cust.points} points.`);
    const [row] = await ctx.db.insert<Row>('pos_loyalty_ledger', [
      {
        organization_id: ctx.m.organization_id,
        customer_id: cust.id,
        entry_type: body.entry_type,
        points: delta,
        balance_after: cust.points + delta,
        note: body.note,
        order_ref: body.order_ref ?? null,
        created_by: ctx.identity.user_id,
      },
    ]);
    await audit(ctx, 'Loyalty entry', 'Loyalty', cust.id, { type: body.entry_type, points: delta });
    return c.json({ data: row }, 201);
  });

  // ── wallet ──
  app.get('/wallet', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    const all = await customerRows(ctx);
    const [r] = await ctx.db.query<Row>(
      `select coalesce(sum(amount) filter (where entry_type = 'topup' and created_at >= now() - interval '30 days'), 0) as topups,
              coalesce(-sum(amount) filter (where entry_type = 'redeem' and created_at >= now() - interval '30 days'), 0) as redemptions
         from pos_wallet_ledger where organization_id = $1`,
      [ctx.m.organization_id],
    );
    return c.json({
      data: {
        float: money(all.reduce((s, x) => s + x.wallet, 0)),
        active_wallets: all.filter((x) => x.wallet > 0).length,
        topups_30d: money(r?.topups),
        redemptions_30d: money(r?.redemptions),
      },
    });
  });

  app.get('/wallet/ledger', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    const rows = await ctx.db.query<Row>(
      `select w.*, trim(c.first_name || ' ' || c.last_name) as customer_name, c.phone
         from pos_wallet_ledger w join pos_customers c on c.id = w.customer_id
        where w.organization_id = $1 order by w.created_at desc limit 200`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows });
  });

  app.post('/wallet/entries', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'write');
    const body = await readJson(c, walletEntry);
    const cust = await oneCustomer(ctx, body.customer_id);
    const amount = money(body.entry_type === 'redeem' ? -Math.abs(body.amount) : body.entry_type === 'adjust' ? body.amount : Math.abs(body.amount));
    const balance = money(cust.wallet + amount);
    if (balance < 0) throw unprocessable(`${cust.first_name}'s wallet has only ₹${cust.wallet.toFixed(2)}.`);
    const [row] = await ctx.db.insert<Row>('pos_wallet_ledger', [
      {
        organization_id: ctx.m.organization_id,
        customer_id: cust.id,
        entry_type: body.entry_type,
        amount,
        method: body.method,
        balance_after: balance,
        note: body.note,
        created_by: ctx.identity.user_id,
      },
    ]);
    await audit(ctx, 'Wallet entry', 'Wallet', cust.id, { type: body.entry_type, amount });
    return c.json({ data: row }, 201);
  });

  // ── feedback ──
  mountTableResource(app, {
    path: 'feedback',
    table: 'pos_customer_feedback',
    module: 'crm',
    columns: {
      customer_id: 'uuid?',
      customer_name: 'text',
      rating: 'int!',
      comment: 'text',
      channel: 'enum:dine_in|takeaway|delivery|qr|online',
      order_ref: 'text?',
      status: 'enum:new|acknowledged|resolved',
      response: 'text',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['status', 'channel', 'customer_id'],
    refs: { customer_id: { table: 'pos_customers' } },
    order: [{ col: 'created_at', ascending: false }],
    remove: 'soft',
    beforeCreate: (ctx, row) => {
      const rating = num(row.rating);
      if (rating < 1 || rating > 5) throw unprocessable('Rating must be 1 to 5.');
      return { ...row, created_by: ctx.identity.user_id };
    },
  });

  // ── ideas ──
  app.get('/ideas', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'crm', 'read');
    const params = [ctx.m.organization_id, ctx.m.branch_scope];
    const scope = `o.organization_id = $1 and o.status in ${PAID} and o.created_at >= now() - interval '180 days'
                   and ($2::uuid is null or o.location_id = $2::uuid)`;
    const top = await ctx.db.query<{ name: string; qty: string; revenue: string; bills: string }>(
      `select oi.name, sum(oi.qty) as qty, sum(oi.qty * oi.unit_price) as revenue, count(distinct o.id) as bills
         from order_items oi join orders o on o.id = oi.order_id
        where ${scope} and oi.status is distinct from 'cancelled'
        group by oi.name order by sum(oi.qty) desc, oi.name limit 8`,
      params,
    );
    const ideas: Row[] = [];
    if (top.length >= 2) {
      const [a, b] = top as [(typeof top)[0], (typeof top)[0]];
      const [pair] = await ctx.db.query<{ both: string }>(
        `select count(*) as both from (
           select o.id from orders o join order_items oi on oi.order_id = o.id
            where ${scope} and oi.name in ($3, $4)
            group by o.id having count(distinct oi.name) = 2) t`,
        [...params, a.name, b.name],
      );
      const rate = Math.round((num(pair?.both) / Math.max(1, Math.min(num(a.bills), num(b.bills)))) * 100);
      ideas.push({
        kind: 'bundle',
        title: `Bundle ${a.name} + ${b.name}`,
        detail: `Your two fastest movers are billed together on ${rate}% of the bills that have either — a combo can lift the average bill.`,
        metric: `${rate}% billed together`,
        action: 'Create combo offer',
        offer: { title: `${a.name} + ${b.name} combo`, campaign_type: 'Combo Deal', linked_items: `${a.name}, ${b.name}` },
      });
    }
    const slow = await ctx.db.query<{ name: string; qty: string }>(
      `select mi.name, coalesce(sum(oi.qty) filter (where ${scope}), 0) as qty
         from menu_items mi
         left join order_items oi on oi.menu_item_id = mi.id
         left join orders o on o.id = oi.order_id
        where mi.organization_id = $1 and mi.is_available
        group by mi.name order by 2 asc, mi.name limit 2`,
      params,
    );
    if (slow.length) {
      ideas.push({
        kind: 'upsell',
        title: `Upsell slow movers: ${slow.map((s) => s.name).join(', ')}`,
        detail: 'Offer these as a discounted add-on at billing instead of discounting the whole bill.',
        metric: `${slow.map((s) => `${s.name} ${num(s.qty)} sold`).join(' · ')}`,
        action: 'Create add-on offer',
        offer: { title: `Add-on: ${slow.map((s) => s.name).join(', ')}`, campaign_type: 'Flat Discount', linked_items: slow.map((s) => s.name).join(', ') },
      });
    }
    const channels = await ctx.db.query<{ channel: string; amount: string }>(
      `select o.channel, sum(o.total) as amount from orders o where ${scope} group by o.channel order by 2 asc`,
      params,
    );
    if (channels.length >= 2) {
      const low = channels[0]!;
      ideas.push({
        kind: 'channel',
        title: `Low-performing channel: ${channelName(low.channel)}`,
        detail: 'Run a time-slot offer on this channel during your quiet hours instead of an all-day discount.',
        metric: `₹${money(low.amount).toLocaleString('en-IN')} in 180 days`,
        action: 'Create time-slot offer',
        offer: { title: `Quiet-hours offer (${channelName(low.channel)})`, campaign_type: 'Percentage Off', linked_items: '' },
      });
    }
    return c.json({
      data: {
        ideas,
        top_items: top.map((t) => ({ name: t.name, qty: num(t.qty), revenue: money(t.revenue), bills: num(t.bills) })),
      },
    });
  });

  return app;
}
