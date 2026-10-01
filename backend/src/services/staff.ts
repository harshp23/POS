import { Hono } from 'hono';
import { z } from 'zod';
import { DEFAULT_STAFF_ROLES, defaultScreens, grantableScreens, roleCatalogue, screenLabel, screensFor } from '../access.js';
import { endSessions, hashPassword } from '../auth/master-admin.js';
import { forgetMembership, requireCan, requireScreen, type RequestContext } from '../context.js';
import { TextArray } from '../db/sql.js';
import type { Db, Row } from '../db/types.js';
import { ctxOf, intParam, readJson, type Env } from '../http.js';
import { ApiError, conflict, forbidden, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { localDate, localTime, localToEpoch, tzOf } from '../lib/time.js';
import { ACTION_WORDS, can, capabilities, MODULE_NAMES, panelFor, POS_ROLES, restaurantRole, roleName } from '../permissions.js';

/// Staff & Users: employees, logins and staff roles, attendance, shifts
/// and roster, advances, salaries, approvals, audit log, reports, training.
/// Every route checks the caller's screens (src/access.ts) on top of the
/// organization fence; logins are master-admin's public.users rows.

const S = {
  dashboard: 'staff.dashboard',
  directory: 'staff.directory',
  attendance: 'staff.attendance',
  salary: 'staff.salary',
  advances: 'staff.advances',
  roles: 'staff.roles',
  shifts: 'staff.shifts',
  loginSecurity: 'staff.login_security',
  approvals: 'staff.approvals',
  auditLog: 'staff.audit_log',
  reports: 'staff.reports',
  training: 'staff.training',
} as const;
const ANY_STAFF = Object.values(S);

const round2 = (n: number) => Math.round(n * 100) / 100;
const HHMM = z.string().regex(/^[0-2]\d:[0-5]\d$/, 'expected HH:MM');
const DATE = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected YYYY-MM-DD');
const OWNER_LIKE = ['org_owner', 'org_admin'];

/// The earlier default staff roles, by name → the role they became.
const OLD_DEFAULT_NAMES: Record<string, string> = {
  administrator: 'org_admin',
  manager: 'location_manager',
  biller: 'biller',
  chef: 'kitchen',
};

const daysInMonth = (year: number, month: number) => new Date(Date.UTC(year, month, 0)).getUTCDate();

// ── shared helpers ───────────────────────────────────────────────────────

const actorName = (ctx: RequestContext) => ctx.identity.full_name || ctx.identity.email;

async function audit(ctx: RequestContext, action: string, entity: string, entityId?: string | null, details: Row = {}) {
  await ctx.db.query(
    `insert into pos_audit_log (organization_id, actor_id, actor_name, action, entity, entity_id, details)
     values ($1, $2, $3, $4, $5, $6, $7)`,
    [ctx.m.organization_id, ctx.identity.user_id, actorName(ctx), action, entity, entityId ?? null, details],
  );
}

/// A staff member's name for audit rows ("" when gone).
async function staffName(ctx: RequestContext, staffId: unknown): Promise<string> {
  if (typeof staffId !== 'string' || !isUuid(staffId)) return '';
  const [r] = await ctx.db.query<Row>(`select full_name from pos_staff where id = $1 and organization_id = $2`, [staffId, ctx.m.organization_id]);
  return (r?.full_name as string) ?? '';
}

function uuidParam(id: string, what: string): string {
  if (!isUuid(id)) throw notFound(`This ${what} was not found.`);
  return id;
}

/// May the caller hand out [base] with [screens]? Owners and admins may
/// grant anything except ownership (owner only); others only what they
/// have themselves — never more module rights or more screens.
function assertCanGrant(ctx: RequestContext, base: string, screens: string[]) {
  const actor = ctx.m.role;
  if (base === 'org_owner' && actor !== 'org_owner' && !ctx.m.platform_admin) {
    throw forbidden('Only the owner can make someone an owner.');
  }
  if (ctx.m.platform_admin || OWNER_LIKE.includes(actor)) return;
  const mine = capabilities(actor);
  const theirs = capabilities(base);
  for (const [module, actions] of Object.entries(theirs)) {
    for (const a of actions) {
      if (!mine[module as keyof typeof mine]?.includes(a)) {
        throw forbidden(`You cannot grant a role with more access than your own (it can ${ACTION_WORDS[a] ?? a} ${MODULE_NAMES[module] ?? module} data).`);
      }
    }
  }
  const extra = screens.filter(
    (s) => !ctx.m.screens.includes(s) && !(s.startsWith('pos.') && can(actor, 'operations', 'write')),
  );
  if (extra.length) throw forbidden(`You cannot grant screens you don't have yourself: ${extra.map(screenLabel).join(', ')}.`);
}

/// May the caller change [targetRole]'s login (role, status, password)?
/// The owner only by the owner; otherwise nobody with more rights than the
/// caller (an HR manager cannot reset an admin's password).
function assertCanManage(ctx: RequestContext, storedRole: string) {
  const actor = ctx.m.role;
  const targetRole = restaurantRole(storedRole);
  if (ctx.m.platform_admin || actor === 'org_owner') return;
  if (targetRole === 'org_owner') throw forbidden("Only the owner can change the owner's login.");
  if (actor === 'org_admin') return;
  const mine = capabilities(actor);
  const theirs = capabilities(targetRole);
  for (const [module, actions] of Object.entries(theirs)) {
    for (const a of actions) {
      if (!mine[module as keyof typeof mine]?.includes(a)) {
        throw forbidden('You cannot change the login of someone with more access than you.');
      }
    }
  }
}

// ── views ────────────────────────────────────────────────────────────────

const EMPLOYEE_SQL = `
  select st.*, s.staff_role_id as role_id, r.name as role_name, u.email as login_email,
         coalesce(u.status, 'Active') as login_status, loc.name as location_name
    from pos_staff st
    left join org_locations loc on loc.id = st.location_id
    left join users u on u.id = st.user_id
    left join pos_login_security s on s.user_id = st.user_id
    left join pos_staff_roles r on r.id = s.staff_role_id and r.deleted_at is null
   where st.organization_id = $1 and st.deleted_at is null
     and ($2::uuid is null or st.location_id = $2::uuid)`;

function employeeView(r: Row, full: boolean) {
  const account = String(r.account_number ?? '');
  return {
    id: r.id,
    staff_code: r.staff_code,
    full_name: r.full_name,
    mobile: r.mobile,
    email: r.email,
    emergency_contact: full ? r.emergency_contact : '',
    designation: r.designation,
    department: r.department,
    bank_name: full ? r.bank_name : '',
    account_number: full ? account : account ? `••••${account.slice(-4)}` : '',
    ifsc: full ? r.ifsc : '',
    upi_id: full ? r.upi_id : '',
    photo_url: r.photo_url,
    id_proof_url: full ? r.id_proof_url : '',
    address: full ? r.address : '',
    joining_date: r.joining_date,
    salary_type: r.salary_type,
    monthly_salary: full ? r.monthly_salary : 0,
    daily_wage: full ? r.daily_wage : 0,
    hourly_rate: full ? r.hourly_rate : 0,
    working_hours: r.working_hours,
    compensation_model: r.compensation_model,
    incentive_type: r.incentive_type,
    incentive_value: full ? r.incentive_value : 0,
    status: r.status,
    location_id: r.location_id,
    location_name: r.location_name ?? null,
    delivery_enabled: r.delivery_enabled,
    user_id: r.user_id,
    role_id: r.role_id,
    role_name: r.role_name,
    login: r.user_id ? { user_id: r.user_id, email: r.login_email, status: r.login_status } : null,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
}

async function loadEmployees(ctx: RequestContext, id?: string) {
  const base = [ctx.m.organization_id, ctx.m.branch_scope];
  return ctx.db.query<Row>(`${EMPLOYEE_SQL}${id ? ' and st.id = $3' : ''} order by st.full_name`, id ? [...base, id] : base);
}

async function oneEmployee(ctx: RequestContext, id: string, db: Db = ctx.db) {
  const [row] = await db.query<Row>(`${EMPLOYEE_SQL} and st.id = $3`, [ctx.m.organization_id, ctx.m.branch_scope, uuidParam(id, 'staff member')]);
  if (!row) throw notFound('This staff member was not found.');
  return row;
}

const LOGIN_SQL = `
  select u.id as user_id,
         btrim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) as full_name,
         u.email, coalesce(u.phone_number, '') as phone_number, u.pos_role, coalesce(u.status, 'Active') as status,
         u.location_id, lo.name as location_name, s.staff_role_id as role_id, r.name as role_name, s.last_login_at, s.last_seen_at,
         coalesce(s.failed_attempts, 0) as failed_attempts, s.locked_until,
         coalesce(s.force_password_change, false) as force_password_change,
         coalesce(s.two_factor_enabled, false) as two_factor_enabled,
         st.id as staff_id, st.full_name as staff_name, st.staff_code, coalesce(st.delivery_enabled, false) as delivery_enabled
    from users u
    left join org_locations lo on lo.id = u.location_id
    left join pos_login_security s on s.user_id = u.id
    left join pos_staff_roles r on r.id = s.staff_role_id and r.deleted_at is null
    left join pos_staff st on st.user_id = u.id and st.deleted_at is null and st.organization_id = u.organization_id
   where u.organization_id = $1`;

const loginView = (r: Row) => {
  const role = restaurantRole(r.pos_role as string);
  return { ...r, pos_role: role, pos_role_name: roleName(role) };
};

async function oneLogin(ctx: RequestContext, userId: string, db: Db = ctx.db) {
  const [row] = await db.query<Row>(`${LOGIN_SQL} and u.id = $2`, [ctx.m.organization_id, uuidParam(userId, 'login')]);
  if (!row) throw notFound('This login was not found in your restaurant.');
  return row;
}

async function oneRole(ctx: RequestContext, id: string, db: Db = ctx.db) {
  const [row] = await db.query<Row>(
    `select * from pos_staff_roles where organization_id = $1 and id = $2 and deleted_at is null`,
    [ctx.m.organization_id, uuidParam(id, 'staff role')],
  );
  if (!row) throw unprocessable('This role was not found in your restaurant. It may have been deleted.');
  return row;
}

/// A role's screens as they apply now (see screensFor in access.ts).
const roleScreens = (r: Row) =>
  screensFor(restaurantRole(r.base_role as string), (r.screens as string[] | null) ?? [], (r.updated_at ?? r.created_at) as string | null);

const roleView = (r: Row) => ({
  id: r.id,
  name: r.name,
  base_role: restaurantRole(r.base_role as string),
  base_role_name: roleName(restaurantRole(r.base_role as string)),
  panel: panelFor(restaurantRole(r.base_role as string)),
  screens: roleScreens(r),
  description: r.description,
  is_default: r.is_default,
  staff_count: Number(r.staff_count ?? 0),
  created_at: r.created_at,
});

function checkScreens(base: string, screens: string[] | undefined): string[] {
  if (!screens) return defaultScreens(base);
  const allowed = new Set(grantableScreens(base));
  const bad = screens.filter((s) => !allowed.has(s));
  if (bad.length) throw unprocessable(`A ${roleName(base)} role cannot open: ${bad.map(screenLabel).join(', ')}.`);
  return [...new Set(screens)];
}

async function nextStaffCode(ctx: RequestContext, db: Db): Promise<string> {
  const prefix = (ctx.m.organization_name.replace(/[^A-Za-z]/g, '').slice(0, 3) || 'STF').toUpperCase();
  const [{ n }] = await db.query<{ n: number }>(`select count(*)::int as n from pos_staff where organization_id = $1`, [ctx.m.organization_id]) as [{ n: number }];
  return `${prefix}-${String(n + 1).padStart(3, '0')}`;
}

// ── schemas ──────────────────────────────────────────────────────────────

const money = z.number().finite().min(0).max(100_000_000);
const employeeFields = {
  full_name: z.string().trim().min(1, 'Name is required.').max(150),
  mobile: z.string().trim().max(30).regex(/^[0-9+\s\-()]*$/, 'Mobile may contain digits, spaces, + - ( ) only.'),
  email: z.union([z.literal(''), z.string().trim().toLowerCase().email()]),
  emergency_contact: z.string().trim().max(150),
  designation: z.string().trim().max(100),
  department: z.string().trim().max(100),
  bank_name: z.string().trim().max(100),
  account_number: z.string().trim().max(40),
  ifsc: z.string().trim().max(20),
  upi_id: z.string().trim().max(100),
  photo_url: z.string().trim().max(2000),
  id_proof_url: z.string().trim().max(2000),
  address: z.string().trim().max(1000),
  joining_date: DATE.nullable(),
  salary_type: z.enum(['monthly', 'daily', 'hourly']),
  monthly_salary: money,
  daily_wage: money,
  hourly_rate: money,
  working_hours: z.number().positive().max(24),
  compensation_model: z.enum(['salary_only', 'salary_incentive']),
  incentive_type: z.enum(['sales_target', 'fixed_amount', 'percentage']),
  incentive_value: money,
  status: z.enum(['active', 'inactive']),
  location_id: z.string().uuid().nullable(),
  delivery_enabled: z.boolean(),
};
const employeeUpdate = z.object(employeeFields).partial().strict();
const loginDraft = z.object({
  email: z.string().trim().toLowerCase().email().optional(),
  password: z.string().min(8, 'Use at least 8 characters.').max(128),
  role_id: z.string().uuid(),
  first_name: z.string().trim().max(100).optional(),
  last_name: z.string().trim().max(100).optional(),
  phone_number: z.string().trim().max(30).optional(),
  staff_id: z.string().uuid().optional(),
  location_id: z.string().uuid().nullable().optional(),
  force_password_change: z.boolean().optional(),
});
const employeeCreate = employeeUpdate.extend({ full_name: employeeFields.full_name, login: loginDraft.optional() });

// ── logins ───────────────────────────────────────────────────────────────

async function createLogin(ctx: RequestContext, db: Db, body: z.infer<typeof loginDraft>, employee?: Row) {
  const role = await oneRole(ctx, body.role_id, db);
  const base = restaurantRole(role.base_role as string);
  assertCanGrant(ctx, base, (role.screens as string[]) ?? []);
  const email = body.email ?? (employee?.email as string | undefined);
  if (!email) throw unprocessable('An email is required for an app login.');
  const [clash] = await db.query(`select 1 from users where lower(email) = lower($1)`, [email]);
  if (clash) throw conflict('An account with this email already exists.');
  if (body.location_id && !ctx.m.locations.some((l) => l.id === body.location_id)) throw forbidden('That branch does not belong to your organization.');
  const [first, ...rest] = String(employee?.full_name ?? '').trim().split(/\s+/);
  const [user] = await db.insert<Row>('users', [
    {
      first_name: body.first_name || first || email.split('@')[0],
      last_name: body.last_name ?? rest.join(' '),
      email,
      phone_number: body.phone_number || (employee?.mobile as string) || '',
      password: await hashPassword(body.password),
      status: 'Active',
      organization_id: ctx.m.organization_id,
      location_id: body.location_id ?? (employee?.location_id as string | null) ?? null,
      pos_role: base,
    },
  ]);
  const userId = user!.id as string;
  await db.query(
    `insert into pos_login_security (user_id, organization_id, staff_role_id, force_password_change)
     values ($1, $2, $3, $4)
     on conflict (user_id) do update set staff_role_id = excluded.staff_role_id, force_password_change = excluded.force_password_change, updated_at = now()`,
    [userId, ctx.m.organization_id, role.id, body.force_password_change ?? false],
  );
  return { userId, role };
}

// ── salaries ─────────────────────────────────────────────────────────────

interface PayInputs {
  staff: Row;
  absent: number;
  half: number;
  present: number;
  otHours: number;
  advances: number;
  existing?: Row;
}

function computeSalary(year: number, month: number, p: PayInputs) {
  const days = daysInMonth(year, month);
  const s = p.staff;
  const hours = Number(s.working_hours) || 8;
  const type = s.salary_type as string;
  const monthly = Number(s.monthly_salary);
  const daily = Number(s.daily_wage);
  const hourly = Number(s.hourly_rate);
  let basic = 0;
  let hourlyForOt = hourly;
  if (type === 'daily') {
    basic = daily * p.present;
    hourlyForOt = daily / hours;
  } else if (type === 'hourly') {
    basic = hourly * hours * p.present;
  } else {
    basic = monthly - (p.absent * monthly) / days - (p.half * 0.5 * monthly) / days;
    hourlyForOt = monthly / (days * hours);
  }
  basic = Math.max(0, round2(basic));
  const ot = round2(p.otHours * hourlyForOt);
  let bonus = 0;
  if (s.compensation_model === 'salary_incentive') {
    if (s.incentive_type === 'fixed_amount') bonus = Number(s.incentive_value);
    else if (s.incentive_type === 'percentage') bonus = (basic * Number(s.incentive_value)) / 100;
  }
  bonus = round2(bonus);
  const penalty = round2(Number(p.existing?.penalty ?? 0));
  const advance = round2(p.advances);
  const net = Math.max(0, round2(basic + ot + bonus - advance - penalty));
  return { basic, ot_amount: ot, bonus, advance, penalty, net };
}

const salaryStatus = (net: number, paid: number) => (paid <= 0 ? 'pending' : paid + 0.005 >= net ? 'paid' : 'partial');

async function salaryRows(ctx: RequestContext, year: number, month: number) {
  const rows = await ctx.db.query<Row>(
    `select sa.*, st.full_name as staff_name from pos_staff_salaries sa join pos_staff st on st.id = sa.staff_id
      where sa.organization_id = $1 and sa.year = $2 and sa.month = $3 order by st.full_name`,
    [ctx.m.organization_id, year, month],
  );
  return rows.map((r): Row => ({ ...r, pending: round2(Math.max(0, Number(r.net) - Number(r.paid))) }));
}

// ── roster ───────────────────────────────────────────────────────────────

function rosterRow(tz: string, date: string, r: Row, nowMs: number) {
  const flags: string[] = [];
  let worked = 0;
  let overtime = 0;
  if (!r.roster_id) {
    flags.push('Not scheduled');
  } else {
    const start = localToEpoch(tz, date, r.start_time as string);
    let end = localToEpoch(tz, date, r.end_time as string);
    if (end <= start) end += 24 * 3_600_000;
    const grace = Number(r.grace_minutes ?? 0) * 60_000;
    const breakMin = Number(r.break_minutes_shift ?? 0);
    const shiftLen = Math.max(0, (end - start) / 60_000 - breakMin);
    const clockIn = r.clock_in ? Date.parse(r.clock_in as string) : null;
    const clockOut = r.clock_out ? Date.parse(r.clock_out as string) : null;
    if (clockIn === null) {
      if (nowMs > start + grace) flags.push('Absent');
    } else {
      if (clockIn > start + grace) flags.push('Late');
      if (clockOut === null) flags.push('On shift');
      const until = clockOut ?? nowMs;
      const brk = clockOut ? Number(r.break_minutes ?? breakMin) : 0;
      worked = Math.max(0, Math.round((until - clockIn) / 60_000 - brk));
      if (worked > shiftLen) {
        overtime = Math.round(worked - shiftLen);
        flags.push('Overtime');
      }
    }
  }
  return {
    staff_id: r.staff_id,
    staff_name: r.staff_name,
    staff_code: r.staff_code,
    roster_id: r.roster_id ?? null,
    shift_id: r.shift_id ?? null,
    shift_name: r.shift_name ?? null,
    start_time: r.start_time ?? null,
    end_time: r.end_time ?? null,
    clock_in: r.clock_in ?? null,
    clock_out: r.clock_out ?? null,
    break_minutes: Number(r.break_minutes ?? 0),
    worked_minutes: worked,
    overtime_minutes: overtime,
    flags,
  };
}

// ── training ─────────────────────────────────────────────────────────────

const trainingBody = z.object({
  title: z.string().trim().min(1, 'Module name is required.').max(200),
  description: z.string().trim().max(5000).default(''),
  category: z.string().trim().max(100).default(''),
  roles: z.array(z.string().trim().min(1).max(100)).max(40).default(['All Staff']),
  pass_score: z.number().int().min(0).max(100).default(80),
  time_limit_minutes: z.number().int().min(1).max(600).default(30),
  videos: z
    .array(z.object({ title: z.string().trim().min(1).max(200), url: z.string().trim().max(2000).default(''), duration: z.string().trim().max(20).default('') }))
    .max(100)
    .default([]),
  questions: z
    .array(
      z
        .object({
          question: z.string().trim().min(1).max(1000),
          options: z.array(z.string().trim().min(1).max(500)).min(2).max(6),
          answer_index: z.number().int().min(0),
        })
        .refine((q) => q.answer_index < q.options.length, 'answer_index must point at one of the options'),
    )
    .max(200)
    .default([]),
  status: z.enum(['draft', 'published']).default('draft'),
});

export function staffRoutes(): Hono<Env> {
  const app = new Hono<Env>();

  // ── dashboard ──────────────────────────────────────────────────────────
  app.get('/dashboard', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.dashboard);
    const org = ctx.m.organization_id;
    // A branch manager's figures are their branch's; an owner's the whole
    // restaurant's.
    const branch = ctx.m.branch_scope;
    const tz = tzOf(ctx);
    const today = localDate(tz);
    const [y, mo] = today.split('-').map(Number) as [number, number];
    const [counts] = await ctx.db.query<Row>(
      `select count(*)::int as total,
              count(*) filter (where status = 'active')::int as active,
              count(*) filter (where status <> 'active')::int as inactive
         from pos_staff where organization_id = $1 and deleted_at is null
          and ($2::uuid is null or location_id = $2::uuid)`,
      [org, branch],
    );
    const [online] = await ctx.db.query<Row>(
      `select count(*)::int as n from pos_login_security s join users u on u.id = s.user_id
        where u.organization_id = $1 and s.last_seen_at > now() - interval '5 minutes'
          and ($2::uuid is null or u.location_id = $2::uuid)`,
      [org, branch],
    );
    const [shift] = await ctx.db.query<Row>(
      `select count(*)::int as n from pos_staff_roster ro join pos_staff st on st.id = ro.staff_id and st.deleted_at is null
        where ro.organization_id = $1 and ro.date = $2 and ro.clock_in is not null and ro.clock_out is null
          and ($3::uuid is null or st.location_id = $3::uuid)`,
      [org, today, branch],
    );
    const [att] = await ctx.db.query<Row>(
      `select count(*) filter (where a.status in ('present', 'half_day'))::int as present,
              count(*) filter (where a.status = 'absent')::int as absent
         from pos_staff_attendance a join pos_staff st on st.id = a.staff_id and st.deleted_at is null
        where a.organization_id = $1 and a.date = $2 and ($3::uuid is null or st.location_id = $3::uuid)`,
      [org, today, branch],
    );
    const [pending] = await ctx.db.query<Row>(
      `select count(*)::int as n from pos_staff_approvals ap join pos_staff st on st.id = ap.staff_id
        where ap.organization_id = $1 and ap.status = 'pending' and ($2::uuid is null or st.location_id = $2::uuid)`,
      [org, branch],
    );
    const [pay] = await ctx.db.query<Row>(
      `select coalesce(sum(sa.net), 0) as payable, coalesce(sum(sa.paid), 0) as paid,
              coalesce(sum(greatest(sa.net - sa.paid, 0)), 0) as pending
         from pos_staff_salaries sa join pos_staff st on st.id = sa.staff_id
        where sa.organization_id = $1 and sa.year = $2 and sa.month = $3 and ($4::uuid is null or st.location_id = $4::uuid)`,
      [org, y, mo, branch],
    );
    const active = Number(counts?.active ?? 0);
    const onShift = Number(shift?.n ?? 0);
    return c.json({
      data: {
        total: Number(counts?.total ?? 0),
        active,
        inactive: Number(counts?.inactive ?? 0),
        online_now: Number(online?.n ?? 0),
        on_shift: onShift,
        off_shift: Math.max(0, active - onShift),
        pending_approvals: Number(pending?.n ?? 0),
        present_today: Number(att?.present ?? 0),
        absent_today: Number(att?.absent ?? 0),
        payable_month: round2(Number(pay?.payable ?? 0)),
        paid_month: round2(Number(pay?.paid ?? 0)),
        pending_month: round2(Number(pay?.pending ?? 0)),
        month: today.slice(0, 7),
      },
    });
  });

  // ── employees ──────────────────────────────────────────────────────────
  app.get('/employees', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, ...ANY_STAFF);
    const full = ctx.m.screens.includes(S.directory);
    return c.json({ data: (await loadEmployees(ctx)).map((r) => employeeView(r, full)) });
  });

  app.post('/employees', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.directory);
    requireCan(ctx, 'staff', 'write');
    const { login, ...fields } = await readJson(c, employeeCreate);
    if (fields.location_id && !ctx.m.locations.some((l) => l.id === fields.location_id)) throw forbidden('That branch does not belong to your organization.');
    const id = await ctx.db.transaction(async (tx) => {
      let created: Row | undefined;
      for (let attempt = 0; attempt < 5 && !created; attempt++) {
        const code = await nextStaffCode(ctx, tx);
        const [exists] = await tx.query(`select 1 from pos_staff where organization_id = $1 and staff_code = $2`, [ctx.m.organization_id, code]);
        if (exists) continue;
        [created] = await tx.insert<Row>('pos_staff', [
          { ...fields, organization_id: ctx.m.organization_id, staff_code: code, created_by: ctx.identity.user_id },
        ]);
      }
      if (!created) throw conflict('Could not allocate a staff code; try again.');
      if (login) {
        const { userId } = await createLogin(ctx, tx, { ...login, email: login.email ?? (fields.email || undefined) }, created);
        await tx.query(`update pos_staff set user_id = $2, updated_at = now() where id = $1`, [created.id, userId]);
      }
      return created.id as string;
    });
    forgetMembership();
    const row = await oneEmployee(ctx, id);
    await audit(ctx, login ? 'Created staff member with app login' : 'Created staff member', 'Staff', id, { name: row.full_name, login: row.login_email ?? null });
    return c.json({ data: employeeView(row, true) }, 201);
  });

  app.patch('/employees/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.directory);
    requireCan(ctx, 'staff', 'write');
    const existing = await oneEmployee(ctx, c.req.param('id'));
    const patch = await readJson(c, employeeUpdate);
    if (patch.location_id && !ctx.m.locations.some((l) => l.id === patch.location_id)) throw forbidden('That branch does not belong to your organization.');
    if (Object.keys(patch).length) {
      await ctx.db.update('pos_staff', { ...patch, updated_at: new Date().toISOString() }, [
        { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
        { col: 'id', op: 'eq', value: existing.id },
      ]);
    }
    const row = await oneEmployee(ctx, existing.id as string);
    await audit(ctx, 'Updated staff member', 'Staff', existing.id as string, { name: row.full_name, fields: Object.keys(patch) });
    return c.json({ data: employeeView(row, true) });
  });

  app.delete('/employees/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.directory);
    requireCan(ctx, 'staff', 'delete');
    const existing = await oneEmployee(ctx, c.req.param('id'));
    if (existing.user_id && existing.user_id !== ctx.identity.user_id) {
      const [u] = await ctx.db.query<Row>(`select pos_role from users where id = $1`, [existing.user_id]);
      if (u?.pos_role) assertCanManage(ctx, u.pos_role as string);
    }
    await ctx.db.transaction(async (tx) => {
      await tx.query(`update pos_staff set deleted_at = now(), status = 'inactive', user_id = null where id = $1 and organization_id = $2`, [
        existing.id,
        ctx.m.organization_id,
      ]);
      if (existing.user_id && existing.user_id !== ctx.identity.user_id) {
        const [u] = await tx.query<Row>(`select pos_role from users where id = $1`, [existing.user_id]);
        if (u?.pos_role !== 'org_owner') {
          await tx.query(`update users set status = 'Inactive', updated_at = now() where id = $1 and organization_id = $2`, [existing.user_id, ctx.m.organization_id]);
        }
      }
    });
    forgetMembership();
    await audit(ctx, 'Removed staff member', 'Staff', existing.id as string, { name: existing.full_name });
    return c.body(null, 204);
  });

  // ── logins ─────────────────────────────────────────────────────────────
  app.get('/logins', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles, S.loginSecurity, S.directory);
    const rows = await ctx.db.query<Row>(`${LOGIN_SQL} order by u.first_name, u.last_name`, [ctx.m.organization_id]);
    return c.json({ data: rows.map(loginView) });
  });

  app.post('/logins', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles, S.directory);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(c, loginDraft);
    const userId = await ctx.db.transaction(async (tx) => {
      let employee: Row | undefined;
      if (body.staff_id) {
        employee = await oneEmployee(ctx, body.staff_id, tx);
        if (employee.user_id) throw conflict(`${employee.full_name} already has a login.`);
      }
      const { userId } = await createLogin(ctx, tx, body, employee);
      if (employee) await tx.query(`update pos_staff set user_id = $2, updated_at = now() where id = $1`, [employee.id, userId]);
      return userId;
    });
    forgetMembership();
    const row = await oneLogin(ctx, userId);
    await audit(ctx, 'Created app login', 'Login', userId, { email: row.email, role: row.role_name });
    return c.json({ data: loginView(row) }, 201);
  });

  app.patch('/logins/:userId', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'staff', 'write');
    const target = await oneLogin(ctx, c.req.param('userId'));
    const body = await readJson(
      c,
      z
        .object({
          role_id: z.string().uuid().optional(),
          status: z.enum(['Active', 'Inactive', 'Suspended']).optional(),
          staff_id: z.string().uuid().nullable().optional(),
          delivery_enabled: z.boolean().optional(),
          location_id: z.string().uuid().nullable().optional(),
          force_password_change: z.boolean().optional(),
          two_factor_enabled: z.boolean().optional(),
        })
        .strict(),
    );
    const accessChange = body.role_id !== undefined || body.status !== undefined || body.staff_id !== undefined || body.delivery_enabled !== undefined || body.location_id !== undefined;
    const securityChange = body.force_password_change !== undefined || body.two_factor_enabled !== undefined;
    if (accessChange) requireScreen(ctx, S.roles);
    if (securityChange) requireScreen(ctx, S.loginSecurity);
    const self = target.user_id === ctx.identity.user_id;
    if (self && (body.role_id || body.status)) throw forbidden('You cannot change your own role or status.');
    if (!self) assertCanManage(ctx, target.pos_role as string);
    if (body.location_id && !ctx.m.locations.some((l) => l.id === body.location_id)) throw forbidden('That branch does not belong to your organization.');
    await ctx.db.transaction(async (tx) => {
      if (body.role_id) {
        const role = await oneRole(ctx, body.role_id, tx);
        const base = restaurantRole(role.base_role as string);
        assertCanGrant(ctx, base, (role.screens as string[]) ?? []);
        await tx.query(`update users set pos_role = $2, updated_at = now() where id = $1`, [target.user_id, base]);
        await tx.query(
          `insert into pos_login_security (user_id, organization_id, staff_role_id) values ($1, $2, $3)
           on conflict (user_id) do update set staff_role_id = excluded.staff_role_id, updated_at = now()`,
          [target.user_id, ctx.m.organization_id, role.id],
        );
      }
      if (body.status) await tx.query(`update users set status = $2, updated_at = now() where id = $1`, [target.user_id, body.status]);
      if (body.location_id !== undefined) await tx.query(`update users set location_id = $2, updated_at = now() where id = $1`, [target.user_id, body.location_id]);
      if (body.staff_id !== undefined) {
        await tx.query(`update pos_staff set user_id = null, updated_at = now() where user_id = $1 and organization_id = $2`, [target.user_id, ctx.m.organization_id]);
        if (body.staff_id) {
          const employee = await oneEmployee(ctx, body.staff_id, tx);
          if (employee.user_id && employee.user_id !== target.user_id) throw conflict(`${employee.full_name} is already linked to another login.`);
          await tx.query(`update pos_staff set user_id = $2, updated_at = now() where id = $1`, [employee.id, target.user_id]);
        }
      }
      if (body.delivery_enabled !== undefined) {
        const [linked] = await tx.query(`select id from pos_staff where user_id = $1 and organization_id = $2 and deleted_at is null`, [target.user_id, ctx.m.organization_id]);
        if (!linked) throw unprocessable('Link this login to a staff member before enabling deliveries.');
        await tx.query(`update pos_staff set delivery_enabled = $2, updated_at = now() where id = $1`, [linked.id, body.delivery_enabled]);
      }
      if (securityChange) {
        const sets = [
          ...(body.force_password_change !== undefined ? [['force_password_change', body.force_password_change] as const] : []),
          ...(body.two_factor_enabled !== undefined ? [['two_factor_enabled', body.two_factor_enabled] as const] : []),
        ];
        await tx.query(
          `insert into pos_login_security (user_id, organization_id, ${sets.map(([k]) => k).join(', ')})
           values ($1, $2, ${sets.map((_, i) => `$${i + 3}`).join(', ')})
           on conflict (user_id) do update set ${sets.map(([k]) => `${k} = excluded.${k}`).join(', ')}, updated_at = now()`,
          [target.user_id, ctx.m.organization_id, ...sets.map(([, v]) => v)],
        );
      }
    });
    forgetMembership();
    const row = await oneLogin(ctx, target.user_id as string);
    await audit(ctx, 'Updated app login', 'Login', target.user_id as string, { email: row.email, changes: Object.keys(body) });
    return c.json({ data: loginView(row) });
  });

  app.post('/logins/:userId/reset-password', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.loginSecurity);
    requireCan(ctx, 'staff', 'write');
    const target = await oneLogin(ctx, c.req.param('userId'));
    assertCanManage(ctx, target.pos_role as string);
    const body = await readJson(c, z.object({ password: z.string().min(8, 'Use at least 8 characters.').max(128), force_change: z.boolean().default(true) }));
    await ctx.db.query(`update users set password = $2, updated_at = now() where id = $1`, [target.user_id, await hashPassword(body.password)]);
    await ctx.db.query(
      `insert into pos_login_security (user_id, organization_id, failed_attempts, locked_until, force_password_change)
       values ($1, $2, 0, null, $3)
       on conflict (user_id) do update set failed_attempts = 0, locked_until = null, force_password_change = excluded.force_password_change, updated_at = now()`,
      [target.user_id, ctx.m.organization_id, body.force_change],
    );
    // Anyone signed in with the old password is signed out.
    await endSessions(ctx.db, target.user_id as string, ctx.m.organization_id);
    await audit(ctx, 'Reset password', 'Login', target.user_id as string, { email: target.email });
    return c.body(null, 204);
  });

  app.get('/login-history', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.loginSecurity);
    const limit = intParam(c.req.query('limit'), 200, 1000);
    const rows = await ctx.db.query<Row>(
      `select e.id, e.user_id, e.email, e.success, e.reason, e.ip, e.user_agent, e.created_at,
              btrim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) as full_name
         from pos_login_events e left join users u on u.id = e.user_id
        where e.organization_id = $1 order by e.created_at desc limit ${limit}`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows });
  });

  // ── roles ──────────────────────────────────────────────────────────────
  const listRoles = async (ctx: RequestContext) =>
    (
      await ctx.db.query<Row>(
        `select r.*, (select count(*) from pos_login_security s join users u on u.id = s.user_id
                       where s.staff_role_id = r.id and u.organization_id = r.organization_id)::int as staff_count
           from pos_staff_roles r where r.organization_id = $1 and r.deleted_at is null order by r.created_at, r.name`,
        [ctx.m.organization_id],
      )
    ).filter((r) => restaurantRole(r.base_role as string) !== 'none');

  app.get('/roles', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles, S.directory);
    const cat = roleCatalogue();
    return c.json({
      data: {
        roles: (await listRoles(ctx)).map(roleView),
        catalogue: { ...cat, base_roles: cat.base_roles.map((b) => ({ ...b, name: roleName(b.key) })) },
      },
    });
  });

  const roleBody = z.object({
    name: z.string().trim().min(1, 'Role name is required.').max(80),
    base_role: z.enum(POS_ROLES),
    screens: z.array(z.string()).max(100).optional(),
    description: z.string().trim().max(500).default(''),
  });

  app.post('/roles', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(c, roleBody);
    const screens = checkScreens(body.base_role, body.screens);
    assertCanGrant(ctx, body.base_role, screens);
    const [dup] = await ctx.db.query(`select 1 from pos_staff_roles where organization_id = $1 and lower(name) = lower($2) and deleted_at is null`, [
      ctx.m.organization_id,
      body.name,
    ]);
    if (dup) throw conflict(`A role named "${body.name}" already exists.`);
    const [row] = await ctx.db.insert<Row>('pos_staff_roles', [
      { organization_id: ctx.m.organization_id, name: body.name, base_role: body.base_role, screens: new TextArray(screens), description: body.description },
    ]);
    await audit(ctx, 'Created role', 'Role', row!.id as string, { name: body.name, base_role: body.base_role });
    return c.json({ data: roleView(row!) }, 201);
  });

  app.patch('/roles/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles);
    requireCan(ctx, 'staff', 'write');
    const existing = await oneRole(ctx, c.req.param('id'));
    const body = await readJson(c, roleBody.partial().strict());
    const base = body.base_role ?? restaurantRole(existing.base_role as string);
    const screens = checkScreens(base, body.screens ?? (body.base_role ? undefined : roleScreens(existing)));
    assertCanGrant(ctx, base, screens);
    if (body.name && body.name.toLowerCase() !== String(existing.name).toLowerCase()) {
      const [dup] = await ctx.db.query(`select 1 from pos_staff_roles where organization_id = $1 and lower(name) = lower($2) and deleted_at is null`, [
        ctx.m.organization_id,
        body.name,
      ]);
      if (dup) throw conflict(`A role named "${body.name}" already exists.`);
    }
    await ctx.db.transaction(async (tx) => {
      await tx.query(
        `update pos_staff_roles set name = $3, base_role = $4, screens = $5::text[], description = $6, updated_at = now()
          where id = $1 and organization_id = $2`,
        [existing.id, ctx.m.organization_id, body.name ?? existing.name, base, new TextArray(screens), body.description ?? existing.description],
      );
      if (base !== existing.base_role) {
        await tx.query(
          `update users set pos_role = $3, updated_at = now()
            where organization_id = $2 and id in (select user_id from pos_login_security where staff_role_id = $1)
              and pos_role <> 'org_owner'`,
          [existing.id, ctx.m.organization_id, base],
        );
      }
    });
    forgetMembership();
    const [row] = (await listRoles(ctx)).filter((r) => r.id === existing.id);
    await audit(ctx, 'Updated role', 'Role', existing.id as string, { name: row?.name });
    return c.json({ data: roleView(row!) });
  });

  app.delete('/roles/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles);
    requireCan(ctx, 'staff', 'delete');
    const existing = await oneRole(ctx, c.req.param('id'));
    const [used] = await ctx.db.query<Row>(
      `select count(*)::int as n from pos_login_security s join users u on u.id = s.user_id
        where s.staff_role_id = $1 and u.organization_id = $2`,
      [existing.id, ctx.m.organization_id],
    );
    if (Number(used?.n ?? 0) > 0) throw conflict(`${used!.n} login(s) still use "${existing.name}". Give them another role first.`);
    await ctx.db.query(`update pos_staff_roles set deleted_at = now() where id = $1 and organization_id = $2`, [existing.id, ctx.m.organization_id]);
    await audit(ctx, 'Deleted role', 'Role', existing.id as string, { name: existing.name });
    return c.body(null, 204);
  });

  app.post('/roles/seed', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.roles, S.directory);
    requireCan(ctx, 'staff', 'write');
    const roles = await listRoles(ctx);
    const existing = new Set(roles.map((r) => String(r.name).toLowerCase()));
    const added: string[] = [];
    for (const d of DEFAULT_STAFF_ROLES) {
      if (existing.has(d.name.toLowerCase())) continue;
      const old = roles.find(
        (r) => r.is_default && OLD_DEFAULT_NAMES[String(r.name).toLowerCase()] === d.base_role,
      );
      if (old) {
        await ctx.db.query(
          `update pos_staff_roles set name = $3, base_role = $4, screens = $5::text[], description = $6, updated_at = now()
            where id = $1 and organization_id = $2`,
          [old.id, ctx.m.organization_id, d.name, d.base_role, new TextArray(d.screens ?? defaultScreens(d.base_role)), d.description],
        );
        added.push(`${old.name} → ${d.name}`);
        continue;
      }
      const screens = d.screens ?? defaultScreens(d.base_role);
      try {
        assertCanGrant(ctx, d.base_role, screens);
      } catch {
        continue; // the caller could not grant it anyway
      }
      await ctx.db.insert('pos_staff_roles', [
        { organization_id: ctx.m.organization_id, name: d.name, base_role: d.base_role, screens: new TextArray(screens), description: d.description, is_default: true },
      ]);
      added.push(d.name);
    }
    if (added.length) await audit(ctx, 'Seeded default roles', 'Role', null, { roles: added });
    return c.json({ data: (await listRoles(ctx)).map(roleView) });
  });

  // ── attendance ─────────────────────────────────────────────────────────
  const attendanceFor = (ctx: RequestContext, date: string) =>
    ctx.db.query<Row>(
      `select st.id as staff_id, st.full_name as staff_name, st.staff_code, $2::date::text as date,
              a.status, a.check_in, a.check_out, coalesce(a.ot_hours, 0) as ot_hours, coalesce(a.notes, '') as notes
         from pos_staff st
         left join pos_staff_attendance a on a.staff_id = st.id and a.date = $2::date
        where st.organization_id = $1 and st.deleted_at is null and st.status = 'active'
          and ($3::uuid is null or st.location_id = $3::uuid)
        order by st.full_name`,
      [ctx.m.organization_id, date, ctx.m.branch_scope],
    );

  app.get('/attendance', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.attendance);
    const date = DATE.parse(c.req.query('date') ?? localDate(tzOf(ctx)));
    return c.json({ data: await attendanceFor(ctx, date) });
  });

  app.put('/attendance', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.attendance);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(
      c,
      z.object({
        date: DATE,
        entries: z
          .array(
            z.object({
              staff_id: z.string().uuid(),
              status: z.enum(['present', 'absent', 'half_day', 'leave', 'week_off']),
              check_in: HHMM.nullable().optional(),
              check_out: HHMM.nullable().optional(),
              ot_hours: z.number().min(0).max(24).default(0),
              notes: z.string().trim().max(500).default(''),
            }),
          )
          .max(2000),
      }),
    );
    const ids = new Set(
      (
        await ctx.db.query<Row>(
          `select id from pos_staff where organization_id = $1 and deleted_at is null and ($2::uuid is null or location_id = $2::uuid)`,
          [ctx.m.organization_id, ctx.m.branch_scope],
        )
      ).map((r) => r.id),
    );
    const bad = body.entries.filter((e) => !ids.has(e.staff_id));
    if (bad.length) throw unprocessable('Some staff members are not in your organization.');
    if (body.entries.length) {
      await ctx.db.upsert(
        'pos_staff_attendance',
        body.entries.map((e) => ({
          organization_id: ctx.m.organization_id,
          staff_id: e.staff_id,
          date: body.date,
          status: e.status,
          check_in: e.check_in ?? null,
          check_out: e.check_out ?? null,
          ot_hours: e.ot_hours,
          notes: e.notes,
          marked_by: ctx.identity.user_id,
          updated_at: new Date().toISOString(),
        })),
        ['staff_id', 'date'],
        'organization_id',
      );
      await audit(ctx, 'Saved attendance', 'Attendance', null, { date: body.date, entries: body.entries.length });
    }
    return c.json({ data: await attendanceFor(ctx, body.date) });
  });

  app.post('/attendance/mark-all-present', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.attendance);
    requireCan(ctx, 'staff', 'write');
    const { date } = await readJson(c, z.object({ date: DATE }));
    await ctx.db.query(
      `insert into pos_staff_attendance (organization_id, staff_id, date, status, check_in, marked_by)
       select st.organization_id, st.id, $2::date, 'present', sh.start_time, $3
         from pos_staff st
         left join pos_staff_roster ro on ro.staff_id = st.id and ro.date = $2::date
         left join pos_staff_shifts sh on sh.id = ro.shift_id
        where st.organization_id = $1 and st.deleted_at is null and st.status = 'active'
          and ($4::uuid is null or st.location_id = $4::uuid)
       on conflict (staff_id, date) do update set status = 'present', check_in = coalesce(pos_staff_attendance.check_in, excluded.check_in),
          marked_by = excluded.marked_by, updated_at = now()
        where pos_staff_attendance.organization_id = excluded.organization_id`,
      [ctx.m.organization_id, date, ctx.identity.user_id, ctx.m.branch_scope],
    );
    await audit(ctx, 'Marked everyone present', 'Attendance', null, { date });
    return c.json({ data: await attendanceFor(ctx, date) });
  });

  // ── shifts & roster ────────────────────────────────────────────────────
  const shiftBody = z.object({
    name: z.string().trim().min(1).max(80),
    start_time: HHMM,
    end_time: HHMM,
    break_minutes: z.number().int().min(0).max(600).default(30),
    grace_minutes: z.number().int().min(0).max(240).default(10),
    active: z.boolean().default(true),
  });

  app.get('/shifts', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    const rows = await ctx.db.query<Row>(`select * from pos_staff_shifts where organization_id = $1 and deleted_at is null order by start_time, name`, [
      ctx.m.organization_id,
    ]);
    return c.json({ data: rows });
  });

  app.post('/shifts', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(c, shiftBody);
    const [row] = await ctx.db.insert<Row>('pos_staff_shifts', [{ ...body, organization_id: ctx.m.organization_id }]);
    await audit(ctx, 'Created shift', 'Shift', row!.id as string, { name: body.name });
    return c.json({ data: row }, 201);
  });

  app.patch('/shifts/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'write');
    const id = uuidParam(c.req.param('id'), 'shift');
    const body = await readJson(c, shiftBody.partial().strict());
    const [row] = await ctx.db.update<Row>('pos_staff_shifts', { ...body, updated_at: new Date().toISOString() }, [
      { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
      { col: 'id', op: 'eq', value: id },
      { col: 'deleted_at', op: 'is', value: null },
    ]);
    if (!row) throw notFound('This shift was not found.');
    await audit(ctx, 'Updated shift', 'Shift', id, { name: row.name });
    return c.json({ data: row });
  });

  app.delete('/shifts/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'delete');
    const id = uuidParam(c.req.param('id'), 'shift');
    const [row] = await ctx.db.update<Row>('pos_staff_shifts', { deleted_at: new Date().toISOString() }, [
      { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
      { col: 'id', op: 'eq', value: id },
    ]);
    if (!row) throw notFound('This shift was not found.');
    await audit(ctx, 'Deleted shift', 'Shift', id, { name: row.name });
    return c.body(null, 204);
  });

  const rosterFor = async (ctx: RequestContext, date: string) => {
    const rows = await ctx.db.query<Row>(
      `select st.id as staff_id, st.full_name as staff_name, st.staff_code,
              ro.id as roster_id, ro.shift_id, ro.clock_in, ro.clock_out, ro.break_minutes,
              sh.name as shift_name, sh.start_time, sh.end_time, sh.break_minutes as break_minutes_shift, sh.grace_minutes
         from pos_staff st
         left join pos_staff_roster ro on ro.staff_id = st.id and ro.date = $2::date
         left join pos_staff_shifts sh on sh.id = ro.shift_id
        where st.organization_id = $1 and st.deleted_at is null and st.status = 'active'
          and ($3::uuid is null or st.location_id = $3::uuid)
        order by st.full_name`,
      [ctx.m.organization_id, date, ctx.m.branch_scope],
    );
    const tz = tzOf(ctx);
    const now = Date.now();
    const out = rows.map((r) => rosterRow(tz, date, r, now));
    return {
      date,
      stats: {
        scheduled: out.filter((r) => r.roster_id).length,
        on_shift: out.filter((r) => r.flags.includes('On shift')).length,
        late: out.filter((r) => r.flags.includes('Late')).length,
        overtime: out.filter((r) => r.flags.includes('Overtime')).length,
      },
      rows: out,
    };
  };

  app.get('/roster', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    const date = DATE.parse(c.req.query('date') ?? localDate(tzOf(ctx)));
    return c.json({ data: await rosterFor(ctx, date) });
  });

  app.post('/roster', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(c, z.object({ date: DATE, staff_id: z.string().uuid(), shift_id: z.string().uuid() }));
    const employee = await oneEmployee(ctx, body.staff_id);
    const [shift] = await ctx.db.query<Row>(`select id, name from pos_staff_shifts where id = $1 and organization_id = $2 and deleted_at is null`, [
      body.shift_id,
      ctx.m.organization_id,
    ]);
    if (!shift) throw unprocessable('This shift was not found. It may have been deleted.');
    await ctx.db.upsert(
      'pos_staff_roster',
      [{ organization_id: ctx.m.organization_id, staff_id: body.staff_id, shift_id: body.shift_id, date: body.date, updated_at: new Date().toISOString() }],
      ['staff_id', 'date'],
      'organization_id',
    );
    await audit(ctx, 'Assigned shift', 'Roster', body.staff_id, { staff: employee.full_name, shift: shift.name, date: body.date });
    return c.json({ data: await rosterFor(ctx, body.date) }, 201);
  });

  const rosterEntry = async (ctx: RequestContext, id: string) => {
    const [row] = await ctx.db.query<Row>(
      `select ro.*, sh.break_minutes as shift_break, sh.start_time, sh.end_time from pos_staff_roster ro
         join pos_staff_shifts sh on sh.id = ro.shift_id
        where ro.id = $1 and ro.organization_id = $2`,
      [uuidParam(id, 'roster entry'), ctx.m.organization_id],
    );
    if (!row) throw notFound('This shift assignment was not found.');
    return row;
  };

  app.post('/roster/:id/clock-in', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'write');
    const ro = await rosterEntry(ctx, c.req.param('id'));
    if (ro.clock_in) throw conflict('Already clocked in.');
    const now = new Date();
    const tz = tzOf(ctx);
    await ctx.db.query(`update pos_staff_roster set clock_in = $3, updated_at = now() where id = $1 and organization_id = $2`, [ro.id, ctx.m.organization_id, now.toISOString()]);
    await ctx.db.query(
      `insert into pos_staff_attendance (organization_id, staff_id, date, status, check_in, marked_by) values ($1, $2, $3, 'present', $4, $5)
       on conflict (staff_id, date) do update set status = 'present', check_in = coalesce(pos_staff_attendance.check_in, excluded.check_in), updated_at = now()
        where pos_staff_attendance.organization_id = excluded.organization_id`,
      [ctx.m.organization_id, ro.staff_id, ro.date, localTime(tz, now), ctx.identity.user_id],
    );
    await audit(ctx, 'Clocked in', 'Roster', ro.staff_id as string, { staff: await staffName(ctx, ro.staff_id), date: ro.date });
    return c.json({ data: await rosterFor(ctx, ro.date as string) });
  });

  app.post('/roster/:id/clock-out', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'write');
    const ro = await rosterEntry(ctx, c.req.param('id'));
    if (!ro.clock_in) throw conflict('Clock in first.');
    if (ro.clock_out) throw conflict('Already clocked out.');
    const now = new Date();
    const tz = tzOf(ctx);
    await ctx.db.query(`update pos_staff_roster set clock_out = $3, break_minutes = $4, updated_at = now() where id = $1 and organization_id = $2`, [
      ro.id,
      ctx.m.organization_id,
      now.toISOString(),
      ro.shift_break ?? 0,
    ]);
    const day = await rosterFor(ctx, ro.date as string);
    const mine = day.rows.find((r) => r.roster_id === ro.id);
    await ctx.db.query(
      `update pos_staff_attendance set check_out = $4, ot_hours = $5, updated_at = now()
        where organization_id = $1 and staff_id = $2 and date = $3`,
      [ctx.m.organization_id, ro.staff_id, ro.date, localTime(tz, now), round2((mine?.overtime_minutes ?? 0) / 60)],
    );
    await audit(ctx, 'Clocked out', 'Roster', ro.staff_id as string, { staff: await staffName(ctx, ro.staff_id), date: ro.date });
    return c.json({ data: day });
  });

  app.delete('/roster/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.shifts);
    requireCan(ctx, 'staff', 'delete');
    const ro = await rosterEntry(ctx, c.req.param('id'));
    await ctx.db.query(`delete from pos_staff_roster where id = $1 and organization_id = $2`, [ro.id, ctx.m.organization_id]);
    await audit(ctx, 'Removed shift assignment', 'Roster', ro.staff_id as string, { staff: await staffName(ctx, ro.staff_id), date: ro.date });
    return c.body(null, 204);
  });

  // ── advances ───────────────────────────────────────────────────────────
  const advancesQuery = (ctx: RequestContext, extra = '', params: unknown[] = []) =>
    ctx.db.query<Row>(
      `select a.*, st.full_name as staff_name from pos_staff_advances a join pos_staff st on st.id = a.staff_id
        where a.organization_id = $1 ${extra} order by a.advance_date desc, a.created_at desc`,
      [ctx.m.organization_id, ...params],
    );

  app.get('/advances', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.advances, S.salary);
    const staff = c.req.query('staff_id');
    return c.json({ data: staff ? await advancesQuery(ctx, 'and a.staff_id = $2', [uuidParam(staff, 'staff member')]) : await advancesQuery(ctx) });
  });

  const advanceBody = z.object({
    staff_id: z.string().uuid(),
    amount: z.number().positive().max(10_000_000),
    advance_date: DATE.optional(),
    deduct_month: z.number().int().min(1).max(12),
    deduct_year: z.number().int().min(2000).max(2100),
    reason: z.string().trim().max(500).default(''),
    mode: z.enum(['cash', 'upi', 'bank']).default('cash'),
  });

  async function insertAdvance(ctx: RequestContext, db: Db, body: z.infer<typeof advanceBody>) {
    const employee = await oneEmployee(ctx, body.staff_id, db);
    const [row] = await db.insert<Row>('pos_staff_advances', [
      { ...body, advance_date: body.advance_date ?? localDate(tzOf(ctx)), organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id },
    ]);
    return { ...row!, staff_name: employee.full_name } as Row;
  }

  app.post('/advances', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.advances);
    requireCan(ctx, 'staff', 'write');
    const row = await insertAdvance(ctx, ctx.db, await readJson(c, advanceBody));
    await audit(ctx, 'Recorded salary advance', 'Advance', row.id as string, { staff: row.staff_name, amount: row.amount });
    return c.json({ data: row }, 201);
  });

  app.patch('/advances/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.advances);
    requireCan(ctx, 'staff', 'write');
    const id = uuidParam(c.req.param('id'), 'advance');
    const body = await readJson(c, z.object({ status: z.enum(['open', 'cancelled']) }).strict());
    const [row] = await ctx.db.update<Row>('pos_staff_advances', { status: body.status, updated_at: new Date().toISOString() }, [
      { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
      { col: 'id', op: 'eq', value: id },
      { col: 'status', op: 'neq', value: 'deducted' },
    ]);
    if (!row) throw conflict('That advance was already deducted from a salary.');
    await audit(ctx, body.status === 'cancelled' ? 'Cancelled advance' : 'Reopened advance', 'Advance', id, { staff: await staffName(ctx, row.staff_id), amount: row.amount });
    return c.json({ data: row });
  });

  // ── salaries ───────────────────────────────────────────────────────────
  const monthQuery = (c: { req: { query: (k: string) => string | undefined } }, ctx: RequestContext) => {
    const [y, m] = localDate(tzOf(ctx)).split('-').map(Number) as [number, number];
    const year = Number(c.req.query('year') ?? y);
    const month = Number(c.req.query('month') ?? m);
    if (!Number.isInteger(year) || year < 2000 || year > 2100 || !Number.isInteger(month) || month < 1 || month > 12) {
      throw unprocessable('year/month are invalid.');
    }
    return { year, month };
  };

  app.get('/salaries', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.salary);
    const { year, month } = monthQuery(c, ctx);
    return c.json({ data: await salaryRows(ctx, year, month) });
  });

  app.post('/salaries/generate', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.salary);
    requireCan(ctx, 'staff', 'write');
    const { year, month } = await readJson(c, z.object({ year: z.number().int().min(2000).max(2100), month: z.number().int().min(1).max(12) }));
    const org = ctx.m.organization_id;
    const from = `${year}-${String(month).padStart(2, '0')}-01`;
    const to = `${year}-${String(month).padStart(2, '0')}-${String(daysInMonth(year, month)).padStart(2, '0')}`;
    const staff = await ctx.db.query<Row>(`select * from pos_staff where organization_id = $1 and deleted_at is null and status = 'active'`, [org]);
    const att = await ctx.db.query<Row>(
      `select staff_id,
              count(*) filter (where status = 'absent')::int as absent,
              count(*) filter (where status = 'half_day')::int as half,
              count(*) filter (where status = 'present')::int as present,
              coalesce(sum(ot_hours), 0) as ot
         from pos_staff_attendance where organization_id = $1 and date between $2::date and $3::date group by staff_id`,
      [org, from, to],
    );
    const adv = await ctx.db.query<Row>(
      `select staff_id, coalesce(sum(amount), 0) as total from pos_staff_advances
        where organization_id = $1 and status = 'open' and deduct_year = $2 and deduct_month = $3 group by staff_id`,
      [org, year, month],
    );
    const existing = await ctx.db.query<Row>(`select * from pos_staff_salaries where organization_id = $1 and year = $2 and month = $3`, [org, year, month]);
    const rows: Row[] = [];
    for (const s of staff) {
      const prev = existing.find((e) => e.staff_id === s.id);
      if (prev && prev.status !== 'pending') continue; // paid rows are final
      const a = att.find((r) => r.staff_id === s.id);
      const pay = computeSalary(year, month, {
        staff: s,
        absent: Number(a?.absent ?? 0),
        half: Number(a?.half ?? 0),
        present: Number(a?.present ?? 0) + Number(a?.half ?? 0) * 0.5,
        otHours: Number(a?.ot ?? 0),
        advances: Number(adv.find((r) => r.staff_id === s.id)?.total ?? 0),
        existing: prev,
      });
      rows.push({ organization_id: org, staff_id: s.id, year, month, ...pay, paid: 0, status: 'pending', generated_at: new Date().toISOString(), updated_at: new Date().toISOString() });
    }
    if (rows.length) await ctx.db.upsert('pos_staff_salaries', rows, ['staff_id', 'year', 'month'], 'organization_id');
    await audit(ctx, 'Generated salaries', 'Salary', null, { year, month, staff: rows.length });
    return c.json({ data: await salaryRows(ctx, year, month) });
  });

  const oneSalary = async (ctx: RequestContext, id: string) => {
    const [row] = await ctx.db.query<Row>(`select * from pos_staff_salaries where id = $1 and organization_id = $2`, [uuidParam(id, 'salary'), ctx.m.organization_id]);
    if (!row) throw notFound('This salary record was not found.');
    return row;
  };

  app.patch('/salaries/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.salary);
    requireCan(ctx, 'staff', 'write');
    const row = await oneSalary(ctx, c.req.param('id'));
    if (row.status === 'paid') throw conflict('This salary is already paid.');
    const body = await readJson(c, z.object({ bonus: money.optional(), penalty: money.optional() }).strict());
    const bonus = round2(body.bonus ?? Number(row.bonus));
    const penalty = round2(body.penalty ?? Number(row.penalty));
    const net = Math.max(0, round2(Number(row.basic) + Number(row.ot_amount) + bonus - Number(row.advance) - penalty));
    await ctx.db.query(`update pos_staff_salaries set bonus = $3, penalty = $4, net = $5, status = $6, updated_at = now() where id = $1 and organization_id = $2`, [
      row.id,
      ctx.m.organization_id,
      bonus,
      penalty,
      net,
      salaryStatus(net, Number(row.paid)),
    ]);
    await audit(ctx, 'Adjusted salary', 'Salary', row.id as string, { staff: await staffName(ctx, row.staff_id), bonus, penalty });
    const [out] = (await salaryRows(ctx, Number(row.year), Number(row.month))).filter((r) => r.id === row.id);
    return c.json({ data: out });
  });

  app.post('/salaries/:id/pay', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.salary);
    requireCan(ctx, 'staff', 'write');
    const found = await oneSalary(ctx, c.req.param('id'));
    const body = await readJson(c, z.object({ amount: z.number().positive().max(100_000_000).optional() }).strict());
    const { row, amount, status } = await ctx.db.transaction(async (tx) => {
      // Lock the row: two clicks cannot both pay the same salary.
      const [row] = await tx.query<Row>(`select * from pos_staff_salaries where id = $1 and organization_id = $2 for update`, [found.id, ctx.m.organization_id]);
      const pending = round2(Math.max(0, Number(row!.net) - Number(row!.paid)));
      if (pending <= 0) throw conflict('Nothing left to pay.');
      const amount = round2(Math.min(body.amount ?? pending, pending));
      const paid = round2(Number(row!.paid) + amount);
      const status = salaryStatus(Number(row!.net), paid);
      await tx.query(
        `update pos_staff_salaries set paid = $3, status = $4, paid_at = case when $4 = 'paid' then now() else paid_at end, updated_at = now()
          where id = $1 and organization_id = $2`,
        [row!.id, ctx.m.organization_id, paid, status],
      );
      if (status === 'paid') {
        await tx.query(
          `update pos_staff_advances set status = 'deducted', updated_at = now()
            where organization_id = $1 and staff_id = $2 and status = 'open' and deduct_year = $3 and deduct_month = $4`,
          [ctx.m.organization_id, row!.staff_id, row!.year, row!.month],
        );
      }
      return { row: row!, amount, status };
    });
    await audit(ctx, 'Paid salary', 'Salary', row.id as string, { staff: await staffName(ctx, row.staff_id), amount, status });
    const [out] = (await salaryRows(ctx, Number(row.year), Number(row.month))).filter((r) => r.id === row.id);
    return c.json({ data: out });
  });

  // ── approvals ──────────────────────────────────────────────────────────
  const approvalBody = z.object({
    staff_id: z.string().uuid(),
    type: z.enum(['leave', 'salary_advance', 'shift_change', 'attendance_correction', 'other']),
    details: z.record(z.string(), z.unknown()).default({}),
  });

  function checkApprovalDetails(type: string, details: Record<string, unknown>) {
    if (type === 'leave') {
      const from = DATE.parse(details.from);
      const to = DATE.parse(details.to ?? details.from);
      if (to < from) throw unprocessable('Leave must end on or after its start.');
      if ((Date.parse(to) - Date.parse(from)) / 86_400_000 > 62) throw unprocessable('Leave requests are limited to 62 days.');
    }
    if (type === 'salary_advance') z.number().positive().max(10_000_000).parse(details.amount);
  }

  async function insertApproval(ctx: RequestContext, body: z.infer<typeof approvalBody>) {
    const employee = await oneEmployee(ctx, body.staff_id);
    checkApprovalDetails(body.type, body.details);
    const [row] = await ctx.db.insert<Row>('pos_staff_approvals', [
      { organization_id: ctx.m.organization_id, staff_id: body.staff_id, type: body.type, details: body.details, requested_by: ctx.identity.user_id },
    ]);
    await audit(ctx, 'Raised approval request', 'Approval', row!.id as string, { staff: employee.full_name, type: body.type });
    return { ...row!, staff_name: employee.full_name };
  }

  app.get('/approvals', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.approvals);
    const history = c.req.query('view') === 'history';
    const rows = await ctx.db.query<Row>(
      `select a.*, st.full_name as staff_name from pos_staff_approvals a join pos_staff st on st.id = a.staff_id
        where a.organization_id = $1 and ${history ? "a.status <> 'pending'" : "a.status = 'pending'"}
          and ($2::uuid is null or st.location_id = $2::uuid)
        order by ${history ? 'a.decided_at' : 'a.requested_at'} desc limit 500`,
      [ctx.m.organization_id, ctx.m.branch_scope],
    );
    const [stats] = await ctx.db.query<Row>(
      `select count(*)::int as total,
              count(*) filter (where status = 'pending')::int as pending,
              count(*) filter (where status = 'approved')::int as approved,
              count(*) filter (where status = 'declined')::int as declined,
              count(*) filter (where type = 'leave')::int as leave_requests,
              count(*) filter (where type = 'salary_advance')::int as salary_advances
         from pos_staff_approvals where organization_id = $1`,
      [ctx.m.organization_id],
    );
    return c.json({ data: { stats, rows } });
  });

  app.post('/approvals', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.approvals);
    requireCan(ctx, 'staff', 'write');
    return c.json({ data: await insertApproval(ctx, await readJson(c, approvalBody)) }, 201);
  });

  app.post('/approvals/:id/decide', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.approvals);
    requireCan(ctx, 'staff', 'write');
    const id = uuidParam(c.req.param('id'), 'approval');
    const body = await readJson(c, z.object({ decision: z.enum(['approve', 'decline']), note: z.string().trim().max(500).optional() }));
    const [row] = await ctx.db.query<Row>(
      `select a.*, st.full_name as staff_name from pos_staff_approvals a join pos_staff st on st.id = a.staff_id
        where a.id = $1 and a.organization_id = $2 and ($3::uuid is null or st.location_id = $3::uuid)`,
      [id, ctx.m.organization_id, ctx.m.branch_scope],
    );
    if (!row) throw notFound('This request was not found.');
    if (row.status !== 'pending') throw conflict('This request was already decided.');
    const own = await ctx.db.query(`select 1 from pos_staff where id = $1 and user_id = $2`, [row.staff_id, ctx.identity.user_id]);
    if (own.length) throw forbidden('You cannot decide your own request.');
    const approve = body.decision === 'approve';
    const details = (row.details ?? {}) as Record<string, unknown>;
    await ctx.db.transaction(async (tx) => {
      const [locked] = await tx.query<Row>(`select status from pos_staff_approvals where id = $1 and organization_id = $2 for update`, [id, ctx.m.organization_id]);
      if (locked?.status !== 'pending') throw conflict('This request was already decided.');
      if (approve && row.type === 'leave') {
        const from = String(details.from);
        const to = String(details.to ?? details.from);
        await tx.query(
          `insert into pos_staff_attendance (organization_id, staff_id, date, status, notes, marked_by)
           select $1, $2, d::date, 'leave', $5, $6 from generate_series($3::date, $4::date, interval '1 day') d
           on conflict (staff_id, date) do update set status = 'leave', updated_at = now()
            where pos_staff_attendance.organization_id = excluded.organization_id`,
          [ctx.m.organization_id, row.staff_id, from, to, String(details.reason ?? 'Approved leave').slice(0, 500), ctx.identity.user_id],
        );
      }
      if (approve && row.type === 'salary_advance') {
        const today = localDate(tzOf(ctx));
        const [y, m] = today.split('-').map(Number) as [number, number];
        const next = m === 12 ? { month: 1, year: y + 1 } : { month: m + 1, year: y };
        await insertAdvance(ctx, tx, {
          staff_id: row.staff_id as string,
          amount: Number(details.amount),
          advance_date: today,
          deduct_month: Number(details.deduct_month ?? next.month),
          deduct_year: Number(details.deduct_year ?? next.year),
          reason: String(details.reason ?? 'Approved advance request').slice(0, 500),
          mode: 'cash',
        });
      }
      await tx.query(
        `update pos_staff_approvals set status = $3, decided_by = $4, decided_by_name = $5, decided_at = now(), decision_note = $6, updated_at = now()
          where id = $1 and organization_id = $2`,
        [id, ctx.m.organization_id, approve ? 'approved' : 'declined', ctx.identity.user_id, actorName(ctx), body.note ?? null],
      );
    });
    await audit(ctx, approve ? 'Approved request' : 'Declined request', 'Approval', id, { staff: row.staff_name, type: row.type });
    const [out] = await ctx.db.query<Row>(
      `select a.*, st.full_name as staff_name from pos_staff_approvals a join pos_staff st on st.id = a.staff_id where a.id = $1`,
      [id],
    );
    return c.json({ data: out });
  });

  // ── self-service (any signed-in staff member) ─────────────────────────
  app.get('/me', async (c) => {
    const ctx = ctxOf(c);
    const [mine] = await ctx.db.query<Row>(`${EMPLOYEE_SQL} and st.user_id = $3`, [ctx.m.organization_id, null, ctx.identity.user_id]);
    const requests = mine
      ? await ctx.db.query<Row>(`select * from pos_staff_approvals where organization_id = $1 and staff_id = $2 order by requested_at desc limit 50`, [
          ctx.m.organization_id,
          mine.id,
        ])
      : [];
    return c.json({ data: { staff: mine ? employeeView(mine, false) : null, requests } });
  });

  app.post('/me/requests', async (c) => {
    const ctx = ctxOf(c);
    const [mine] = await ctx.db.query<Row>(`select id from pos_staff where organization_id = $1 and user_id = $2 and deleted_at is null`, [
      ctx.m.organization_id,
      ctx.identity.user_id,
    ]);
    if (!mine) throw unprocessable('Your login is not linked to a staff profile yet. Ask your manager.');
    const body = await readJson(c, approvalBody.omit({ staff_id: true }));
    return c.json({ data: await insertApproval(ctx, { ...body, staff_id: mine.id as string }) }, 201);
  });

  // ── audit log ──────────────────────────────────────────────────────────
  app.get('/audit-log', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.auditLog);
    const q = (c.req.query('q') ?? '').trim();
    const limit = intParam(c.req.query('limit'), 300, 2000);
    const rows = await ctx.db.query<Row>(
      `select id, created_at, action, entity, entity_id, actor_name, details from pos_audit_log
        where organization_id = $1
          and ($2 = '' or action ilike '%' || $2 || '%' or entity ilike '%' || $2 || '%' or actor_name ilike '%' || $2 || '%')
        order by created_at desc limit ${limit}`,
      [ctx.m.organization_id, q],
    );
    return c.json({ data: rows });
  });

  // ── reports ────────────────────────────────────────────────────────────
  const REPORT_KINDS = ['staff_list', 'attendance', 'salaries', 'salary_paid', 'salary_pending', 'advances'] as const;

  app.get('/reports', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.reports);
    const [r] = await ctx.db.query<Row>(
      `select (select count(*) from pos_staff where organization_id = $1 and deleted_at is null)::int as staff_list,
              (select count(*) from pos_staff_attendance where organization_id = $1)::int as attendance,
              (select count(*) from pos_staff_salaries where organization_id = $1)::int as salaries,
              (select count(*) from pos_staff_salaries where organization_id = $1 and status = 'paid')::int as salary_paid,
              (select count(*) from pos_staff_salaries where organization_id = $1 and status <> 'paid')::int as salary_pending,
              (select count(*) from pos_staff_advances where organization_id = $1)::int as advances`,
      [ctx.m.organization_id],
    );
    return c.json({ data: r });
  });

  app.get('/reports/:kind', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.reports);
    const kind = c.req.param('kind') as (typeof REPORT_KINDS)[number];
    if (!REPORT_KINDS.includes(kind)) throw notFound('This report is not available.');
    const org = ctx.m.organization_id;
    const salaryCols = ['Staff', 'Month', 'Basic', 'OT', 'Bonus', 'Advance', 'Penalty', 'Net', 'Paid', 'Pending', 'Status'];
    const salarySql = (where: string) =>
      ctx.db.query<Row>(
        `select st.full_name, sa.year, sa.month, sa.basic, sa.ot_amount, sa.bonus, sa.advance, sa.penalty, sa.net, sa.paid,
                greatest(sa.net - sa.paid, 0) as pending, sa.status
           from pos_staff_salaries sa join pos_staff st on st.id = sa.staff_id
          where sa.organization_id = $1 ${where} order by sa.year desc, sa.month desc, st.full_name limit 5000`,
        [org],
      );
    const salaryRowsOut = (rows: Row[]) =>
      rows.map((r) => [r.full_name, `${r.month}/${r.year}`, r.basic, r.ot_amount, r.bonus, r.advance, r.penalty, r.net, r.paid, r.pending, r.status]);
    let out: { title: string; columns: string[]; rows: unknown[][] };
    switch (kind) {
      case 'staff_list': {
        const rows = await loadEmployees(ctx);
        const full = ctx.m.screens.includes(S.directory);
        out = {
          title: 'Staff List',
          columns: ['Code', 'Name', 'Mobile', 'Email', 'Role', 'Department', 'Joined', 'Salary type', 'Pay rate', 'Status', 'App login'],
          rows: rows.map((r) => {
            const v = employeeView(r, full);
            const rate = v.salary_type === 'daily' ? v.daily_wage : v.salary_type === 'hourly' ? v.hourly_rate : v.monthly_salary;
            return [v.staff_code, v.full_name, v.mobile, v.email, v.role_name ?? v.designation, v.department, v.joining_date, v.salary_type, rate, v.status, v.login?.email ?? ''];
          }),
        };
        break;
      }
      case 'attendance': {
        const rows = await ctx.db.query<Row>(
          `select a.date::text as date, st.full_name, a.status, a.check_in, a.check_out, a.ot_hours, a.notes
             from pos_staff_attendance a join pos_staff st on st.id = a.staff_id
            where a.organization_id = $1 order by a.date desc, st.full_name limit 5000`,
          [org],
        );
        out = { title: 'Attendance', columns: ['Date', 'Staff', 'Status', 'Check-in', 'Check-out', 'OT (hr)', 'Notes'], rows: rows.map((r) => Object.values(r)) };
        break;
      }
      case 'salaries':
        out = { title: 'Salaries', columns: salaryCols, rows: salaryRowsOut(await salarySql('')) };
        break;
      case 'salary_paid':
        out = { title: 'Salary Paid', columns: salaryCols, rows: salaryRowsOut(await salarySql(`and sa.status = 'paid'`)) };
        break;
      case 'salary_pending':
        out = { title: 'Salary Pending', columns: salaryCols, rows: salaryRowsOut(await salarySql(`and sa.status <> 'paid'`)) };
        break;
      case 'advances': {
        const rows = await advancesQuery(ctx);
        out = {
          title: 'Advances',
          columns: ['Date', 'Staff', 'Amount', 'Deduct in', 'Reason', 'Mode', 'Status'],
          rows: rows.map((r) => [r.advance_date, r.staff_name, r.amount, `${r.deduct_month}/${r.deduct_year}`, r.reason, r.mode, r.status]),
        };
        break;
      }
    }
    return c.json({ data: { kind, ...out } });
  });

  // ── training ───────────────────────────────────────────────────────────
  app.get('/training', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.training);
    const org = ctx.m.organization_id;
    const modules = await ctx.db.query<Row>(`select * from pos_training_modules where organization_id = $1 and deleted_at is null order by created_at desc`, [org]);
    const staff = await ctx.db.query<Row>(
      `select st.id, st.full_name, st.designation, r.name as role_name
         from pos_staff st
         left join pos_login_security s on s.user_id = st.user_id
         left join pos_staff_roles r on r.id = s.staff_role_id and r.deleted_at is null
        where st.organization_id = $1 and st.deleted_at is null and st.status = 'active'
          and ($2::uuid is null or st.location_id = $2::uuid)
        order by st.full_name`,
      [org, ctx.m.branch_scope],
    );
    const attempts = await ctx.db.query<Row>(
      `select module_id, staff_id, max(score)::int as best, bool_or(passed) as passed, count(*)::int as n,
              count(*) filter (where not passed)::int as failed
         from pos_training_attempts where organization_id = $1 group by module_id, staff_id`,
      [org],
    );
    let completions = 0;
    let inProgress = 0;
    let failedAttempts = 0;
    const out = modules.map((m) => {
      const roles = ((m.roles as string[]) ?? []).map((r) => r.toLowerCase());
      const all = roles.includes('all staff');
      const assigned = staff.filter(
        (s) => all || roles.includes(String(s.role_name ?? '').toLowerCase()) || roles.includes(String(s.designation ?? '').toLowerCase()),
      );
      const progress = assigned.map((s) => {
        const a = attempts.find((x) => x.module_id === m.id && x.staff_id === s.id);
        const status = !a ? 'not_started' : a.passed ? 'passed' : 'failed';
        return { staff_id: s.id, staff_name: s.full_name, status, best_score: a ? Number(a.best) : null };
      });
      const passed = progress.filter((p) => p.status === 'passed').length;
      completions += passed;
      inProgress += progress.filter((p) => p.status === 'failed').length;
      failedAttempts += attempts.filter((x) => x.module_id === m.id).reduce((n, x) => n + Number(x.failed), 0);
      return { ...m, assigned_count: assigned.length, passed_count: passed, progress };
    });
    return c.json({
      data: {
        stats: { modules: modules.length, completions_passed: completions, in_progress: inProgress, failed_attempts: failedAttempts },
        modules: out,
      },
    });
  });

  app.post('/training', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.training);
    requireCan(ctx, 'staff', 'write');
    const body = await readJson(c, trainingBody);
    const [row] = await ctx.db.insert<Row>('pos_training_modules', [
      { ...body, roles: new TextArray(body.roles), organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id },
    ]);
    await audit(ctx, body.status === 'published' ? 'Published training module' : 'Created training module', 'Training', row!.id as string, { title: body.title });
    return c.json({ data: { ...row, assigned_count: 0, passed_count: 0, progress: [] } }, 201);
  });

  app.patch('/training/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.training);
    requireCan(ctx, 'staff', 'write');
    const id = uuidParam(c.req.param('id'), 'training module');
    const body = await readJson(c, trainingBody.partial());
    const patch: Row = { ...body, updated_at: new Date().toISOString() };
    if (body.roles) patch.roles = new TextArray(body.roles);
    const [row] = await ctx.db.update<Row>('pos_training_modules', patch, [
      { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
      { col: 'id', op: 'eq', value: id },
      { col: 'deleted_at', op: 'is', value: null },
    ]);
    if (!row) throw notFound('This training module was not found.');
    await audit(ctx, 'Updated training module', 'Training', id, { title: row.title });
    return c.json({ data: { ...row, assigned_count: 0, passed_count: 0, progress: [] } });
  });

  app.delete('/training/:id', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.training);
    requireCan(ctx, 'staff', 'delete');
    const id = uuidParam(c.req.param('id'), 'training module');
    const [row] = await ctx.db.update<Row>('pos_training_modules', { deleted_at: new Date().toISOString() }, [
      { col: 'organization_id', op: 'eq', value: ctx.m.organization_id },
      { col: 'id', op: 'eq', value: id },
    ]);
    if (!row) throw notFound('This training module was not found.');
    await audit(ctx, 'Deleted training module', 'Training', id, { title: row.title });
    return c.body(null, 204);
  });

  app.post('/training/:id/attempts', async (c) => {
    const ctx = ctxOf(c);
    requireScreen(ctx, S.training);
    requireCan(ctx, 'staff', 'write');
    const id = uuidParam(c.req.param('id'), 'training module');
    const body = await readJson(c, z.object({ staff_id: z.string().uuid(), answers: z.array(z.number().int().min(-1)).max(200) }));
    const [m] = await ctx.db.query<Row>(`select * from pos_training_modules where id = $1 and organization_id = $2 and deleted_at is null`, [id, ctx.m.organization_id]);
    if (!m) throw notFound('This training module was not found.');
    await oneEmployee(ctx, body.staff_id);
    const questions = (m.questions as { answer_index: number }[]) ?? [];
    if (!questions.length) throw unprocessable('This module has no test questions yet.');
    const correct = questions.filter((q, i) => body.answers[i] === q.answer_index).length;
    const score = Math.round((correct / questions.length) * 100);
    const passed = score >= Number(m.pass_score);
    await ctx.db.insert('pos_training_attempts', [
      { organization_id: ctx.m.organization_id, module_id: id, staff_id: body.staff_id, score, passed, answers: body.answers, created_by: ctx.identity.user_id },
    ]);
    await audit(ctx, passed ? 'Passed training test' : 'Failed training test', 'Training', id, { title: m.title, score });
    return c.json({ data: { score, passed, correct, total: questions.length } }, 201);
  });

  return app;
}

export { ApiError };
