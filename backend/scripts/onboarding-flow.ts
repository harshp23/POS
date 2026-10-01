/**
 * The whole onboarding path, for real, on a throw-away local database:
 *
 *   platform admin (master-admin) creates a restaurant, a branch and the
 *   owner's account  ->  owner signs in to the POS backend with the invited
 *   password and must replace it  ->  owner creates the restaurant's own
 *   logins (admin, branch manager, cashier, captain, kitchen)  ->  each role
 *   signs in and works its modules  ->  a second restaurant proves the two
 *   cannot see each other.
 *
 * It starts BOTH services itself (POS backend in local mode = PGlite, and
 * master-admin on the same database) with one shared JWT secret, so it never
 * touches Supabase.
 *
 *   JWT_SECRET=<the shared secret> npx tsx scripts/onboarding-flow.ts
 *
 * Writes docs/qa/ONBOARDING-<run>.md.
 */
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const SECRET = process.env.JWT_SECRET ?? '';
if (SECRET.length < 16) {
  console.error('Set JWT_SECRET (at least 16 characters) - the same value both services use.');
  process.exit(2);
}
const RUN = randomBytes(3).toString('hex');
const PW = { platform: 'Platform-Admin-2026', invite: `Invite-${RUN}-Temp`, owner: `Owner-${RUN}-Final`, staff: `Staff-${RUN}-Temp`, staffNew: `Staff-${RUN}-Final` };
const rnd = (a: number, b: number) => a + Math.floor(Math.random() * (b - a));
const P = { pos: rnd(20000, 30000), db: rnd(30000, 40000), master: rnd(40000, 50000) };
const POS = `http://127.0.0.1:${P.pos}`;
const MASTER = `http://127.0.0.1:${P.master}/api`;
const dataDir = mkdtempSync(join(tmpdir(), 'proviyaa_onboard_'));
const procs: ChildProcess[] = [];
const logs = { pos: '', master: '' };

interface Step { who: string; what: string; check: string; pass: boolean }
const steps: Step[] = [];
function record(who: string, what: string, check: string, pass: boolean) {
  steps.push({ who, what, check, pass });
  console.log(`${pass ? 'PASS' : 'FAIL'}  [${who}] ${what} - ${check}`);
}

function start(name: 'pos' | 'master', cmd: string, args: string[], cwd: string, env: Record<string, string>, marker: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { cwd, env: { ...process.env, ...env }, shell: process.platform === 'win32' });
    procs.push(p);
    const timer = setTimeout(() => reject(new Error(`${name} did not start:\n${logs[name]}`)), 150_000);
    const onData = (d: Buffer) => {
      logs[name] += d.toString();
      if (logs[name].includes(marker)) { clearTimeout(timer); resolve(); }
    };
    p.stdout!.on('data', onData);
    p.stderr!.on('data', onData);
    p.on('exit', (code) => { if (!logs[name].includes(marker)) { clearTimeout(timer); reject(new Error(`${name} exited ${code}:\n${logs[name]}`)); } });
  });
}
function stopAll() {
  for (const p of procs) {
    if (process.platform === 'win32' && p.pid) spawnSync('taskkill', ['/F', '/T', '/PID', String(p.pid)]);
    else p.kill();
  }
  try { rmSync(dataDir, { recursive: true, force: true }); } catch { /* ignore */ }
}

async function call(base: string, method: string, path: string, token?: string, body?: unknown, headers: Record<string, string> = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: { Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json: any = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, json, data: json?.data, error: json?.error ?? json?.message };
}
const pos = (m: string, p: string, t?: string, b?: unknown, h?: Record<string, string>) => call(POS, m, p, t, b, h);
const master = (m: string, p: string, t?: string, b?: unknown) => call(MASTER, m, p, t, b);
async function must(r: Promise<{ status: number; data: any; json: any; error: any }>, what: string) {
  const x = await r;
  if (x.status < 200 || x.status >= 300) throw new Error(`${what} -> ${x.status} ${JSON.stringify(x.error ?? x.json)}`);
  return x;
}

