import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { defaultScreens, grantableScreens, SCREENS, screensFor } from '../src/access.js';
import { forgetMembership } from '../src/context.js';
import { POS_ROLES } from '../src/permissions.js';
import { addStaff, call, login, makeWorld, PASSWORD, type World } from './helpers.js';

/// Staff & Users end to end on the real schema: employees with app logins,
/// staff roles deciding each login's screens, attendance → salary,
/// approvals, login security, audit log, training — and that nobody can
/// reach a tab (or grant a role) beyond their own access.
describe('staff & users', () => {
  let w: World;
  let admin: string;
  // The branches run on India time, as the server's "today" does.
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
  const [year, month] = today.split('-').map(Number) as [number, number];

  beforeAll(async () => {
    w = await makeWorld();
    admin = await login(w, 'admin@spicybistro.test');
  }, 60_000);
  afterAll(() => w.close());

  const api = <T = any>(method: string, path: string, body?: unknown, token = admin) => call<T>(w, method, path, { token, body });

  let roles: Record<string, string> = {};

  it('seeds the default staff roles and describes the catalogue', async () => {
    const empty = await api('GET', '/v1/staff/roles');
    expect(empty.status).toBe(200);
    expect(empty.body.data.roles).toEqual([]);
    const biller = empty.body.data.catalogue.base_roles.find((b: any) => b.key === 'biller');
    expect(biller.panel).toBe('pos');
    expect(biller.default_screens).toContain('pos.billing');
    expect(biller.grantable.every((s: string) => s.startsWith('pos.'))).toBe(true);

    const seeded = await api('POST', '/v1/staff/roles/seed');
    expect(seeded.status).toBe(200);
    roles = Object.fromEntries(seeded.body.data.map((r: any) => [r.name, r.id]));
    expect(Object.keys(roles)).toEqual(
      expect.arrayContaining(['Restaurant Admin', 'Branch Manager', 'Cashier', 'Captain', 'Kitchen (KOT)']),
    );
    const again = await api('POST', '/v1/staff/roles/seed');
    expect(again.body.data).toHaveLength(seeded.body.data.length);
  });

  let cashierStaffId = '';
  it('adds an employee with an app login; the login opens only the POS billing screens', async () => {
    const r = await api('POST', '/v1/staff/employees', {
      full_name: 'Suresh Kumar',
      mobile: '+91 8877665544',
      email: 'suresh@spicybistro.test',
      designation: 'Cashier',
      department: 'Billing',
      joining_date: '2023-11-01',
      salary_type: 'monthly',
      monthly_salary: 18000,
      account_number: '123456789012',
      login: { password: 'Cashier-Pass-2026', role_id: roles.Cashier },
    });
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    cashierStaffId = r.body.data.id;
    expect(r.body.data.staff_code).toMatch(/^SPI-\d{3}$/);
    expect(r.body.data.role_name).toBe('Cashier');
    expect(r.body.data.login.email).toBe('suresh@spicybistro.test');

    const signIn = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'Cashier-Pass-2026' } });
    expect(signIn.status).toBe(200);
    const me = signIn.body.data.me;
    expect(me.panel).toBe('pos');
    expect(me.member.role).toBe('biller');
    expect(me.member.role_name).toBe('Cashier');
    expect(me.screens).toEqual(defaultScreens('biller'));
    expect(me.screens.some((s: string) => s.startsWith('staff.') || s.startsWith('master.'))).toBe(false);

    // A cashier cannot open staff data.
    const token = signIn.body.data.session.access_token;
    expect((await api('GET', '/v1/staff/employees', undefined, token)).status).toBe(403);
    expect((await api('GET', '/v1/staff/salaries', undefined, token)).status).toBe(403);
  });

  it('shows logins with their role and linked staff, and changes a login role', async () => {
    const list = await api('GET', '/v1/staff/logins');
    const suresh = list.body.data.find((l: any) => l.email === 'suresh@spicybistro.test');
    expect(suresh).toMatchObject({ role_name: 'Cashier', pos_role: 'biller', staff_name: 'Suresh Kumar', status: 'Active' });

    const chef = await api('POST', '/v1/staff/logins', {
      email: 'ramesh@spicybistro.test',
      password: 'Chef-Pass-2026',
      role_id: roles['Kitchen (KOT)'],
      first_name: 'Ramesh',
      last_name: 'Singh',
      phone_number: '+91 7766554433',
    });
    expect(chef.status, JSON.stringify(chef.body)).toBe(201);
    const chefToken = await login(w, 'ramesh@spicybistro.test', 'Chef-Pass-2026');
    const me = await call(w, 'GET', '/v1/auth/me', { token: chefToken });
    expect(me.body.data.screens).toEqual(['pos.kitchen']);

    // Promote to Captain: pos_role follows the staff role.
    const up = await api('PATCH', `/v1/staff/logins/${chef.body.data.user_id}`, { role_id: roles.Captain });
    expect(up.status).toBe(200);
    expect(up.body.data).toMatchObject({ role_name: 'Captain', pos_role: 'captain' });
    forgetMembership();
    const me2 = await call(w, 'GET', '/v1/auth/me', { token: chefToken });
    expect(me2.body.data.screens).toEqual(defaultScreens('captain'));
  });

  it('custom roles narrow the screens and cannot exceed their base role', async () => {
    const bad = await api('POST', '/v1/staff/roles', { name: 'Sneaky Cashier', base_role: 'biller', screens: ['pos.billing', 'staff.salary'] });
    expect(bad.status).toBe(422);

    const custom = await api('POST', '/v1/staff/roles', { name: 'Counter Only', base_role: 'biller', screens: ['pos.billing', 'pos.takeaway'] });
    expect(custom.status).toBe(201);
    expect(custom.body.data).toMatchObject({ panel: 'pos', screens: ['pos.billing', 'pos.takeaway'] });

    const logins = await api('GET', '/v1/staff/logins');
    const suresh = logins.body.data.find((l: any) => l.email === 'suresh@spicybistro.test');
    await api('PATCH', `/v1/staff/logins/${suresh.user_id}`, { role_id: custom.body.data.id });
    forgetMembership();
    const token = await login(w, 'suresh@spicybistro.test', 'Cashier-Pass-2026');
    const me = await call(w, 'GET', '/v1/auth/me', { token });
    expect(me.body.data.screens).toEqual(['pos.billing', 'pos.takeaway']);

    // A role in use cannot be deleted.
    expect((await api('DELETE', `/v1/staff/roles/${custom.body.data.id}`)).status).toBe(409);
    await api('PATCH', `/v1/staff/logins/${suresh.user_id}`, { role_id: roles.Cashier });
  });

  it('a branch manager adds branch staff but cannot grant more than they have', async () => {
    await addStaff(w, w.spicy, 'mgr@spicybistro.test', 'location_manager');
    const mgr = await login(w, 'mgr@spicybistro.test');
    // Branch managers see attendance but not salaries or roles.
    expect((await api('GET', `/v1/staff/attendance?date=${today}`, undefined, mgr)).status).toBe(200);
    // Their dashboard counts their branch, not the whole restaurant.
    const mine = await api('GET', '/v1/staff/employees', undefined, mgr);
    const dash = await api('GET', '/v1/staff/dashboard', undefined, mgr);
    expect(dash.status).toBe(200);
    expect(dash.body.data.total).toBe(mine.body.data.length);
    expect((await api('GET', '/v1/staff/salaries', undefined, mgr)).status).toBe(403);
    expect((await api('POST', '/v1/staff/roles', { name: 'Boss', base_role: 'org_admin' }, mgr)).status).toBe(403);

    // They create the branch's cashier, captain and kitchen logins…
    for (const [email, role] of [['c1@spicybistro.test', 'Cashier'], ['c2@spicybistro.test', 'Captain'], ['c3@spicybistro.test', 'Kitchen (KOT)']]) {
      const made = await api('POST', '/v1/staff/logins', { email, password: 'Branch-Staff-2026', role_id: roles[role] }, mgr);
      expect(made.status, JSON.stringify(made.body)).toBe(201);
    }
    // …but never an admin or an owner.
    const promote = await api('POST', '/v1/staff/logins', { email: 'x@spicybistro.test', password: 'Whatever-2026', role_id: roles['Restaurant Admin'] }, mgr);
    expect(promote.status).toBe(403);
    const owner = await api('POST', '/v1/staff/roles', { name: 'Co-owner', base_role: 'org_owner' }, mgr);
    expect(owner.status).toBe(403);
  });

  it('cannot touch another restaurant’s staff', async () => {
    const other = await login(w, 'admin@burgerexpress.test');
    expect((await api('PATCH', `/v1/staff/employees/${cashierStaffId}`, { full_name: 'Hacked' }, other)).status).toBe(404);
    const list = await api('GET', '/v1/staff/employees', undefined, other);
    expect(list.body.data).toEqual([]);
    const theirRole = (await api('GET', '/v1/staff/roles')).body.data.roles[0].id;
    const r = await api('POST', '/v1/staff/logins', { email: 'y@burger.test', password: 'Whatever-2026', role_id: theirRole }, other);
    expect(r.status).toBe(422);
  });

  it('attendance, advances and salary generation add up', async () => {
    const all = await api('POST', '/v1/staff/attendance/mark-all-present', { date: today });
    expect(all.status).toBe(200);
    expect(all.body.data.every((a: any) => a.status === 'present')).toBe(true);

    const other = `${year}-${String(month).padStart(2, '0')}-${today.endsWith('-01') ? '02' : '01'}`;
    const put = await api('PUT', '/v1/staff/attendance', {
      date: other,
      entries: [{ staff_id: cashierStaffId, status: 'absent' }],
    });
    expect(put.status).toBe(200);

    const adv = await api('POST', '/v1/staff/advances', {
      staff_id: cashierStaffId,
      amount: 1000,
      deduct_month: month,
      deduct_year: year,
      reason: 'Travel',
      mode: 'cash',
    });
    expect(adv.status).toBe(201);

    const gen = await api('POST', '/v1/staff/salaries/generate', { year, month });
    expect(gen.status).toBe(200);
    const row = gen.body.data.find((r: any) => r.staff_id === cashierStaffId);
    const days = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const basic = Math.round((18000 - 18000 / days) * 100) / 100;
    expect(row.basic).toBeCloseTo(basic, 2);
    expect(row.advance).toBe(1000);
    expect(row.net).toBeCloseTo(basic - 1000, 2);

    const paid = await api('POST', `/v1/staff/salaries/${row.id}/pay`, {});
    expect(paid.body.data).toMatchObject({ status: 'paid', pending: 0 });
    const advances = await api('GET', '/v1/staff/advances');
    expect(advances.body.data[0].status).toBe('deducted');
    const dash = await api('GET', '/v1/staff/dashboard');
    expect(dash.body.data.paid_month).toBeCloseTo(row.net, 2);
    expect(dash.body.data.present_today).toBeGreaterThan(0);
  });

  it('approving leave marks attendance; approving an advance records it', async () => {
    const leave = await api('POST', '/v1/staff/approvals', {
      staff_id: cashierStaffId,
      type: 'leave',
      details: { from: '2026-12-24', to: '2026-12-26', reason: 'Family function' },
    });
    expect(leave.status).toBe(201);
    const decided = await api('POST', `/v1/staff/approvals/${leave.body.data.id}/decide`, { decision: 'approve' });
    expect(decided.body.data.status).toBe('approved');
    const att = await api('GET', '/v1/staff/attendance?date=2026-12-25');
    expect(att.body.data.find((a: any) => a.staff_id === cashierStaffId).status).toBe('leave');
    expect((await api('POST', `/v1/staff/approvals/${leave.body.data.id}/decide`, { decision: 'decline' })).status).toBe(409);

    // Self-service: the cashier asks for an advance from the POS.
    const cashier = await login(w, 'suresh@spicybistro.test', 'Cashier-Pass-2026');
    const ask = await api('POST', '/v1/staff/me/requests', { type: 'salary_advance', details: { amount: 500, reason: 'Medical' } }, cashier);
    expect(ask.status).toBe(201);
    const pending = await api('GET', '/v1/staff/approvals');
    expect(pending.body.data.stats).toMatchObject({ pending: 1, approved: 1 });
    await api('POST', `/v1/staff/approvals/${ask.body.data.id}/decide`, { decision: 'approve' });
    const advances = await api('GET', `/v1/staff/advances?staff_id=${cashierStaffId}`);
    expect(advances.body.data.some((a: any) => a.amount === 500 && a.status === 'open')).toBe(true);
  });

  it('login security: wrong passwords lock the login; an admin reset unlocks it and forces a change', async () => {
    for (let i = 0; i < 4; i++) {
      const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'nope-nope' } });
      expect(r.status).toBe(401);
    }
    // The fifth wrong password locks the login, but a wrong guess never
    // learns that (same 401 as an unknown email) …
    const locked = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'nope-nope' } });
    expect(locked.status).toBe(401);
    const unknown = await call(w, 'POST', '/v1/auth/login', { body: { email: 'nobody@spicybistro.test', password: 'nope-nope' } });
    expect(unknown.status).toBe(401);
    // … only the real password, which is refused while locked.
    const stillLocked = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'Cashier-Pass-2026' } });
    expect(stillLocked.status).toBe(423);

    const logins = await api('GET', '/v1/staff/logins');
    const suresh = logins.body.data.find((l: any) => l.email === 'suresh@spicybistro.test');
    expect(suresh.failed_attempts).toBe(5);
    expect(suresh.locked_until).toBeTruthy();

    expect((await api('POST', `/v1/staff/logins/${suresh.user_id}/reset-password`, { password: 'Temp-Pass-2026' })).status).toBe(204);
    const ok = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'Temp-Pass-2026' } });
    expect(ok.status).toBe(200);
    expect(ok.body.data.me.must_change_password).toBe(true);

    const token = ok.body.data.session.access_token;
    const change = await call(w, 'POST', '/v1/auth/change-password', {
      token,
      body: { current_password: 'Temp-Pass-2026', new_password: 'Cashier-Pass-2027' },
    });
    expect(change.status).toBe(200);
    // The old token is signed out with the old password; the new one works.
    expect((await call(w, 'GET', '/v1/auth/me', { token })).status).toBe(401);
    const fresh = change.body.data.session.access_token as string;
    const after = await call(w, 'GET', '/v1/auth/me', { token: fresh });
    expect(after.body.data.must_change_password).toBe(false);

    const history = await api('GET', '/v1/staff/login-history');
    const mine = history.body.data.filter((e: any) => e.email === 'suresh@spicybistro.test');
    expect(mine.some((e: any) => e.success === false && e.reason === 'locked')).toBe(true);
    expect(mine.some((e: any) => e.success === true)).toBe(true);
  });

  it('shifts and roster: assign, clock in, clock out', async () => {
    const shift = await api('POST', '/v1/staff/shifts', { name: 'All day', start_time: '00:00', end_time: '23:59', break_minutes: 0, grace_minutes: 240 });
    expect(shift.status).toBe(201);
    const assign = await api('POST', '/v1/staff/roster', { date: today, staff_id: cashierStaffId, shift_id: shift.body.data.id });
    expect(assign.status).toBe(201);
    const row = assign.body.data.rows.find((r: any) => r.staff_id === cashierStaffId);
    expect(row.shift_name).toBe('All day');
    const inn = await api('POST', `/v1/staff/roster/${row.roster_id}/clock-in`);
    expect(inn.body.data.stats.on_shift).toBe(1);
    const out = await api('POST', `/v1/staff/roster/${row.roster_id}/clock-out`);
    expect(out.body.data.rows.find((r: any) => r.staff_id === cashierStaffId).clock_out).toBeTruthy();
    expect((await api('POST', `/v1/staff/roster/${row.roster_id}/clock-out`)).status).toBe(409);
  });

  it('training: build a test, take it, see progress', async () => {
    const m = await api('POST', '/v1/staff/training', {
      title: 'Kitchen Fire Safety Protocol',
      roles: ['Cashier'],
      pass_score: 50,
      videos: [{ title: 'Fire extinguisher types', duration: '8:30' }],
      questions: [
        { question: 'Extinguisher for electrical fires?', options: ['Water', 'CO2', 'Foam', 'Sand'], answer_index: 1 },
        { question: 'First step during a kitchen fire?', options: ['Shut off gas', 'Open windows'], answer_index: 0 },
      ],
      status: 'published',
    });
    expect(m.status, JSON.stringify(m.body)).toBe(201);
    const fail = await api('POST', `/v1/staff/training/${m.body.data.id}/attempts`, { staff_id: cashierStaffId, answers: [0, 1] });
    expect(fail.body.data).toMatchObject({ score: 0, passed: false });
    const pass = await api('POST', `/v1/staff/training/${m.body.data.id}/attempts`, { staff_id: cashierStaffId, answers: [1, 0] });
    expect(pass.body.data).toMatchObject({ score: 100, passed: true, correct: 2, total: 2 });
    const overview = await api('GET', '/v1/staff/training');
    const mod = overview.body.data.modules[0];
    expect(mod.assigned_count).toBe(1);
    expect(mod.progress[0]).toMatchObject({ staff_name: 'Suresh Kumar', status: 'passed', best_score: 100 });
    expect(overview.body.data.stats).toMatchObject({ modules: 1, completions_passed: 1, failed_attempts: 1 });
  });

  it('audit log records panel actions from every module; reports export', async () => {
    await api('POST', '/v1/operations/dining-areas', { name: 'Terrace' });
    const log = await api('GET', '/v1/staff/audit-log');
    const actions = log.body.data.map((e: any) => `${e.action} | ${e.entity}`);
    expect(actions).toEqual(expect.arrayContaining(['Created staff member with app login | Staff', 'Generated salaries | Salary', 'Created | Operations · dining areas']));
    expect(log.body.data[0].actor_name).toBe('Asha Admin');
    const search = await api('GET', '/v1/staff/audit-log?q=salar');
    expect(search.body.data.length).toBeGreaterThan(0);
    expect(search.body.data.every((e: any) => /salar/i.test(`${e.action} ${e.entity}`))).toBe(true);

    const counts = await api('GET', '/v1/staff/reports');
    expect(counts.body.data).toMatchObject({ staff_list: 1, salaries: 1, salary_paid: 1, salary_pending: 0 });
    const list = await api('GET', '/v1/staff/reports/staff_list');
    expect(list.body.data.columns[1]).toBe('Name');
    expect(list.body.data.rows[0][1]).toBe('Suresh Kumar');
  });

  it('removing an employee deactivates their login', async () => {
    expect((await api('DELETE', `/v1/staff/employees/${cashierStaffId}`)).status).toBe(204);
    const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'suresh@spicybistro.test', password: 'Cashier-Pass-2027' } });
    expect(r.status).toBe(403);
    expect(PASSWORD).toBeTruthy();
  });

  it('every default screen is grantable for its role, and ids are unique', () => {
    expect(new Set(SCREENS.map((s) => s.id)).size).toBe(SCREENS.length);
    for (const key of POS_ROLES) {
      const allowed = new Set(grantableScreens(key));
      expect(defaultScreens(key).filter((s) => !allowed.has(s)), key).toEqual([]);
    }
  });

  it('the business sections: owners see all nine, a branch manager three, the floor none', () => {
    const business = SCREENS.filter((s) => s.group === 'Business').map((s) => s.id);
    expect(business).toEqual(['task_manager', 'customers', 'marketing', 'finance', 'integrations', 'settings']);
    const placeholders = SCREENS.filter((s) => s.group === 'Coming soon').map((s) => s.id);
    expect(placeholders).toEqual(['reports', 'page_builder', 'support']);
    const soon = [...business, ...placeholders];
    for (const owner of ['org_owner', 'org_admin']) {
      expect(defaultScreens(owner), owner).toEqual(expect.arrayContaining(soon));
    }
    const branch = ['customers', 'finance', 'reports'];
    expect(defaultScreens('location_manager').filter((s) => soon.includes(s)).sort()).toEqual(branch);
    // …and a custom role on Branch Manager cannot be given the rest.
    expect(grantableScreens('location_manager').filter((s) => soon.includes(s)).sort()).toEqual(branch);
    for (const floor of ['biller', 'captain', 'kitchen']) {
      expect(grantableScreens(floor).filter((s) => soon.includes(s)), floor).toEqual([]);
    }
  });

  it('a section added after a role was saved reaches it, until an admin edits the role', () => {
    const branch = ['reports', 'customers', 'finance'];
    const saved = defaultScreens('location_manager').filter((s) => !branch.includes(s));
    const before = '2026-09-29T10:00:00.000Z';
    const after = '2026-10-01T10:00:00.000Z';
    expect(screensFor('location_manager', saved, before)).toEqual([...saved, ...branch]);
    // Saved after the sections existed: the admin's choice stands.
    expect(screensFor('location_manager', saved, after)).toEqual(saved);
    expect(screensFor('org_admin', ['dashboard'], before)).toContain('settings');
    // Only what the base role gets by default, never more.
    expect(screensFor('location_manager', saved, before)).not.toContain('settings');
  });
  it('staff and logins show their branch by name; not-found messages carry no ids', async () => {
    const me = await api('GET', '/v1/auth/me');
    const branch = me.body.data.locations[0];
    const made = await api('POST', '/v1/staff/employees', {
      full_name: 'Neha Kulkarni',
      email: 'neha@spicybistro.test',
      location_id: branch.id,
      login: { password: 'Captain-Pass-2026', role_id: roles.Captain, location_id: branch.id },
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const staff = await api('GET', '/v1/staff/employees');
    expect(staff.body.data.find((s: any) => s.full_name === 'Neha Kulkarni')).toMatchObject({ location_id: branch.id, location_name: branch.name });
    const logins = await api('GET', '/v1/staff/logins');
    expect(logins.body.data.find((l: any) => l.email === 'neha@spicybistro.test')).toMatchObject({ location_id: branch.id, location_name: branch.name });

    const missing = '00000000-0000-4000-8000-000000000000';
    for (const [method, path, body] of [
      ['PATCH', `/v1/staff/employees/${missing}`, { designation: 'Captain' }],
      ['PATCH', `/v1/staff/logins/${missing}`, { status: 'Active' }],
      ['PATCH', `/v1/staff/shifts/${missing}`, { name: 'Late' }],
      ['GET', '/v1/staff/reports/not-a-report', undefined],
    ] as const) {
      const r = await api(method, path, body);
      expect(r.status, path).toBeGreaterThanOrEqual(400);
      expect(r.body.error.message, path).not.toContain(missing);
      expect(r.body.error.message, path).not.toContain('not-a-report');
    }
  });
});
