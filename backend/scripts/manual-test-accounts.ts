/**
 * Creates (or refreshes) one login per built-in role in a test restaurant,
 * for testing the vendor panel by hand, then signs each one in and records
 * what the server gives it. Run against a RUNNING backend:
 *
 *   QA_BASE=http://localhost:8787 QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… \
 *     npx tsx scripts/manual-test-accounts.ts
 *
 * Logins are `test.<role>@<owner's email domain>`, made through the same
 * Staff API the app's Staff screen uses, each with a staff role that has
 * exactly the built-in role's default screens. Branch roles get the owner's
 * default branch as home branch. Passwords are new on every run and are
 * written only to the git-ignored .data/manual-test-accounts.txt.
 * `test.first-login@…` (a cashier) must set a new password at first sign-in.
 * Never point it at production without the owner's go-ahead.
 */
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { defaultScreens, SCREENS } from '../src/access.js';
import { BRANCH_BOUND_ROLES, panelFor, POS_ROLE_NAMES, POS_ROLES } from '../src/permissions.js';

const BASE = (process.env.QA_BASE ?? 'http://localhost:8787').replace(/\/$/, '');
const OWNER_EMAIL = process.env.QA_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.QA_OWNER_PASSWORD;
if (!OWNER_EMAIL || !OWNER_PASSWORD) {
  console.error('Set QA_OWNER_EMAIL and QA_OWNER_PASSWORD (a restaurant owner login created in master-admin).');
  process.exit(2);
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
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${json?.error?.message ?? text}`);
  return json?.data;
}

const sameSet = (a: string[], b: string[]) => a.length === b.length && [...a].sort().join() === [...b].sort().join();
const label = (id: string) => SCREENS.find((s) => s.id === id)?.label ?? id;
const password = () => `Test-${randomBytes(4).toString('hex')}-${randomBytes(2).toString('hex').toUpperCase()}9`;

async function main() {
  const login = await call('POST', '/v1/auth/login', undefined, { email: OWNER_EMAIL, password: OWNER_PASSWORD });
  const O = login.session.access_token as string;
  const me = login.me;
  const org = me.organization.name as string;
  const home = me.location as { id: string; name: string } | null;
  const domain = OWNER_EMAIL!.split('@')[1];

  // A staff role per built-in role with exactly its default screens.
  let { roles } = await call('GET', '/v1/staff/roles', O);
  if (!roles.length) roles = await call('POST', '/v1/staff/roles/seed', O);
  const roleFor = new Map<string, any>();
  for (const base of POS_ROLES) {
    if (base === 'org_owner') continue;
    let role = roles.find((r: any) => r.base_role === base && sameSet(r.screens, defaultScreens(base)));
    if (!role) {
      role = await call('POST', '/v1/staff/roles', O, { name: `Test · ${POS_ROLE_NAMES[base]}`, base_role: base });
    }
    roleFor.set(base, role);
  }

  const wanted = [
    ...POS_ROLES.filter((b) => b !== 'org_owner').map((base) => ({ base, email: `test.${base.replace(/_/g, '-')}@${domain}`, force: false })),
    { base: 'biller', email: `test.first-login@${domain}`, force: true },
  ];
  const existing: any[] = await call('GET', '/v1/staff/logins', O);
  const out: { base: string; email: string; password: string; force: boolean }[] = [];
  for (const w of wanted) {
    const pw = password();
    const role = roleFor.get(w.base);
    const branch = BRANCH_BOUND_ROLES.has(w.base) ? (home?.id ?? null) : null;
    const found = existing.find((l) => String(l.email).toLowerCase() === w.email);
    if (found) {
      await call('PATCH', `/v1/staff/logins/${found.user_id}`, O, { role_id: role.id, status: 'Active', location_id: branch });
      await call('POST', `/v1/staff/logins/${found.user_id}/reset-password`, O, { password: pw, force_change: w.force });
    } else {
      await call('POST', '/v1/staff/employees', O, {
        full_name: `Test ${w.force ? 'First Login' : POS_ROLE_NAMES[w.base]}`,
        mobile: '+91 90000 00000',
        email: w.email,
        designation: POS_ROLE_NAMES[w.base],
        location_id: branch,
        login: { password: pw, role_id: role.id, force_password_change: w.force },
      });
    }
    out.push({ base: w.base, email: w.email, password: pw, force: w.force });
  }

  // Sign each in and record what the server gives it.
  const checked: any[] = [];
  for (const a of out) {
    const s = await call('POST', '/v1/auth/login', undefined, { email: a.email, password: a.password });
    const screens: string[] = s.me.screens;
    const expected = defaultScreens(a.base);
    checked.push({
      email: a.email,
      base: a.base,
      role: s.me.member.role,
      role_name: s.me.member.role_name,
      panel: s.me.panel,
      branch: s.me.locations.length === 1 ? s.me.locations[0].name : `all (${s.me.locations.length})`,
      must_change_password: s.me.must_change_password,
      screens: screens.map(label),
      ok: s.me.member.role === a.base && s.me.panel === panelFor(a.base) && sameSet(screens, expected),
    });
    await call('POST', '/v1/auth/logout', s.session.access_token);
  }

  mkdirSync(new URL('../.data/', import.meta.url), { recursive: true });
  writeFileSync(
    new URL('../.data/manual-test-accounts.txt', import.meta.url),
    [
      `MANUAL TEST LOGINS — ${org} (${BASE}) — created ${new Date().toISOString()}`,
      'Test accounts on the LOCAL database only. Re-running the script replaces these passwords.',
      '',
      `owner                ${OWNER_EMAIL}  (password: see qa-accounts.txt)`,
      ...out.map((a) => `${(a.force ? 'biller (first login)' : a.base).padEnd(20)} ${a.email}  ${a.password}`),
      '',
    ].join('\n'),
  );
  writeFileSync(new URL('../.data/manual-test-accounts.json', import.meta.url), JSON.stringify({ org, home: home?.name ?? null, accounts: checked }, null, 2));
  for (const c of checked) console.log(`${c.ok ? 'OK  ' : 'FAIL'} ${c.email.padEnd(40)} ${c.role.padEnd(20)} ${c.panel.padEnd(6)} ${c.branch.padEnd(24)} ${c.screens.length} screens${c.must_change_password ? ' · must change password' : ''}`);
  const bad = checked.filter((c) => !c.ok);
  console.log(`\n${checked.length} logins, ${bad.length} wrong. Passwords: backend/.data/manual-test-accounts.txt`);
  if (bad.length) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
