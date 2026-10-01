import { Hono } from 'hono';
import { z } from 'zod';
import { assertBranchAccess, listBranch, requireCan, type RequestContext } from '../context.js';
import { eq, gte, is, isIn, lt, type Filter, type Row } from '../db/types.js';
import { ctxOf, intParam, readJson, type Env } from '../http.js';
import { localDate, localToEpoch, tzOf } from '../lib/time.js';
import { ApiError, conflict, forbidden, notFound, unprocessable } from '../lib/errors.js';
import { isUuid, newId } from '../lib/ids.js';
import { toMinor } from '../lib/money.js';
import { mirroredResources } from '../schema/resources.js';
import { mountTableResource } from './crud.js';
import { canPlaceOrders, canTakePayments, canVerifyPayments } from '../permissions.js';
import { isOperations } from './master.js';
import { mountMirroredResource } from './mirrored-rest.js';
import { recomputeOrders } from './sync/mapped/orders.js';
import { loadExtras, saveExtra } from './sync/extras.js';

// ── order lifecycle (OS status vocabulary, 0010) ─────────────────────────

const TRANSITIONS: Record<string, string[]> = {
  new: ['in_billing', 'sent_to_kitchen', 'awaiting_payment', 'cancelled'],
  in_billing: ['sent_to_kitchen', 'awaiting_payment', 'cancelled'],
  sent_to_kitchen: ['ready', 'awaiting_payment', 'cancelled'],
  ready: ['awaiting_payment', 'delivered', 'paid', 'cancelled'],
  awaiting_payment: ['paid', 'cancelled'],
  paid: ['delivered'],
  delivered: [],
  cancelled: [],
};

const KOT_NEXT: Record<string, string> = { new: 'preparing', preparing: 'ready', ready: 'delivered' };

/// Order and KOT states as people say them.
const STATUS_WORDS: Record<string, string> = {
  new: 'new',
  in_billing: 'being billed',
  sent_to_kitchen: 'in the kitchen',
  preparing: 'being prepared',
  ready: 'ready',
  awaiting_payment: 'awaiting payment',
  paid: 'paid',
  delivered: 'delivered',
  served: 'served',
  cancelled: 'cancelled',
};
const statusWord = (s: unknown) => STATUS_WORDS[String(s)] ?? String(s).replace(/_/g, ' ');

async function event(ctx: RequestContext, orderId: string, kind: string, message: string, meta: Row = {}) {
  await ctx.db.insert('order_events', [
    { organization_id: ctx.m.organization_id, order_id: orderId, kind, message, actor: ctx.m.full_name || ctx.user.email, meta },
  ]);
}

