/// Which screens an account may open.
///
/// The backend is the authority: `GET /v1/auth/me` returns the signed-in
/// account's `screens`, computed from its restaurant role (a built-in
/// `pos_role`, or a custom role made in Staff → Roles & permissions). The
/// app only hides what the list leaves out; every API call is checked again
/// on the server. The table below mirrors backend/src/access.ts and is used
/// when there is no backend (local demo) or an older backend sends no list.
library;

class AppScreen {
  const AppScreen(this.id, this.label, this.group);
  final String id;
  final String label;

  /// Sidebar group: Overview, Franchise, Master, Operations, Staff,
  /// Business, Coming soon, POS.
  final String group;

  bool get isPos => id.startsWith('pos.');
}

abstract final class Screens {
  static const dashboard = 'dashboard';

  static const franchiseCommandCenter = 'franchise.command_center';
  static const franchiseBranchPerformance = 'franchise.branch_performance';
  static const franchiseBranchDetail = 'franchise.branch_detail';
  static const franchiseInventory = 'franchise.inventory';
  static const franchiseExceptions = 'franchise.exceptions';
  static const franchiseTargets = 'franchise.targets';
  static const franchiseCompliance = 'franchise.compliance';

  static const masterMenuItems = 'master.menu_items';
  static const masterProductsOnline = 'master.products_online';
  static const masterMedia = 'master.media';
  static const masterOffers = 'master.offers';
  static const masterInventory = 'master.inventory';
  static const masterRecipes = 'master.recipes';
  static const masterSuppliers = 'master.suppliers';
  static const masterPurchaseOrders = 'master.purchase_orders';

  static const opsLive = 'ops.live';
  static const opsCaptainOrders = 'ops.captain_orders';
  static const opsKitchen = 'ops.kitchen';
  static const opsDineIn = 'ops.dine_in';
  static const opsReservations = 'ops.reservations';
  static const opsBilling = 'ops.billing';
  static const opsDelivery = 'ops.delivery';
  static const opsOnlineOrders = 'ops.online_orders';
  static const opsQrOrdering = 'ops.qr_ordering';

  static const staffDashboard = 'staff.dashboard';
  static const staffDirectory = 'staff.directory';
  static const staffAttendance = 'staff.attendance';
  static const staffSalary = 'staff.salary';
  static const staffAdvances = 'staff.advances';
  static const staffRoles = 'staff.roles';
  static const staffShifts = 'staff.shifts';
  static const staffLoginSecurity = 'staff.login_security';
  static const staffApprovals = 'staff.approvals';
  static const staffAuditLog = 'staff.audit_log';
  static const staffReports = 'staff.reports';
  static const staffTraining = 'staff.training';

  // The design's other sidebar sections (owner decision, 2026-09-30); each
  // screen opens the whole section. Reports, Page Builder and Support are
  // not designed yet and open a placeholder page.
  static const taskManager = 'task_manager';
  static const reports = 'reports';
  static const pageBuilder = 'page_builder';
  static const customers = 'customers';
  static const marketing = 'marketing';
  static const finance = 'finance';
  static const integrations = 'integrations';
  static const support = 'support';
  static const settings = 'settings';

  static const posBilling = 'pos.billing';
  static const posDineIn = 'pos.dine_in';
  static const posTables = 'pos.tables';
  static const posTakeaway = 'pos.takeaway';
  static const posDelivery = 'pos.delivery';
  static const posOnline = 'pos.online';
  static const posAllOrders = 'pos.all_orders';
  static const posMenu = 'pos.menu';
  static const posKitchen = 'pos.kitchen';

