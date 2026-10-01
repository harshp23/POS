import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addStaff, call, login, makeWorld, type World } from './helpers.js';

let w: World;
let token: string;
let delhi: string;
beforeAll(async () => {
  w = await makeWorld();
  token = await login(w, 'admin@spicybistro.test');
  delhi = w.spicy.locationIds[0]!;
});
afterAll(async () => w.close());

const api = (method: string, path: string, body?: unknown) => call(w, method, path, { token, location: delhi, body });

describe('orders, kitchen and billing', () => {
  let orderId: string;
  let paneer: string;

  it('creates an order from menu items with order/KOT numbers and totals', async () => {
    paneer = (await api('POST', '/v1/master/menu-items', { name: 'Paneer Butter Masala', price: 340, station: 'curry' })).body.data.id;
    const table = (await api('POST', '/v1/operations/dining-tables', { label: 'T5', seats: 4 })).body.data.id;
    const r = await api('POST', '/v1/operations/orders', {
      table_id: table,
      guest_count: 2,
      items: [{ menu_item_id: paneer, qty: 2 }, { name: 'Mineral Water', qty: 1, unit_price: 40 }],
    });
    expect(r.status).toBe(201);
    orderId = r.body.data.id;
    expect(r.body.data).toMatchObject({
      display_no: 'ORD-1',
      status: 'sent_to_kitchen',
      location_id: delhi,
      subtotal: 720,
      gst_amount: 36,
      total: 756,
    });
    expect(r.body.data.kot_tickets).toHaveLength(1);
    expect(r.body.data.items.map((i: { station: string }) => i.station).sort()).toEqual(['curry', 'main']);
    expect(r.body.data.events[0].kind).toBe('placed');
  });

  it('rejects an item that is not on this organization menu, and a foreign table', async () => {
    const burger = await login(w, 'admin@burgerexpress.test');
    const foreign = await call(w, 'POST', '/v1/operations/orders', { token: burger, body: { items: [{ menu_item_id: paneer, qty: 1 }] } });
    expect(foreign.status).toBe(422);
    const t = (await api('POST', '/v1/operations/dining-tables', { label: 'T9' })).body.data.id;
    const cross = await call(w, 'POST', '/v1/operations/orders', { token: burger, body: { table_id: t, items: [{ name: 'X', qty: 1, unit_price: 1 }] } });
    expect(cross.status).toBe(422);
  });

  it('advances the KOT through the kitchen; the order follows', async () => {
    const kots = (await api('GET', '/v1/operations/kot-tickets')).body.data;
    expect(kots).toHaveLength(1);
    const kotId = kots[0].id;
    expect((await api('POST', `/v1/operations/kot-tickets/${kotId}/advance`)).body.data.status).toBe('preparing');
    expect((await api('POST', `/v1/operations/kot-tickets/${kotId}/advance`)).body.data.status).toBe('ready');
    const order = (await api('GET', `/v1/operations/orders/${orderId}`)).body.data;
    expect(order.status).toBe('ready');
    expect(order.items.every((i: { status: string }) => i.status === 'ready')).toBe(true);
  });

  it('refuses an impossible status change', async () => {
    const r = await api('POST', `/v1/operations/orders/${orderId}/status`, { status: 'new' });
    expect(r.status).toBe(409);
  });

  it('settles on payment: UPI waits for verification, cash does not, and nothing is overpaid', async () => {
    await api('POST', `/v1/operations/orders/${orderId}/status`, { status: 'awaiting_payment' });
    // "paid" is never set by a status change.
    expect((await api('POST', `/v1/operations/orders/${orderId}/status`, { status: 'paid' })).status).toBe(409);
    const part = await api('POST', `/v1/operations/orders/${orderId}/payments`, { method: 'upi', amount: 500 });
    expect(part.body.data.status).toBe('awaiting_payment');
    // More than is due is refused (give change instead).
    expect((await api('POST', `/v1/operations/orders/${orderId}/payments`, { method: 'cash', amount: 999 })).status).toBe(422);
    // A retried request with the same Idempotency-Key is recorded once.
    const key = { 'Idempotency-Key': 'pay-rest-1' };
    const rest = await call(w, 'POST', `/v1/operations/orders/${orderId}/payments`, { token, body: { method: 'cash', amount: 256 }, headers: key });
    expect(rest.status).toBe(201);
    const retry = await call(w, 'POST', `/v1/operations/orders/${orderId}/payments`, { token, body: { method: 'cash', amount: 256 }, headers: key });
    expect(retry.status).toBe(200);
    // The bill is covered, but ₹500 of it is UPI: pending verification.
    expect(retry.body.data).toMatchObject({ status: 'awaiting_payment', payment_method: 'split' });
    expect(retry.body.data.payments).toHaveLength(2);
    expect(retry.body.data.events.some((e: { kind: string }) => e.kind === 'payment_pending_verification')).toBe(true);
    // A cashier cannot verify; an admin can, and the order becomes paid.
    await addStaff(w, w.spicy, 'biller-verify@spicybistro.test', 'biller');
    const biller = await login(w, 'biller-verify@spicybistro.test');
    expect((await call(w, 'POST', `/v1/operations/orders/${orderId}/verify-payment`, { token: biller, body: {} })).status).toBe(403);
    const ok = await api('POST', `/v1/operations/orders/${orderId}/verify-payment`, { reference: 'UPI-4471' });
    expect(ok.body.data.status).toBe('paid');
    expect(ok.body.data.events.some((e: { kind: string; message: string }) => e.kind === 'payment_verified' && /UPI-4471/.test(e.message))).toBe(true);
    const again = await api('POST', `/v1/operations/orders/${orderId}/payments`, { method: 'cash', amount: 1 });
    expect(again.status).toBe(409);
  });

  it('summarises the day for the branch', async () => {
    const s = (await api('GET', '/v1/operations/summary')).body.data;
    expect(s).toMatchObject({ orders: 1, sales_minor: 75600 });
    expect(s.top_items[0]).toEqual({ name: 'Paneer Butter Masala', qty: 2 });
  });
});

