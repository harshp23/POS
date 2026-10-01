/**
 * The vendor panel's business sections (Customers & CRM, Marketing,
 * Finance, Integrations, Task Manager, Settings) exercised through the API
 * on a running backend, and every write read back to prove it is stored.
 * Leaves the data in place so it can be seen in the app.
 *
 *   QA_BASE=http://localhost:8787 QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… \
 *     npx tsx scripts/business-day.ts
 *
 * The branch manager login comes from .data/manual-test-accounts.txt (made
 * by scripts/manual-test-accounts.ts). Writes docs/qa/BUSINESS-DAY-<run>.md.
 * Test restaurants only — never production without the owner's go-ahead.
 */
import { randomBytes, randomInt } from 'node:crypto';
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

const logins = new Map<string, { email: string; password: string }>();
for (const line of readFileSync(new URL('../.data/manual-test-accounts.txt', import.meta.url), 'utf8').split(/\r?\n/)) {
  const m = /^(\w+)\s+(\S+@\S+)\s+(\S+)$/.exec(line.trim());
  if (m && !logins.has(m[1]!)) logins.set(m[1]!, { email: m[2]!, password: m[3]! });
}

interface Step {
  section: string;
  what: string;
  saved: string;
  check: string;
  pass: boolean;
}
const steps: Step[] = [];
function record(section: string, what: string, saved: string, check: string, pass: boolean) {
  steps.push({ section, what, saved, check, pass });
  console.log(`${pass ? 'PASS' : 'FAIL'}  [${section}] ${what} — ${check}`);
}

async function call(method: string, path: string, token?: string, body?: unknown) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
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
  return { status: res.status, data: json?.data, body: json, error: json?.error };
}
async function must(method: string, path: string, token: string, body?: unknown) {
  const r = await call(method, path, token, body);
  if (r.status < 200 || r.status >= 300) throw new Error(`${method} ${path} → ${r.status} ${r.error?.message ?? ''}`);
  return r.data;
}
async function signIn(email: string, password: string): Promise<string> {
  const r = await call('POST', '/v1/auth/login', undefined, { email, password });
  if (r.status !== 200) throw new Error(`${email} cannot sign in: ${r.status} ${r.error?.message}`);
  return r.data.session.access_token as string;
}
const inr = (v: unknown) => `₹${Number(v ?? 0).toFixed(2)}`;

