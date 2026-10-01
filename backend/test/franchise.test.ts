import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addStaff, call, login, makeWorld, type World } from './helpers.js';

let w: World;
let token: string;
let delhi: string;
let noida: string;

const material = (stock: number, reorder: number) => ({
  id: 'rm-chicken', code: 'RM-POU-001', name: 'Raw Chicken Breast', category: 'Poultry & Meats', unit: 'kg',
  stock_qty: stock, reorder_level: reorder, max_capacity: 200, purchase_cost: 310, last_purchase_price: 305,
  preferred_supplier_id: 'sup-std', hsn: '0207', emoji: '🍗', lead_time_days: 1, active: true, created_at: '2026-09-28T00:00:00.000Z',
});

beforeAll(async () => {
  w = await makeWorld();
  token = await login(w, 'admin@spicybistro.test');
  [delhi, noida] = w.spicy.locationIds as [string, string];
  // Branch stock as the two branch devices would have synced it.
  for (const [loc, stock] of [[delhi, 14], [noida, 82]] as const) {
    const r = await call(w, 'POST', '/v1/sync/push', {
      token,
      location: loc,
      body: { changes: [{ change_id: `rm-${loc}`, resource: 'raw-materials', op: 'upsert', row: material(stock, 15) }] },
    });
    expect(r.body.data.summary.accepted).toBe(1);
  }
});
afterAll(async () => w.close());

describe('branches and staff', () => {
  it('lists, adds and edits branches (org_locations)', async () => {
    const list = await call(w, 'GET', '/v1/franchise/branches', { token });
    expect(list.body.data.map((b: { name: string }) => b.name)).toEqual(['Delhi - Connaught Place', 'Noida Sector 62']);
    const add = await call(w, 'POST', '/v1/franchise/branches', { token, body: { name: 'Bengaluru Indiranagar', code: 'BLR-IND', area: 'Indiranagar' } });
    expect(add.status).toBe(201);
    expect(add.body.data.org_id).toBe(w.spicy.organizationId);
    const me = await call(w, 'GET', '/v1/auth/me', { token });
    expect(me.body.data.locations).toHaveLength(3);
    const edit = await call(w, 'PATCH', `/v1/franchise/branches/${add.body.data.id}`, { token, body: { status: 'Inactive' } });
    expect(edit.body.data.status).toBe('Inactive');
  });

  it('lets only an org admin change branches and roles', async () => {
    await addStaff(w, w.spicy, 'manager@spicybistro.test', 'manager');
    const manager = await login(w, 'manager@spicybistro.test');
    const add = await call(w, 'POST', '/v1/franchise/branches', { token: manager, body: { name: 'Pune' } });
    expect(add.status).toBe(403); // branches are owner / org-admin only
    // Restaurant logins are managed in Staff & Users (the old duplicate
    // /v1/franchise/staff API is gone).
    expect((await call(w, 'GET', '/v1/franchise/staff', { token })).status).toBe(404);
    const seeded = await call(w, 'POST', '/v1/staff/roles/seed', { token });
    const roleId = (name: string) => seeded.body.data.find((r: { name: string }) => r.name === name).id as string;
    const staff = await call(w, 'GET', '/v1/staff/logins', { token });
    const mgr = staff.body.data.find((s: { email: string }) => s.email === 'manager@spicybistro.test');
    // An old "manager" login works as a Branch Manager.
    expect(mgr).toMatchObject({ pos_role: 'location_manager', pos_role_name: 'Branch Manager' });
    const promote = await call(w, 'PATCH', `/v1/staff/logins/${mgr.user_id}`, { token, body: { role_id: roleId('Captain') } });
    expect(promote.body.data).toMatchObject({ role_name: 'Captain', pos_role: 'captain' });
    // An owner-level account adds a cashier for Noida who can then sign in to the POS.
    const addStaffRes = await call(w, 'POST', '/v1/staff/logins', {
      token,
      body: { first_name: 'Ravi', last_name: 'Cashier', email: 'ravi@spicybistro.test', phone_number: '+91 98765 11111', password: 'Cashier@2026', role_id: roleId('Cashier'), location_id: noida },
    });
    expect(addStaffRes.status).toBe(201);
    const ravi = await call(w, 'POST', '/v1/auth/login', { body: { email: 'ravi@spicybistro.test', password: 'Cashier@2026' } });
    expect(ravi.body.data.me).toMatchObject({ panel: 'pos', member: { role: 'biller' }, location: { id: noida } });
    // A branch cashier sees only that branch.
    expect(ravi.body.data.me.locations.map((l: { id: string }) => l.id)).toEqual([noida]);
    const dup = await call(w, 'POST', '/v1/staff/logins', {
      token,
      body: { first_name: 'Ravi', last_name: 'Again', email: 'ravi@spicybistro.test', phone_number: '+91 98765 22222', password: 'Cashier@2026', role_id: roleId('Cashier') },
    });
    expect(dup.status).toBe(409);
  });
});

