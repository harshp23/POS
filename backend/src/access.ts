/// Screens: what each account may open in the app. The server is the
/// authority — `/v1/auth/me` returns the list, the app hides everything
/// else, and the staff service checks it on every call. Mirrors
/// lib/domain/access.dart (test/access-contract.test.ts compares them).
import { can, panelFor, POS_ROLES, type Module } from './permissions.js';

export interface ScreenDef {
  id: string;
  label: string;
  group: 'Overview' | 'Franchise' | 'Master' | 'Operations' | 'Staff' | 'Business' | 'Coming soon' | 'POS';
  /// When the screen joined the app. A staff role last saved before then
  /// gets it from its base role's defaults (see screensFor).
  added?: string;
}

const SECTIONS_ADDED = '2026-09-30T05:30:00.000Z';

export const SCREENS: ScreenDef[] = [
  { id: 'dashboard', label: 'Dashboard', group: 'Overview' },
  { id: 'franchise.command_center', label: 'Command Center', group: 'Franchise' },
  { id: 'franchise.branch_performance', label: 'Branch Performance', group: 'Franchise' },
  { id: 'franchise.branch_detail', label: 'Branch Detail', group: 'Franchise' },
  { id: 'franchise.inventory', label: 'Inventory & Supply', group: 'Franchise' },
  { id: 'franchise.exceptions', label: 'Exceptions / Action Centre', group: 'Franchise' },
  { id: 'franchise.targets', label: 'Targets & Benchmarking', group: 'Franchise' },
  { id: 'franchise.compliance', label: 'Compliance & Audit', group: 'Franchise' },
  { id: 'master.menu_items', label: 'Menu Items', group: 'Master' },
  { id: 'master.products_online', label: 'Products (Online)', group: 'Master' },
  { id: 'master.media', label: 'Media', group: 'Master' },
  { id: 'master.offers', label: 'Offers', group: 'Master' },
  { id: 'master.inventory', label: 'Inventory', group: 'Master' },
  { id: 'master.recipes', label: 'Recipes', group: 'Master' },
  { id: 'master.suppliers', label: 'Suppliers', group: 'Master' },
  { id: 'master.purchase_orders', label: 'Purchase Orders', group: 'Master' },
  { id: 'ops.live', label: 'Live Operations', group: 'Operations' },
  { id: 'ops.captain_orders', label: 'Captain Orders', group: 'Operations' },
  { id: 'ops.kitchen', label: 'KOT / Kitchen', group: 'Operations' },
  { id: 'ops.dine_in', label: 'Dine In', group: 'Operations' },
  { id: 'ops.reservations', label: 'Reservations', group: 'Operations' },
  { id: 'ops.billing', label: 'POS Billing', group: 'Operations' },
  { id: 'ops.delivery', label: 'Delivery', group: 'Operations' },
  { id: 'ops.online_orders', label: 'Online Orders', group: 'Operations' },
  { id: 'ops.qr_ordering', label: 'QR Ordering', group: 'Operations' },
  { id: 'staff.dashboard', label: 'Staff Dashboard', group: 'Staff' },
  { id: 'staff.directory', label: 'Staff Directory', group: 'Staff' },
  { id: 'staff.attendance', label: 'Attendance', group: 'Staff' },
  { id: 'staff.salary', label: 'Salary', group: 'Staff' },
  { id: 'staff.advances', label: 'Advances', group: 'Staff' },
  { id: 'staff.roles', label: 'Roles & Permissions', group: 'Staff' },
  { id: 'staff.shifts', label: 'Shifts & Roster', group: 'Staff' },
  { id: 'staff.login_security', label: 'Login Security', group: 'Staff' },
  { id: 'staff.approvals', label: 'Approvals', group: 'Staff' },
  { id: 'staff.audit_log', label: 'Audit Log', group: 'Staff' },
  { id: 'staff.reports', label: 'Staff Reports', group: 'Staff' },
  { id: 'staff.training', label: 'Training', group: 'Staff' },
  // The design's other sidebar sections (owner decision, 2026-09-30). Each
  // opens the whole section; its sidebar entries are pages within it.
  { id: 'task_manager', label: 'Task Manager', group: 'Business', added: SECTIONS_ADDED },
  { id: 'customers', label: 'Customers & CRM', group: 'Business', added: SECTIONS_ADDED },
  { id: 'marketing', label: 'Marketing', group: 'Business', added: SECTIONS_ADDED },
  { id: 'finance', label: 'Finance', group: 'Business', added: SECTIONS_ADDED },
  { id: 'integrations', label: 'Integrations', group: 'Business', added: SECTIONS_ADDED },
  { id: 'settings', label: 'Settings', group: 'Business', added: SECTIONS_ADDED },
  // Not designed yet: a placeholder page that holds no data.
  { id: 'reports', label: 'Reports', group: 'Coming soon', added: SECTIONS_ADDED },
  { id: 'page_builder', label: 'Page Builder', group: 'Coming soon', added: SECTIONS_ADDED },
  { id: 'support', label: 'Support', group: 'Coming soon', added: SECTIONS_ADDED },
  { id: 'pos.billing', label: 'New Order / Billing', group: 'POS' },
  { id: 'pos.dine_in', label: 'Dine In', group: 'POS' },
  { id: 'pos.tables', label: 'Tables', group: 'POS' },
  { id: 'pos.takeaway', label: 'Takeaway', group: 'POS' },
  { id: 'pos.delivery', label: 'Delivery', group: 'POS' },
  { id: 'pos.online', label: 'Online Orders', group: 'POS' },
  { id: 'pos.all_orders', label: 'All Orders', group: 'POS' },
  { id: 'pos.menu', label: 'Menu', group: 'POS' },
  { id: 'pos.kitchen', label: 'Kitchen Display', group: 'POS' },
];

