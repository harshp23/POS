import { readFileSync } from 'node:fs';
import { Hono } from 'hono';
import { z } from 'zod';
import { forgetMembership, requireCan, type RequestContext } from '../context.js';
import type { Row } from '../db/types.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { localDate, tzOf } from '../lib/time.js';
import { mountTableResource } from './crud.js';
import { audit, money, num, sectionGuard } from './section.js';
import { PROVIDERS } from './integrations.js';

/// Where an incident came from, as people know it: the connected app's
/// name, the webhook's own name, or the kind of data a device sent.
function incidentSource(origin: string, source: string): string {
  if (origin === 'app') return PROVIDERS.find((p) => p.key === source)?.name ?? source.replace(/_/g, ' ');
  if (origin === 'device') {
    const words = source.replace(/[-_]/g, ' ');
    return words.charAt(0).toUpperCase() + words.slice(1);
  }
  return source;
}

/// Settings (/v1/settings): the restaurant's outlet profile, bill format,
/// devices and printers, KDS and update preferences, notifications, the
/// subscription plan, and live system health.
///
/// Settings are stored as one JSON document per section (pos_settings);
/// the bill header also goes to org_bill_settings, which the POS prints.
/// Nothing here pretends to reach hardware: a test print or a KDS broadcast
/// needs the local print / KDS agent, which is not part of this release.

const outletSchema = z
  .object({
    name: z.string().trim().min(1, 'Restaurant name is required.').max(150),
    phone: z.string().trim().min(1, 'Phone is required.').max(30),
    cuisine: z.string().trim().max(200).default(''),
    email: z.string().trim().email('Enter a valid email.'),
    address: z.string().trim().min(1, 'Address is required.').max(500),
    business_category: z.enum(['Fine Dining', 'Casual Dining', 'QSR / Cafe', 'Cloud Kitchen', 'Bar & Lounge', 'Bakery / Desserts', 'Other']),
    description: z.string().trim().max(1000).default(''),
    logo_url: z.union([z.string().trim().url().max(500), z.literal('')]).default(''),
  })
  .strict();

const billSchema = z
  .object({
    store_name: z.string().trim().min(1, 'Store name is required.').max(150),
    branch_label: z.string().trim().max(100).default(''),
    address: z.string().trim().min(1, 'Address is required.').max(500),
    phone: z.string().trim().min(1, 'Phone is required.').max(30),
    gstin: z.union([z.string().trim().regex(/^[0-9A-Z]{15}$/, 'GSTIN has 15 letters and digits.'), z.literal('')]).default(''),
    fssai: z.string().trim().max(20).default(''),
    bill_prefix: z.string().trim().max(10).default('BIL-'),
    paper_size: z.enum(['58mm', '80mm', 'A4']).default('80mm'),
    footer: z.string().trim().max(200).default('Thank you - Visit again!'),
    show_logo: z.boolean().default(true),
    show_customer: z.boolean().default(true),
    show_cashier: z.boolean().default(false),
    show_tax_breakup: z.boolean().default(true),
    show_discount: z.boolean().default(true),
    show_qr: z.boolean().default(true),
  })
  .strict();

const kdsSchema = z
  .object({
    enabled: z.boolean().default(false),
    server_ip: z.union([z.ipv4('Enter an IPv4 address, e.g. 192.168.1.10.'), z.literal('')]).default(''),
    port: z.number().int().min(1024).max(65535).default(8787),
    subnet: z.string().trim().max(40).default(''),
    channel: z.string().trim().max(60).default('kds'),
    auto_sync: z.boolean().default(true),
    auto_route: z.boolean().default(true),
    offline_billing: z.boolean().default(false),
  })
  .strict();

const updatesSchema = z
  .object({
    auto_install: z.boolean().default(false),
    backup_before_update: z.boolean().default(true),
    notify: z.boolean().default(true),
    window: z.enum(['00:00-02:00', '02:00-05:00', '05:00-07:00', '14:00-16:00']).default('02:00-05:00'),
    channel: z.enum(['stable', 'beta', 'nightly']).default('stable'),
  })
  .strict();

const notificationsSchema = z
  .object({
    low_stock: z.boolean().default(true),
    new_online_order: z.boolean().default(true),
    payment_pending: z.boolean().default(true),
    task_overdue: z.boolean().default(true),
    document_expiry: z.boolean().default(true),
    daily_summary: z.boolean().default(false),
    via_email: z.boolean().default(true),
    via_whatsapp: z.boolean().default(false),
    via_sms: z.boolean().default(false),
    via_push: z.boolean().default(true),
    recipients: z.array(z.string().trim().email()).max(10).default([]),
  })
  .strict();