describe('chain analytics', () => {
  beforeAll(async () => {
    const orders = [
      [delhi, 1000],
      [delhi, 500],
      [noida, 2000],
    ] as const;
    for (const [loc, price] of orders) {
      const o = await call(w, 'POST', '/v1/operations/orders', { token, location: loc, body: { gst_pct: 0, items: [{ name: 'Thali', qty: 1, unit_price: price }] } });
      await call(w, 'POST', `/v1/operations/orders/${o.body.data.id}/status`, { token, location: loc, body: { status: 'awaiting_payment' } });
      await call(w, 'POST', `/v1/operations/orders/${o.body.data.id}/payments`, { token, location: loc, body: { method: 'cash', amount: price } });
    }
    // Branch days run on India time.
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
    const r = await call(w, 'POST', '/v1/franchise/targets', {
      token,
      body: { location_id: delhi, period_start: today, period_end: today, sales_target: 3000, labour_cost_pct: 18, food_cost_target_pct: 30 },
    });
    expect(r.status).toBe(201);
  });

  it('computes the overview from real orders, targets and stock', async () => {
    const o = (await call(w, 'GET', '/v1/franchise/overview', { token })).body.data;
    expect(o).toMatchObject({
      total_sales_minor: 350000,
      total_orders: 3,
      average_order_value_minor: 116667,
      labour_cost_pct: 18,
      critical_items: 1,
      inventory_value_minor: (14 + 82) * 310 * 100,
      customer_rating: null,
    });
    expect(o.sales_vs_target_pct).toBeCloseTo(16.7, 1); // 3500 vs 3000
    expect(o.operating_profit_minor).toBe(350000 - Math.round(350000 * 0.18));
  });

  it('ranks branches with target attainment and a health index', async () => {
    const perf = (await call(w, 'GET', '/v1/franchise/branch-performance', { token })).body.data.branches;
    expect(perf.map((b: { branch_name: string }) => b.branch_name).slice(0, 2)).toEqual(['Noida Sector 62', 'Delhi - Connaught Place']);
    const d = perf.find((b: { location_id: string }) => b.location_id === delhi);
    expect(d).toMatchObject({ revenue_minor: 150000, orders: 2, target_met_pct: 50, critical_items: 1 });
    expect(d.health_index).toBeGreaterThan(0);
  });

  it('shows stock across branches and suggests a lateral transfer', async () => {
    const inv = (await call(w, 'GET', '/v1/franchise/inventory', { token })).body.data;
    expect(inv.materials[0].branches.map((b: { status: string }) => b.status).sort()).toEqual(['Critical', 'Surplus']);
    expect(inv.transfer_suggestions).toEqual([
      expect.objectContaining({ material_id: 'rm-chicken', from_location_id: noida, to_location_id: delhi, quantity: 16 }),
    ]);
  });

  it('raises a de-duplicated stock exception', async () => {
    const first = await call(w, 'POST', '/v1/franchise/exceptions/generate', { token });
    expect(first.body.data.created).toBe(1);
    expect(first.body.data.exceptions[0]).toMatchObject({ action_type: 'Transfer', source: 'system', location_id: delhi });
    const again = await call(w, 'POST', '/v1/franchise/exceptions/generate', { token });
    expect(again.body.data.created).toBe(0);
    const resolved = await call(w, 'POST', '/v1/franchise/exceptions/resolve-all', { token });
    expect(resolved.body.data.resolved).toBe(1);
  });

  it('executes a stock transfer: both branches, movements and a record', async () => {
    const r = await call(w, 'POST', '/v1/franchise/stock-transfers', {
      token,
      body: { material_id: 'rm-chicken', from_location_id: noida, to_location_id: delhi, quantity: 30 },
    });
    expect(r.status).toBe(201);
    expect(r.body.data).toMatchObject({ record_type: 'stock_transfer', status: 'completed' });
    // Each branch device pulls its new stock and the movement.
    const d = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['raw-materials', 'stock-movements'] } });
    expect(d.body.data.resources['raw-materials'].rows[0].stock_qty).toBe(44);
    expect(d.body.data.resources['stock-movements'].rows[0]).toMatchObject({ material_id: 'rm-chicken', qty_delta: 30, reason: 'Transfer In' });
    const n = await call(w, 'POST', '/v1/sync/pull', { token, location: noida, body: { resources: ['raw-materials', 'stock-movements'] } });
    expect(n.body.data.resources['raw-materials'].rows[0].stock_qty).toBe(52);
    expect(n.body.data.resources['stock-movements'].rows[0].qty_delta).toBe(-30);
    const tooMuch = await call(w, 'POST', '/v1/franchise/stock-transfers', {
      token,
      body: { material_id: 'rm-chicken', from_location_id: noida, to_location_id: delhi, quantity: 999 },
    });
    expect(tooMuch.status).toBe(409);
  });

  it('lists purchase orders waiting for approval and records the decision', async () => {
    const po = {
      number: 'PO-1050', supplier_id: 'sup-std', order_date: '2026-09-28T00:00:00.000Z', expected_delivery: '2026-09-30T00:00:00.000Z',
      status: 'Pending', created_by: 'Chef Rahul', delivery_address: '', delivery_city: 'Delhi', tax_pct: 5, notes: '', updated_at: '2026-09-28T00:00:00.000Z',
    };
    const line = { id: 1, po_number: 'PO-1050', material_id: 'rm-chicken', material_name: 'Raw Chicken Breast', code: 'RM-POU-001', unit: 'kg', unit_cost: 320, ordered_qty: 40, received_qty: 0, rejected_qty: 0 };
    await call(w, 'POST', '/v1/sync/push', {
      token,
      location: delhi,
      body: {
        changes: [
          { change_id: 'po-1', resource: 'purchase-orders', op: 'upsert', row: po },
          { change_id: 'po-1-l1', resource: 'purchase-order-lines', op: 'upsert', row: line },
        ],
      },
    });
    const req = (await call(w, 'GET', '/v1/franchise/purchase-requirements', { token })).body.data;
    expect(req).toEqual([expect.objectContaining({ po_number: 'PO-1050', branch_name: 'Delhi - Connaught Place', quantity: 40, amount_minor: 1280000 })]);
    const decide = await call(w, 'POST', `/v1/franchise/purchase-orders/${req[0].row_id}/decision`, { token, body: { decision: 'approve' } });
    expect(decide.body.data.status).toBe('Approved');
    const pulled = await call(w, 'POST', '/v1/sync/pull', { token, location: delhi, body: { resources: ['purchase-orders'] } });
    expect(pulled.body.data.resources['purchase-orders'].rows[0].status).toBe('Approved');
  });

  it('keeps chain records (audits, incidents) per organization', async () => {
    const r = await call(w, 'POST', '/v1/franchise/records', {
      token,
      body: { record_type: 'audit_report', title: 'Delhi CP kitchen audit', location_id: delhi, details: { score: 92, grade: 'A' } },
    });
    expect(r.status).toBe(201);
    expect(r.body.data.created_by_name).toBe('Asha Admin');
    const burger = await login(w, 'admin@burgerexpress.test');
    expect((await call(w, 'GET', '/v1/franchise/records', { token: burger })).body.data).toEqual([]);
    const list = await call(w, 'GET', '/v1/franchise/records?record_type=audit_report', { token });
    expect(list.body.data).toHaveLength(1);
  });
});
