import { defaultScreens, screensFor } from './access.js';
import type { AuthUser } from './auth/types.js';
import { eq, type Db } from './db/types.js';
import { ApiError, DbError, forbidden, unauthorized } from './lib/errors.js';
import { isUuid } from './lib/ids.js';
import { ACTION_WORDS, BRANCH_BOUND_ROLES, can, MODULE_NAMES, restaurantRole, roleName, type Action, type Module } from './permissions.js';

export interface Location {
  id: string;
  name: string;
  area: string | null;
  code: string | null;
  type: string | null;
  status: string | null;
  time_zone: string | null;
  currency: string | null;
}

/// The signed-in account, from master-admin's users table.
export interface Identity {
  user_id: string;
  email: string;
  full_name: string;
  status: string;
  /// Restaurant the account belongs to (users.organization_id).
  organization_id: string | null;
  /// Home branch (users.location_id).
  location_id: string | null;
  pos_role: string | null;
  /// security_roles.key = 'super_admin': may open any organization.
  platform_admin: boolean;
}

export interface Membership {
  organization_id: string;
  organization_name: string;
  organization_status: string | null;
  role: string;
  role_name: string;
  full_name: string;
  email: string;
  locations: Location[];
  platform_admin: boolean;
  home_location_id: string | null;
  /// Screens this account may open (src/access.ts).
  screens: string[];
  /// The custom staff role behind [screens], if one is assigned.
  staff_role: { id: string; name: string } | null;
  /// Set for branch-bound accounts (BRANCH_BOUND_ROLES with a home
  /// branch): the only branch they may see. [locations] then holds just it.
  branch_scope: string | null;
}

/// Runs a query against a table added by the POS migration; before the
/// migration has been run, behaves as if the table were empty.
export async function optionalTable<T>(run: () => Promise<T>, fallback: T): Promise<T> {
  try {
    return await run();
  } catch (e) {
    if (e instanceof DbError && (e.code === '42P01' || e.code === '42703')) return fallback;
    throw e;
  }
}

async function staffRoleOf(db: Db, userId: string, orgId: string) {
  const rows = await optionalTable(
    () =>
      db.query<{ id: string; name: string; screens: string[]; saved_at: string | null }>(
        `select r.id, r.name, r.screens, coalesce(r.updated_at, r.created_at) as saved_at
           from pos_login_security s
           join pos_staff_roles r on r.id = s.staff_role_id and r.deleted_at is null and r.organization_id = $2
          where s.user_id = $1
          limit 1`,
        [userId, orgId],
      ),
    [],
  );
  return rows[0] ?? null;
}

export interface RequestContext {
  user: AuthUser;
  accessToken: string;
  db: Db;
  identity: Identity;
  m: Membership;
  /// The branch this request acts for (X-Location-Id, else the account's
  /// home branch, else the first active branch).
  location: Location | null;
  /// Branch part of device-record ids: the location id, or "org" for an
  /// organization without branches.
  locationKey: string;
}

const cache = new Map<string, { m: Membership; until: number }>();

export function forgetMembership(): void {
  cache.clear();
}

const isActive = (status: string | null | undefined) => (status ?? 'active').toLowerCase() === 'active';

export async function loadIdentity(db: Db, user: AuthUser): Promise<Identity> {
  const [u] = await db.query<{
    id: string;
    email: string;
    first_name: string | null;
    last_name: string | null;
    status: string;
    organization_id: string | null;
    location_id: string | null;
    pos_role: string | null;
    role_key: string | null;
  }>(
    `select u.id, u.email, u.first_name, u.last_name, coalesce(u.status, 'Active') as status,
            u.organization_id, u.location_id, u.pos_role, sr.key as role_key
       from users u
       left join security_roles sr on sr.id = u.role_id and sr.is_active
      where u.id = $1
      limit 1`,
    [user.id],
  );
  if (!u) throw unauthorized('This account no longer exists.');
  if (!isActive(u.status)) throw forbidden('This account has been deactivated or suspended.');
  return {
    user_id: u.id,
    email: u.email,
    full_name: [u.first_name, u.last_name].filter(Boolean).join(' '),
    status: u.status,
    organization_id: u.organization_id,
    location_id: u.location_id,
    pos_role: u.pos_role,
    platform_admin: u.role_key === 'super_admin',
  };
}

