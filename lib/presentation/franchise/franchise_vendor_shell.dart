import 'package:flutter/material.dart';
import '../../domain/access.dart';
import '../coming_soon_screen.dart';
import '../dashboard/dashboard_widgets.dart' show friendlyErrorText;
import '../vinii_theme.dart';

enum FranchiseTab {
  dashboard,
  commandCenter,
  branchPerformance,
  branchDetail,
  inventorySupply,
  exceptions,
  targetsBenchmarking,
  complianceAudit,
  masterMenuItems,
  masterProductsOnline,
  masterMedia,
  masterOffers,
  masterInventory,
  masterRecipes,
  masterSuppliers,
  masterPurchaseOrders,
  opsLiveOperations,
  opsCaptainOrders,
  opsKitchen,
  opsDineIn,
  opsReservations,
  opsPosBilling,
  opsDelivery,
  opsOnlineOrders,
  opsQrOrdering,
  staff,
  staffRoles,
  staffAttendance,
  staffTraining,
  taskManager,
  // Customers & CRM, Marketing, Finance, Integrations and Settings: one
  // tab per sidebar entry, each opening its page of the section.
  crmCustomers,
  crmGroups,
  crmFeedback,
  crmLoyalty,
  marketingCampaigns,
  marketingPromotions,
  marketingNotifications,
  financePayments,
  financeTransactions,
  financeExpenses,
  financeSettlements,
  financeDocuments,
  integrationsZomato,
  integrationsSwiggy,
  integrationsPayment,
  integrationsOther,
  settingsRestaurant,
  settingsPos,
  settingsOrder,
  settingsNotifications,
  settingsAccount,
  settingsUpdates,
  // Not designed yet; each opens a placeholder page.
  reports,
  pageBuilder,
  support,
}

/// The screen (lib/domain/access.dart) each tab needs. The Staff entry
/// opens Staff Management and is shown when any staff.* screen is allowed.
const franchiseTabScreens = <FranchiseTab, String>{
  FranchiseTab.dashboard: Screens.dashboard,
  FranchiseTab.commandCenter: Screens.franchiseCommandCenter,
  FranchiseTab.branchPerformance: Screens.franchiseBranchPerformance,
  FranchiseTab.branchDetail: Screens.franchiseBranchDetail,
  FranchiseTab.inventorySupply: Screens.franchiseInventory,
  FranchiseTab.exceptions: Screens.franchiseExceptions,
  FranchiseTab.targetsBenchmarking: Screens.franchiseTargets,
  FranchiseTab.complianceAudit: Screens.franchiseCompliance,
  FranchiseTab.masterMenuItems: Screens.masterMenuItems,
  FranchiseTab.masterProductsOnline: Screens.masterProductsOnline,
  FranchiseTab.masterMedia: Screens.masterMedia,
  FranchiseTab.masterOffers: Screens.masterOffers,
  FranchiseTab.masterInventory: Screens.masterInventory,
  FranchiseTab.masterRecipes: Screens.masterRecipes,
  FranchiseTab.masterSuppliers: Screens.masterSuppliers,
  FranchiseTab.masterPurchaseOrders: Screens.masterPurchaseOrders,
  FranchiseTab.opsLiveOperations: Screens.opsLive,
  FranchiseTab.opsCaptainOrders: Screens.opsCaptainOrders,
  FranchiseTab.opsKitchen: Screens.opsKitchen,
  FranchiseTab.opsDineIn: Screens.opsDineIn,
  FranchiseTab.opsReservations: Screens.opsReservations,
  FranchiseTab.opsPosBilling: Screens.opsBilling,
  FranchiseTab.opsDelivery: Screens.opsDelivery,
  FranchiseTab.opsOnlineOrders: Screens.opsOnlineOrders,
  FranchiseTab.opsQrOrdering: Screens.opsQrOrdering,
  FranchiseTab.staffRoles: Screens.staffRoles,
  FranchiseTab.staffAttendance: Screens.staffAttendance,
  FranchiseTab.staffTraining: Screens.staffTraining,
  FranchiseTab.taskManager: Screens.taskManager,
  FranchiseTab.crmCustomers: Screens.customers,
  FranchiseTab.crmGroups: Screens.customers,
  FranchiseTab.crmFeedback: Screens.customers,
  FranchiseTab.crmLoyalty: Screens.customers,
  FranchiseTab.marketingCampaigns: Screens.marketing,
  FranchiseTab.marketingPromotions: Screens.marketing,
  FranchiseTab.marketingNotifications: Screens.marketing,
  FranchiseTab.financePayments: Screens.finance,
  FranchiseTab.financeTransactions: Screens.finance,
  FranchiseTab.financeExpenses: Screens.finance,
  FranchiseTab.financeSettlements: Screens.finance,
  FranchiseTab.financeDocuments: Screens.finance,
  FranchiseTab.integrationsZomato: Screens.integrations,
  FranchiseTab.integrationsSwiggy: Screens.integrations,
  FranchiseTab.integrationsPayment: Screens.integrations,
  FranchiseTab.integrationsOther: Screens.integrations,
  FranchiseTab.settingsRestaurant: Screens.settings,
  FranchiseTab.settingsPos: Screens.settings,
  FranchiseTab.settingsOrder: Screens.settings,
  FranchiseTab.settingsNotifications: Screens.settings,
  FranchiseTab.settingsAccount: Screens.settings,
  FranchiseTab.settingsUpdates: Screens.settings,
  FranchiseTab.reports: Screens.reports,
  FranchiseTab.pageBuilder: Screens.pageBuilder,
  FranchiseTab.support: Screens.support,
};

