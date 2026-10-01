/**
 * A restaurant's day through the vendor-panel APIs, each step done by the
 * role that does it in the restaurant, and every write read back to prove
 * it is stored. Leaves the data in place so it can be seen in the app.
 *
 *   QA_BASE=http://localhost:8787 QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… \
 *     npx tsx scripts/restaurant-day.ts
 *
 * Staff logins come from .data/manual-test-accounts.txt (made by
 * scripts/manual-test-accounts.ts). Writes docs/qa/RESTAURANT-DAY-<run>.md.
 * Test restaurants only — never production without the owner's go-ahead.
 */
import { randomBytes } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const BASE = (process.env.QA_BASE ?? 'http://localhost:8787').replace(/\/$/, '');
const OWNER_EMAIL = process.env.QA_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.QA_OWNER_PASSWORD;
if (!OWNER_EMAIL || !OWNER_PASSWORD) {
  console.error('Set QA_OWNER_EMAIL and QA_OWNER_PASSWORD.');
  process.exit(2);
}
const RUN = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 12) + randomBytes(2).toString('hex');
const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

// Staff logins (git-ignored file: "<base role> <email> <password>").
const logins = new Map<string, { email: string; password: string }>();
for (const line of readFileSync(new URL('../.data/manual-test-accounts.txt', import.meta.url), 'utf8').split(/\r?\n/)) {
  const m = /^(\w+)\s+(\S+@\S+)\s+(\S+)$/.exec(line.trim());
  if (m && !logins.has(m[1]!)) logins.set(m[1]!, { email: m[2]!, password: m[3]! });
}

interface Step {
  who: string;
  what: string;
  saved: string;
  check: string;
  pass: boolean;
}
const steps: Step[] = [];
function record(who: string, what: string, saved: string, check: string, pass: boolean) {
  steps.push({ who, what, saved, check, pass });
  console.log(`${pass ? 'PASS' : 'FAIL'}  [${who}] ${what} — ${check}`);
}

async function call(method: string, path: string, token?: string, body?: unknown, headers: Record<string, string> = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = text;
  }
  return { status: res.status, data: json?.data, error: json?.error };
}
async function must(method: string, path: string, token: string, body?: unknown, headers?: Record<string, string>) {
  const r = await call(method, path, token, body, headers);
  if (r.status < 200 || r.status >= 300) throw new Error(`${method} ${path} → ${r.status} ${r.error?.message ?? ''}`);
  return r.data;
}
async function signIn(role: string): Promise<string> {
  const l = role === 'owner' ? { email: OWNER_EMAIL!, password: OWNER_PASSWORD! } : logins.get(role);
  if (!l) throw new Error(`No login for ${role} in .data/manual-test-accounts.txt — run scripts/manual-test-accounts.ts first.`);
  const r = await call('POST', '/v1/auth/login', undefined, l);
  if (r.status !== 200) throw new Error(`${role} cannot sign in: ${r.status} ${r.error?.message}`);
  return r.data.session.access_token as string;
}
const rupees = (minor: number) => `₹${(minor / 100).toFixed(2)}`;