const SCHEMAS = { outlet: outletSchema, bill_format: billSchema, kds: kdsSchema, updates: updatesSchema, notifications: notificationsSchema } as const;
type Section = keyof typeof SCHEMAS;

async function readSetting(ctx: RequestContext, key: Section | 'print_agent'): Promise<Row | null> {
  const [row] = await ctx.db.query<Row>(`select value, updated_at from pos_settings where organization_id = $1 and key = $2`, [
    ctx.m.organization_id,
    key,
  ]);
  return row ? { ...(row.value as Row), updated_at: row.updated_at } : null;
}

async function writeSetting(ctx: RequestContext, key: Section | 'print_agent', value: Row) {
  await ctx.db.query(
    `insert into pos_settings (organization_id, key, value, updated_by) values ($1, $2, $3, $4)
     on conflict (organization_id, key) do update set value = excluded.value, updated_by = excluded.updated_by`,
    [ctx.m.organization_id, key, value, ctx.identity.user_id],
  );
}

async function outlet(ctx: RequestContext): Promise<Row> {
  const saved = await readSetting(ctx, 'outlet');
  if (saved) return saved;
  const [org] = await ctx.db.query<Row>(`select business_name, email, phone_number from organizations where id = $1`, [ctx.m.organization_id]);
  return {
    name: org?.business_name ?? ctx.m.organization_name,
    phone: org?.phone_number ?? '',
    cuisine: '',
    email: org?.email ?? '',
    address: '',
    business_category: 'Casual Dining',
    description: '',
    logo_url: '',
    updated_at: null,
  };
}

async function billFormat(ctx: RequestContext): Promise<Row> {
  const saved = await readSetting(ctx, 'bill_format');
  const [bill] = await ctx.db.query<Row>(`select * from org_bill_settings where organization_id = $1`, [ctx.m.organization_id]);
  const o = await outlet(ctx);
  return {
    ...billSchema.parse({
      store_name: String(bill?.legal_name || o.name || ctx.m.organization_name),
      address: String(bill?.address || o.address || '-'),
      phone: String(bill?.phone || o.phone || '-'),
      gstin: String(bill?.gstin ?? ''),
      fssai: String(bill?.fssai ?? ''),
      footer: String(bill?.footer_note || 'Thank you - Visit again!'),
      ...(saved ? Object.fromEntries(Object.entries(saved).filter(([k]) => k !== 'updated_at')) : {}),
    }),
    sgst_pct: num(bill?.sgst_pct ?? 2.5),
    cgst_pct: num(bill?.cgst_pct ?? 2.5),
    updated_at: saved?.updated_at ?? bill?.updated_at ?? null,
  };
}

// ── plans ──────────────────────────────────────────────────────────────────

const STANDARD = ['Dashboard', 'Operations', 'Specials', 'Menu', 'Inventory', 'Customers', 'Staff', 'Reports'];
const PREMIUM = ['Dashboard', 'Operations', 'Specials', 'Menu', 'Customers', 'Staff', 'Marketing', 'Integrations'];
export const PLANS = [
  { key: 'standard_1', tier: 'Standard', name: 'Standard Monthly', months: 1, price: 449, features: STANDARD },
  { key: 'standard_3', tier: 'Standard', name: 'Standard Quarterly', months: 3, price: 1213, features: STANDARD },
  { key: 'standard_6', tier: 'Standard', name: 'Standard Half Yearly', months: 6, price: 2248, features: STANDARD },
  { key: 'standard_12', tier: 'Standard', name: 'Standard Yearly', months: 12, price: 4042, features: STANDARD },
  { key: 'premium_1', tier: 'Premium', name: 'Premium Monthly', months: 1, price: 899, features: PREMIUM },
  { key: 'premium_3', tier: 'Premium', name: 'Premium Quarterly', months: 3, price: 2428, features: PREMIUM },
  { key: 'premium_6', tier: 'Premium', name: 'Premium Half Yearly', months: 6, price: 4406, features: PREMIUM },
  { key: 'premium_12', tier: 'Premium', name: 'Premium Yearly', months: 12, price: 8002, features: PREMIUM },
].map((p) => ({ ...p, gst_pct: 18 }));