/// Whether [allowed] (null = everything) lets the account open [tab].
bool franchiseTabAllowed(FranchiseTab tab, Set<String>? allowed) {
  if (allowed == null) return true;
  if (tab == FranchiseTab.staff) {
    return allowed.any((s) => s.startsWith('staff.'));
  }
  final id = franchiseTabScreens[tab];
  return id != null && allowed.contains(id);
}

/// The first tab [allowed] opens, for landing after sign-in.
FranchiseTab firstAllowedFranchiseTab(Set<String>? allowed) =>
    FranchiseTab.values.firstWhere((t) => franchiseTabAllowed(t, allowed),
        orElse: () => FranchiseTab.dashboard);

/// Shortcuts in the top bar's Quick Actions menu — each only opens a real
/// tab, and only when the signed-in role may open it.
const franchiseQuickActions = <(String, IconData, FranchiseTab)>[
  ('New order (POS Billing)', Icons.point_of_sale, FranchiseTab.opsPosBilling),
  (
    'Kitchen (KOT) display',
    Icons.soup_kitchen_outlined,
    FranchiseTab.opsKitchen
  ),
  ('Live operations', Icons.bolt_outlined, FranchiseTab.opsLiveOperations),
  (
    'Stock & raw materials',
    Icons.inventory_2_outlined,
    FranchiseTab.masterInventory
  ),
  ('Staff & users', Icons.badge_outlined, FranchiseTab.staff),
];

class FranchiseVendorShell extends StatefulWidget {
  final FranchiseTab activeTab;
  final ValueChanged<FranchiseTab> onTabChanged;
  final ValueChanged<String>? onSelectBranch;
  final String? selectedBranchId;
  final Widget content;
  final String? userEmail;
  final VoidCallback? onSignOut;

  /// Runs a backend sync now; returns a one-line result for the snackbar.
  /// Null when no backend is configured (local-only mode).
  final Future<String> Function()? onSync;

  /// Current sync state ("Synced", "Offline · 3 waiting", …).
  final String? syncLabel;

  /// Screens the signed-in account may open (null = all). Everything else
  /// is left out of the sidebar.
  final Set<String>? allowedScreens;

  /// The restaurant's name for the sidebar header.
  final String? organizationName;

  /// The signed-in person's name and role for the top-bar profile. Without
  /// a name the profile shows [userEmail].
  final String? userName;
  final String? roleName;

  const FranchiseVendorShell({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.content,
    this.onSelectBranch,
    this.selectedBranchId,
    this.userEmail,
    this.onSignOut,
    this.onSync,
    this.syncLabel,
    this.allowedScreens,
    this.organizationName,
    this.userName,
    this.roleName,
  });

  @override
  State<FranchiseVendorShell> createState() => _FranchiseVendorShellState();
}

