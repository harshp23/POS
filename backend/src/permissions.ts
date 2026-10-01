/// Restaurant (POS) roles and what each may do. A restaurant account is a
/// master-admin `users` row with organization_id + pos_role (migration
/// 008); a platform super admin (security_roles.key = 'super_admin') acts
/// as the owner of whichever organization they open.
///
/// A restaurant has six roles (owner decision, 2026-09-29):
///   Owner → Restaurant Admin → Branch Manager (one branch) →
///   the branch's Cashier, Captain and Kitchen.
/// Anything more specific (a store keeper, an accountant) is a custom staff
/// role: one of these six as its base, with fewer screens.

export type Module =
  | 'franchise'
  | 'master'
  | 'operations'
  | 'staff'
  | 'crm'
  | 'marketing'
  | 'finance'
  | 'integrations'
  | 'tasks'
  | 'settings';
export type Action = 'read' | 'write' | 'delete';

export const POS_ROLE_NAMES: Record<string, string> = {
  org_owner: 'Owner',
  org_admin: 'Restaurant Admin',
  location_manager: 'Branch Manager',
  biller: 'Cashier',
  captain: 'Captain',
  kitchen: 'Kitchen (KOT)',
};

export const POS_ROLES = Object.keys(POS_ROLE_NAMES) as [string, ...string[]];

/// Values of the older, generic role list that the database still accepts
/// (master-admin migration 008). A login that has one works as the nearest
/// restaurant role; any other old value has no access until an admin gives
/// the login one of the six roles.
const LEGACY_ROLES: Record<string, string> = {
  business_manager: 'location_manager',
  operations_manager: 'location_manager',
  manager: 'location_manager',
  staff_user: 'captain',
};

/// The role a stored pos_role (or a staff role's base role) works as.
export function restaurantRole(posRole: string | null | undefined): string {
  if (!posRole) return 'none';
  if (posRole in POS_ROLE_NAMES) return posRole;
  return LEGACY_ROLES[posRole] ?? 'none';
}

export const roleName = (role: string) => POS_ROLE_NAMES[role] ?? 'No role — ask your restaurant admin';

const OWNERS = ['org_owner', 'org_admin'];
const MANAGERS = [...OWNERS, 'location_manager'];
const FLOOR = ['biller', 'captain', 'kitchen'];

/// What people call each module and action in messages.
export const MODULE_NAMES: Record<string, string> = {
  franchise: 'franchise',
  master: 'master data',
  operations: 'orders and billing',
  staff: 'staff',
  crm: 'customer',
  finance: 'finance',
  marketing: 'marketing',
  integrations: 'integrations',
  tasks: 'task',
  settings: 'settings',
};
export const ACTION_WORDS: Record<string, string> = { read: 'view', write: 'change', delete: 'delete' };

/// Roles that work for one branch: an account with one of these and a home
/// branch (users.location_id) sees only that branch — its data, its staff,
/// its orders. Without a home branch they work across the organization
/// (single-branch restaurants).
export const BRANCH_BOUND_ROLES = new Set(['location_manager', ...FLOOR]);

const rules: Record<Module, Record<Action, string[]>> = {
  // Chain views across branches: the owner and the restaurant admin.
  franchise: {
    read: OWNERS,
    write: OWNERS,
    delete: OWNERS,
  },
  master: {
    read: [...MANAGERS, ...FLOOR],
    write: MANAGERS,
    delete: MANAGERS,
  },
  operations: {
    read: [...MANAGERS, ...FLOOR],
    write: [...MANAGERS, ...FLOOR],
    delete: MANAGERS,
  },
  // Staff & Users (logins, attendance, payroll). Which tabs each role sees
  // is decided per screen (src/access.ts); this is the outer fence.
  staff: {
    read: MANAGERS,
    write: MANAGERS,
    delete: MANAGERS,
  },
  // Customers, loyalty and wallet: the branch's manager looks after them
  // too; the floor roles don't open the panel.
  crm: {
    read: MANAGERS,
    write: MANAGERS,
    delete: MANAGERS,
  },
  // Branch money (payments, cash entries, settlements): a branch manager
  // records and reads their branch; only the owners delete.
  finance: {
    read: MANAGERS,
    write: MANAGERS,
    delete: OWNERS,
  },
  // Restaurant-wide: campaigns, connected apps and keys, staff tasks, and
  // the restaurant's settings.
  marketing: {
    read: OWNERS,
    write: OWNERS,
    delete: OWNERS,
  },
  integrations: {
    read: OWNERS,
    write: OWNERS,
    delete: OWNERS,
  },
  tasks: {
    read: OWNERS,
    write: OWNERS,
    delete: OWNERS,
  },
  settings: {
    read: OWNERS,
    write: OWNERS,
    delete: OWNERS,
  },
};

/// Roles that may confirm a card / UPI / wallet / credit payment as
/// received (after checking the bank or UPI statement): until then such a
/// payment is "pending verification" and the order is not paid.
export const PAYMENT_VERIFIERS = new Set(MANAGERS);
export const canVerifyPayments = (role: string) => PAYMENT_VERIFIERS.has(role);

/// Roles that may collect money (record a payment / settle a bill): the
/// cashier and the managers. Captains and the kitchen cannot.
export const canTakePayments = (role: string) =>
  can(role, 'operations', 'write') && (role === 'biller' || PAYMENT_VERIFIERS.has(role));

/// Roles that may place orders. The kitchen only works the KOT queue.
export const canPlaceOrders = (role: string) => role !== 'kitchen' && can(role, 'operations', 'write');

export function can(role: string, module: Module, action: Action): boolean {
  return rules[module][action].includes(role);
}

/// Restaurant admin panel (franchise / master / operations / staff) or the
/// POS terminal.
export function panelFor(role: string): 'vendor' | 'pos' {
  return FLOOR.includes(role) ? 'pos' : 'vendor';
}

export function capabilities(role: string): Record<Module, Action[]> {
  const out = {} as Record<Module, Action[]>;
  for (const m of Object.keys(rules) as Module[]) {
    out[m] = (['read', 'write', 'delete'] as Action[]).filter((a) => can(role, m, a));
  }
  return out;
}
