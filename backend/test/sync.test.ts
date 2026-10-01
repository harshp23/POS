import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addStaff, call, login, makeWorld, type World } from './helpers.js';

let w: World;
let token: string;
let delhi: string;
let noida: string;
beforeAll(async () => {
  w = await makeWorld();
  token = await login(w, 'admin@spicybistro.test');
  [delhi, noida] = w.spicy.locationIds as [string, string];
});
afterAll(async () => w.close());

// An hour ago: the server hands a device the orders of the last 36 hours,
// so fixed dates would fall out of that window as the calendar moves on.
const base = Date.now() - 3600 * 1000;
const t0 = new Date(base).toISOString();
const at = (minutes: number) => new Date(base + minutes * 60 * 1000).toISOString();

/// Device rows exactly as the Flutter app's CloudSyncService sends them
/// (Drift column names, ISO timestamps, integer paise).
type DeviceChange = { resource: string; row: Record<string, unknown> };

const deviceBatch = (): DeviceChange[] => [
  { resource: 'menu-categories', row: { id: 'main_course', name: 'MAIN COURSE', created_at: t0 } },
  {
    resource: 'menu-items',
    row: {
      id: 'dish_sb_01', category_id: 'main_course', name: 'Spicy Butter Chicken', price_minor: 38000, is_veg: false,
      is_bestseller: true, available: true, unavailable_reason: null, created_at: t0, sku: 'SB-BC-001', hsn: '21069099',
      food_cost_minor: 11400, channels: 'POS, Zomato, Swiggy', kitchen_station: 'North Indian Curry Counter',
      menu_status: 'Active', availability_label: 'In Stock', image_url: '', diet_type: 'non-veg',
      details_json: '{"prepTime":15,"description":"Tandoor-roasted chicken in makhani gravy"}',
    },
  },
  {
    resource: 'menu-items',
    row: {
      id: 'dish_sb_03', category_id: 'breads', name: 'Garlic Butter Naan', price_minor: 6000, is_veg: true,
      is_bestseller: false, available: true, unavailable_reason: null, created_at: t0, sku: 'SB-GBN-003', hsn: '21069099',
      food_cost_minor: 1200, channels: 'POS', kitchen_station: 'Tandoor Station', menu_status: 'Active',
      availability_label: 'In Stock', image_url: '', diet_type: 'veg', details_json: '{}',
    },
  },
  {
    resource: 'tables',
    row: {
      id: 'T2', label: 'T2', seats: 4, zone: 'indoor', status: 'occupied', guest_count: 3, elapsed_minutes: null,
      order_total_minor: null, reserved_by_name: null, reserved_at: null, created_at: t0, floor: 'Ground Floor',
      shape: 'square', server_name: 'Chef Rahul', payment_pending: false, current_order_id: 'ORD-9981',
      seated_at: t0, last_cleaned_at: null,
    },
  },
  {
    resource: 'orders',
    row: {
      client_order_id: 'ORD-9981', location_id: 'location-demo', currency_code: 'INR', status: 'pendingUpload',
      order_type: 'dineIn', table_label: 'T2', created_at: t0, ops_status: 'settled', channel: 'dineIn', source: 'POS',
      guests: 3, server_name: 'Chef Rahul', notes: '', discount_pct: 10, tax_pct: 5, bill_no: 4801,
      payment_method: 'cash', settled_at: at(40), customer_name: 'Rohan',
    },
  },
  {
    resource: 'order-lines',
    row: { client_order_id: 'ORD-9981', item_id: 'dish_sb_01', name: 'Spicy Butter Chicken', unit_minor: 38000, quantity: 1, station: 'Main Kitchen', is_veg: false, kitchen_done: true },
  },
  {
    resource: 'order-lines',
    row: { client_order_id: 'ORD-9981', item_id: 'dish_sb_03', name: 'Garlic Butter Naan', unit_minor: 6000, quantity: 2, station: 'Tandoor', is_veg: true, kitchen_done: true },
  },
  {
    resource: 'kitchen-tickets',
    row: { ticket_id: 'KOT-4081', client_order_id: 'ORD-9981', status: 'completed', created_at: t0, notes: 'less spicy', urgent: true, completed_at: at(25) },
  },
  {
    resource: 'payments',
    row: { payment_id: 'PAY-ORD-9981', client_order_id: 'ORD-9981', method: 'cash', amount_minor: 47250, received_minor: 50000, recorded_at: at(40) },
  },
  {
    resource: 'settings',
    row: {
      key: 'kds_kitchen_stations',
      value: JSON.stringify([
        { name: 'Tandoor', targetMinutes: 5, colorValue: 0xffff7043, active: true },
        { name: 'Main Kitchen', targetMinutes: 15, colorValue: 0xff76ec00, active: true },
      ]),
    },
  },
  {
    resource: 'raw-materials',
    row: {
      id: 'rm-chicken', code: 'RM-POU-001', name: 'Raw Chicken Breast', category: 'Poultry & Meats', unit: 'kg', stock_qty: 14,
      reorder_level: 15, max_capacity: 120, purchase_cost: 310, last_purchase_price: 305, preferred_supplier_id: 'sup-standard',
      hsn: '0207', emoji: '🍗', lead_time_days: 1, active: true, created_at: t0,
    },
  },
  {
    resource: 'offers',
    row: {
      id: 'OFF-SB-2026-001', title: 'Spicy Bistro Weekend Fest', code: 'SPICYFEST25', campaign_type: 'Flat Discount',
      discount_rule: '25% OFF (Upto ₹100)', min_order: 300, max_discount: 100, start_date: '2026-09-20T00:00:00.000Z',
      end_date: '2026-10-10T00:00:00.000Z', channels: 'POS Dine-In, Zomato', linked_items: 'Spicy Butter Chicken', status: 'Active',
      usage_count: 284, updated_at: t0,
    },
  },
];