describe('online orders inbox', () => {
  let olId: string;

  beforeAll(async () => {
    const [row] = await w.db.query<{ id: string }>(
      `insert into ol_orders (organization_id, status, subtotal, total, delivery_address, payment_status)
       values ($1, 'placed', 400, 420, '{"name":"Priya Nair"}', 'paid') returning id`,
      [w.spicy.organizationId],
    );
    olId = row!.id;
    await w.db.query(`insert into ol_order_items (order_id, name, price, qty, line_total) values ($1, 'Veg Biryani', 200, 2, 400)`, [olId]);
  });

  it('lists One Latur orders for the organization (via the migration\'s member policy)', async () => {
    const rows = (await api('GET', '/v1/operations/online-orders')).body.data;
    const ol = rows.find((r: { order_id: string }) => r.order_id === `ol:${olId}`);
    expect(ol).toMatchObject({ platform: 'One Latur', customer: 'Priya Nair', items_label: '2x Veg Biryani', amount_minor: 42000, status: 'Pending', action_label: 'Accept' });
  });

  it('accepts and advances a One Latur order in the shared table', async () => {
    const r = await api('POST', `/v1/operations/online-orders/ol:${olId}/status`, { status: 'Accepted' });
    expect(r.body.data).toMatchObject({ status: 'Accepted', action_label: 'Prepare' });
    const [row] = await w.db.query<{ status: string }>(`select status from ol_orders where id = $1`, [olId]);
    expect(row!.status).toBe('accepted');
  });

  it('records a manual Zomato order as a central order, and rejecting cancels it', async () => {
    const r = await api('POST', '/v1/operations/online-orders', { platform: 'Zomato', customer: 'Kabir', items_label: '1x Paneer Tikka', amount_minor: 29000 });
    expect(r.status).toBe(201);
    expect(r.body.data).toMatchObject({ platform: 'Zomato', status: 'Pending', amount_minor: 29000 });
    const del = await api('DELETE', `/v1/operations/online-orders/${r.body.data.order_id}`);
    expect(del.status).toBe(204);
    const [o] = await w.db.query<{ status: string; channel: string }>(`select status, channel from orders where channel = 'zomato'`);
    expect(o).toEqual({ status: 'cancelled', channel: 'zomato' });
  });

  it("doesn't let another organization see or touch it", async () => {
    const burger = await login(w, 'admin@burgerexpress.test');
    const rows = (await call(w, 'GET', '/v1/operations/online-orders', { token: burger })).body.data;
    expect(rows).toEqual([]);
    const r = await call(w, 'POST', `/v1/operations/online-orders/ol:${olId}/status`, { token: burger, body: { status: 'Cancelled' } });
    expect(r.status).toBe(404);
  });
});

describe('store settings', () => {
  it('toggles a sales channel and saves bill settings', async () => {
    const ch = await api('POST', '/v1/operations/channels', { channel: 'swiggy', display_name: 'Swiggy', is_accepting: true });
    expect(ch.status).toBe(201);
    const off = await api('PATCH', `/v1/operations/channels/${ch.body.data.id}`, { is_accepting: false });
    expect(off.body.data.is_accepting).toBe(false);
    const put = await api('PUT', '/v1/operations/bill-settings', { gstin: '07AABCS1234F1Z5', sgst_pct: 2.5, cgst_pct: 2.5 });
    expect(put.body.data.gstin).toBe('07AABCS1234F1Z5');
    expect((await api('GET', '/v1/operations/bill-settings')).body.data.gstin).toBe('07AABCS1234F1Z5');
  });

  it('keeps reservations per branch through the REST API', async () => {
    const put = await api('PUT', '/v1/operations/reservations', {
      id: 'RSV-1', guest_name: 'Meera', phone: '+91 98765 43210', email: '', guests: 4,
      scheduled_at: '2026-09-29T19:30:00.000Z', status: 'confirmed', table_id: null, notes: 'Anniversary',
    });
    expect(put.status).toBe(200);
    const list = (await api('GET', '/v1/operations/reservations')).body.data;
    expect(list).toHaveLength(1);
    const noida = await call(w, 'GET', '/v1/operations/reservations', { token, location: w.spicy.locationIds[1] });
    expect(noida.body.data).toEqual([]);
  });
});