async function main() {
  console.log(`Starting POS backend :${P.pos} and master-admin :${P.master} on a local database ...`);
  const platformEmail = `platform-${RUN}@proviyaa.test`;
  await start('pos', 'node', ['--import', 'tsx', 'src/local-server.ts'], join(import.meta.dirname, '..'), {
    PORT: String(P.pos), LOCAL_DB_PORT: String(P.db), LOCAL_DATA_DIR: dataDir, JWT_SECRET: SECRET,
    LOCAL_PLATFORM_EMAIL: platformEmail, LOCAL_PLATFORM_PASSWORD: PW.platform,
  }, 'listening');
  await start('master', 'node', ['-r', 'ts-node/register/transpile-only', 'src/index.ts'], join(import.meta.dirname, '../../master-admin/backend'), {
    PORT: String(P.master), NODE_ENV: 'development', JWT_SECRET: SECRET, JWT_EXPIRES_IN: '7d',
    DATABASE_URL: `postgresql://postgres:postgres@127.0.0.1:${P.db}/postgres`,
  }, 'Server running');

  /* ---------- 1. Proviyaa master: onboard a restaurant ---------- */
  const login = await must(master('POST', '/auth/login', undefined, { email: platformEmail, password: PW.platform }), 'platform login');
  const A = login.json.token as string;
  record('Platform admin', 'signs in to Proviyaa master', 'token issued', !!A);
  const orgIn = { business_name: `Saffron Table ${RUN}`, domain: `saffron${RUN}`, email: `hello+${RUN}@saffron.test`, phone_number: `+91 98${rnd(10000000, 99999999)}` };
  const org = (await must(master('POST', '/organizations', A, orgIn), 'create organization')).json.organization;
  record('Platform admin', 'creates the restaurant', `${org.business_name} (${org.id.slice(0, 8)})`, !!org.id);
  const branch = (await must(master('POST', `/organizations/${org.id}/locations`, A, { name: 'Saffron Indiranagar', code: `SF-${RUN}`, area: 'Indiranagar' }), 'create branch')).json.location;
  record('Platform admin', 'adds its first branch', branch.name, !!branch.id);
  const ownerEmail = `owner+${RUN}@saffron.test`;
  const invited = (await must(master('POST', `/organizations/${org.id}/accounts`, A, {
    first_name: 'Asha', last_name: 'Rao', email: ownerEmail, phone_number: '+91 90000 11111', password: PW.invite, pos_role: 'org_owner', location_id: null,
  }), 'invite owner')).json.account;
  record('Platform admin', 'invites the owner (temporary password)', `${ownerEmail} as ${invited.pos_role}`, invited.pos_role === 'org_owner');

  /* ---------- 2. Owner: first sign-in on the POS ---------- */
  const badLogin = await pos('POST', '/v1/auth/login', undefined, { email: ownerEmail, password: 'wrong-password' });
  record('Owner', 'wrong password is refused', `status ${badLogin.status}`, badLogin.status === 401 || badLogin.status === 400);
  const first = await must(pos('POST', '/v1/auth/login', undefined, { email: ownerEmail, password: PW.invite }), 'owner first login');
  const me1 = first.data.me;
  record('Owner', 'signs in with the invited password', `${me1.organization.name}, role ${me1.member.role}`, me1.organization.id === org.id && me1.member.role === 'org_owner');
  record('Owner', 'is told to choose their own password', `must_change_password = ${me1.must_change_password}`, me1.must_change_password === true);
  record('Owner', 'sees the full screen catalogue', `${me1.screens?.length ?? 0} screens`, (me1.screens?.length ?? 0) > 10);
  const shortPw = await pos('POST', '/v1/auth/change-password', first.data.session.access_token, { current_password: PW.invite, new_password: 'short' });
  record('Owner', 'a weak new password is refused', `status ${shortPw.status}`, shortPw.status >= 400 && shortPw.status < 500);
  const changed = await must(pos('POST', '/v1/auth/change-password', first.data.session.access_token, { current_password: PW.invite, new_password: PW.owner }), 'change password');
  const oldPw = await pos('POST', '/v1/auth/login', undefined, { email: ownerEmail, password: PW.invite });
  record('Owner', 'the invited password stops working', `status ${oldPw.status}`, oldPw.status === 401 || oldPw.status === 400);
  const second = await must(pos('POST', '/v1/auth/login', undefined, { email: ownerEmail, password: PW.owner }), 'owner second login');
  record('Owner', 'signs in with the new password', `must_change_password = ${second.data.me.must_change_password}`, second.data.me.must_change_password === false);
  const O = second.data.session.access_token as string;
  const meOwner = (await must(pos('GET', '/v1/auth/me', O), 'me')).data;
  const bId = (meOwner.location?.id ?? meOwner.locations?.[0]?.id ?? branch.id) as string;
  record('Owner', 'lands in their own restaurant and branch', `${meOwner.organization.name} / ${meOwner.location?.name ?? branch.name}`, meOwner.organization.id === org.id);
  const bearerOnly = await pos('GET', '/v1/master/menu-items', undefined);
  record('Owner', 'API refuses a request with no token', `status ${bearerOnly.status}`, bearerOnly.status === 401);
  void changed;

  /* ---------- 3. Owner builds the team ---------- */
  await must(pos('POST', '/v1/staff/roles/seed', O, {}), 'seed roles');
  const rolesRes = (await must(pos('GET', '/v1/staff/roles', O), 'list roles')).data;
  const roles = (rolesRes.roles ?? rolesRes) as any[];
  const roleFor = (base: string) => roles.find((r) => r.base_role === base && r.is_default) ?? roles.find((r) => r.base_role === base);
  record('Owner', 'gets the standard staff roles', roles.map((r) => r.name).join(', '), roles.length >= 5);
  const team: Array<[string, string, string]> = [
    ['Restaurant Admin', 'org_admin', 'admin'], ['Branch Manager', 'location_manager', 'manager'],
    ['Cashier', 'biller', 'cashier'], ['Captain', 'captain', 'captain'], ['Kitchen', 'kitchen', 'kitchen'],
  ];
  const tokens: Record<string, string> = {};
  const emails: Record<string, string> = {};
  for (const [label, base, key] of team) {
    const role = roleFor(base);
    if (!role) { record('Owner', `creates a ${label} login`, 'no matching role', false); continue; }
    emails[key] = `${key}+${RUN}@saffron.test`;
    const branchBound = base !== 'org_admin';
    const created = await pos('POST', '/v1/staff/logins', O, {
      email: emails[key], password: PW.staff, role_id: role.id, first_name: label.split(' ')[0], last_name: 'Test',
      location_id: branchBound ? bId : null, force_password_change: true,
    });
    record('Owner', `creates a ${label} login`, `${emails[key]} (status ${created.status})`, created.status === 201);
  }
  const logins = (await must(pos('GET', '/v1/staff/logins', O), 'list logins')).data as any[];
  record('Owner', 'sees the team in the staff directory', `${logins.length} logins`, logins.length >= 6 && Object.values(emails).every((e) => logins.some((l) => l.email === e)));

  /* ---------- 4. Every staff member signs in (and replaces the temporary password) ---------- */
  const screens: Record<string, string[]> = {};
  for (const [label, , key] of team) {
    if (!emails[key]) continue;
    const s1 = await pos('POST', '/v1/auth/login', undefined, { email: emails[key], password: PW.staff });
    if (s1.status !== 200) { record(label, 'signs in with the temporary password', `status ${s1.status}`, false); continue; }
    const must1 = s1.data.me.must_change_password === true;
    await must(pos('POST', '/v1/auth/change-password', s1.data.session.access_token, { current_password: PW.staff, new_password: PW.staffNew }), `${label} change password`);
    const s2 = await must(pos('POST', '/v1/auth/login', undefined, { email: emails[key], password: PW.staffNew }), `${label} relogin`);
    tokens[key] = s2.data.session.access_token;
    screens[key] = s2.data.me.screens ?? [];
    record(label, 'signs in, is asked for a new password, then signs in again',
      `${s2.data.me.organization.name}, ${s2.data.me.member.role}, ${screens[key].length} screens`, must1 && s2.data.me.organization.id === org.id && s2.data.me.must_change_password === false);
  }
  record('Roles', 'kitchen sees fewer screens than the cashier, the cashier fewer than the owner',
    `kitchen ${screens.kitchen?.length}, cashier ${screens.cashier?.length}, owner ${meOwner.screens.length}`,
    (screens.kitchen?.length ?? 99) < (screens.cashier?.length ?? 0) && (screens.cashier?.length ?? 99) < meOwner.screens.length);

  /* ---------- 5. Modules: each role does its job ---------- */
  const cat = (await must(pos('POST', '/v1/master/menu-categories', O, { name: 'House Specials' }), 'category')).data;
  const dishes: Array<[string, number, string]> = [['Veg Biryani', 220, 'veg'], ['Butter Naan', 45, 'veg'], ['Masala Chai', 30, 'veg']];
  for (const [name, price, food] of dishes) await must(pos('POST', '/v1/master/menu-items', O, { name, price, category_id: cat.id, food_type: food }), `menu ${name}`);
  const items = (await must(pos('GET', '/v1/master/menu-items?limit=500', O), 'menu list')).data as any[];
  record('Owner', 'builds the menu', dishes.map(([n, p]) => `${n} ${p}`).join(', '), dishes.every(([n, p]) => Number(items.find((i) => i.name === n)?.price) === p));
  const dish = (n: string) => items.find((i) => i.name === n)!;
  const hall = (await must(pos('POST', '/v1/operations/dining-areas', O, { name: 'Main Hall' }), 'area')).data;
  await must(pos('POST', '/v1/operations/dining-tables', O, { label: 'T1', seats: 4, area_id: hall.id }), 'table');
  const tables = (await must(pos('GET', '/v1/operations/dining-tables', O), 'tables')).data as any[];
  record('Owner', 'lays out the floor', 'Main Hall with T1', tables.some((t) => t.label === 'T1'));
  await must(pos('PUT', '/v1/master/raw-materials', O, { id: `rm-${RUN}`, code: 'RM-1', name: 'Basmati Rice', category: 'Grains', unit: 'kg', stock_qty: 25, reorder_level: 10, max_capacity: 100, purchase_cost: 95, last_purchase_price: 95, hsn: '', emoji: '', lead_time_days: 1, active: true, created_at: new Date().toISOString() }), 'raw material');
  const rm = (await must(pos('GET', '/v1/master/raw-materials', O), 'materials')).data as any[];
  record('Owner', 'stocks inventory', 'Basmati Rice 25 kg', rm.some((r) => r.id === `rm-${RUN}`));

  const cap = tokens.captain;
  const order = (await must(pos('POST', '/v1/operations/orders', cap, {
    channel: 'dine_in', table_id: tables.find((t) => t.label === 'T1').id, guest_count: 2, captain_name: 'Captain Test', placed_by: 'captain',
    items: [{ menu_item_id: dish('Veg Biryani').id, qty: 2 }, { menu_item_id: dish('Masala Chai').id, qty: 2 }],
  }), 'captain order')).data;
  const stored = (await must(pos('GET', `/v1/operations/orders/${order.id}`, O), 'order read-back')).data;
  record('Captain', 'takes a table order', `${stored.items.length} lines, status ${stored.status}`, stored.status === 'sent_to_kitchen' && stored.kot_tickets.length === 1);
  const capPays = await pos('POST', `/v1/operations/orders/${order.id}/payments`, cap, { method: 'cash', amount: Number(order.total) });
  record('Captain', 'cannot take money', `status ${capPays.status}`, capPays.status === 403);

  const kq = (await must(pos('GET', '/v1/operations/kot-tickets', tokens.kitchen), 'kitchen queue')).data as any[];
  const kot = kq.find((k) => k.order_id === order.id);
  let ready: any = null;
  if (kot) { await must(pos('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, tokens.kitchen), 'start'); ready = (await must(pos('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, tokens.kitchen), 'ready')).data; }
  record('Kitchen', 'sees the KOT and marks it ready', `status ${ready?.status}`, ready?.status === 'ready');
  const kOrder = await pos('POST', '/v1/operations/orders', tokens.kitchen, { channel: 'pickup', items: [{ menu_item_id: dish('Masala Chai').id, qty: 1 }] });
  record('Kitchen', 'cannot place orders', `status ${kOrder.status}`, kOrder.status === 403);

  const paid = (await must(pos('POST', `/v1/operations/orders/${order.id}/payments`, tokens.cashier, { method: 'cash', amount: Number(order.total) }, { 'Idempotency-Key': `onb-${RUN}` }), 'cashier pays')).data;
  record('Cashier', 'collects the cash payment', `order ${paid.status}`, paid.status === 'paid');
  const walk = (await must(pos('POST', '/v1/operations/orders', tokens.cashier, { channel: 'pickup', customer_name: 'Walk-in', items: [{ menu_item_id: dish('Butter Naan').id, qty: 4 }] }), 'walk-in')).data;
  const upi = (await must(pos('POST', `/v1/operations/orders/${walk.id}/payments`, tokens.cashier, { method: 'upi', amount: Number(walk.total), reference: `UTR${RUN}` }), 'upi')).data;
  record('Cashier', 'takes a takeaway paid by UPI', `order ${upi.status}`, upi.status === 'awaiting_payment');
  const cashierVerify = await pos('POST', `/v1/operations/orders/${walk.id}/verify-payment`, tokens.cashier, {});
  record('Cashier', 'cannot verify UPI', `status ${cashierVerify.status}`, cashierVerify.status === 403);
  const verified = (await must(pos('POST', `/v1/operations/orders/${walk.id}/verify-payment`, tokens.manager, { reference: `UTR${RUN}` }), 'manager verify')).data;
  record('Branch Manager', 'verifies the UPI payment', `order ${verified.status}`, verified.status === 'paid');
  const summary = (await must(pos('GET', '/v1/operations/summary', tokens.admin), 'summary')).data;
  record('Restaurant Admin', 'reads the day summary', `${summary.orders} orders, ${summary.sales_minor} minor units`, Number(summary.orders) >= 2 && Number(summary.sales_minor) > 0);

  /* ---------- 6. A second restaurant cannot see the first ---------- */
  const org2 = (await must(master('POST', '/organizations', A, { business_name: `Other Kitchen ${RUN}`, domain: `other${RUN}`, email: `hello+2${RUN}@other.test`, phone_number: `+91 97${rnd(10000000, 99999999)}` }), 'org2')).json.organization;
  const e2 = `owner2+${RUN}@other.test`;
  await must(master('POST', `/organizations/${org2.id}/accounts`, A, { first_name: 'Ravi', last_name: 'Kumar', email: e2, phone_number: '+91 90000 22222', password: PW.invite, pos_role: 'org_owner' }), 'owner2');
  const l2 = await must(pos('POST', '/v1/auth/login', undefined, { email: e2, password: PW.invite }), 'owner2 login');
  const O2 = l2.data.session.access_token as string;
  const items2 = (await must(pos('GET', '/v1/master/menu-items?limit=500', O2), 'menu2')).data as any[];
  const seen = await pos('GET', `/v1/operations/orders/${order.id}`, O2);
  record('Second restaurant', "cannot see the first restaurant's menu or orders", `${items2.length} menu items; order lookup status ${seen.status}`, items2.length === 0 && (seen.status === 404 || seen.status === 403));

  /* ---------- 7. Master admin can suspend a login ---------- */
  const cashierAcc = (await must(master('GET', `/organizations/${org.id}/accounts`, A), 'accounts')).json.accounts?.find((a: any) => a.email === emails.cashier);
  if (cashierAcc) {
    await must(master('PATCH', `/organizations/${org.id}/accounts/${cashierAcc.id}`, A, { status: 'Suspended' }), 'suspend');
    const blocked = await pos('POST', '/v1/auth/login', undefined, { email: emails.cashier, password: PW.staffNew });
    record('Platform admin', 'suspends the cashier: they can no longer sign in', `status ${blocked.status}`, blocked.status >= 400 && blocked.status < 500);
  }

  await report();
}

async function report() {
  const failed = steps.filter((s) => !s.pass).length;
  const md = [
    `# Onboarding flow - ${new Date().toISOString()}`, '',
    `Run ${RUN} - local database, POS backend and master-admin on one shared JWT secret - ${steps.length} steps, ${steps.length - failed} passed, ${failed} failed`, '',
    '| Who | What | Checked | Result |', '|---|---|---|---|',
    ...steps.map((s) => `| ${s.who} | ${s.what} | ${s.check.replace(/\|/g, '/')} | ${s.pass ? 'PASS' : '**FAIL**'} |`), '',
  ].join('\n');
  const dir = new URL('../../docs/qa/', import.meta.url);
  mkdirSync(dir, { recursive: true });
  writeFileSync(new URL(`ONBOARDING-${RUN}.md`, dir), md);
  console.log(`\n${steps.length} steps, ${failed} failed. Report: docs/qa/ONBOARDING-${RUN}.md`);
  stopAll();
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  console.error('\n--- POS log tail ---\n' + logs.pos.slice(-1500) + '\n--- master log tail ---\n' + logs.master.slice(-1500));
  stopAll();
  process.exit(1);
});