const asChanges = (batch: ReturnType<typeof deviceBatch>, prefix: string) =>
  batch.map((c, i) => ({ change_id: `${prefix}-${i}`, resource: c.resource, op: 'upsert' as const, row: c.row }));

const q = (sql: string, params: unknown[] = []) => w.db.query<Record<string, any>>(sql, params);

describe('device push → existing OS tables', () => {
  it('accepts a full device batch', async () => {
    const r = await call(w, 'POST', '/v1/sync/push', { token, location: delhi, body: { changes: asChanges(deviceBatch(), 'dev1') } });
    expect(r.status).toBe(200);
    const bad = r.body.data.results.filter((x: { status: string }) => x.status !== 'accepted');
    expect(bad).toEqual([]);
    expect(r.body.data.summary.accepted).toBe(deviceBatch().length);
  });

  it('writes menu items with rupee prices, OS food_type and station', async () => {
    const items = await q(`select name, price, food_type, station, is_recommended, prep_minutes, description, sku
                             from menu_items where organization_id = $1 order by name`, [w.spicy.organizationId]);
    expect(items).toEqual([
      { name: 'Garlic Butter Naan', price: 60, food_type: 'veg', station: 'Tandoor Station', is_recommended: false, prep_minutes: 10, description: null, sku: 'SB-GBN-003' },
      { name: 'Spicy Butter Chicken', price: 380, food_type: 'non_veg', station: 'North Indian Curry Counter', is_recommended: true, prep_minutes: 15, description: 'Tandoor-roasted chicken in makhani gravy', sku: 'SB-BC-001' },
    ]);
    const cats = await q(`select name from menu_categories where organization_id = $1 order by name`, [w.spicy.organizationId]);
    expect(cats.map((c) => c.name)).toEqual(['Breads', 'MAIN COURSE']); // "breads" auto-created from the item
  });

  it('writes the order with an OS order number, branch, table, totals and settled status', async () => {
    const [o] = await q(`select * from orders where organization_id = $1`, [w.spicy.organizationId]);
    expect(o).toMatchObject({
      display_no: 'ORD-9981',
      order_no: 1,
      location_id: delhi,
      channel: 'dine_in',
      status: 'paid',
      payment_method: 'cash',
      placed_by: 'pos',
      customer_name: 'Rohan',
      captain_name: 'Chef Rahul',
      guest_count: 3,
      // 380 + 2×60 = 500; 10 % off = 50; GST 5 % of 450 = 22.50
      subtotal: 500,
      discount: 50,
      gst_amount: 22.5,
      total: 472.5,
    });
    const [table] = await q(`select id, label, location_id from dining_tables where organization_id = $1`, [w.spicy.organizationId]);
    expect(o.table_id).toBe(table.id);
    expect(table.location_id).toBe(delhi);

    const lines = await q(`select name, qty, unit_price, status, menu_item_id is not null as linked from order_items where order_id = $1 order by name`, [o.id]);
    expect(lines).toEqual([
      { name: 'Garlic Butter Naan', qty: 2, unit_price: 60, status: 'ready', linked: true },
      { name: 'Spicy Butter Chicken', qty: 1, unit_price: 380, status: 'ready', linked: true },
    ]);
    const [kot] = await q(`select kot_no, status, priority from kot_tickets where order_id = $1`, [o.id]);
    expect(kot).toEqual({ kot_no: 1, status: 'delivered', priority: 'urgent' });
    const [pay] = await q(`select method, amount, reference from payments where order_id = $1`, [o.id]);
    expect(pay).toEqual({ method: 'cash', amount: 472.5, reference: 'PAY-ORD-9981' });
  });

  it('writes KDS stations to kitchen_stations and mirrors new-domain rows into pos_* tables', async () => {
    const st = await q(`select key, name, colour, sort_order from kitchen_stations where organization_id = $1 order by sort_order`, [w.spicy.organizationId]);
    expect(st).toEqual([
      { key: 'tandoor', name: 'Tandoor', colour: '#ff7043', sort_order: 0 },
      { key: 'main_kitchen', name: 'Main Kitchen', colour: '#76ec00', sort_order: 1 },
    ]);
    const [rm] = await q(`select id, stock_qty, location_id from pos_raw_materials where organization_id = $1`, [w.spicy.organizationId]);
    expect(rm).toEqual({ id: 'rm-chicken', stock_qty: 14, location_id: delhi });
    const [off] = await q(`select code, usage_count, location_id from pos_offers where organization_id = $1`, [w.spicy.organizationId]);
    expect(off).toEqual({ code: 'SPICYFEST25', usage_count: 284, location_id: delhi });
  });
});