async function currentPlan(ctx: RequestContext) {
  const today = localDate(tzOf(ctx));
  const [row] = await ctx.db.query<Row>(
    `select * from pos_plan_requests where organization_id = $1 and status = 'active' and (ends_on is null or ends_on >= $2::date)
      order by starts_on desc nulls last limit 1`,
    [ctx.m.organization_id, today],
  );
  if (!row) return null;
  const days = row.ends_on ? Math.max(0, Math.ceil((Date.parse(String(row.ends_on)) - Date.parse(today)) / 86_400_000)) : null;
  return { ...row, price: money(row.price), days_remaining: days };
}

// ── health ─────────────────────────────────────────────────────────────────

async function health(ctx: RequestContext) {
  const org = ctx.m.organization_id;
  const t0 = performance.now();
  await ctx.db.query('select 1');
  const dbLatency = Math.round((performance.now() - t0) * 10) / 10;
  const [r] = await ctx.db.query<Row>(
    `select
       (select max(created_at) from pos_sync_receipts where organization_id = $1) as last_sync,
       (select count(*) from pos_sync_receipts where organization_id = $1 and created_at >= now() - interval '24 hours')::int as sync_24h,
       (select count(*) from pos_sync_receipts where organization_id = $1 and created_at >= now() - interval '24 hours'
           and status <> 'accepted')::int as sync_rejected_24h,
       (select count(*) from pos_printers where organization_id = $1 and deleted_at is null)::int as printers,
       (select count(*) from pos_printers where organization_id = $1 and deleted_at is null and active)::int as printers_active,
       (select count(*) from pos_devices where organization_id = $1 and deleted_at is null)::int as devices,
       (select count(*) from pos_devices where organization_id = $1 and deleted_at is null and device_type = 'kds')::int as kds,
       (select count(*) from pos_devices where organization_id = $1 and deleted_at is null and device_type = 'kds' and active)::int as kds_active,
       (select count(*) from pos_integrations where organization_id = $1 and status = 'connected')::int as integrations_connected,
       (select count(*) from pos_integrations where organization_id = $1 and status = 'pending')::int as integrations_pending,
       (select count(*) from pos_sync_jobs where organization_id = $1 and status = 'failed' and finished_at >= now() - interval '24 hours')::int as jobs_failed_24h,
       (select count(*) from pos_sync_jobs where organization_id = $1 and status = 'queued')::int as jobs_queued,
       (select count(*) from pos_webhook_endpoints where organization_id = $1 and deleted_at is null and active)::int as webhooks,
       (select count(*) from pos_webhook_deliveries where organization_id = $1 and status = 'failed' and created_at >= now() - interval '24 hours')::int as webhook_failed_24h,
       (select count(*) from pos_business_documents where organization_id = $1 and deleted_at is null and expiry_date < current_date)::int as docs_expired,
       (select count(*) from pos_business_documents where organization_id = $1 and deleted_at is null
           and expiry_date between current_date and current_date + 30)::int as docs_expiring,
       (select count(*) from dining_tables where organization_id = $1 and is_active)::int as tables,
       (select count(*) from menu_items where organization_id = $1)::int as menu_items,
       (select count(*) from users where organization_id = $1 and pos_role = 'captain' and lower(status) = 'active')::int as order_takers,
       (select count(*) from pos_reservations where organization_id = $1 and deleted_at is null)::int as reservations,
       (select count(*) from pos_franchise_exceptions where organization_id = $1 and status = 'open')::int as open_exceptions`,
    [org],
  );
  return { dbLatency, ...r } as Row & { dbLatency: number };
}

function alertsFrom(h: Row): Row[] {
  const out: Row[] = [];
  if (num(h.docs_expired)) out.push({ level: 'critical', title: `${num(h.docs_expired)} business document(s) expired`, detail: 'Finance → Documents' });
  if (num(h.docs_expiring)) out.push({ level: 'warning', title: `${num(h.docs_expiring)} document(s) expire within 30 days`, detail: 'Finance → Documents' });
  if (num(h.webhook_failed_24h)) out.push({ level: 'warning', title: `${num(h.webhook_failed_24h)} webhook delivery(ies) failed in 24 h`, detail: 'Integrations → Webhooks' });
  if (num(h.jobs_failed_24h)) out.push({ level: 'warning', title: `${num(h.jobs_failed_24h)} sync job(s) failed in 24 h`, detail: 'Integrations → Sync engine' });
  if (num(h.sync_rejected_24h)) out.push({ level: 'warning', title: `${num(h.sync_rejected_24h)} device change(s) rejected in 24 h`, detail: 'A device sent a change the server refused' });
  if (!num(h.printers)) out.push({ level: 'info', title: 'No printer configured', detail: 'Settings → Printer Setup' });
  if (num(h.open_exceptions)) out.push({ level: 'warning', title: `${num(h.open_exceptions)} open exception(s)`, detail: 'Franchise / Chain → Exceptions' });
  return out;
}