export const SCREEN_IDS = new Set(SCREENS.map((s) => s.id));

/// A screen's name as the sidebar shows it.
export const screenLabel = (id: string) => SCREENS.find((s) => s.id === id)?.label ?? id.replace(/[._]/g, ' ');
const group = (g: ScreenDef['group']) => SCREENS.filter((s) => s.group === g).map((s) => s.id);
const VENDOR_ALL = SCREENS.filter((s) => s.group !== 'POS').map((s) => s.id);

/// What each role opens by default:
///   Owner / Restaurant Admin — the whole panel, every branch;
///   Branch Manager — its branch: menu and stock, operations, the
///     branch's staff (logins, attendance, shifts), and its reports,
///     customers and finance; no chain views, no payroll, no settings;
///   Cashier — the POS; Captain — table orders; Kitchen — the KOT display.
export function defaultScreens(role: string): string[] {
  switch (role) {
    case 'org_owner':
    case 'org_admin':
      return VENDOR_ALL;
    case 'location_manager':
      return [
        'dashboard',
        'master.menu_items',
        'master.inventory',
        'master.recipes',
        'master.suppliers',
        'master.purchase_orders',
        ...group('Operations'),
        'staff.dashboard',
        'staff.directory',
        'staff.attendance',
        'staff.shifts',
        'staff.login_security',
        'staff.approvals',
        'staff.training',
        'reports',
        'customers',
        'finance',
      ];
    case 'biller':
      return ['pos.billing', 'pos.dine_in', 'pos.tables', 'pos.takeaway', 'pos.delivery', 'pos.online', 'pos.all_orders', 'pos.menu'];
    case 'captain':
      return ['pos.billing', 'pos.dine_in', 'pos.tables', 'pos.all_orders'];
    case 'kitchen':
      return ['pos.kitchen'];
    default:
      return [];
  }
}

/// The data module behind each section (src/permissions.ts decides which
/// roles may read it).
const SECTION_MODULES: Record<string, Module> = {
  task_manager: 'tasks',
  customers: 'crm',
  marketing: 'marketing',
  finance: 'finance',
  integrations: 'integrations',
  settings: 'settings',
  reports: 'operations',
};

const moduleOf = (screen: string): Module | null => {
  if (screen.startsWith('franchise.')) return 'franchise';
  if (screen in SECTION_MODULES) return SECTION_MODULES[screen]!;
  if (screen.startsWith('master.')) return 'master';
  if (screen.startsWith('ops.') || screen.startsWith('pos.')) return 'operations';
  if (screen.startsWith('staff.')) return 'staff';
  // Placeholders for the whole restaurant: owners only, like the chain views.
  if (SCREENS.some((s) => s.id === screen && s.group === 'Coming soon')) return 'franchise';
  return null;
};

/// Screens a staff role built on [base] may be given: its panel's screens
/// whose data the base role may at least read.
export function grantableScreens(base: string): string[] {
  const pos = panelFor(base) === 'pos';
  return SCREENS.filter((s) => (s.group === 'POS') === pos)
    .map((s) => s.id)
    .filter((id) => {
      const m = moduleOf(id);
      return m === null || can(base, m, 'read');
    });
}

/// The screens an account opens: its custom staff role's list (kept inside
/// what the base role may have), else the base role's defaults. Screens
/// that joined the app after the role was last saved ([savedAt]) come from
/// the base role's defaults, so a new section reaches existing roles until
/// an admin edits the role.
export function screensFor(
  base: string,
  custom: string[] | null | undefined,
  savedAt?: string | Date | null,
): string[] {
  if (!custom) return defaultScreens(base);
  const allowed = new Set(grantableScreens(base));
  const out = custom.filter((s) => allowed.has(s));
  const saved = savedAt ? new Date(savedAt).getTime() : null;
  if (saved !== null) {
    const newer = new Set(SCREENS.filter((s) => s.added && Date.parse(s.added) > saved).map((s) => s.id));
    for (const s of defaultScreens(base)) if (newer.has(s) && !out.includes(s)) out.push(s);
  }
  return out;
}

export function roleCatalogue() {
  return {
    screens: SCREENS,
    base_roles: POS_ROLES.map((key) => ({
      key,
      panel: panelFor(key),
      grantable: grantableScreens(key),
      default_screens: defaultScreens(key),
    })),
  };
}

/// Default staff roles ("Seed default roles" in Roles & permissions): one
/// per restaurant role below the owner.
export const DEFAULT_STAFF_ROLES: { name: string; base_role: string; screens?: string[]; description: string }[] = [
  { name: 'Restaurant Admin', base_role: 'org_admin', description: 'Runs the whole restaurant: every branch and module.' },
  { name: 'Branch Manager', base_role: 'location_manager', description: 'Runs one branch: its menu and stock, orders and staff.' },
  { name: 'Cashier', base_role: 'biller', description: 'POS billing: takes orders and collects payments.' },
  { name: 'Captain', base_role: 'captain', description: 'Takes table orders and sends them to the kitchen.' },
  { name: 'Kitchen (KOT)', base_role: 'kitchen', description: 'Kitchen display: prepares the KOTs.' },
];