class _FranchiseVendorShellState extends State<FranchiseVendorShell> {
  bool _isFranchiseExpanded = false;
  bool _isMasterExpanded = false;
  bool _isOperationsExpanded = false;
  bool _isStaffExpanded = false;
  bool _isCrmExpanded = false;
  bool _isMarketingExpanded = false;
  bool _isFinanceExpanded = false;
  bool _isIntegrationsExpanded = false;
  bool _isSettingsExpanded = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _autoExpandActiveGroup();
  }

  @override
  void didUpdateWidget(FranchiseVendorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab) {
      _autoExpandActiveGroup();
    }
  }

  void _autoExpandActiveGroup() {
    final tabName = widget.activeTab.name;
    if (tabName.startsWith('master')) {
      _isMasterExpanded = true;
    } else if (tabName.startsWith('ops')) {
      _isOperationsExpanded = true;
    } else if (tabName.startsWith('staff')) {
      _isStaffExpanded = true;
    } else if (tabName.startsWith('crm')) {
      _isCrmExpanded = true;
    } else if (tabName.startsWith('marketing')) {
      _isMarketingExpanded = true;
    } else if (tabName.startsWith('finance')) {
      _isFinanceExpanded = true;
    } else if (tabName.startsWith('integrations')) {
      _isIntegrationsExpanded = true;
    } else if (tabName.startsWith('settings')) {
      _isSettingsExpanded = true;
    } else if (franchiseTabScreens[widget.activeTab]
            ?.startsWith('franchise.') ??
        false) {
      _isFranchiseExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // Left Sidebar (Franchise / Chain Vendor Panel Sidebar)
          _buildFranchiseSidebar(context, cardColor, isDark),

          // Main Workspace Body
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(context, cardColor, isDark),
                Expanded(child: widget.content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFranchiseSidebar(
      BuildContext context, Color cardColor, bool isDark) {
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Vendor Panel Logo Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ViniiColors.brandGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'V',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((widget.organizationName ?? '').trim().isNotEmpty)
                        Text(
                          widget.organizationName!.trim(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: ViniiColors.emeraldText,
                          ),
                        ),
                      Text(
                        'VENDOR PANEL',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ..._buildNavChildren(context, isDark),
              ],
            ),
          ),
          const Divider(height: 1),
          if (widget.onSignOut != null)
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.logout, size: 18, color: Colors.red),
                title: const Text('Sign Out',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
                onTap: widget.onSignOut,
              ),
            ),
        ],
      ),
    );
  }

  bool _can(FranchiseTab tab) =>
      franchiseTabAllowed(tab, widget.allowedScreens);

  List<Widget> _buildNavChildren(BuildContext context, bool isDark) {
    List<Widget> group(
      String title,
      IconData icon,
      bool expanded,
      VoidCallback toggle,
      List<(String, FranchiseTab)> entries,
    ) {
      final visible = [
        for (final e in entries)
          if (_can(e.$2)) e
      ];
      if (visible.isEmpty) return const [];
      return [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(6),
            hoverColor: Colors.black.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_right,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      for (final (label, tab) in visible)
                        _buildSubSidebarItem(
                          title: label,
                          isSelected: widget.activeTab == tab,
                          onTap: () => widget.onTabChanged(tab),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
      ];
    }

    // A top-level entry without sub-items. A section not designed yet is
    // tagged "Soon" and opens its placeholder page.
    List<Widget> entry(FranchiseTab tab, String title, IconData icon) {
      if (!_can(tab)) return const [];
      final soon = comingSoonSections.containsKey(franchiseTabScreens[tab]);
      final selected = widget.activeTab == tab;
      final color = selected
          ? ViniiColors.emeraldText
          : (isDark ? Colors.white : Colors.black87);
      return [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('sidebar-${tab.name}'),
            onTap: () => widget.onTabChanged(tab),
            borderRadius: BorderRadius.circular(6),
            hoverColor: Colors.black.withValues(alpha: 0.04),
            child: Container(
              color: selected ? ViniiColors.successPillBg : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color: selected
                          ? ViniiColors.emeraldText
                          : Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color),
                    ),
                  ),
                  if (soon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Soon',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700])),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ];
    }

    return [
      if (_can(FranchiseTab.dashboard)) ...[
        _buildSectionHeader('OVERVIEW'),
        _buildSidebarItem(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          isSelected: widget.activeTab == FranchiseTab.dashboard,
          onTap: () => widget.onTabChanged(FranchiseTab.dashboard),
        ),
        const SizedBox(height: 12),
      ],
      _buildSectionHeader('MANAGE'),
      ...group(
        'Franchise / Chain',
        Icons.hub_outlined,
        _isFranchiseExpanded,
        () => setState(() => _isFranchiseExpanded = !_isFranchiseExpanded),
        const [
          ('Command Center', FranchiseTab.commandCenter),
          ('Branch Performance', FranchiseTab.branchPerformance),
          ('Branch Detail', FranchiseTab.branchDetail),
          ('Inventory & Supply', FranchiseTab.inventorySupply),
          ('Exceptions', FranchiseTab.exceptions),
          ('Action Centre', FranchiseTab.exceptions),
          ('Targets & Benchmarking', FranchiseTab.targetsBenchmarking),
          ('Compliance & Audit', FranchiseTab.complianceAudit),
        ],
      ),
      ...group(
        'Master',
        Icons.inventory_2_outlined,
        _isMasterExpanded,
        () => setState(() => _isMasterExpanded = !_isMasterExpanded),
        const [
          ('Menu Items', FranchiseTab.masterMenuItems),
          ('Products (Online)', FranchiseTab.masterProductsOnline),
          ('Media', FranchiseTab.masterMedia),
          ('Offers', FranchiseTab.masterOffers),
          ('Inventory', FranchiseTab.masterInventory),
          ('Recipes', FranchiseTab.masterRecipes),
          ('Suppliers', FranchiseTab.masterSuppliers),
          ('Purchase Orders', FranchiseTab.masterPurchaseOrders),
        ],
      ),
      ...group(
        'Operations',
        Icons.shopping_cart_outlined,
        _isOperationsExpanded,
        () => setState(() => _isOperationsExpanded = !_isOperationsExpanded),
        const [
          ('Live Operations', FranchiseTab.opsLiveOperations),
          ('Captain Orders', FranchiseTab.opsCaptainOrders),
          ('KOT / Kitchen', FranchiseTab.opsKitchen),
          ('Dine In', FranchiseTab.opsDineIn),
          ('Reservations', FranchiseTab.opsReservations),
          ('POS Billing', FranchiseTab.opsPosBilling),
          ('Delivery', FranchiseTab.opsDelivery),
          ('Online Orders', FranchiseTab.opsOnlineOrders),
          ('QR Ordering', FranchiseTab.opsQrOrdering),
        ],
      ),
      // The rest in the design's order (Figma "Restaurant Vendor Panel").
      ...entry(
          FranchiseTab.taskManager, 'Task Manager', Icons.assignment_outlined),
      ...entry(FranchiseTab.reports, 'Reports', Icons.bar_chart_outlined),
      ...entry(FranchiseTab.pageBuilder, 'Page Builder', Icons.web_outlined),
      ...group(
        'Customers & CRM',
        Icons.people_outline,
        _isCrmExpanded,
        () => setState(() => _isCrmExpanded = !_isCrmExpanded),
        const [
          ('Customers', FranchiseTab.crmCustomers),
          ('Customer Groups', FranchiseTab.crmGroups),
          ('Feedback', FranchiseTab.crmFeedback),
          ('Loyalty', FranchiseTab.crmLoyalty),
        ],
      ),
      ...group(
        'Marketing',
        Icons.campaign_outlined,
        _isMarketingExpanded,
        () => setState(() => _isMarketingExpanded = !_isMarketingExpanded),
        const [
          ('Campaigns', FranchiseTab.marketingCampaigns),
          ('Promotions', FranchiseTab.marketingPromotions),
          ('Notifications', FranchiseTab.marketingNotifications),
        ],
      ),
      ...group(
        'Finance',
        Icons.currency_rupee,
        _isFinanceExpanded,
        () => setState(() => _isFinanceExpanded = !_isFinanceExpanded),
        const [
          ('Payments', FranchiseTab.financePayments),
          ('Transactions', FranchiseTab.financeTransactions),
          ('Expenses', FranchiseTab.financeExpenses),
          ('Settlements', FranchiseTab.financeSettlements),
          ('Documents', FranchiseTab.financeDocuments),
        ],
      ),
      ...group(
        'Staff & Users',
        Icons.badge_outlined,
        _isStaffExpanded,
        () => setState(() => _isStaffExpanded = !_isStaffExpanded),
        const [
          ('Staff', FranchiseTab.staff),
          ('Roles & Permissions', FranchiseTab.staffRoles),
          ('Attendance', FranchiseTab.staffAttendance),
          ('Training', FranchiseTab.staffTraining),
        ],
      ),
      ...group(
        'Integrations',
        Icons.power_outlined,
        _isIntegrationsExpanded,
        () =>
            setState(() => _isIntegrationsExpanded = !_isIntegrationsExpanded),
        const [
          ('Zomato', FranchiseTab.integrationsZomato),
          ('Swiggy', FranchiseTab.integrationsSwiggy),
          ('Payment', FranchiseTab.integrationsPayment),
          ('Other Integrations', FranchiseTab.integrationsOther),
        ],
      ),
      ...entry(FranchiseTab.support, 'Support', Icons.headset_mic_outlined),
      ...group(
        'Settings',
        Icons.settings_outlined,
        _isSettingsExpanded,
        () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
        const [
          ('Restaurant Settings', FranchiseTab.settingsRestaurant),
          ('POS Settings', FranchiseTab.settingsPos),
          ('Order Settings', FranchiseTab.settingsOrder),
          ('Notification Settings', FranchiseTab.settingsNotifications),
          ('Account Settings', FranchiseTab.settingsAccount),
          ('System Updates', FranchiseTab.settingsUpdates),
        ],
      ),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: isSelected
              ? ViniiColors.successPillBg.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color:
                  isSelected ? ViniiColors.successPillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      isSelected ? ViniiColors.emeraldText : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? ViniiColors.emeraldText : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubSidebarItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: isSelected
              ? ViniiColors.successPillBg.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected ? ViniiColors.successPillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected ? ViniiColors.emeraldText : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? ViniiColors.emeraldText
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    final onSync = widget.onSync;
    if (onSync == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Working locally — no Proviyaa server is configured (PROVIYAA_API_BASE_URL).')));
      return;
    }
    setState(() => _syncing = true);
    messenger.showSnackBar(const SnackBar(
        content: Text('Syncing with Proviyaa…'),
        duration: Duration(seconds: 1)));
    try {
      final result = await onSync();
      messenger.showSnackBar(SnackBar(content: Text(result)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Sync failed: ${friendlyErrorText(e)}'),
          backgroundColor: ViniiColors.redSolid));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// "RK" from "Rahul Khanna", "A" from "admin@x.com".
  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  Widget _buildProfile() {
    final name = (widget.userName?.trim().isNotEmpty ?? false)
        ? widget.userName!.trim()
        : (widget.userEmail?.trim().isNotEmpty ?? false)
            ? widget.userEmail!.trim()
            : 'Signed in';
    final role = widget.roleName?.trim() ?? '';
    return Row(
      key: const Key('shell-profile'),
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: ViniiColors.successPillBg,
          child: Text(_initials(name),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ViniiColors.emeraldText)),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (role.isNotEmpty)
              Text(role,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildTopHeader(BuildContext context, Color cardColor, bool isDark) {
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final quickActions = [
      for (final a in franchiseQuickActions)
        if (_can(a.$3)) a
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.storefront, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'RESTAURANT PANEL',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            if (quickActions.isNotEmpty) ...[
              PopupMenuButton<FranchiseTab>(
                key: const Key('shell-quick-actions'),
                tooltip: 'Quick Actions',
                onSelected: widget.onTabChanged,
                itemBuilder: (_) => [
                  for (final (label, icon, tab) in quickActions)
                    PopupMenuItem(
                      value: tab,
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: ViniiColors.emeraldText),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.flash_on, size: 14),
                      SizedBox(width: 6),
                      Text('Quick Actions', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (widget.syncLabel != null) ...[
              Text(widget.syncLabel!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(width: 8),
            ],
            ElevatedButton(
              onPressed: _syncing ? null : _sync,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              child: Text(_syncing ? 'Syncing…' : 'Sync'),
            ),
            const SizedBox(width: 10),
            if (_can(FranchiseTab.exceptions)) ...[
              InkWell(
                onTap: () => widget.onTabChanged(FranchiseTab.exceptions),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE4E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDCA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.report_problem_outlined,
                          size: 14, color: Color(0xFFD92D20)),
                      SizedBox(width: 6),
                      Text(
                        'Action Center',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            _buildProfile(),
          ],
        ),
      ),
    );
  }
}