async function main() {
  const O = await signIn(OWNER_EMAIL!, OWNER_PASSWORD!);
  const me = await must('GET', '/v1/auth/me', O);
  const orgName = me.organization.name as string;
  const bmLogin = logins.get('location_manager');
  const BM = bmLogin ? await signIn(bmLogin.email, bmLogin.password) : null;

  // ── Customers & CRM ──────────────────────────────────────────────────
  const phone = `9${String(randomInt(100000000, 999999999))}`;
  const cust = await must('POST', '/v1/crm/customers', O, {
    first_name: 'Business',
    last_name: `Day ${RUN.slice(-4)}`,
    phone,
    email: `bizday.${RUN}@example.com`,
    tags: ['QA', 'Regular'],
    preferred_dining: 'dine_in',
  });
  const found = (await must('GET', `/v1/crm/customers?q=${phone}`, O)) as any[];
  record('CRM', 'add a customer', `${cust.first_name} ${cust.last_name} · ${phone}`, 'found by phone in /crm/customers', found.some((c) => c.id === cust.id));

  const order = await must('POST', '/v1/operations/orders', O, {
    channel: 'dine_in',
    customer_phone: `+91 ${phone}`,
    customer_name: 'Business Day',
    gst_pct: 0,
    items: [{ name: 'QA Thali', unit_price: 420, qty: 1 }],
  });
  await must('POST', `/v1/operations/orders/${order.id}/payments`, O, { method: 'cash', amount: order.total });
  const after = await must('GET', `/v1/crm/customers/${cust.id}`, O);
  const loyalty = await must('GET', '/v1/crm/loyalty', O);
  const expected = Math.floor(420 / loyalty.settings.earn_per_amount) * loyalty.settings.points_per_earn;
  record('CRM', 'a paid bill with the customer\'s phone', `order ${order.display_no} ${inr(order.total)}`, `customer shows 1 order, ${inr(after.spent)}, ${after.points} points (expected ${expected})`, after.orders === 1 && after.spent === 420 && after.points === expected);

  await must('POST', '/v1/crm/wallet/entries', O, { customer_id: cust.id, entry_type: 'topup', amount: 500, method: 'upi', note: 'QA top-up' });
  const wallet = await must('GET', `/v1/crm/customers/${cust.id}`, O);
  record('CRM', 'wallet top-up ₹500', `wallet ${inr(wallet.wallet)}`, 'balance read back', wallet.wallet === 500);

  const seg = await must('POST', '/v1/crm/segments', O, { name: `QA regulars ${RUN}`, rules: { tags: ['QA'] } });
  const members = (await must('GET', `/v1/crm/segments/${seg.id}/customers`, O)) as any[];
  record('CRM', 'custom segment (tag QA)', seg.name, `${members.length} member(s) incl. the new customer`, members.some((m) => m.id === cust.id));

  const fb = await must('POST', '/v1/crm/feedback', O, { customer_id: cust.id, customer_name: 'Business Day', rating: 5, comment: 'QA feedback' });
  const fbs = (await must('GET', '/v1/crm/feedback', O)) as any[];
  record('CRM', 'feedback', `${fb.rating}★ "${fb.comment}"`, 'listed in /crm/feedback', fbs.some((f) => f.id === fb.id));

  // ── Marketing ────────────────────────────────────────────────────────
  const camp = await must('POST', '/v1/marketing/campaigns', O, {
    name: `QA campaign ${RUN}`,
    channel: 'whatsapp',
    segment: seg.id,
    message: 'Hi {name}, thanks for visiting!',
    action: 'send',
  });
  record('Marketing', 'campaign → Send now', `${camp.status} · audience ${camp.audience_count}`, `honest note: "${camp.status_note}"`, camp.status === 'queued' && /not connected/.test(camp.status_note));

  const code = `QA${RUN.slice(-6).toUpperCase()}`;
  const promo = await must('POST', '/v1/marketing/promotions', O, {
    title: `QA offer ${RUN}`,
    offer_type: 'promo_code',
    code,
    discount_type: 'percent',
    discount_value: 10,
    max_discount: 100,
    min_order: 300,
    channels: ['pos', 'qr'],
  });
  const masterOffers = (await must('GET', '/v1/master/offers?limit=500', O)) as any[];
  record('Marketing', 'promotion with a code', `${promo.code} · ${promo.discount_rule} · ${promo.state}`, 'same offer in Master → Offers (/master/offers)', masterOffers.some((o) => o.code === code));

  const ad = await must('POST', '/v1/marketing/ads', O, { title: `QA ad ${RUN}`, discount_text: '10% OFF', placement: 'offer_strip' });
  record('Marketing', 'ad request', `${ad.title} · ${ad.status}`, 'waits for the Proviyaa team', ad.status === 'pending');

  // ── Finance ──────────────────────────────────────────────────────────
  const writer = BM ?? O;
  const exp = await must('POST', '/v1/finance/entries', writer, { direction: 'out', kind: 'expense', account: 'cash', category: 'Packaging', amount: 250, note: `QA ${RUN}` });
  const dash = await must('GET', '/v1/finance/dashboard', writer);
  record('Finance', `${BM ? 'branch manager' : 'owner'} records a ₹250 expense`, `entry ${exp.id.slice(0, 8)}`, `today's expense ${inr(dash.today_expense)} ≥ ₹250`, dash.today_expense >= 250);

  const pays = await call('GET', `/v1/finance/payments?from=${today}&to=${today}`, O);
  record('Finance', 'payments list', `${pays.data.length} payment(s) today · gross ${inr(pays.body.summary.gross)}`, `includes order ${order.display_no}`, pays.data.some((p: any) => p.reference === order.display_no));

  const stl = await must('POST', '/v1/finance/settlements', O, { source: 'zomato', amount: 1000, status: 'completed', utr: `UTR${RUN}` });
  const stlSum = await must('GET', '/v1/finance/settlements-summary', O);
  record('Finance', 'Zomato settlement ₹1,000 (completed)', stl.settlement_no, `total settled ${inr(stlSum.total_settled)}`, /^STL-\d{8}-\d{3}$/.test(stl.settlement_no) && stlSum.total_settled >= 1000);

  const expiry = new Date(Date.now() + 30 * 86_400_000).toISOString().slice(0, 10);
  const doc = await must('POST', '/v1/finance/documents', O, { name: `QA Fire Safety ${RUN}`, doc_type: 'safety', doc_no: `FSC-${RUN}`, expiry_date: expiry });
  const docSum = await must('GET', '/v1/finance/documents-summary', O);
  record('Finance', 'document expiring in 30 days', `${doc.name} · ${expiry}`, `expiring soon: ${docSum.expiring_soon}`, docSum.expiring_soon >= 1);

  // ── Integrations ─────────────────────────────────────────────────────
  const conn = await call('POST', '/v1/integrations/apps/tally_prime/connect', O, { account_ref: `TALLY-${RUN}` });
  record('Integrations', 'connect Tally Prime', conn.data.status, conn.body.message, conn.data.status === 'pending');
  await must('POST', '/v1/integrations/sync-jobs', O, { provider: 'tally_prime', resource: 'orders', mode: 'delta' });
  const ran = await must('POST', '/v1/integrations/sync-jobs/run', O);
  const jobs = (await must('GET', '/v1/integrations/sync-jobs', O)) as any[];
  record('Integrations', 'queue + run a sync job', `ran ${ran.ran}, failed ${ran.failed}`, `reason: "${jobs[0]?.error}"`, ran.failed >= 1 && /not connected/.test(jobs[0]?.error ?? ''));
  const key = await must('POST', '/v1/integrations/api-keys', O, { name: `QA key ${RUN}`, scopes: ['reports:read'], expires_in_days: 30 });
  const keys = (await must('GET', '/v1/integrations/api-keys', O)) as any[];
  const listed = keys.find((k) => k.id === key.id);
  record('Integrations', 'generate an API key', `${key.prefix}**** (shown once)`, 'listed without the key; prefix matches', !!listed && !JSON.stringify(keys).includes(key.key) && key.key.startsWith(listed.prefix));
  await must('POST', `/v1/integrations/api-keys/${key.id}/revoke`, O);

  // ── Task Manager ─────────────────────────────────────────────────────
  let staff = ((await must('GET', '/v1/tasks/assignees', O)) as any[])[0];
  if (!staff) staff = await must('POST', '/v1/staff/employees', O, { full_name: 'QA Captain', designation: 'Captain' });
  const task = await must('POST', '/v1/tasks/tasks', O, {
    title: `QA fire extinguisher check ${RUN}`,
    priority: 'high',
    category: 'Safety & Compliance',
    assignee_staff_id: staff.id,
    due_date: today,
    approval_required: true,
    checklist_required: true,
    checklist: [{ text: 'Check the expiry tag' }, { text: 'Check the pressure gauge' }],
  });
  await must('POST', `/v1/tasks/tasks/${task.id}/start`, O);
  await must('POST', `/v1/tasks/tasks/${task.id}/checklist`, O, { index: 0, done: true });
  await must('POST', `/v1/tasks/tasks/${task.id}/checklist`, O, { index: 1, done: true });
  await must('POST', `/v1/tasks/tasks/${task.id}/submit`, O, { note: 'Both checked' });
  await must('POST', `/v1/tasks/tasks/${task.id}/verify`, O, { approved: true, note: 'OK' });
  const done = await must('GET', `/v1/tasks/tasks/${task.id}`, O);
  record('Task Manager', `task for ${staff.full_name}: start → checklist → submit → approve`, `${done.status} · ${done.events.length} timeline events`, 'read back from /tasks/tasks/:id', done.status === 'completed' && done.events.length >= 6);

  // ── Settings ─────────────────────────────────────────────────────────
  const outlet = await must('GET', '/v1/settings/outlet', O);
  const saved = await must('PUT', '/v1/settings/outlet', O, {
    name: orgName,
    phone: outlet.phone || '+91 90000 00000',
    cuisine: outlet.cuisine || 'North Indian, South Indian',
    email: outlet.email || 'hello@qakitchen.test',
    address: outlet.address || 'Gandhi Road, Latur, Maharashtra 413512',
    business_category: outlet.business_category || 'Casual Dining',
    description: outlet.description || '',
    logo_url: outlet.logo_url || '',
  });
  record('Settings', 'outlet profile', `${saved.name} · ${saved.address}`, 'read back from /settings/outlet', saved.name === orgName);
  const bill = await must('PUT', '/v1/settings/bill-format', O, { store_name: orgName, address: saved.address, phone: saved.phone, bill_prefix: 'BIL-', show_cashier: true });
  const posBill = await must('GET', '/v1/operations/bill-settings', O);
  record('Settings', 'bill format', `${bill.store_name} · ${bill.paper_size}`, 'POS bill settings show the same name', posBill.legal_name === orgName);
  const printer = await must('POST', '/v1/settings/printers', O, { name: `QA KOT printer ${RUN.slice(-4)}`, printer_type: 'kot', station: 'Kitchen', address: '192.168.1.13:9100' });
  const test = await call('POST', `/v1/settings/printers/${printer.id}/test`, O);
  record('Settings', 'add a printer + test print', printer.name, `test print answered ${test.status}: "${test.error?.message}"`, test.status === 409);
  await must('PUT', '/v1/settings/notifications', O, { low_stock: true, document_expiry: true, daily_summary: true });
  const overview = await must('GET', '/v1/settings/overview', O);
  const done2 = overview.checklist.filter((i: any) => i.done).length;
  record('Settings', 'system overview', `${done2}/${overview.checklist.length} setup items done · ${overview.alerts.length} alert(s)`, 'printers + notifications ticked', overview.checklist.find((i: any) => i.key === 'printers')?.done && overview.checklist.find((i: any) => i.key === 'notifications')?.done);

  // ── Who may open what ────────────────────────────────────────────────
  if (BM) {
    const denied = await Promise.all(['/v1/marketing/dashboard', '/v1/settings/overview', '/v1/integrations/overview', '/v1/tasks/tasks'].map((p) => call('GET', p, BM)));
    const allowed = await Promise.all(['/v1/crm/customers', '/v1/finance/dashboard'].map((p) => call('GET', p, BM)));
    record('Access', 'branch manager', 'CRM + Finance: ' + allowed.map((r) => r.status).join('/'), 'Marketing / Settings / Integrations / Tasks: ' + denied.map((r) => r.status).join('/'), allowed.every((r) => r.status === 200) && denied.every((r) => r.status === 403));
  }

  const failed = steps.filter((s) => !s.pass).length;
  const md = [
    `# Business sections — ${new Date().toISOString()}`,
    '',
    `Backend: ${BASE} · restaurant: ${orgName} · run ${RUN} · ${steps.length} steps · ${steps.length - failed} passed · ${failed} failed`,
    '',
    'Customers & CRM, Marketing, Finance, Integrations, Task Manager and Settings through the API; every write is read back (the data stays in the database).',
    '',
    '| Section | What | Saved | Checked | Result |',
    '|---|---|---|---|---|',
    ...steps.map((s) => `| ${s.section} | ${s.what} | ${s.saved.replace(/\|/g, '/')} | ${s.check.replace(/\|/g, '/')} | ${s.pass ? 'PASS' : '**FAIL**'} |`),
    '',
  ].join('\n');
  mkdirSync(new URL('../../docs/qa/', import.meta.url), { recursive: true });
  const file = new URL(`../../docs/qa/BUSINESS-DAY-${RUN}.md`, import.meta.url);
  writeFileSync(file, md);
  console.log(`\n${steps.length} steps, ${failed} failed. Report: ${file.pathname}`);
  if (failed) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