/// Which organization the request acts for, and in what role:
///  * a restaurant account → its own organization, its pos_role;
///  * a platform super admin → the organization named in X-Organization-Id,
///    as its owner (support / onboarding).
export async function loadMembership(db: Db, id: Identity, requestedOrg: string | null | undefined): Promise<Membership> {
  let orgId = id.organization_id;
  // Old role values map to the six restaurant roles (see permissions.ts).
  let role = restaurantRole(id.pos_role);
  if (!orgId) {
    if (!id.platform_admin) {
      throw forbidden('This account is not linked to a restaurant. Ask the Proviyaa team to link it from the master admin panel.');
    }
    if (!requestedOrg) {
      throw new ApiError(409, 'organization_required', 'Choose which restaurant to open (X-Organization-Id).');
    }
    if (!isUuid(requestedOrg)) throw forbidden('Unknown organization.');
    orgId = requestedOrg;
    role = 'org_owner';
  } else if (requestedOrg && requestedOrg !== orgId) {
    throw forbidden('This account belongs to a different restaurant.');
  }

  const key = `${id.user_id}|${orgId}|${role}`;
  const hit = cache.get(key);
  if (hit && hit.until > Date.now()) return hit.m;

  const [org] = await db.select<{ id: string; business_name: string; status: string }>('organizations', {
    columns: ['id', 'business_name', 'status'],
    filters: [eq('id', orgId)],
  });
  if (!org) throw forbidden('Unknown organization.');
  if (!id.platform_admin && !isActive(org.status)) {
    throw forbidden(`Your restaurant's Proviyaa account is ${org.status}. Contact Proviyaa support.`);
  }
  const locations = await db.select<Location>('org_locations', {
    columns: ['id', 'name', 'area', 'code', 'type', 'status', 'time_zone', 'currency'],
    filters: [eq('org_id', orgId)],
    // Oldest first: an account without a home branch acts for the branch
    // the restaurant started with, not whichever sorts first by name.
    order: [{ col: 'created_at' }, { col: 'name' }],
  });
  const m: Membership = {
    organization_id: orgId,
    organization_name: org.business_name,
    organization_status: org.status,
    role,
    role_name: roleName(role),
    full_name: id.full_name,
    email: id.email,
    locations,
    platform_admin: id.platform_admin,
    home_location_id: id.organization_id ? id.location_id : null,
    screens: defaultScreens(role),
    staff_role: null,
    branch_scope: null,
  };
  if (!id.platform_admin && id.location_id && BRANCH_BOUND_ROLES.has(role) && locations.some((l) => l.id === id.location_id)) {
    m.locations = locations.filter((l) => l.id === id.location_id);
    m.branch_scope = id.location_id;
  }
  if (!id.platform_admin) {
    const custom = await staffRoleOf(db, id.user_id, orgId);
    if (custom) {
      m.screens = screensFor(role, custom.screens, custom.saved_at);
      m.staff_role = { id: custom.id, name: custom.name };
    }
  }
  cache.set(key, { m, until: Date.now() + 30_000 });
  return m;
}

export function pickLocation(m: Membership, requested: string | undefined | null): Location | null {
  if (requested) {
    const found = m.locations.find((l) => l.id === requested);
    if (!found) throw forbidden('That branch does not belong to your organization.');
    return found;
  }
  const home = m.home_location_id ? m.locations.find((l) => l.id === m.home_location_id) : undefined;
  return home ?? m.locations.find((l) => isActive(l.status)) ?? m.locations[0] ?? null;
}

/// Throws unless a branch-bound account (Membership.branch_scope) owns a
/// record of branch [locationId]. Rows with no branch (the chain's shared
/// catalogue, org-level records) are readable by everyone in the org.
export function assertBranchAccess(ctx: RequestContext, locationId: unknown): void {
  const scope = ctx.m.branch_scope;
  if (scope && locationId !== null && locationId !== undefined && locationId !== scope) {
    throw forbidden('That record belongs to another branch.');
  }
}

/// The branch a list must be limited to: a branch-bound account's own
/// branch (whatever was asked), else the requested one — which must be a
/// branch of the organization ('null' = rows without a branch) — else none.
export function listBranch(ctx: RequestContext, requested: string | undefined): string | null | undefined {
  const scope = ctx.m.branch_scope;
  if (scope) {
    if (requested && requested !== scope) throw forbidden('You can only see your own branch.');
    return scope;
  }
  if (requested === undefined || requested === '') return undefined;
  if (requested === 'null') return null;
  if (!ctx.m.locations.some((l) => l.id === requested)) throw forbidden('That branch does not belong to your organization.');
  return requested;
}

/// Chain-level views (franchise analytics, branch comparisons) are for
/// organization-level roles, not for accounts bound to one branch.
export function requireOrgWide(ctx: RequestContext): void {
  if (ctx.m.branch_scope) throw forbidden('Chain-wide views are for organization-level roles; you work for one branch.');
}

/// Throws unless the account may open one of [screens].
export function requireScreen(ctx: RequestContext, ...screens: string[]): void {
  if (!screens.some((s) => ctx.m.screens.includes(s))) {
    throw forbidden(`Your role (${ctx.m.staff_role?.name ?? ctx.m.role_name}) does not have access to this screen.`);
  }
}

export function requireCan(ctx: RequestContext, module: Module, action: Action): void {
  if (!can(ctx.m.role, module, action)) {
    throw forbidden(`Your role (${ctx.m.role_name}) cannot ${ACTION_WORDS[action] ?? action} ${MODULE_NAMES[module] ?? module} data.`);
  }
}

/// Throws unless [id] is a row of [table] owned by the caller's
/// organization — for foreign keys a client sends (category_id, table_id,
/// menu_item_id …). The backend bypasses RLS, so this is the fence.
export async function assertOwned(ctx: RequestContext, table: string, id: unknown, orgColumn = 'organization_id'): Promise<void> {
  if (id === null || id === undefined) return;
  if (!isUuid(id)) throw new ApiError(422, 'invalid_reference', `${table} reference must be a UUID.`);
  if (table === 'org_locations') {
    if (!ctx.m.locations.some((l) => l.id === id)) throw forbidden('That branch does not belong to your organization.');
    return;
  }
  const [row] = await ctx.db.select(table, { columns: ['id'], filters: [eq('id', id), eq(orgColumn, ctx.m.organization_id)] });
  if (!row) throw new ApiError(422, 'invalid_reference', `No ${table.replace(/_/g, ' ')} ${id} in your organization.`);
}
