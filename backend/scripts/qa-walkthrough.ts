/**
 * QA walkthrough of the restaurant vendor panel's backend, run against a
 * RUNNING POS backend (local `npm run start:local`, or a staging/live one):
 *
 *   QA_BASE=http://localhost:8787 QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… \
 *     npx tsx scripts/qa-walkthrough.ts
 *
 * Starting from a restaurant owner's login (created in master-admin), it
 *   1. creates a test login for every built-in role through the Staff API the
 *      Flutter "Staff & Users" screens use (seeded + custom staff roles),
 *   2. signs in as each and checks the screens the server grants and every
 *      protected data call — allowed ones must succeed, the rest must be
 *      refused (expectations come from src/permissions.ts + src/access.ts),
 *   3. checks branch and restaurant isolation,
 *   4. runs create / read / update / delete through each module as the owner,
 *   5. checks sign-out.
 * It writes a markdown report to docs/qa/ and exits non-zero on a failure.
 * It creates data (logins, menu items, orders…) — never point it at
 * production without the owner's go-ahead.
 */
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { defaultScreens } from '../src/access.js';
import { BRANCH_BOUND_ROLES, can, canPlaceOrders, canTakePayments, canVerifyPayments, panelFor, POS_ROLE_NAMES, POS_ROLES } from '../src/permissions.js';

const BASE = (process.env.QA_BASE ?? 'http://localhost:8787').replace(/\/$/, '');
const OWNER_EMAIL = process.env.QA_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.QA_OWNER_PASSWORD;
if (!OWNER_EMAIL || !OWNER_PASSWORD) {
  console.error('Set QA_OWNER_EMAIL and QA_OWNER_PASSWORD (a restaurant owner login created in master-admin).');
  process.exit(2);
}
const RUN = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14) + randomBytes(2).toString('hex');
const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

interface Result {
  section: string;
  check: string;
  expected: string;
  actual: string;
  pass: boolean;
}
const results: Result[] = [];
const record = (section: string, check: string, expected: string, actual: string, pass: boolean) => {
  results.push({ section, check, expected, actual, pass });
  console.log(`${pass ? 'PASS' : 'FAIL'}  [${section}] ${check} — expected ${expected}, got ${actual}`);
};

interface Res {
  status: number;
  body: any;
}
async function call(method: string, path: string, opts: { token?: string; body?: unknown; headers?: Record<string, string> } = {}): Promise<Res> {
  const headers: Record<string, string> = { Accept: 'application/json', ...(opts.headers ?? {}) };
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(`${BASE}${path}`, { method, headers, body: opts.body === undefined ? undefined : JSON.stringify(opts.body) });
  const text = await res.text();
  let body: any = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body };
}
const ok = (r: Res) => r.status >= 200 && r.status < 300;
const data = (r: Res) => r.body?.data;

/// Expect success; returns the data or throws with the server's message.
async function must(section: string, check: string, r: Promise<Res>): Promise<any> {
  const res = await r;
  const pass = ok(res);
  record(section, check, '2xx', `${res.status}${pass ? '' : ` ${res.body?.error?.code ?? ''} ${res.body?.error?.message ?? ''}`}`, pass);
  if (!pass) throw new Error(`${check} failed`);
  return data(res);
}
async function expectStatus(section: string, check: string, r: Promise<Res>, expected: number | 'ok') {
  const res = await r;
  const pass = expected === 'ok' ? ok(res) : res.status === expected;
  record(section, check, String(expected), `${res.status}${pass || !res.body?.error ? '' : ` ${res.body.error.code}`}`, pass);
  return res;
}

async function signIn(email: string, password: string) {
  const r = await call('POST', '/v1/auth/login', { body: { email, password } });
  if (!ok(r)) throw new Error(`sign-in ${email}: ${r.status} ${JSON.stringify(r.body)}`);
  return { token: data(r).session.access_token as string, me: data(r).me };
}