describe('idempotency and conflicts', () => {
  it('answers a retried batch as duplicates with no second effect', async () => {
    const r = await call(w, 'POST', '/v1/sync/push', { token, location: delhi, body: { changes: asChanges(deviceBatch(), 'dev1') } });
    expect(new Set(r.body.data.results.map((x: { status: string }) => x.status))).toEqual(new Set(['duplicate']));
    const [{ n }] = await q(`select count(*)::int n from orders where organization_id = $1`, [w.spicy.organizationId]);
    expect(n).toBe(1);
    const [{ k }] = await q(`select count(*)::int k from payments where organization_id = $1`, [w.spicy.organizationId]);
    expect(k).toBe(1);
  });

  it('re-sending the same records under new change ids is still one record each', async () => {
    const r = await call(w, 'POST', '/v1/sync/push', { token, location: delhi, body: { changes: asChanges(deviceBatch(), 'dev1-again') } });
    expect(r.body.data.summary.accepted).toBe(deviceBatch().length);
    const [{ n }] = await q(`select count(*)::int n from order_items`);
    expect(n).toBe(2);
  });

  it('rejects a change id reused for a different payload', async () => {
    const changes = asChanges(deviceBatch(), 'dev1').slice(0, 1);
    changes[0]!.row = { ...changes[0]!.row, name: 'Mains' };
    const r = await call(w, 'POST', '/v1/sync/push', { token, location: delhi, body: { changes } });
    expect(r.body.data.results[0]).toMatchObject({ status: 'rejected', error: { code: 'change_id_reused' } });
  });

  it('flags an order edited elsewhere since the device last saw it as a conflict', async () => {
    const order = deviceBatch().find((c) => c.resource === 'orders')!.row;
    const r = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: { changes: [{ change_id: 'stale-1', resource: 'orders', op: 'upsert', row: { ...order, notes: 'edited' }, base_version: '2020-01-01T00:00:00+00:00' }] },
    });
    expect(r.body.data.results[0].status).toBe('conflict');
  });

  it('treats a changed payment as a conflict — payment evidence is immutable', async () => {
    const pay = deviceBatch().find((c) => c.resource === 'payments')!.row;
    const r = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: { changes: [{ change_id: 'pay-edit', resource: 'payments', op: 'upsert', row: { ...pay, amount_minor: 100 } }] },
    });
    expect(r.body.data.results[0].status).toBe('conflict');
    const [p] = await q(`select amount from payments`);
    expect(p.amount).toBe(472.5);
  });

  it('refuses to delete orders or payments', async () => {
    const r = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: {
        changes: [
          { change_id: 'del-o', resource: 'orders', op: 'delete', row: { client_order_id: 'ORD-9981' } },
          { change_id: 'del-p', resource: 'payments', op: 'delete', row: { payment_id: 'PAY-ORD-9981' } },
        ],
      },
    });
    expect(r.body.data.results.map((x: { status: string }) => x.status)).toEqual(['rejected', 'rejected']);
  });

  it('keeps floor staff from changing the master catalogue', async () => {
    await addStaff(w, w.spicy, 'captain@spicybistro.test', 'captain');
    const captain = await login(w, 'captain@spicybistro.test');
    const item = deviceBatch().find((c) => c.resource === 'menu-items')!;
    const r = await call(w, 'POST', '/v1/sync/push', {
      token: captain,
      location: delhi,
      body: { changes: [{ change_id: 'cap-1', resource: 'menu-items', op: 'upsert', row: { ...item.row, price_minor: 1 } }] },
    });
    expect(r.body.data.results[0]).toMatchObject({ status: 'rejected', error: { code: 'forbidden' } });
  });

  it('validates device rows against the contract', async () => {
    const r = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: { changes: [{ change_id: 'bad-1', resource: 'orders', op: 'upsert', row: { client_order_id: 'ORD-1', guests: 'three' } }] },
    });
    expect(r.body.data.results[0].status).toBe('rejected');
  });
});