async function loadOrder(ctx: RequestContext, id: string): Promise<Row> {
  let [o] = isUuid(id) ? await ctx.db.select('orders', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', id)] }) : [];
  if (!o) {
    // The key a POS device knows the order by (its own order id), for
    // actions a device sends straight to the server (e.g. a manager
    // verifying a payment).
    const [x] = await ctx.db.select<Row>('pos_entity_extras', {
      columns: ['entity_id'],
      filters: [
        eq('organization_id', ctx.m.organization_id),
        eq('entity', 'order'),
        eq('client_key', id),
        ...(ctx.location ? [eq('location_id', ctx.location.id)] : []),
      ],
      limit: 1,
    });
    if (x) [o] = await ctx.db.select('orders', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', x.entity_id as string)] });
  }
  if (!o) throw notFound('This order was not found.');
  assertBranchAccess(ctx, o.location_id);
  return o;
}

async function orderDetail(ctx: RequestContext, id: string) {
  const order = await loadOrder(ctx, id);
  const [items, kots, payments, events] = await Promise.all([
    ctx.db.select('order_items', { filters: [eq('order_id', id)], order: [{ col: 'created_at' }] }),
    ctx.db.select('kot_tickets', { filters: [eq('order_id', id)], order: [{ col: 'created_at' }] }),
    ctx.db.select('payments', { filters: [eq('order_id', id)], order: [{ col: 'created_at' }] }),
    ctx.db.select('order_events', { filters: [eq('order_id', id)], order: [{ col: 'created_at' }] }),
  ]);
  return { ...order, items, kot_tickets: kots, payments, events };
}

async function nextNo(ctx: RequestContext, kind: 'order' | 'kot'): Promise<number> {
  return ctx.db.rpc<number>('next_org_seq', { org: ctx.m.organization_id, counter_kind: kind });
}

const createOrderSchema = z.object({
  channel: z.enum(['dine_in', 'delivery', 'pickup', 'online', 'swiggy', 'zomato', 'other']).default('dine_in'),
  table_id: z.string().uuid().nullable().optional(),
  customer_name: z.string().max(200).optional(),
  customer_phone: z.string().max(40).optional(),
  captain_name: z.string().max(200).optional(),
  notes: z.string().max(2000).optional(),
  guest_count: z.number().int().min(1).max(500).default(1),
  gst_pct: z.number().min(0).max(28).default(5),
  discount_pct: z.number().min(0).max(100).default(0),
  placed_by: z.enum(['pos', 'captain', 'guest', 'integration']).default('pos'),
  external_ref: z.string().max(200).optional(),
  send_to_kitchen: z.boolean().default(true),
  items: z
    .array(
      z.object({
        menu_item_id: z.string().uuid().optional(),
        name: z.string().min(1).max(300).optional(),
        qty: z.number().int().min(1).max(999),
        unit_price: z.number().min(0).optional(),
        notes: z.string().max(500).optional(),
        variant_name: z.string().max(100).optional(),
      }),
    )
    .min(1),
});

/// Creates a central order with its lines (and a KOT), the way the OS web
/// POS does: order/KOT numbers from next_org_seq, totals from the lines.
export async function createOrder(ctx: RequestContext, body: z.infer<typeof createOrderSchema>): Promise<Row> {
  const id = await ctx.db.transaction((tx) => placeOrder({ ...ctx, db: tx }, body));
  return orderDetail(ctx, id);
}

async function placeOrder(ctx: RequestContext, body: z.infer<typeof createOrderSchema>): Promise<string> {
  if (body.table_id) {
    const [table] = await ctx.db.select('dining_tables', {
      columns: ['id'],
      filters: [eq('organization_id', ctx.m.organization_id), eq('id', body.table_id)],
    });
    if (!table) throw unprocessable('That table is not part of your floor plan.');
  }
  const menuIds = body.items.map((i) => i.menu_item_id).filter(Boolean) as string[];
  const menu = menuIds.length
    ? await ctx.db.select<Row>('menu_items', { filters: [eq('organization_id', ctx.m.organization_id), isIn('id', menuIds)] })
    : [];
  const byId = new Map(menu.map((m) => [m.id as string, m]));
  const lines = body.items.map((i) => {
    const m = i.menu_item_id ? byId.get(i.menu_item_id) : undefined;
    if (i.menu_item_id && !m) throw unprocessable(`${i.name ?? 'An item in this order'} is no longer on your menu.`);
    const name = i.name ?? (m?.name as string | undefined);
    // A menu item always bills at its menu price; only open (non-menu)
    // items carry a price from the till.
    const price = m ? Number(m.price) : i.unit_price;
    if (!name || price === undefined) throw unprocessable('Each item needs a menu_item_id, or a name and unit_price.');
    return { ...i, name, unit_price: price, station: (m?.station as string) ?? 'main', course: (m?.course as string) ?? 'eat' };
  });

  const id = newId();
  const orderNo = await nextNo(ctx, 'order');
  await ctx.db.insert('orders', [
    {
      id,
      organization_id: ctx.m.organization_id,
      location_id: ctx.location?.id ?? null,
      order_no: orderNo,
      display_no: `ORD-${orderNo}`,
      channel: body.channel,
      status: 'new',
      table_id: body.table_id ?? null,
      customer_name: body.customer_name ?? null,
      customer_phone: body.customer_phone ?? null,
      captain_name: body.captain_name ?? null,
      gst_pct: body.gst_pct,
      guest_count: body.guest_count,
      placed_by: body.placed_by,
      notes: body.notes ?? null,
      external_ref: body.external_ref ?? null,
    },
  ]);
  if (body.discount_pct) await saveExtra(ctx, 'order', id, null, { discount_pct: body.discount_pct });

  let kotId: string | null = null;
  if (body.send_to_kitchen) {
    kotId = newId();
    await ctx.db.insert('kot_tickets', [
      { id: kotId, organization_id: ctx.m.organization_id, order_id: id, kot_no: await nextNo(ctx, 'kot'), station: 'main', status: 'new' },
    ]);
  }
  await ctx.db.insert(
    'order_items',
    lines.map((l) => ({
      order_id: id,
      menu_item_id: l.menu_item_id ?? null,
      name: l.name,
      qty: l.qty,
      unit_price: l.unit_price,
      notes: l.notes ?? null,
      variant_name: l.variant_name ?? null,
      station: l.station,
      course: l.course,
      kot_ticket_id: kotId,
    })),
  );
  await recomputeOrders(ctx, [id]);
  await event(ctx, id, 'placed', `Order ORD-${orderNo} placed (${lines.length} item${lines.length === 1 ? '' : 's'})`);
  return id;
}

// ── online orders: One Latur (ol_orders) + aggregator orders (orders) ────

const OL_TO_UI: Record<string, string> = {
  placed: 'Pending', pending: 'Pending', created: 'Pending', new: 'Pending',
  confirmed: 'Accepted', accepted: 'Accepted',
  preparing: 'Preparing',
  ready: 'Ready',
  picked_up: 'Dispatched', out_for_delivery: 'Dispatched', dispatched: 'Dispatched',
  delivered: 'Delivered', completed: 'Delivered',
  cancelled: 'Cancelled', rejected: 'Cancelled',
};
const UI_TO_OL: Record<string, string> = {
  Pending: 'placed', Accepted: 'accepted', Preparing: 'preparing', Ready: 'ready',
  Dispatched: 'out_for_delivery', Delivered: 'delivered', Cancelled: 'cancelled',
};
const POS_TO_UI: Record<string, string> = {
  new: 'Pending', in_billing: 'Accepted', sent_to_kitchen: 'Preparing', ready: 'Ready',
  awaiting_payment: 'Ready', paid: 'Delivered', delivered: 'Delivered', cancelled: 'Cancelled',
};
const UI_TO_POS: Record<string, string> = {
  Pending: 'new', Accepted: 'new', Preparing: 'sent_to_kitchen', Ready: 'ready',
  Dispatched: 'ready', Delivered: 'delivered', Cancelled: 'cancelled',
};
const ACTION: Record<string, string> = {
  Pending: 'Accept', Accepted: 'Prepare', Preparing: 'Ready', Ready: 'Dispatch',
  Dispatched: 'Complete', Delivered: 'Archive', Archived: 'Archived', Cancelled: 'Accept',
};
const PLATFORM: Record<string, string> = { swiggy: 'Swiggy', zomato: 'Zomato', online: 'Website' };
const UI_STATUSES = ['Pending', 'Accepted', 'Preparing', 'Ready', 'Dispatched', 'Delivered', 'Archived', 'Cancelled'] as const;

const clock = (iso: string) => {
  const d = new Date(iso);
  const h = d.getHours() % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
};

async function onlineOrders(ctx: RequestContext): Promise<Row[]> {
  const org = eq('organization_id', ctx.m.organization_id);
  const since = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
  const [ol, agg] = await Promise.all([
    ctx.db.select<Row>('ol_orders', { filters: [org, gte('created_at', since)], order: [{ col: 'created_at', ascending: false }], limit: 300 }),
    ctx.db.select<Row>('orders', {
      filters: [org, isIn('channel', ['swiggy', 'zomato', 'online']), gte('created_at', since)],
      order: [{ col: 'created_at', ascending: false }],
      limit: 300,
    }),
  ]);
  const olIds = ol.map((o) => o.id as string);
  const aggIds = agg.map((o) => o.id as string);
  const [olItems, aggItems, olExtras, aggExtras] = await Promise.all([
    olIds.length ? ctx.db.select<Row>('ol_order_items', { filters: [isIn('order_id', olIds)] }) : Promise.resolve([]),
    aggIds.length ? ctx.db.select<Row>('order_items', { filters: [isIn('order_id', aggIds)] }) : Promise.resolve([]),
    loadExtras(ctx, 'online_order', olIds),
    loadExtras(ctx, 'online_order', aggIds),
  ]);
  const label = (items: Row[], id: string) =>
    items
      .filter((i) => i.order_id === id)
      .map((i) => `${i.qty}x ${i.name}`)
      .join(', ');

  const rows: Row[] = [];
  for (const o of ol) {
    const id = o.id as string;
    const status = (olExtras.get(id)?.data.ui_status as string) ?? OL_TO_UI[String(o.status)] ?? 'Pending';
    const addr = (o.delivery_address ?? {}) as Row;
    rows.push({
      order_id: `ol:${id}`,
      display_id: `OL-${id.slice(0, 8).toUpperCase()}`,
      source: 'one_latur',
      platform: 'One Latur',
      customer: (addr.name as string) || 'Guest',
      items_label:
        label(olItems, id) ||
        ((o.items as Row[] | null) ?? []).map((i) => `${i.qty ?? 1}x ${i.name ?? 'Item'}`).join(', '),
      amount_minor: toMinor(o.total),
      status,
      action_label: ACTION[status] ?? 'Accept',
      time: clock(o.created_at as string),
      created_at: o.created_at,
      raw_status: o.status,
      payment_status: o.payment_status ?? null,
    });
  }
  for (const o of agg) {
    const id = o.id as string;
    const status = (aggExtras.get(id)?.data.ui_status as string) ?? POS_TO_UI[String(o.status)] ?? 'Pending';
    rows.push({
      order_id: `pos:${id}`,
      display_id: (o.display_no as string) ?? `ORD-${id.slice(0, 8).toUpperCase()}`,
      source: 'aggregator',
      platform: PLATFORM[String(o.channel)] ?? String(o.channel),
      customer: (o.customer_name as string) || 'Guest',
      items_label: label(aggItems, id),
      amount_minor: toMinor(o.total),
      status,
      action_label: ACTION[status] ?? 'Accept',
      time: clock(o.created_at as string),
      created_at: o.created_at,
      raw_status: o.status,
    });
  }
  return rows.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
}

async function setOnlineStatus(ctx: RequestContext, orderId: string, ui: string): Promise<void> {
  const [kind, id] = orderId.split(':');
  if (!id || !isUuid(id) || (kind !== 'ol' && kind !== 'pos')) throw notFound('This online order was not found.');
  const org = eq('organization_id', ctx.m.organization_id);
  if (kind === 'ol') {
    if (ui !== 'Archived') {
      const rows = await ctx.db.update('ol_orders', { status: UI_TO_OL[ui], updated_at: new Date().toISOString() }, [org, eq('id', id)]);
      if (!rows.length) throw new ApiError(404, 'not_found', 'Order not found, or your organization cannot update One Latur orders yet (run the POS migration).');
    }
  } else {
    await loadOrder(ctx, id);
    if (ui !== 'Archived') await ctx.db.update('orders', { status: UI_TO_POS[ui] }, [org, eq('id', id)]);
    await event(ctx, id, 'status_changed', `Online order moved to ${ui}`);
  }
  await saveExtra(ctx, 'online_order', id, orderId, { ui_status: ui });
}

// ── routes ────────────────────────────────────────────────────────────────

export function operationsRoutes(): Hono<Env> {
  const app = new Hono<Env>();

  mountTableResource(app, {
    path: 'dining-areas',
    table: 'dining_areas',
    module: 'operations',
    columns: { name: 'text!', sort_order: 'int', location_id: 'uuid?' },
    locationColumn: 'location_id',
    refs: { location_id: { table: 'org_locations' } },
    order: [{ col: 'sort_order' }],
    remove: 'none',
  });

  mountTableResource(app, {
    path: 'dining-tables',
    table: 'dining_tables',
    module: 'operations',
    columns: {
      label: 'text!',
      seats: 'int',
      min_capacity: 'int',
      area_id: 'uuid?',
      is_active: 'bool',
      sort_order: 'int',
      location_id: 'uuid?',
    },
    locationColumn: 'location_id',
    filters: ['area_id', 'is_active'],
    refs: { area_id: { table: 'dining_areas' }, location_id: { table: 'org_locations' } },
    order: [{ col: 'sort_order' }, { col: 'label' }],
    remove: 'hard',
  });

  mountTableResource(app, {
    path: 'kitchen-stations',
    table: 'kitchen_stations',
    module: 'operations',
    columns: { key: 'text!', name: 'text!', colour: 'text', sort_order: 'int' },
    order: [{ col: 'sort_order' }],
    remove: 'none',
  });

  mountTableResource(app, {
    path: 'service-requests',
    table: 'service_requests',
    module: 'operations',
    columns: {
      table_id: 'uuid?',
      kind: 'enum:water|cutlery|clean_up|bill|assistance|other',
      note: 'text?',
      status: 'enum:open|acknowledged|done',
    },
    filters: ['status', 'table_id'],
    refs: { table_id: { table: 'dining_tables' } },
    order: [{ col: 'created_at', ascending: false }],
    remove: 'none',
    beforeUpdate: (_ctx, patch) => (patch.status === 'done' ? { ...patch, resolved_at: new Date().toISOString() } : patch),
  });

  for (const r of mirroredResources.filter((m) => isOperations(m.resource))) mountMirroredResource(app, r);

  // Orders
  app.get('/orders', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    const filters: Filter[] = [eq('organization_id', ctx.m.organization_id)];
    for (const col of ['status', 'channel', 'table_id']) {
      const v = c.req.query(col);
      if (v) filters.push(eq(col, v));
    }
    const branch = listBranch(ctx, c.req.query('location_id'));
    if (branch !== undefined) filters.push(branch === null ? is('location_id', null) : eq('location_id', branch));
    const from = c.req.query('from');
    const to = c.req.query('to');
    if (from) filters.push(gte('created_at', from));
    if (to) filters.push(lt('created_at', to));
    const limit = intParam(c.req.query('limit'), 100, 500);
    const offset = intParam(c.req.query('offset'), 0, 1_000_000);
    const rows = await ctx.db.select('orders', { filters, order: [{ col: 'created_at', ascending: false }], limit, offset });
    return c.json({ data: rows, limit, offset });
  });

  app.get('/orders/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    return c.json({ data: await orderDetail(ctx, c.req.param('id')) });
  });

  app.post('/orders', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    if (!canPlaceOrders(ctx.m.role)) throw forbidden(`Your role (${ctx.m.role_name}) cannot place orders.`);
    return c.json({ data: await createOrder(ctx, await readJson(c, createOrderSchema)) }, 201);
  });

  app.post('/orders/:id/status', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    const { status } = await readJson(c, z.object({ status: z.enum(Object.keys(TRANSITIONS) as [string, ...string[]]) }));
    if (status === 'paid') throw conflict('An order becomes paid by recording its payments, not by a status change.');
    const order = await loadOrder(ctx, c.req.param('id'));
    const from = order.status as string;
    if (!TRANSITIONS[from]?.includes(status)) throw conflict(`An order that is ${statusWord(from)} cannot be marked ${statusWord(status)}.`);
    await ctx.db.update('orders', { status, ...(status === 'paid' ? { paid_at: new Date().toISOString() } : {}) }, [
      eq('organization_id', ctx.m.organization_id),
      eq('id', order.id),
    ]);
    await event(ctx, order.id as string, 'status_changed', `Status ${from} → ${status}`);
    return c.json({ data: await orderDetail(ctx, order.id as string) });
  });

  app.post('/orders/:id/payments', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    const body = await readJson(
      c,
      z.object({
        method: z.enum(['cash', 'upi', 'card', 'wallet', 'due', 'other']),
        amount: z.number().positive().max(10_000_000),
        reference: z.string().max(200).optional(),
      }),
    );
    if (!canTakePayments(ctx.m.role)) throw forbidden(`Your role (${ctx.m.role_name}) cannot take payments.`);
    // A retried request (same Idempotency-Key) returns the order as it is
    // instead of recording the payment twice.
    const key = c.req.header('idempotency-key')?.trim().slice(0, 100) || null;
    const orderId = (await loadOrder(ctx, c.req.param('id'))).id as string;
    const outcome = await ctx.db.transaction(async (tx) => {
      const [order] = await tx.query<Row>(`select * from orders where id = $1 and organization_id = $2 for update`, [orderId, ctx.m.organization_id]);
      if (!order) throw notFound('This order was not found.');
      if (key) {
        const [seen] = await tx.query(`select 1 from order_events where order_id = $1 and meta->>'idempotency_key' = $2`, [orderId, key]);
        if (seen) return 'duplicate';
      }
      if (['cancelled', 'paid', 'delivered'].includes(order.status as string)) {
        throw conflict(`This order is already ${statusWord(order.status)}; it takes no more payments.`);
      }
      const payments = await tx.query<Row>(`select method, amount from payments where order_id = $1`, [orderId]);
      const received = payments.reduce((s, p) => s + toMinor(p.amount), 0);
      const due = toMinor(order.total) - received;
      if (toMinor(body.amount) > due) {
        throw unprocessable(`That is more than the ₹${(Math.max(due, 0) / 100).toFixed(2)} still due. Give the difference back as change.`);
      }
      await tx.insert('payments', [
        { organization_id: ctx.m.organization_id, order_id: orderId, method: body.method, amount: body.amount, reference: body.reference ?? null },
      ]);
      const all = [...payments, { method: body.method, amount: body.amount }];
      const cash = all.filter((p) => p.method === 'cash').reduce((s, p) => s + toMinor(p.amount), 0);
      const total = all.reduce((s, p) => s + toMinor(p.amount), 0);
      const methods = new Set(all.map((p) => p.method as string));
      const method = methods.size > 1 ? 'split' : [...methods][0]!;
      const osMethod = ['cash', 'upi', 'card', 'split'].includes(method) ? method : null;
      const ev = (kind: string, message: string) =>
        tx.insert('order_events', [
          {
            organization_id: ctx.m.organization_id,
            order_id: orderId,
            kind,
            message,
            actor: ctx.m.full_name || ctx.user.email,
            meta: { method: body.method, amount: body.amount, reference: body.reference ?? null, idempotency_key: key },
          },
        ]);
      if (cash >= toMinor(order.total)) {
        await tx.query(`update orders set status = 'paid', paid_at = now(), payment_method = $3 where id = $1 and organization_id = $2`, [orderId, ctx.m.organization_id, osMethod]);
        await ev('settled', `Settled ₹${(total / 100).toFixed(2)} in cash`);
      } else if (total >= toMinor(order.total)) {
        // Card / UPI / wallet / credit money is not confirmed until someone
        // checks the statement: the order waits for verification.
        await tx.query(`update orders set status = 'awaiting_payment', payment_method = $3 where id = $1 and organization_id = $2`, [orderId, ctx.m.organization_id, osMethod]);
        await ev('payment_pending_verification', `₹${body.amount.toFixed(2)} by ${body.method} recorded — pending verification`);
      } else {
        await ev('payment', `Received ₹${body.amount.toFixed(2)} by ${body.method}`);
      }
      return 'recorded';
    });
    return c.json({ data: await orderDetail(ctx, orderId) }, outcome === 'duplicate' ? 200 : 201);
  });

  // Confirms card / UPI / wallet / credit payments as received (checked
  // against the bank / UPI statement). Recorded in the order's history.
  app.post('/orders/:id/verify-payment', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    if (!canVerifyPayments(ctx.m.role)) throw forbidden(`Your role (${ctx.m.role_name}) cannot verify payments.`);
    const body = await readJson(c, z.object({ reference: z.string().trim().max(200).optional(), note: z.string().trim().max(500).optional() }));
    const orderId = (await loadOrder(ctx, c.req.param('id'))).id as string;
    await ctx.db.transaction(async (tx) => {
      const [order] = await tx.query<Row>(`select * from orders where id = $1 and organization_id = $2 for update`, [orderId, ctx.m.organization_id]);
      if (!order || order.status !== 'awaiting_payment') throw conflict('Only an order awaiting payment can be verified.');
      const [sum] = await tx.query<Row>(`select coalesce(sum(amount), 0) as received from payments where order_id = $1`, [orderId]);
      if (toMinor(sum?.received) < toMinor(order.total)) throw conflict('The recorded payments do not cover the bill yet.');
      await tx.query(`update orders set status = 'paid', paid_at = now() where id = $1 and organization_id = $2`, [orderId, ctx.m.organization_id]);
      await tx.insert('order_events', [
        {
          organization_id: ctx.m.organization_id,
          order_id: orderId,
          kind: 'payment_verified',
          message: `Payment verified manually${body.reference ? ` (ref ${body.reference})` : ''}`,
          actor: ctx.m.full_name || ctx.user.email,
          meta: { reference: body.reference ?? null, note: body.note ?? null, verified_by: ctx.identity.user_id, how: 'manual' },
        },
      ]);
    });
    return c.json({ data: await orderDetail(ctx, orderId) });
  });

  // Kitchen
  app.get('/kot-tickets', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    const filters: Filter[] = [eq('organization_id', ctx.m.organization_id)];
    const status = c.req.query('status');
    if (status) filters.push(isIn('status', status.split(',')));
    else filters.push(isIn('status', ['new', 'preparing', 'ready']));
    const branch = listBranch(ctx, c.req.query('location_id'));
    if (branch !== undefined) {
      // KOTs have no branch of their own: they follow their order's.
      const orders = await ctx.db.select<Row>('orders', {
        columns: ['id'],
        filters: [eq('organization_id', ctx.m.organization_id), branch === null ? is('location_id', null) : eq('location_id', branch), isIn('status', ['new', 'in_billing', 'sent_to_kitchen', 'ready', 'awaiting_payment'])],
        limit: 2000,
      });
      if (!orders.length) return c.json({ data: [] });
      filters.push(isIn('order_id', orders.map((o) => o.id as string)));
    }
    const kots = await ctx.db.select<Row>('kot_tickets', { filters, order: [{ col: 'created_at' }], limit: 300 });
    const items = kots.length ? await ctx.db.select<Row>('order_items', { filters: [isIn('order_id', kots.map((k) => k.order_id as string))] }) : [];
    return c.json({ data: kots.map((k) => ({ ...k, items: items.filter((i) => i.order_id === k.order_id) })) });
  });

  app.post('/kot-tickets/:id/advance', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This KOT was not found.');
    const [kot] = await ctx.db.select<Row>('kot_tickets', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', id)] });
    if (!kot) throw notFound('This KOT was not found.');
    const next = KOT_NEXT[kot.status as string];
    if (!next) throw conflict(`KOT #${kot.kot_no as number} is already ${statusWord(kot.status)}.`);
    const [updated] = await ctx.db.update('kot_tickets', { status: next }, [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    if (next === 'ready') await ctx.db.update('order_items', { status: 'ready' }, [eq('kot_ticket_id', id)]);
    await recomputeOrders(ctx, [kot.order_id as string]);
    await event(ctx, kot.order_id as string, 'kot', `KOT #${kot.kot_no as number} is ${statusWord(next)}`);
    return c.json({ data: updated });
  });

  // Online orders inbox
  app.get('/online-orders', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    const status = c.req.query('status');
    const rows = await onlineOrders(ctx);
    return c.json({ data: status ? rows.filter((r) => r.status === status) : rows });
  });

  app.post('/online-orders/:orderId/status', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    const { status } = await readJson(c, z.object({ status: z.enum(UI_STATUSES) }));
    await setOnlineStatus(ctx, c.req.param('orderId'), status);
    const row = (await onlineOrders(ctx)).find((r) => r.order_id === c.req.param('orderId'));
    return c.json({ data: row ?? null });
  });

  /// Manual entry of an aggregator order (e.g. taken over the phone from a
  /// Zomato/Swiggy tablet): becomes a central order with channel = platform.
  app.post('/online-orders', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    const body = await readJson(
      c,
      z.object({
        platform: z.enum(['Zomato', 'Swiggy', 'Website']),
        customer: z.string().min(1).max(200),
        items_label: z.string().min(1).max(2000),
        amount_minor: z.number().int().positive(),
        external_ref: z.string().max(200).optional(),
      }),
    );
    const channel = { Zomato: 'zomato', Swiggy: 'swiggy', Website: 'online' }[body.platform] as 'zomato' | 'swiggy' | 'online';
    const order = await createOrder(ctx, {
      channel,
      customer_name: body.customer,
      placed_by: 'integration',
      external_ref: body.external_ref,
      gst_pct: 0,
      discount_pct: 0,
      guest_count: 1,
      send_to_kitchen: false,
      items: [{ name: body.items_label, qty: 1, unit_price: body.amount_minor / 100 }],
    });
    const row = (await onlineOrders(ctx)).find((r) => r.order_id === `pos:${order.id as string}`);
    return c.json({ data: row ?? order }, 201);
  });

  app.delete('/online-orders/:orderId', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'write');
    await setOnlineStatus(ctx, c.req.param('orderId'), 'Cancelled');
    return c.body(null, 204);
  });

  // Sales channels (store on/off)
  mountTableResource(app, {
    path: 'channels',
    table: 'channel_integrations',
    module: 'operations',
    columns: {
      channel: 'enum:swiggy|zomato|ondc|website|whatsapp|qr!',
      display_name: 'text!',
      is_connected: 'bool',
      is_accepting: 'bool',
      next_open_at: 'timestamp?',
      auto_accept: 'bool',
      commission_pct: 'numeric',
    },
    order: [{ col: 'channel' }],
    versionColumn: 'updated_at',
    remove: 'none',
  });

  // Bill settings (one row per organization)
  const billSchema = z
    .object({
      legal_name: z.string().max(300).nullable(),
      address: z.string().max(1000).nullable(),
      gstin: z.string().max(20).nullable(),
      fssai: z.string().max(30).nullable(),
      phone: z.string().max(40).nullable(),
      sgst_pct: z.number().min(0).max(50),
      cgst_pct: z.number().min(0).max(50),
      service_charge_pct: z.number().min(0).max(50),
      round_off_enabled: z.boolean(),
      footer_note: z.string().max(1000).nullable(),
    })
    .partial()
    .strict();

  app.get('/bill-settings', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    const [row] = await ctx.db.select('org_bill_settings', { filters: [eq('organization_id', ctx.m.organization_id)] });
    return c.json({
      data: row ?? { organization_id: ctx.m.organization_id, sgst_pct: 2.5, cgst_pct: 2.5, service_charge_pct: 0, round_off_enabled: true },
    });
  });

  app.put('/bill-settings', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'delete');
    const body = await readJson(c, billSchema);
    const [row] = await ctx.db.upsert('org_bill_settings', [{ ...body, organization_id: ctx.m.organization_id }], ['organization_id']);
    return c.json({ data: row });
  });

  // Live summary for the current branch (or ?scope=org for the chain)
  app.get('/summary', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'operations', 'read');
    const tz = tzOf(ctx);
    const day = c.req.query('date') ?? localDate(tz);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) throw new ApiError(400, 'bad_request', 'date must be YYYY-MM-DD.');
    const start = new Date(localToEpoch(tz, day));
    const end = new Date(start.getTime() + 24 * 3600 * 1000);
    const filters: Filter[] = [eq('organization_id', ctx.m.organization_id), gte('created_at', start.toISOString()), lt('created_at', end.toISOString())];
    if (ctx.m.branch_scope) filters.push(eq('location_id', ctx.m.branch_scope));
    else if (c.req.query('scope') !== 'org' && ctx.location) filters.push(eq('location_id', ctx.location.id));
    const orders = await ctx.db.select<Row>('orders', { filters, limit: 5000 });
    const ids = orders.map((o) => o.id as string);
    const [items, kots] = await Promise.all([
      ids.length ? ctx.db.select<Row>('order_items', { columns: ['order_id', 'name', 'qty'], filters: [isIn('order_id', ids.slice(0, 1000))] }) : [],
      ids.length ? ctx.db.select<Row>('kot_tickets', { columns: ['status'], filters: [isIn('order_id', ids.slice(0, 1000))] }) : [],
    ]);
    const paid = orders.filter((o) => o.status === 'paid' || o.status === 'delivered');
    const count = (rows: Row[], col: string) =>
      rows.reduce<Record<string, number>>((m, r) => ((m[String(r[col])] = (m[String(r[col])] ?? 0) + 1), m), {});
    const top = Object.entries(
      items.reduce<Record<string, number>>((m, i) => ((m[String(i.name)] = (m[String(i.name)] ?? 0) + Number(i.qty)), m), {}),
    )
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([name, qty]) => ({ name, qty }));
    return c.json({
      data: {
        date: day,
        location_id: c.req.query('scope') === 'org' ? null : (ctx.location?.id ?? null),
        orders: orders.filter((o) => o.status !== 'cancelled').length,
        sales_minor: paid.reduce((s, o) => s + toMinor(o.total), 0),
        by_status: count(orders, 'status'),
        by_channel: count(orders, 'channel'),
        kitchen: count(kots, 'status'),
        top_items: top,
      },
    });
  });

  return app;
}