async function main() {
  console.log(`QA walkthrough against ${BASE} (run ${RUN})\n`);
  await expectStatus('Platform', 'backend health', call('GET', '/health'), 'ok');

  // ── 1. owner ──────────────────────────────────────────────────────────
  const owner = await signIn(OWNER_EMAIL!, OWNER_PASSWORD!);
  const O = owner.token;
  record('Owner', 'signs in with the master-admin account', 'role org_owner', owner.me.member.role, owner.me.member.role === 'org_owner');
  record('Owner', 'lands in the vendor panel', 'vendor', owner.me.panel, owner.me.panel === 'vendor');
  const ownerScreens = new Set<string>(owner.me.screens);
  const missing = defaultScreens('org_owner').filter((s) => !ownerScreens.has(s));
  record('Owner', 'gets every vendor screen', 'all', missing.length ? `missing ${missing.join(',')}` : 'all', missing.length === 0);
  const branch = owner.me.location?.id as string | undefined;
  record('Owner', 'has a branch (created in master-admin)', 'a branch', owner.me.location?.name ?? 'none', Boolean(branch));
  const orgName = owner.me.organization.name as string;

  // ── 2. a login for every built-in role, through the Staff API ─────────
  const seeded: any[] = await must('Staff setup', 'seed default staff roles', call('POST', '/v1/staff/roles/seed', { token: O }));
  const roleByBase = new Map<string, any>();
  for (const r of seeded) if (!roleByBase.has(r.base_role)) roleByBase.set(r.base_role, r);
  for (const base of POS_ROLES) {
    if (base === 'org_owner' || roleByBase.has(base)) continue;
    const role = await must('Staff setup', `create staff role for ${base}`, call('POST', '/v1/staff/roles', { token: O, body: { name: `QA ${POS_ROLE_NAMES[base]} ${RUN}`, base_role: base } }));
    roleByBase.set(base, role);
  }
  const accounts: { base: string; email: string; password: string; roleName: string }[] = [];
  for (const base of POS_ROLES) {
    if (base === 'org_owner') continue;
    const role = roleByBase.get(base);
    const email = `qa-${base.replace(/_/g, '-')}-${RUN}@qa.proviyaa.test`;
    const password = `Qa-${randomBytes(6).toString('hex')}-A1`;
    await must(
      'Staff setup',
      `add employee + login as ${role.name} (${base})`,
      call('POST', '/v1/staff/employees', {
        token: O,
        body: {
          full_name: `QA ${POS_ROLE_NAMES[base]}`,
          mobile: '+91 90000 00000',
          email,
          designation: POS_ROLE_NAMES[base],
          location_id: branch ?? null,
          login: { password, role_id: role.id },
        },
      }),
    );
    accounts.push({ base, email, password, roleName: role.name });
  }
  mkdirSync(new URL('../.data/', import.meta.url), { recursive: true });
  writeFileSync(
    new URL(`../.data/qa-run-${RUN}.txt`, import.meta.url),
    `QA logins created by run ${RUN} against ${BASE} (${orgName}) — test accounts only\n` +
      accounts.map((a) => `${a.base.padEnd(20)} ${a.email}  ${a.password}`).join('\n') +
      '\n',
  );

  // Orders the verify-payment checks work on.
  const menuCat = await must('Setup', 'menu category for QA', call('POST', '/v1/master/menu-categories', { token: O, body: { name: `QA Cat ${RUN}` } }));
  const dish = await must('Setup', 'menu item for QA', call('POST', '/v1/master/menu-items', { token: O, body: { name: `QA Dal ${RUN}`, price: 150, category_id: menuCat.id } }));
  const awaitingUpiOrder = async () => {
    const o = await must('Setup', 'order for a verify-payment check', call('POST', '/v1/operations/orders', { token: O, body: { channel: 'pickup', items: [{ menu_item_id: dish.id, qty: 1 }] } }));
    await call('POST', `/v1/operations/orders/${o.id}/payments`, { token: O, body: { method: 'upi', amount: Number(o.total) } });
    return o.id as string;
  };
  const sharedAwaiting = await awaitingUpiOrder();

  // ── 3. every role: screens + every protected data call ───────────────
  const checks: { name: string; allowed: (base: string, screens: Set<string>) => boolean; run: (t: string) => Promise<Res> }[] = [
    { name: 'franchise overview', allowed: (b) => can(b, 'franchise', 'read') && !BRANCH_BOUND_ROLES.has(b), run: (t) => call('GET', '/v1/franchise/overview', { token: t }) },
    { name: 'read menu', allowed: (b) => can(b, 'master', 'read'), run: (t) => call('GET', '/v1/master/menu-items', { token: t }) },
    {
      name: 'create menu category',
      allowed: (b) => can(b, 'master', 'write'),
      run: async (t) => {
        const r = await call('POST', '/v1/master/menu-categories', { token: t, body: { name: `QA tmp ${randomBytes(3).toString('hex')}` } });
        if (ok(r)) await call('DELETE', `/v1/master/menu-categories/${data(r).id}`, { token: O });
        return r;
      },
    },
    { name: 'list orders', allowed: (b) => can(b, 'operations', 'read'), run: (t) => call('GET', '/v1/operations/orders', { token: t }) },
    {
      name: 'take an order',
      allowed: (b) => canPlaceOrders(b),
      run: (t) => call('POST', '/v1/operations/orders', { token: t, body: { channel: 'pickup', items: [{ menu_item_id: dish.id, qty: 1 }] } }),
    },
    { name: 'kitchen queue', allowed: (b) => can(b, 'operations', 'read'), run: (t) => call('GET', '/v1/operations/kot-tickets', { token: t }) },
    {
      name: 'take a cash payment',
      allowed: (b) => canTakePayments(b),
      run: async (t) => {
        const o = await call('POST', '/v1/operations/orders', { token: O, body: { channel: 'pickup', items: [{ menu_item_id: dish.id, qty: 1 }] } });
        return call('POST', `/v1/operations/orders/${data(o).id}/payments`, { token: t, body: { method: 'cash', amount: Number(data(o).total) } });
      },
    },
    {
      name: 'verify a UPI payment',
      allowed: (b) => canVerifyPayments(b),
      run: async (t) => call('POST', `/v1/operations/orders/${sharedAwaiting}/verify-payment`, { token: t, body: { reference: 'QA' } }),
    },
    { name: 'staff directory', allowed: (_b, s) => [...s].some((x) => x.startsWith('staff.')), run: (t) => call('GET', '/v1/staff/employees', { token: t }) },
    { name: 'salaries', allowed: (_b, s) => s.has('staff.salary'), run: (t) => call('GET', '/v1/staff/salaries', { token: t }) },
    { name: 'attendance', allowed: (_b, s) => s.has('staff.attendance'), run: (t) => call('GET', '/v1/staff/attendance', { token: t }) },
    { name: 'staff roles', allowed: (_b, s) => s.has('staff.roles') || s.has('staff.directory'), run: (t) => call('GET', '/v1/staff/roles', { token: t }) },
    { name: 'login security', allowed: (_b, s) => s.has('staff.login_security'), run: (t) => call('GET', '/v1/staff/login-history', { token: t }) },
    { name: 'audit log', allowed: (_b, s) => s.has('staff.audit_log'), run: (t) => call('GET', '/v1/staff/audit-log', { token: t }) },
    {
      name: 'sync pull (menu + orders)',
      allowed: () => true, // every role may pull what it may read; the server skips the rest
      run: (t) => call('POST', '/v1/sync/pull', { token: t, body: { resources: ['menu-items', 'orders'] } }),
    },
  ];

  for (const a of accounts) {
    const section = `Role ${a.base}`;
    let session;
    try {
      session = await signIn(a.email, a.password);
    } catch (e) {
      record(section, 'signs in', '200', String(e), false);
      continue;
    }
    const me = session.me;
    const expectedPanel = panelFor(a.base);
    record(section, 'signs in and is resolved to its role', a.base, me.member.role, me.member.role === a.base);
    record(section, 'opens the right app', expectedPanel, me.panel, me.panel === expectedPanel);
    const screens = new Set<string>(me.screens);
    const want = new Set(roleByBase.get(a.base).screens as string[]);
    const same = screens.size === want.size && [...want].every((s) => screens.has(s));
    record(section, 'gets exactly its role screens', `${want.size} screens`, `${screens.size} screens`, same);
    const scoped = BRANCH_BOUND_ROLES.has(a.base);
    record(section, 'branch scope', scoped ? 'own branch only' : 'all branches', `${me.locations.length} branch(es)`, scoped ? me.locations.length === 1 : true);
    for (const c of checks) {
      if (c.name === 'verify a UPI payment' && c.allowed(a.base, screens)) {
        const id = await awaitingUpiOrder();
        const r = await call('POST', `/v1/operations/orders/${id}/verify-payment`, { token: session.token, body: { reference: 'QA' } });
        record(section, c.name, 'allowed', String(r.status), ok(r));
        continue;
      }
      const allowed = c.allowed(a.base, screens);
      const r = await c.run(session.token);
      const pass = allowed ? ok(r) : r.status === 403;
      record(section, c.name, allowed ? 'allowed' : 'refused (403)', `${r.status}${ok(r) ? '' : ` ${r.body?.error?.code ?? ''}`}`, pass);
    }
    // A restaurant account can never switch into another restaurant.
    await expectStatus(section, 'cannot open another restaurant', call('GET', '/v1/auth/me', { token: session.token, headers: { 'X-Organization-Id': '00000000-0000-4000-8000-000000000000' } }), 403);
    await call('POST', '/v1/auth/logout', { token: session.token });
    await expectStatus(section, 'signed-out token is refused', call('GET', '/v1/auth/me', { token: session.token }), 401);
  }

  // ── 4. branch isolation ───────────────────────────────────────────────
  const second = await must('Branches', 'owner opens a second branch', call('POST', '/v1/franchise/branches', { token: O, body: { name: `QA Branch ${RUN}`, code: `QA-${RUN.slice(-4)}` } }));
  const cashier = accounts.find((a) => a.base === 'biller')!;
  const c1 = await signIn(cashier.email, cashier.password);
  await expectStatus('Branches', "cashier cannot read the other branch's orders", call('GET', '/v1/operations/orders', { token: c1.token, headers: { 'X-Location-Id': second.id } }), 403);
  await expectStatus('Branches', "cashier cannot list the other branch's orders by filter", call('GET', `/v1/operations/orders?location_id=${second.id}`, { token: c1.token }), 403);
  await expectStatus('Branches', 'owner can open the second branch', call('GET', '/v1/operations/orders', { token: O, headers: { 'X-Location-Id': second.id } }), 'ok');

  // ── 5. CRUD through each module as the owner ─────────────────────────
  const M = 'CRUD Master';
  const item = await must(M, 'create menu item', call('POST', '/v1/master/menu-items', { token: O, body: { name: `QA Paneer ${RUN}`, price: 320, category_id: menuCat.id, food_type: 'veg' } }));
  const upd = await must(M, 'update menu item price', call('PATCH', `/v1/master/menu-items/${item.id}`, { token: O, body: { price: 340 } }));
  record(M, 'price saved', '340', String(upd.price), Number(upd.price) === 340);
  await must(M, 'read menu item', call('GET', `/v1/master/menu-items/${item.id}`, { token: O }));
  await expectStatus(M, 'delete menu item', call('DELETE', `/v1/master/menu-items/${item.id}`, { token: O }), 204);
  const rmKey = `qa-rm-${RUN}`;
  const rm = await must(M, 'create raw material', call('PUT', '/v1/master/raw-materials', {
    token: O,
    body: { id: rmKey, code: `RM-${RUN.slice(-4)}`, name: 'QA Basmati Rice', category: 'Grains', unit: 'kg', stock_qty: 25, reorder_level: 10, max_capacity: 100, purchase_cost: 90, hsn: '1006', emoji: '🍚', lead_time_days: 2, active: true, created_at: new Date().toISOString() },
  }));
  const rmList: any[] = await must(M, 'list raw materials', call('GET', '/v1/master/raw-materials', { token: O }));
  record(M, 'raw material listed', 'present', rmList.some((r) => r.row_id === rm.row_id) ? 'present' : 'missing', rmList.some((r) => r.row_id === rm.row_id));
  await must(M, 'update stock (upsert same key)', call('PUT', '/v1/master/raw-materials', {
    token: O,
    body: { id: rmKey, code: `RM-${RUN.slice(-4)}`, name: 'QA Basmati Rice', category: 'Grains', unit: 'kg', stock_qty: 8, reorder_level: 10, max_capacity: 100, purchase_cost: 90, hsn: '1006', emoji: '🍚', lead_time_days: 2, active: true, created_at: new Date().toISOString() },
  }));
  await must(M, 'create supplier', call('PUT', '/v1/master/suppliers', {
    token: O,
    body: { id: `qa-sup-${RUN}`, name: 'QA Grains Co', legal_name: 'QA Grains Pvt Ltd', category: 'Grains', contact_person: 'Ravi', phone: '+91 90000 11111', email: 'grains@qa.test', gstin: '27AAAAA0000A1Z5', city: 'Latur', rating: 4, payment_terms: 'Net 15', active: true, created_at: new Date().toISOString() },
  }));
  await expectStatus(M, 'delete raw material', call('DELETE', `/v1/master/raw-materials/${rm.row_id}`, { token: O }), 204);

  const P = 'CRUD Operations';
  const area = await must(P, 'create dining area', call('POST', '/v1/operations/dining-areas', { token: O, body: { name: `QA Terrace ${RUN}` } }));
  const table = await must(P, 'create table', call('POST', '/v1/operations/dining-tables', { token: O, body: { label: `Q${RUN.slice(-3)}`, seats: 4, area_id: area.id } }));
  await must(P, 'update table seats', call('PATCH', `/v1/operations/dining-tables/${table.id}`, { token: O, body: { seats: 6 } }));
  const order = await must(P, 'place a dine-in order', call('POST', '/v1/operations/orders', { token: O, body: { channel: 'dine_in', table_id: table.id, guest_count: 2, items: [{ menu_item_id: dish.id, qty: 2 }] } }));
  record(P, 'menu price used (client cannot set it)', '₹300 subtotal', `₹${order.subtotal}`, Number(order.subtotal) === 300);
  const kots: any[] = await must(P, 'kitchen queue shows the KOT', call('GET', '/v1/operations/kot-tickets', { token: O }));
  const kot = kots.find((k) => k.order_id === order.id);
  record(P, 'KOT created with the order', 'present', kot ? kot.status : 'missing', Boolean(kot));
  if (kot) {
    const adv = await must(P, 'advance KOT', call('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, { token: O }));
    record(P, 'KOT moved forward', 'preparing', adv.status, adv.status === 'preparing');
  }
  await expectStatus(P, '"paid" cannot be set by a status change', call('POST', `/v1/operations/orders/${order.id}/status`, { token: O, body: { status: 'paid' } }), 409);
  await expectStatus(P, 'overpayment refused', call('POST', `/v1/operations/orders/${order.id}/payments`, { token: O, body: { method: 'cash', amount: 99999 } }), 422);
  const paid = await must(P, 'cash payment settles', call('POST', `/v1/operations/orders/${order.id}/payments`, { token: O, body: { method: 'cash', amount: Number(order.total) } }));
  record(P, 'order paid by cash', 'paid', paid.status, paid.status === 'paid');
  const upiId = await awaitingUpiOrder();
  const upi = await must(P, 'UPI order detail', call('GET', `/v1/operations/orders/${upiId}`, { token: O }));
  record(P, 'UPI waits for verification', 'awaiting_payment', upi.status, upi.status === 'awaiting_payment');
  const verified = await must(P, 'owner verifies UPI', call('POST', `/v1/operations/orders/${upiId}/verify-payment`, { token: O, body: { reference: 'UPI-QA-1' } }));
  record(P, 'verified order is paid', 'paid', verified.status, verified.status === 'paid');

  // A POS device's UPI order, verified by the branch manager with the id the
  // device knows it by; the cashier's device then pulls it back settled.
  const branchManager = accounts.find((a) => a.base === 'location_manager')!;
  const acc = await signIn(branchManager.email, branchManager.password);
  const devKey = `QA-ORD-${RUN.slice(-6)}`;
  const now = new Date().toISOString();
  const pushed = await must(P, 'cashier device uploads a UPI order', call('POST', '/v1/sync/push', {
    token: c1.token,
    body: {
      changes: [
        {
          change_id: `qa-${RUN}-o`, resource: 'orders', op: 'upsert',
          row: { client_order_id: devKey, location_id: 'location-demo', currency_code: 'INR', status: 'pendingUpload', order_type: 'takeaway', table_label: null, created_at: now, ops_status: 'billed', channel: 'takeaway', source: 'POS', guests: 1, server_name: 'QA Cashier', notes: '', discount_pct: 0, tax_pct: 5, bill_no: 1, payment_method: 'upi', settled_at: null, customer_name: 'QA Guest' },
        },
        { change_id: `qa-${RUN}-l`, resource: 'order-lines', op: 'upsert', row: { client_order_id: devKey, item_id: 'qa-dal', name: 'QA Dal', unit_minor: 15000, quantity: 1, station: 'Main Kitchen', is_veg: true, kitchen_done: false } },
        { change_id: `qa-${RUN}-p`, resource: 'payments', op: 'upsert', row: { payment_id: `PAY-${devKey}`, client_order_id: devKey, method: 'upi', amount_minor: 15750, received_minor: 15750, recorded_at: now } },
      ],
    },
  }));
  const statuses = pushed.results.map((r: any) => r.status).join(',');
  record(P, 'device upload accepted', 'accepted,accepted,accepted', statuses, statuses === 'accepted,accepted,accepted');
  const byKey = await must(P, 'branch manager verifies it by its POS id', call('POST', `/v1/operations/orders/${devKey}/verify-payment`, {
    token: acc.token,
    headers: branch ? { 'X-Location-Id': branch } : {},
    body: { note: 'QA statement check' },
  }));
  record(P, 'device order paid on the server', 'paid', byKey.status, byKey.status === 'paid');
  let pulledRow: any;
  let cursor: string | null = null;
  for (let page = 0; page < 20 && !pulledRow; page++) {
    const r = await call('POST', '/v1/sync/pull', { token: c1.token, body: { resources: ['orders'], ...(cursor ? { cursors: { orders: cursor } } : {}) } });
    const orders = data(r)?.resources?.orders;
    pulledRow = orders?.rows?.find((x: any) => x.client_order_id === devKey);
    if (!orders?.more) break;
    cursor = orders.cursor;
  }
  record(P, "cashier's device sees it settled", 'settled', pulledRow?.ops_status ?? 'missing', pulledRow?.ops_status === 'settled');
  const cancel = await must(P, 'order to cancel', call('POST', '/v1/operations/orders', { token: O, body: { channel: 'pickup', items: [{ menu_item_id: dish.id, qty: 1 }] } }));
  const cancelled = await must(P, 'cancel an order', call('POST', `/v1/operations/orders/${cancel.id}/status`, { token: O, body: { status: 'cancelled' } }));
  record(P, 'order cancelled', 'cancelled', cancelled.status, cancelled.status === 'cancelled');
  const summary = await must(P, 'day summary', call('GET', '/v1/operations/summary', { token: O }));
  record(P, 'summary counts orders', '> 0', String(summary.orders), Number(summary.orders) > 0);
  await must(P, 'create reservation', call('PUT', '/v1/operations/reservations', {
    token: O,
    body: { id: `qa-res-${RUN}`, guest_name: 'QA Guest', phone: '+91 90000 22222', email: 'guest@qa.test', guests: 4, scheduled_at: new Date(Date.now() + 86_400_000).toISOString(), status: 'confirmed', table_id: null, notes: '', created_at: new Date().toISOString() },
  }));

  const F = 'CRUD Franchise';
  await must(F, 'overview', call('GET', '/v1/franchise/overview', { token: O }));
  const perf = await must(F, 'branch performance', call('GET', '/v1/franchise/branch-performance', { token: O }));
  record(F, 'both branches listed', '≥ 2', String(perf.branches.length), perf.branches.length >= 2);
  await must(F, 'inventory across branches', call('GET', '/v1/franchise/inventory', { token: O }));
  const rec = await must(F, 'log an audit record', call('POST', '/v1/franchise/records', { token: O, body: { record_type: 'audit_report', title: `QA audit ${RUN}`, status: 'completed', details: { score: 92 } } }));
  const recs: any[] = await must(F, 'list records', call('GET', '/v1/franchise/records?record_type=audit_report', { token: O }));
  record(F, 'record listed', 'present', recs.some((r) => r.id === rec.id) ? 'present' : 'missing', recs.some((r) => r.id === rec.id));
  await must(F, 'set a branch target', call('POST', '/v1/franchise/targets', { token: O, body: { location_id: second.id, period_start: today, period_end: today, sales_target: 5000, orders_target: 20, aov_target: 250, food_cost_target_pct: 30 } }));
  await must(F, 'generate exceptions', call('POST', '/v1/franchise/exceptions/generate', { token: O }));

  const S = 'CRUD Staff';
  const employees: any[] = await must(S, 'staff directory', call('GET', '/v1/staff/employees', { token: O }));
  record(S, 'every QA login is an employee', `${accounts.length}+`, String(employees.length), employees.length >= accounts.length);
  await must(S, 'staff dashboard', call('GET', '/v1/staff/dashboard', { token: O }));
  await must(S, 'mark all present', call('POST', '/v1/staff/attendance/mark-all-present', { token: O, body: { date: today } }));
  const [y, m] = today.split('-').map(Number) as [number, number];
  // This run's cashier (earlier runs on the same day may have clocked theirs in).
  const emp = employees.find((e) => e.email === cashier.email) ?? employees[0];
  await must(S, 'record salary advance', call('POST', '/v1/staff/advances', { token: O, body: { staff_id: emp.id, amount: 500, deduct_month: m, deduct_year: y, reason: 'QA', mode: 'cash' } }));
  await must(S, 'generate salaries', call('POST', '/v1/staff/salaries/generate', { token: O, body: { year: y, month: m } }));
  const shift = await must(S, 'create shift', call('POST', '/v1/staff/shifts', { token: O, body: { name: `QA Shift ${RUN}`, start_time: '09:00', end_time: '17:00' } }));
  const roster = await must(S, 'assign shift', call('POST', '/v1/staff/roster', { token: O, body: { date: today, staff_id: emp.id, shift_id: shift.id } }));
  const row = roster.rows.find((r: any) => r.staff_id === emp.id);
  await must(S, 'clock in', call('POST', `/v1/staff/roster/${row.roster_id}/clock-in`, { token: O }));
  const leave = await must(S, 'leave request', call('POST', '/v1/staff/approvals', { token: O, body: { staff_id: emp.id, type: 'leave', details: { from: today, to: today, reason: 'QA' } } }));
  await must(S, 'approve leave', call('POST', `/v1/staff/approvals/${leave.id}/decide`, { token: O, body: { decision: 'approve' } }));
  const mod = await must(S, 'create training module', call('POST', '/v1/staff/training', { token: O, body: { title: `QA Hygiene ${RUN}`, roles: ['All Staff'], pass_score: 50, questions: [{ question: 'Wash hands?', options: ['Yes', 'No'], answer_index: 0 }], status: 'published' } }));
  const attempt = await must(S, 'take the test', call('POST', `/v1/staff/training/${mod.id}/attempts`, { token: O, body: { staff_id: emp.id, answers: [0] } }));
  record(S, 'test passed', 'passed', attempt.passed ? 'passed' : 'failed', attempt.passed === true);
  await must(S, 'reports', call('GET', '/v1/staff/reports', { token: O }));
  const log: any[] = await must(S, 'audit log', call('GET', '/v1/staff/audit-log', { token: O }));
  record(S, 'audit log records actions', '> 0', String(log.length), log.length > 0);

  // ── 6. sign-out ───────────────────────────────────────────────────────
  await expectStatus('Session', 'owner signs out', call('POST', '/v1/auth/logout', { token: O }), 204);
  await expectStatus('Session', 'signed-out token is refused', call('GET', '/v1/auth/me', { token: O }), 401);
}

main()
  .catch((e) => record('Run', 'walkthrough completed', 'no crash', String(e?.message ?? e), false))
  .finally(() => {
    const failed = results.filter((r) => !r.pass);
    const md = [
      `# QA walkthrough — ${new Date().toISOString()}`,
      '',
      `Backend: ${BASE} · run ${RUN} · ${results.length} checks · ${results.length - failed.length} passed · ${failed.length} failed`,
      '',
      '| Section | Check | Expected | Actual | Result |',
      '|---|---|---|---|---|',
      ...results.map((r) => `| ${r.section} | ${r.check} | ${r.expected} | ${r.actual.replace(/\|/g, '/')} | ${r.pass ? 'PASS' : '**FAIL**'} |`),
      '',
    ].join('\n');
    mkdirSync(new URL('../../docs/qa/', import.meta.url), { recursive: true });
    const out = new URL(`../../docs/qa/QA-WALKTHROUGH-${RUN}.md`, import.meta.url);
    writeFileSync(out, md);
    console.log(`\n${results.length} checks, ${failed.length} failed. Report: ${out.pathname}`);
    process.exit(failed.length ? 1 : 0);
  });