describe('pull', () => {
  it('returns what the device pushed, in device shape (round trip)', async () => {
    const r = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: {} });
    expect(r.status).toBe(200);
    const res = r.body.data.resources;
    const byResource = Object.fromEntries(deviceBatch().map((c) => [c.resource, [] as unknown[]]));
    for (const c of deviceBatch()) byResource[c.resource]!.push(c.row);

    expect(res['menu-items'].rows).toEqual(expect.arrayContaining(byResource['menu-items']!.map((r) => expect.objectContaining(r as object))));
    expect(res['tables'].rows).toEqual([byResource['tables']![0]]);
    // Plus the server's numbers: the order's (a device order keeps its key)
    // and the KOT's.
    expect(res['orders'].rows).toEqual([{ ...(byResource['orders']![0] as object), status: 'synchronized', display_no: 'ORD-9981' }]);
    expect(res['order-lines'].rows).toEqual(expect.arrayContaining(byResource['order-lines']!));
    expect(res['kitchen-tickets'].rows).toEqual(
      byResource['kitchen-tickets']!.map((k) => ({ ...(k as object), kot_no: expect.any(Number) })),
    );
    expect(res['payments'].rows).toEqual(byResource['payments']);
    expect(res['raw-materials'].rows).toEqual(byResource['raw-materials']);
    expect(res['offers'].rows).toEqual(byResource['offers']);
    expect(JSON.parse(res['settings'].rows[0].value)).toEqual(JSON.parse((byResource['settings']![0] as { value: string }).value));
    expect(res['orders'].versions['ORD-9981']).toBeTruthy();
  });

  it('an order made on the server reaches the device with its number and KOT number', async () => {
    const o = await call(w, 'POST', '/v1/operations/orders', {
      token,
      location: delhi,
      body: { channel: 'pickup', gst_pct: 0, items: [{ name: 'QA Thali', unit_price: 100, qty: 1 }] },
    });
    expect(o.status).toBe(201);
    const r = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['orders', 'kitchen-tickets'] } });
    const order = r.body.data.resources.orders.rows.find((x: { client_order_id: string }) => x.client_order_id === o.body.data.id);
    expect(order.display_no).toBe(o.body.data.display_no);
    expect(order.display_no).toMatch(/^ORD-[0-9]+$/);
    const kot = r.body.data.resources['kitchen-tickets'].rows.find((x: { client_order_id: string }) => x.client_order_id === o.body.data.id);
    const [row] = (await w.pg.query<{ kot_no: number }>('select kot_no from kot_tickets where order_id = $1', [o.body.data.id])).rows;
    expect(kot.kot_no).toBe(Number(row!.kot_no));
  });

  it('pulls incrementally from a cursor', async () => {
    const first = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['orders', 'raw-materials'] } });
    const cursors = {
      orders: first.body.data.resources.orders.cursor,
      'raw-materials': first.body.data.resources['raw-materials'].cursor,
    };
    const again = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['orders', 'raw-materials'], cursors } });
    expect(again.body.data.resources.orders.rows).toEqual([]);
    expect(again.body.data.resources['raw-materials'].rows).toEqual([]);
  });

  it("keeps branch data to its branch and the chain catalogue shared", async () => {
    const r = await call(w, 'POST', '/v1/sync/pull', { token, location: noida, body: {} });
    const res = r.body.data.resources;
    expect(res.orders.rows).toEqual([]);
    expect(res.tables.rows).toEqual([]);
    expect(res['raw-materials'].rows).toEqual([]);
    expect(res['menu-items'].rows.length).toBe(2);
    expect(res.offers.rows.length).toBe(1);
  });

  it('shows another organization nothing', async () => {
    const burger = await login(w, 'admin@burgerexpress.test');
    const r = await call(w, 'POST', '/v1/sync/pull', { token: burger, body: {} });
    for (const [name, page] of Object.entries<{ rows: unknown[] }>(r.body.data.resources)) {
      expect(page.rows, name).toEqual([]);
    }
  });

  it('propagates a deletion as a tombstone', async () => {
    const before = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['offers'] } });
    const cursor = before.body.data.resources.offers.cursor;
    await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: { changes: [{ change_id: 'del-offer', resource: 'offers', op: 'delete', row: { id: 'OFF-SB-2026-001' } }] },
    });
    const after = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['offers'], cursors: { offers: cursor } } });
    expect(after.body.data.resources.offers.deleted).toEqual([{ id: 'OFF-SB-2026-001' }]);
  });
});