export function settingsRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('settings'));

  app.get('/overview', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    const h = await health(ctx);
    const o = await outlet(ctx);
    const bill = await readSetting(ctx, 'bill_format');
    const notifications = await readSetting(ctx, 'notifications');
    const plan = await currentPlan(ctx);
    const checklist = [
      { key: 'outlet', title: 'Outlet profile', detail: 'Name, address and contact number.', done: !!(o.updated_at && o.address && o.phone) },
      { key: 'bill', title: 'Bill format', detail: 'Store name, address and GSTIN on bills.', done: !!bill },
      { key: 'menu', title: 'Menu items', detail: 'At least one dish on the menu.', done: num(h.menu_items) > 0 },
      { key: 'tables', title: 'Dine-in tables', detail: 'Tables for dine-in orders.', done: num(h.tables) > 0 },
      { key: 'order_takers', title: 'Order takers', detail: 'A captain login to take table orders.', done: num(h.order_takers) > 0 },
      { key: 'printers', title: 'Printers', detail: 'A receipt or KOT printer.', done: num(h.printers) > 0 },
      { key: 'devices', title: 'Registered devices', detail: 'POS terminals, KDS screens, cash drawers.', done: num(h.devices) > 0 },
      { key: 'notifications', title: 'Notification preferences', detail: 'Who gets alerts and how.', done: !!notifications },
    ];
    const components = [
      { name: 'Database', status: 'live', detail: `${h.dbLatency} ms` },
      { name: 'Authentication', status: 'live', detail: 'Signed in' },
      { name: 'Sync engine', status: h.last_sync ? 'live' : 'idle', detail: h.last_sync ? `Last device sync ${new Date(String(h.last_sync)).toISOString()}` : 'No device has synced yet' },
      { name: 'Integrations', status: num(h.integrations_connected) ? 'live' : num(h.integrations_pending) ? 'pending' : 'idle', detail: `${num(h.integrations_connected)} connected · ${num(h.integrations_pending)} pending` },
      { name: 'Printers', status: num(h.printers_active) ? 'live' : 'not_configured', detail: `${num(h.printers_active)} of ${num(h.printers)} active` },
      { name: 'KDS', status: num(h.kds_active) ? 'live' : 'not_configured', detail: `${num(h.kds_active)} screen(s)` },
      { name: 'Webhook queue', status: num(h.webhook_failed_24h) ? 'alert' : 'live', detail: `${num(h.webhook_failed_24h)} failed in 24 h` },
    ];
    return c.json({
      data: {
        checklist,
        components,
        alerts: alertsFrom(h),
        devices: num(h.devices),
        printers: { total: num(h.printers), active: num(h.printers_active) },
        db_latency_ms: h.dbLatency,
        last_sync: h.last_sync ?? null,
        plan,
        modules: [
          { name: 'Kitchen Display (KDS)', status: num(h.kds_active) ? 'active' : 'not_configured' },
          { name: 'POS & Billing', status: 'active' },
          { name: 'Reservations', status: num(h.reservations) ? 'active' : 'idle' },
          { name: 'Online aggregators', status: num(h.integrations_connected) ? 'active' : num(h.integrations_pending) ? 'pending' : 'not_connected' },
        ],
      },
    });
  });

  app.get('/operations-centre', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    const h = await health(ctx);
    const incidents = await ctx.db.query<Row>(
      `select * from (
         select finished_at as at, provider as source, 'Sync failed' as kind, error as detail, 'app' as origin from pos_sync_jobs
          where organization_id = $1 and status = 'failed'
         union all
         select d.created_at, coalesce(e.name, 'Webhook'), 'Webhook failed', d.error, 'webhook' from pos_webhook_deliveries d
           left join pos_webhook_endpoints e on e.id = d.endpoint_id where d.organization_id = $1 and d.status = 'failed'
         union all
         select created_at, resource, 'Device change ' || status, coalesce(result ->> 'message', ''), 'device' from pos_sync_receipts
          where organization_id = $1 and status <> 'accepted'
       ) t order by at desc nulls last limit 20`,
      [ctx.m.organization_id],
    );
    const aggregators = await ctx.db.query<Row>(
      `select channel, display_name, is_connected, is_accepting from channel_integrations where organization_id = $1 order by channel`,
      [ctx.m.organization_id],
    );
    return c.json({
      data: {
        database: { status: 'healthy', latency_ms: h.dbLatency },
        sync: { last_sync: h.last_sync ?? null, changes_24h: num(h.sync_24h), rejected_24h: num(h.sync_rejected_24h), status: num(h.sync_rejected_24h) ? 'attention' : 'healthy' },
        printers: { total: num(h.printers), active: num(h.printers_active), status: num(h.printers) ? 'healthy' : 'not_configured' },
        kitchen: { total: num(h.kds), active: num(h.kds_active) },
        integrations: { connected: num(h.integrations_connected), pending: num(h.integrations_pending), queued_jobs: num(h.jobs_queued), failed_24h: num(h.jobs_failed_24h) },
        webhooks: { active: num(h.webhooks), failed_24h: num(h.webhook_failed_24h), status: num(h.webhook_failed_24h) ? 'attention' : 'healthy' },
        alerts: alertsFrom(h),
        incidents: incidents.map(({ origin, ...i }) => ({ ...i, source: incidentSource(String(origin), String(i.source ?? '')) })),
        aggregators,
      },
    });
  });

  // ── outlet ──
  app.get('/outlet', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    return c.json({ data: await outlet(ctx) });
  });

  app.put('/outlet', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'write');
    const body = await readJson(c, outletSchema);
    await writeSetting(ctx, 'outlet', body);
    await ctx.db.query(`update organizations set business_name = $2 where id = $1`, [ctx.m.organization_id, body.name]);
    forgetMembership();
    await audit(ctx, 'Saved outlet settings', 'Settings', null, { name: body.name });
    return c.json({ data: await outlet(ctx) });
  });

  // ── bill format ──
  app.get('/bill-format', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    return c.json({ data: await billFormat(ctx) });
  });

  app.put('/bill-format', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'write');
    const body = await readJson(c, billSchema);
    await writeSetting(ctx, 'bill_format', body);
    await ctx.db.query(
      `insert into org_bill_settings (organization_id, legal_name, address, gstin, fssai, phone, footer_note)
       values ($1, $2, $3, nullif($4, ''), nullif($5, ''), $6, $7)
       on conflict (organization_id) do update set legal_name = excluded.legal_name, address = excluded.address,
         gstin = excluded.gstin, fssai = excluded.fssai, phone = excluded.phone, footer_note = excluded.footer_note, updated_at = now()`,
      [ctx.m.organization_id, body.store_name, body.address, body.gstin, body.fssai, body.phone, body.footer],
    );
    await audit(ctx, 'Saved bill format', 'Settings');
    return c.json({ data: await billFormat(ctx) });
  });

  // ── devices & printers ──
  mountTableResource(app, {
    path: 'devices',
    table: 'pos_devices',
    module: 'settings',
    columns: {
      name: 'text!',
      device_type: 'enum:kds|pos_terminal|receipt_printer|kot_printer|cash_drawer|scanner!',
      station: 'text',
      ip: 'text',
      mac: 'text',
      connection: 'enum:lan|wifi|usb|bluetooth',
      firmware: 'text',
      model: 'text',
      active: 'bool',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['device_type', 'active'],
    order: [{ col: 'device_type' }, { col: 'name' }],
    remove: 'soft',
  });

  mountTableResource(app, {
    path: 'printers',
    table: 'pos_printers',
    module: 'settings',
    columns: {
      name: 'text!',
      printer_type: 'enum:receipt|kot|label',
      station: 'text',
      connection: 'enum:lan|usb|bluetooth',
      address: 'text',
      paper_mm: 'int',
      density: 'int',
      copies: 'int',
      auto_cut: 'bool',
      active: 'bool',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['printer_type', 'active'],
    order: [{ col: 'name' }],
    remove: 'soft',
    beforeCreate: (_ctx, row) => {
      if (row.paper_mm !== undefined && ![58, 80].includes(num(row.paper_mm))) throw unprocessable('Paper width is 58 or 80 mm.');
      return row;
    },
  });

  app.post('/printers/:id/test', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This printer was not found.');
    const [p] = await ctx.db.query<Row>(`select name from pos_printers where id = $1 and organization_id = $2 and deleted_at is null`, [
      id,
      ctx.m.organization_id,
    ]);
    if (!p) throw notFound('This printer was not found.');
    throw conflict(`${p.name}: a test print needs the local print agent on the counter PC, which is not installed. Nothing was printed.`);
  });

  // ── kds, updates, notifications, print agent ──
  for (const key of ['kds', 'updates', 'notifications'] as const) {
    const path = `/${key}`;
    app.get(path, async (c) => {
      const ctx = ctxOf(c);
      requireCan(ctx, 'settings', 'read');
      const saved = await readSetting(ctx, key);
      const { updated_at: updatedAt, ...value } = saved ?? {};
      return c.json({ data: { ...(SCHEMAS[key].parse(value) as Row), updated_at: updatedAt ?? null, saved: !!saved } });
    });
    app.put(path, async (c) => {
      const ctx = ctxOf(c);
      requireCan(ctx, 'settings', 'write');
      const body = await readJson(c, SCHEMAS[key] as unknown as z.ZodType<Row>);
      await writeSetting(ctx, key, body as Row);
      await audit(ctx, `Saved ${key} settings`, 'Settings');
      return c.json({ data: { ...body, saved: true } });
    });
  }

  app.get('/version', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    let server = 'unknown';
    try {
      server = JSON.parse(readFileSync(new URL('../../package.json', import.meta.url), 'utf8')).version ?? 'unknown';
    } catch {
      // version stays unknown
    }
    return c.json({ data: { server, started_at: STARTED_AT, uptime_seconds: Math.round((Date.now() - Date.parse(STARTED_AT)) / 1000) } });
  });

  // ── subscription ──
  app.get('/subscription', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'read');
    const requests = await ctx.db.query<Row>(
      `select * from pos_plan_requests where organization_id = $1 order by created_at desc limit 20`,
      [ctx.m.organization_id],
    );
    const devices = await ctx.db.query<Row>(
      `select count(*)::int as n from pos_devices where organization_id = $1 and deleted_at is null and device_type in ('pos_terminal', 'kds')`,
      [ctx.m.organization_id],
    );
    const takers = await ctx.db.query<Row>(
      `select count(*)::int as n from users where organization_id = $1 and pos_role in ('captain', 'biller') and lower(status) = 'active'`,
      [ctx.m.organization_id],
    );
    return c.json({
      data: {
        current: await currentPlan(ctx),
        plans: PLANS,
        requests: requests.map((r) => ({ ...r, price: money(r.price) })),
        usage: { terminals: num(devices[0]?.n), order_takers: num(takers[0]?.n) },
      },
    });
  });

  app.post('/subscription/requests', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'write');
    const body = await readJson(c, z.object({ plan_key: z.string() }).strict());
    const plan = PLANS.find((p) => p.key === body.plan_key);
    if (!plan) throw unprocessable('This plan is not available.');
    const [open] = await ctx.db.query<Row>(
      `select plan_name from pos_plan_requests where organization_id = $1 and status = 'requested'`,
      [ctx.m.organization_id],
    );
    if (open) throw conflict(`A request for ${open.plan_name} is already waiting for the Proviyaa team.`);
    const [row] = await ctx.db.insert<Row>('pos_plan_requests', [
      {
        organization_id: ctx.m.organization_id,
        plan_key: plan.key,
        plan_name: plan.name,
        cycle_months: plan.months,
        price: plan.price,
        requested_by: ctx.identity.user_id,
      },
    ]);
    await audit(ctx, 'Requested plan', 'Subscription', String(row!.id), { plan: plan.key });
    return c.json(
      { data: { ...row, price: money(row!.price) }, message: `${plan.name} requested. The Proviyaa team will contact you to activate it; no payment was taken.` },
      201,
    );
  });

  app.post('/subscription/requests/:id/cancel', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'settings', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This request was not found.');
    const rows = await ctx.db.query<Row>(
      `update pos_plan_requests set status = 'cancelled' where id = $1 and organization_id = $2 and status = 'requested' returning *`,
      [id, ctx.m.organization_id],
    );
    if (!rows.length) throw conflict('Only a waiting request can be cancelled.');
    return c.json({ data: rows[0] });
  });

  return app;
}

const STARTED_AT = new Date().toISOString();