  static const all = <AppScreen>[
    AppScreen(dashboard, 'Dashboard', 'Overview'),
    AppScreen(franchiseCommandCenter, 'Command Center', 'Franchise'),
    AppScreen(franchiseBranchPerformance, 'Branch Performance', 'Franchise'),
    AppScreen(franchiseBranchDetail, 'Branch Detail', 'Franchise'),
    AppScreen(franchiseInventory, 'Inventory & Supply', 'Franchise'),
    AppScreen(franchiseExceptions, 'Exceptions / Action Centre', 'Franchise'),
    AppScreen(franchiseTargets, 'Targets & Benchmarking', 'Franchise'),
    AppScreen(franchiseCompliance, 'Compliance & Audit', 'Franchise'),
    AppScreen(masterMenuItems, 'Menu Items', 'Master'),
    AppScreen(masterProductsOnline, 'Products (Online)', 'Master'),
    AppScreen(masterMedia, 'Media', 'Master'),
    AppScreen(masterOffers, 'Offers', 'Master'),
    AppScreen(masterInventory, 'Inventory', 'Master'),
    AppScreen(masterRecipes, 'Recipes', 'Master'),
    AppScreen(masterSuppliers, 'Suppliers', 'Master'),
    AppScreen(masterPurchaseOrders, 'Purchase Orders', 'Master'),
    AppScreen(opsLive, 'Live Operations', 'Operations'),
    AppScreen(opsCaptainOrders, 'Captain Orders', 'Operations'),
    AppScreen(opsKitchen, 'KOT / Kitchen', 'Operations'),
    AppScreen(opsDineIn, 'Dine In', 'Operations'),
    AppScreen(opsReservations, 'Reservations', 'Operations'),
    AppScreen(opsBilling, 'POS Billing', 'Operations'),
    AppScreen(opsDelivery, 'Delivery', 'Operations'),
    AppScreen(opsOnlineOrders, 'Online Orders', 'Operations'),
    AppScreen(opsQrOrdering, 'QR Ordering', 'Operations'),
    AppScreen(staffDashboard, 'Staff Dashboard', 'Staff'),
    AppScreen(staffDirectory, 'Staff Directory', 'Staff'),
    AppScreen(staffAttendance, 'Attendance', 'Staff'),
    AppScreen(staffSalary, 'Salary', 'Staff'),
    AppScreen(staffAdvances, 'Advances', 'Staff'),
    AppScreen(staffRoles, 'Roles & Permissions', 'Staff'),
    AppScreen(staffShifts, 'Shifts & Roster', 'Staff'),
    AppScreen(staffLoginSecurity, 'Login Security', 'Staff'),
    AppScreen(staffApprovals, 'Approvals', 'Staff'),
    AppScreen(staffAuditLog, 'Audit Log', 'Staff'),
    AppScreen(staffReports, 'Staff Reports', 'Staff'),
    AppScreen(staffTraining, 'Training', 'Staff'),
    AppScreen(taskManager, 'Task Manager', 'Business'),
    AppScreen(customers, 'Customers & CRM', 'Business'),
    AppScreen(marketing, 'Marketing', 'Business'),
    AppScreen(finance, 'Finance', 'Business'),
    AppScreen(integrations, 'Integrations', 'Business'),
    AppScreen(settings, 'Settings', 'Business'),
    AppScreen(reports, 'Reports', 'Coming soon'),
    AppScreen(pageBuilder, 'Page Builder', 'Coming soon'),
    AppScreen(support, 'Support', 'Coming soon'),
    AppScreen(posBilling, 'New Order / Billing', 'POS'),
    AppScreen(posDineIn, 'Dine In', 'POS'),
    AppScreen(posTables, 'Tables', 'POS'),
    AppScreen(posTakeaway, 'Takeaway', 'POS'),
    AppScreen(posDelivery, 'Delivery', 'POS'),
    AppScreen(posOnline, 'Online Orders', 'POS'),
    AppScreen(posAllOrders, 'All Orders', 'POS'),
    AppScreen(posMenu, 'Menu', 'POS'),
    AppScreen(posKitchen, 'Kitchen Display', 'POS'),
  ];

  static final Map<String, AppScreen> byId = {for (final s in all) s.id: s};

  static Set<String> _group(String group) => {
        for (final s in all)
          if (s.group == group) s.id
      };

  static Set<String> get vendorAll => {
        for (final s in all)
          if (!s.isPos) s.id
      };
}

/// Built-in restaurant roles (users.pos_role). Mirrors
/// backend/src/permissions.ts and backend/src/access.ts.
abstract final class PosRoles {
  /// The restaurant's roles (owner decision, 2026-09-29): the Owner, then
  /// the five the restaurant hands out — Restaurant Admin, Branch Manager
  /// (one branch), and the branch's Cashier, Captain and Kitchen. Anything
  /// more specific is a custom staff role on top of one of these. Mirrors
  /// backend/src/permissions.ts.
  static const names = <String, String>{
    'org_owner': 'Owner',
    'org_admin': 'Restaurant Admin',
    'location_manager': 'Branch Manager',
    'biller': 'Cashier',
    'captain': 'Captain',
    'kitchen': 'Kitchen (KOT)',
  };

  /// Floor roles work on the POS terminal, everyone else in the vendor
  /// panel.
  static const floor = {'biller', 'captain', 'kitchen'};

  static String panelFor(String role) =>
      floor.contains(role) ? 'pos' : 'vendor';

  /// Roles that may confirm card / UPI payments as received (mirrors
  /// PAYMENT_VERIFIERS in backend/src/permissions.ts).
  static const paymentVerifiers = {
    'org_owner',
    'org_admin',
    'location_manager'
  };
  static bool canVerifyPayments(String role) => paymentVerifiers.contains(role);

  /// Roles with write access to orders (the operations module in
  /// backend/src/permissions.ts).
  static const operationsWriters = {...paymentVerifiers, ...floor};

  /// Roles that may collect money: the cashier and the managers. Captains
  /// and the kitchen do not.
  static bool canTakePayments(String role) =>
      operationsWriters.contains(role) &&
      (role == 'biller' || paymentVerifiers.contains(role));

  /// The kitchen works the KOT queue; it does not place orders.
  static bool canPlaceOrders(String role) =>
      role != 'kitchen' && operationsWriters.contains(role);

  /// What each role opens by default.
  static Set<String> defaultScreens(String role) {
    switch (role) {
      case 'org_owner':
      case 'org_admin':
        return Screens.vendorAll;
      case 'location_manager':
        return {
          Screens.dashboard,
          Screens.masterMenuItems,
          Screens.masterInventory,
          Screens.masterRecipes,
          Screens.masterSuppliers,
          Screens.masterPurchaseOrders,
          ...Screens._group('Operations'),
          Screens.staffDashboard,
          Screens.staffDirectory,
          Screens.staffAttendance,
          Screens.staffShifts,
          Screens.staffLoginSecurity,
          Screens.staffApprovals,
          Screens.staffTraining,
          Screens.customers,
          Screens.finance,
          Screens.reports,
        };
      case 'biller':
        return {
          Screens.posBilling,
          Screens.posDineIn,
          Screens.posTables,
          Screens.posTakeaway,
          Screens.posDelivery,
          Screens.posOnline,
          Screens.posAllOrders,
          Screens.posMenu,
        };
      case 'captain':
        return {
          Screens.posBilling,
          Screens.posDineIn,
          Screens.posTables,
          Screens.posAllOrders,
        };
      case 'kitchen':
        return {Screens.posKitchen};
      default:
        return const {};
    }
  }
}