describe('payments verified on the server', () => {
  const upiOrder = {
    client_order_id: 'ORD-7001', location_id: 'location-demo', currency_code: 'INR', status: 'pendingUpload',
    order_type: 'takeaway', table_label: null, created_at: t0, ops_status: 'billed', channel: 'takeaway', source: 'POS',
    guests: 1, server_name: 'Cashier', notes: '', discount_pct: 0, tax_pct: 5, bill_no: 4802,
    payment_method: 'upi', settled_at: null, customer_name: 'Asha',
  };
  const batch = [
    { resource: 'orders', row: upiOrder },
    { resource: 'order-lines', row: { client_order_id: 'ORD-7001', item_id: 'dish_sb_01', name: 'Spicy Butter Chicken', unit_minor: 38000, quantity: 1, station: 'Main Kitchen', is_veg: false, kitchen_done: false } },
    { resource: 'payments', row: { payment_id: 'PAY-ORD-7001', client_order_id: 'ORD-7001', method: 'upi', amount_minor: 39900, received_minor: 39900, recorded_at: t0 } },
  ];

  it('a manager verifies a device order by its POS id; devices then see it settled and cannot undo it', async () => {
    const pushed = await call(w, 'POST', '/v1/sync/push', { token, location: delhi, body: { changes: asChanges(batch, 'upi') } });
    expect(pushed.body.data.results.map((r: { status: string }) => r.status)).toEqual(['accepted', 'accepted', 'accepted']);

    await addStaff(w, w.spicy, 'books@spicybistro.test', 'location_manager');
    const accountant = await login(w, 'books@spicybistro.test');
    const verified = await call(w, 'POST', '/v1/operations/orders/ORD-7001/verify-payment', { token: accountant, location: delhi, body: { note: 'UTR 998877' } });
    expect(verified.status).toBe(200);
    expect(verified.body.data.status).toBe('paid');
    const orderId = verified.body.data.id as string;

    // Another branch cannot reach it by that key.
    const other = await call(w, 'POST', '/v1/operations/orders/ORD-7001/verify-payment', { token: accountant, location: noida, body: {} });
    expect(other.status).toBe(404);

    const pulled = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['orders'] } });
    const row = pulled.body.data.resources.orders.rows.find((r: { client_order_id: string }) => r.client_order_id === 'ORD-7001');
    expect(row.ops_status).toBe('settled');
    expect(row.settled_at).toBeTruthy();

    // A device that has not synced yet sends its old "billed" copy again.
    const stale = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: { changes: [{ change_id: 'upi-stale', resource: 'orders', op: 'upsert', row: { ...upiOrder, notes: 'late edit' } }] },
    });
    expect(stale.body.data.results[0].status).toBe('accepted');
    const [o] = await q('select status, paid_at from orders where id = $1', [orderId]);
    expect(o!.status).toBe('paid');
    expect(o!.paid_at).toBeTruthy();
  });
});