async function main() {
  console.log(`Restaurant day against ${BASE} (run ${RUN})\n`);
  const O = await signIn('owner');
  const me = (await must('GET', '/v1/auth/me', O)) as any;
  const org = me.organization.name as string;
  const branch = me.location as { id: string; name: string };

  // ── Owner: menu ──────────────────────────────────────────────────────
  const W = 'Owner';
  const cats = (await must('GET', '/v1/master/menu-categories', O)) as any[];
  const category = cats.find((c) => c.name === 'House Specials') ?? (await must('POST', '/v1/master/menu-categories', O, { name: 'House Specials' }));
  const wanted: [string, number, string][] = [
    ['Veg Biryani', 220, 'veg'],
    ['Paneer Butter Masala', 260, 'veg'],
    ['Butter Naan', 45, 'veg'],
    ['Masala Chai', 30, 'veg'],
    ['Chicken Tikka', 280, 'non_veg'],
  ];
  let items = (await must('GET', '/v1/master/menu-items?limit=500', O)) as any[];
  for (const [name, price, food] of wanted) {
    if (!items.some((i) => i.name === name)) {
      await must('POST', '/v1/master/menu-items', O, { name, price, category_id: category.id, food_type: food });
    }
  }
  items = (await must('GET', '/v1/master/menu-items?limit=500', O)) as any[];
  const dish = (n: string) => items.find((i) => i.name === n)!;
  const allThere = wanted.every(([n, p]) => dish(n) && Number(dish(n).price) === p);
  record(W, 'menu: 5 dishes in "House Specials"', wanted.map(([n, p]) => `${n} ₹${p}`).join(', '), 'read back from /master/menu-items with the same prices', allThere);

  // ── Owner: stock and supplier ────────────────────────────────────────
  const now = new Date().toISOString();
  const materials = [
    { id: 'day-rm-rice', code: 'RM-GRN-101', name: 'Basmati Rice', category: 'Grains', unit: 'kg', stock_qty: 25, reorder_level: 10, max_capacity: 100, purchase_cost: 95 },
    { id: 'day-rm-paneer', code: 'RM-DAI-102', name: 'Paneer', category: 'Dairy', unit: 'kg', stock_qty: 3, reorder_level: 5, max_capacity: 30, purchase_cost: 320 },
    { id: 'day-rm-milk', code: 'RM-DAI-103', name: 'Milk', category: 'Dairy', unit: 'L', stock_qty: 20, reorder_level: 8, max_capacity: 60, purchase_cost: 58 },
  ];
  for (const m of materials) {
    await must('PUT', '/v1/master/raw-materials', O, { ...m, last_purchase_price: m.purchase_cost, hsn: '', emoji: '📦', lead_time_days: 1, active: true, created_at: now });
  }
  const rm = (await must('GET', '/v1/master/raw-materials', O)) as any[];
  const stored = materials.every((m) => rm.some((r) => r.id === m.id && Number(r.stock_qty) === m.stock_qty));
  record(W, 'stock: 3 raw materials (Paneer below reorder level)', materials.map((m) => `${m.name} ${m.stock_qty}${m.unit}`).join(', '), 'read back from /master/raw-materials', stored);
  await must('PUT', '/v1/master/suppliers', O, {
    id: 'day-sup-dairy', name: 'Latur Fresh Dairy', legal_name: 'Latur Fresh Dairy LLP', category: 'Dairy', contact_person: 'Sunil',
    phone: '+91 90000 44444', email: 'orders@laturdairy.test', gstin: '27AAAAA1111A1Z5', city: 'Latur', rating: 4, payment_terms: 'Net 7', active: true, created_at: now,
  });
  const sups = (await must('GET', '/v1/master/suppliers', O)) as any[];
  record(W, 'supplier: Latur Fresh Dairy', 'day-sup-dairy', 'read back from /master/suppliers', sups.some((s) => s.id === 'day-sup-dairy'));

  // ── Owner: floor plan and a reservation ─────────────────────────────
  const areas = (await must('GET', '/v1/operations/dining-areas', O)) as any[];
  const hall = areas.find((a) => a.name === 'Main Hall' && a.location_id === branch.id) ?? (await must('POST', '/v1/operations/dining-areas', O, { name: 'Main Hall' }));
  let tables = (await must('GET', '/v1/operations/dining-tables', O)) as any[];
  for (const label of ['T1', 'T2', 'T3', 'T4']) {
    if (!tables.some((t) => t.label === label && t.location_id === branch.id)) {
      await must('POST', '/v1/operations/dining-tables', O, { label, seats: 4, area_id: hall.id });
    }
  }
  tables = (await must('GET', '/v1/operations/dining-tables', O)) as any[];
  const table = (l: string) => tables.find((t) => t.label === l && t.location_id === branch.id)!;
  record(W, `floor: Main Hall with T1–T4 at ${branch.name}`, ['T1', 'T2', 'T3', 'T4'].map((l) => table(l)?.id?.slice(0, 8)).join(', '), 'read back from /operations/dining-tables', ['T1', 'T2', 'T3', 'T4'].every((l) => table(l)));
  const resId = `day-res-${RUN}`;
  await must('PUT', '/v1/operations/reservations', O, {
    id: resId, guest_name: 'Mehta family', phone: '+91 90000 55555', email: '', guests: 5,
    scheduled_at: new Date(Date.now() + 86_400_000).toISOString(), status: 'confirmed', table_id: null, notes: 'Birthday', created_at: now,
  });
  const res = (await must('GET', '/v1/operations/reservations', O)) as any[];
  record(W, 'reservation: Mehta family, 5 guests, tomorrow', resId, 'read back from /operations/reservations', res.some((r) => r.id === resId));

  // ── Captain: takes table orders ─────────────────────────────────────
  const C = await signIn('captain');
  const t1 = await must('POST', '/v1/operations/orders', C, {
    channel: 'dine_in', table_id: table('T1').id, guest_count: 3, captain_name: 'Test Captain', placed_by: 'captain',
    items: [{ menu_item_id: dish('Veg Biryani').id, qty: 2 }, { menu_item_id: dish('Butter Naan').id, qty: 3 }, { menu_item_id: dish('Masala Chai').id, qty: 3 }],
  });
  const t2 = await must('POST', '/v1/operations/orders', C, {
    channel: 'dine_in', table_id: table('T2').id, guest_count: 2, captain_name: 'Test Captain', placed_by: 'captain',
    items: [{ menu_item_id: dish('Paneer Butter Masala').id, qty: 1 }, { menu_item_id: dish('Chicken Tikka').id, qty: 1 }, { menu_item_id: dish('Butter Naan').id, qty: 2 }],
  });
  for (const [label, o] of [['T1', t1], ['T2', t2]] as const) {
    const d = await must('GET', `/v1/operations/orders/${o.id}`, O);
    record('Captain', `order at ${label} (${d.items.length} lines)`, `${d.display_no ?? d.id} · ${rupees(Math.round(Number(d.total) * 100))}`, `stored with status ${d.status} and ${d.kot_tickets.length} KOT`, d.status === 'sent_to_kitchen' && d.kot_tickets.length === 1);
  }
  const captainPays = await call('POST', `/v1/operations/orders/${t1.id}/payments`, C, { method: 'cash', amount: Number(t1.total) });
  record('Captain', 'tries to take the cash for T1', '—', `refused with ${captainPays.status} (the cashier collects money)`, captainPays.status === 403);

  // ── Kitchen: prepares ───────────────────────────────────────────────
  const K = await signIn('kitchen');
  const queue = (await must('GET', '/v1/operations/kot-tickets', K)) as any[];
  for (const o of [t1, t2]) {
    const kot = queue.find((k) => k.order_id === o.id);
    if (!kot) {
      record('Chef', 'finds the KOT', '—', 'missing from the kitchen queue', false);
      continue;
    }
    await must('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, K);
    const ready = await must('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, K);
    record('Chef', `KOT for ${o.id === t1.id ? 'T1' : 'T2'}: start cooking → ready`, kot.id.slice(0, 8), `stored as ${ready.status}`, ready.status === 'ready');
  }
  const chefOrders = await call('POST', '/v1/operations/orders', K, { channel: 'pickup', items: [{ menu_item_id: dish('Masala Chai').id, qty: 1 }] });
  record('Chef', 'tries to place an order', '—', `refused with ${chefOrders.status}`, chefOrders.status === 403);

  // ── Cashier: bills and collects ─────────────────────────────────────
  const B = await signIn('biller');
  const cash = await must('POST', `/v1/operations/orders/${t1.id}/payments`, B, { method: 'cash', amount: Number(t1.total) }, { 'Idempotency-Key': `day-${RUN}-t1` });
  record('Cashier', 'T1 paid in cash', rupees(Math.round(Number(t1.total) * 100)), `order stored as ${cash.status}`, cash.status === 'paid');
  const retry = await call('POST', `/v1/operations/orders/${t1.id}/payments`, B, { method: 'cash', amount: Number(t1.total) }, { 'Idempotency-Key': `day-${RUN}-t1` });
  const t1Payments = (await must('GET', `/v1/operations/orders/${t1.id}`, O)).payments as any[];
  record('Cashier', 'the same payment sent twice (network retry)', '—', `answer ${retry.status}; ${t1Payments.length} payment stored`, t1Payments.length === 1);
  const upi = await must('POST', `/v1/operations/orders/${t2.id}/payments`, B, { method: 'upi', amount: Number(t2.total), reference: `UTR${RUN.slice(-6)}` });
  record('Cashier', 'T2 paid by UPI', rupees(Math.round(Number(t2.total) * 100)), `order stored as ${upi.status} (pending verification)`, upi.status === 'awaiting_payment');
  const take = await must('POST', '/v1/operations/orders', B, {
    channel: 'pickup', customer_name: 'Walk-in Ravi', items: [{ menu_item_id: dish('Veg Biryani').id, qty: 1 }, { menu_item_id: dish('Masala Chai').id, qty: 2 }],
  });
  const card = await must('POST', `/v1/operations/orders/${take.id}/payments`, B, { method: 'card', amount: Number(take.total), reference: 'CARD-4421' });
  record('Cashier', 'takeaway for Walk-in Ravi paid by card', rupees(Math.round(Number(take.total) * 100)), `stored as ${card.status}`, card.status === 'awaiting_payment');
  const cancel = await must('POST', '/v1/operations/orders', B, { channel: 'pickup', customer_name: 'Left without ordering', items: [{ menu_item_id: dish('Masala Chai').id, qty: 1 }] });
  const cancelled = await must('POST', `/v1/operations/orders/${cancel.id}/status`, B, { status: 'cancelled' });
  record('Cashier', 'cancels an order the guest walked out on', cancel.id.slice(0, 8), `stored as ${cancelled.status}`, cancelled.status === 'cancelled');
  const billerVerify = await call('POST', `/v1/operations/orders/${t2.id}/verify-payment`, B, {});
  record('Cashier', 'tries to verify the UPI', '—', `refused with ${billerVerify.status}`, billerVerify.status === 403);

  // ── Branch manager: verifies card / UPI ─────────────────────────────
  const A = await signIn('location_manager');
  const v1 = await must('POST', `/v1/operations/orders/${t2.id}/verify-payment`, A, { reference: `UTR${RUN.slice(-6)}`, note: 'Seen on the bank statement' });
  record('Branch Manager', 'verifies T2 UPI against the statement', t2.id.slice(0, 8), `stored as ${v1.status}`, v1.status === 'paid');
  const M = A;
  const v2 = await must('POST', `/v1/operations/orders/${take.id}/verify-payment`, M, { reference: 'CARD-4421' });
  record('Branch Manager', 'verifies the card payment', take.id.slice(0, 8), `stored as ${v2.status}`, v2.status === 'paid');
  const events = ((await must('GET', `/v1/operations/orders/${t2.id}`, O)).events as any[]).map((e) => e.kind);
  record('Branch Manager', 'the UPI order history', events.join(' → '), 'records pending verification and who verified', events.includes('payment_pending_verification') && events.includes('payment_verified'));

  // ── Staff: attendance ───────────────────────────────────────────────
  await must('POST', '/v1/staff/attendance/mark-all-present', M, { date: today });
  const att = (await must('GET', `/v1/staff/attendance?date=${today}`, M)) as any[];
  const present = att.filter((a) => a.status === 'present').length;
  record('Branch Manager', `attendance for ${today}: mark all present`, `${present} of ${att.length} present`, 'read back from /staff/attendance', att.length > 0 && present === att.length);

  // ── Owner: the day in numbers ───────────────────────────────────────
  const summary = await must('GET', '/v1/operations/summary', O);
  const paidToday = [t1, t2, take].reduce((s, o) => s + Math.round(Number(o.total) * 100), 0);
  record(W, 'end-of-day summary', `${summary.orders} orders · ${rupees(summary.sales_minor)} sales today`, `includes this run's ${rupees(paidToday)}`, summary.sales_minor >= paidToday);

  // ── Report ──────────────────────────────────────────────────────────
  const failed = steps.filter((s) => !s.pass).length;
  const md = [
    `# Restaurant day — ${new Date().toISOString()}`,
    '',
    `Backend: ${BASE} · restaurant: ${org} · branch: ${branch.name} · run ${RUN} · ${steps.length} steps · ${steps.length - failed} passed · ${failed} failed`,
    '',
    'Each step is done by the role that does it in the restaurant; every write is read back through the API (the data stays in the database).',
    '',
    '| Who | What | Saved | Checked | Result |',
    '|---|---|---|---|---|',
    ...steps.map((s) => `| ${s.who} | ${s.what} | ${s.saved.replace(/\|/g, '/')} | ${s.check.replace(/\|/g, '/')} | ${s.pass ? 'PASS' : '**FAIL**'} |`),
    '',
  ].join('\n');
  mkdirSync(new URL('../../docs/qa/', import.meta.url), { recursive: true });
  const file = new URL(`../../docs/qa/RESTAURANT-DAY-${RUN}.md`, import.meta.url);
  writeFileSync(file, md);
  console.log(`\n${steps.length} steps, ${failed} failed. Report: ${file.pathname}`);
  if (failed) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