describe('floor plan made in the back office', () => {
  it("a device updating a back-office table reuses that table's area", async () => {
    const area = await call(w, 'POST', '/v1/operations/dining-areas', { token, location: delhi, body: { name: 'Rooftop' } });
    expect(area.status).toBe(201);
    const table = await call(w, 'POST', '/v1/operations/dining-tables', { token, location: delhi, body: { label: 'R1', seats: 4, area_id: area.body.data.id } });
    expect(table.status).toBe(201);
    const tableId = table.body.data.id as string;

    // The device pulled it (key = the server id) and seats guests there.
    const pushed = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: {
        changes: [
          {
            change_id: 'rooftop-1', resource: 'tables', op: 'upsert',
            row: {
              id: tableId, label: 'R1', seats: 4, zone: 'outdoor', status: 'occupied', guest_count: 2, elapsed_minutes: null,
              order_total_minor: null, reserved_by_name: null, reserved_at: null, created_at: t0, floor: 'Rooftop',
              shape: 'square', server_name: '', payment_pending: false, current_order_id: null, seated_at: t0, last_cleaned_at: null,
            },
          },
        ],
      },
    });
    expect(pushed.body.data.results[0], JSON.stringify(pushed.body.data.results[0])).toMatchObject({ status: 'accepted' });
    const [t] = await q('select area_id from dining_tables where id = $1', [tableId]);
    expect(t!.area_id).toBe(area.body.data.id);
    const areas = await q("select count(*)::int as n from dining_areas where location_id = $1 and name = 'Rooftop'", [delhi]);
    expect(areas[0]!.n).toBe(1);
  });
});
