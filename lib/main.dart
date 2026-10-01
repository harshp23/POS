import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'application/cloud_sync_service.dart';
import 'application/device_binding.dart';
import 'application/kitchen_service.dart';
import 'config/app_config.dart';
import 'data/api/api_client.dart';
import 'data/api/api_online_orders_store.dart';
import 'data/api/session_vault.dart';
import 'data/app_database.dart';
import 'data/drift_all_orders_store.dart';
import 'data/drift_inventory_store.dart';
import 'data/drift_kitchen_store.dart';
import 'data/drift_local_store.dart';
import 'data/drift_master_store.dart';
import 'data/drift_menu_store.dart';
import 'data/drift_table_store.dart';
import 'data/local_dine_in_catalog.dart';
import 'data/master_seeder.dart';
import 'data/drift_operations_store.dart';
import 'data/operations_seeder.dart';
import 'data/online_orders_store.dart';
import 'data/franchise_organization_store.dart';
import 'data/franchise_repository.dart';
import 'data/staff_repository.dart';
import 'data/staff_repository_memory.dart';
import 'data/sync/sync_contract.dart';
import 'domain/access.dart';
import 'domain/operations.dart' show OpsChannel;
import 'domain/vendor_account.dart';
import 'data/spicy_bistro_seeder.dart';
import 'data/tab_storage.dart';
import 'domain/restaurant_table.dart';
import 'presentation/all_orders_screen.dart';
import 'presentation/business/business_ui.dart';
import 'presentation/business/crm_screen.dart';
import 'presentation/business/finance_screen.dart';
import 'presentation/business/integrations_screen.dart';
import 'presentation/business/marketing_screen.dart';
import 'presentation/business/settings_screen.dart';
import 'presentation/business/tasks_screen.dart';
import 'presentation/change_password_dialog.dart';
import 'presentation/coming_soon_screen.dart';
import 'presentation/delivery_screen.dart';
import 'presentation/dine_in_screen.dart';
import 'presentation/kitchen_display_screen.dart';
import 'presentation/menu_management_screen.dart';
import 'presentation/online_orders_screen.dart';
import 'presentation/pos_order_screen.dart';
import 'presentation/pos_shell.dart';
import 'presentation/pos_sidebar.dart';
import 'presentation/tables_screen.dart';
import 'presentation/takeaway_screen.dart';
import 'presentation/vinii_theme.dart';
import 'presentation/login_screen.dart';
import 'presentation/franchise/branch_detail_screen.dart';
import 'presentation/franchise/branch_performance_screen.dart';
import 'presentation/franchise/compliance_audit_screen.dart';
import 'presentation/franchise/franchise_command_center_screen.dart';
import 'presentation/franchise/franchise_exceptions_screen.dart';
import 'presentation/franchise/franchise_inventory_screen.dart';
import 'presentation/franchise/franchise_vendor_shell.dart';
import 'presentation/franchise/restaurant_dashboard_screen.dart';
import 'presentation/franchise/targets_benchmarking_screen.dart';
import 'presentation/master/master_inventory_screen.dart';
import 'presentation/master/master_media_screen.dart';
import 'presentation/master/master_menu_items_screen.dart';
import 'presentation/master/master_offers_screen.dart';
import 'presentation/master/master_products_online_screen.dart';
import 'presentation/master/master_purchase_orders_screen.dart';
import 'presentation/master/master_recipes_screen.dart';
import 'presentation/master/master_suppliers_screen.dart';
import 'presentation/operations/ops_captain_orders_screen.dart';
import 'presentation/operations/ops_delivery_screen.dart';
import 'presentation/operations/ops_dine_in_screen.dart';
import 'presentation/operations/ops_kitchen_screen.dart';
import 'presentation/operations/ops_live_operations_screen.dart';
import 'presentation/operations/ops_pos_billing_screen.dart';
import 'presentation/operations/ops_qr_ordering_screen.dart';
import 'presentation/operations/ops_reservations_screen.dart';
import 'presentation/staff/staff_management_screen.dart';

/// The app never talks to Supabase: with PROVIYAA_API_BASE_URL set it signs
/// in and syncs through the Proviyaa backend (backend/); without it, it runs
/// fully local with the demo sign-in.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviyaaPosApp(config: AppConfig.fromDartDefines()));
}

/// One enrolled device serves one location for V1 (D02: one primary POS
/// per location; multi-terminal offline coordination is deferred). This
/// placeholder id stands in for the real value device bootstrap (Phase
/// B) will supply.
const _demoLocationId = 'location-demo';

/// Stand-in for the signed-in staff session shown in the sidebar footer
/// until real auth (lib/application/auth_service.dart) is wired into the
/// UI — see the "ideal first screen" discussion: no login screen exists
/// in any of the 36 v1/ references, so nothing here is skipping a
/// designed screen.
const _demoStaffName = 'Rahul Sharma';
const _demoBranchName = 'Latur Main Branch';

class ProviyaaPosApp extends StatefulWidget {
  const ProviyaaPosApp({
    super.key,
    required this.config,
    this.database,
    this.onlineOrdersStore,
    this.sessionVault,
    this.apiClient,
  });
  final AppConfig config;

  /// Where the backend login is kept between runs. Defaults to the OS
  /// keystore in the real app; tests pass a [MemorySessionVault] (or none).
  final SessionVault? sessionVault;

  /// Overrides the backend client built from [config] — for tests.
  final ProviyaaApiClient? apiClient;

  /// Overrides the real on-device database — for tests only. Constructing
  /// the real `AppDatabase.defaults()` (native file-backed, via
  /// drift_flutter) inside a `flutter test` widget test leaves a
  /// background timer pending past the pumped frame, which the test
  /// binding treats as a leak. Pass an in-memory `AppDatabase` instead.
  final AppDatabase? database;
  final OnlineOrdersStore? onlineOrdersStore;

  @override
  State<ProviyaaPosApp> createState() => _ProviyaaPosAppState();
}

class _ProviyaaPosAppState extends State<ProviyaaPosApp> {
  // Lazily created on first build, once per app process — this is the
  // real on-device Drift/SQLite database (R17), not a mock, unless a
  // test supplied its own via widget.database. It auto-creates its file
  // on first launch; see lib/data/app_database.dart.
  late final AppDatabase _db = widget.database ?? AppDatabase.defaults();
  late final Future<void> _schemaReady;
  late final _localStore = DriftLocalStore(_db);
  late final _kitchenService = KitchenService(DriftKitchenStore(_db));
  late final _tableStore = DriftTableStore(_db);
  late final _allOrdersStore = DriftAllOrdersStore(_db);
  late final _menuStore = DriftMenuStore(_db);
  // Master module: one common inventory store + the master catalogue.
  late final _inventoryStore = DriftInventoryStore(_db);
  late final _masterStore = DriftMasterStore(_db);
  // Operations: works on the same tables/orders/KOT/payment rows as POS.
  late final _opsStore = DriftOperationsStore(_db);

  /// Order to open when jumping to POS Billing (e.g. from Dine In).
  String? _opsFocusOrderId;
  // Backend (null = local-only mode). Created once; the session lives in it.
  late final ProviyaaApiClient? _api = (widget.apiClient ??
      (widget.config.usesBackend
          ? ProviyaaApiClient(baseUrl: widget.config.apiBaseUrl)
          : null))
    ?..onSessionChanged = _onSessionChanged;
  late final SessionVault? _vault = widget.sessionVault ??
      (widget.config.usesBackend && widget.database == null
          ? SecureSessionVault()
          : null);
  SavedLogin? _saved;
  bool _restoring = false;

  /// Shown on the sign-in screen when a saved login could not be used.
  String? _offlineMessage;

  /// Set when the app has run offline past the 24-hour grant: protected
  /// work stops until the server confirms the login again.
  bool _offlineLocked = false;
  Timer? _grantTimer;
  final _navigatorKey = GlobalKey<NavigatorState>();
  VendorAccount? _account;
  CloudSyncService? _sync;
  StreamSubscription<SyncStatus>? _syncSub;
  SyncStatus? _syncStatus;
  FranchiseRepository? _franchiseRepo;
  FranchiseSnapshot? _franchise;

  // Staff & Users: the backend when signed in to one, else on-device demo
  // data (local mode).
  StaffRepository? _staffRepo;
  late final StaffRepository _demoStaff = InMemoryStaffRepository();
  StaffRepository get _staff => _staffRepo ?? _demoStaff;

  /// The restaurant's branches (for branch pickers and names) and the
  /// signed-in person's name (recorded on what they create).
  List<BranchLocation> get _branches => _account?.locations ?? const [];
  String get _userName => _account == null
      ? _demoStaffName
      : (_account!.fullName.isNotEmpty ? _account!.fullName : _account!.email);

  /// Tab Staff Management opens on; bumping [_staffNav] reopens it there.
  StaffTab _staffOpenTab = StaffTab.dashboard;
  int _staffNav = 0;

  /// Screens the signed-in account may open; null = everything (local
  /// demo mode, where there is no server-side role).
  Set<String>? get _screens => _account?.screens;
  bool _canOpen(String screen) => _screens?.contains(screen) ?? true;

  // Created on first use (after sign-in): polls the backend inbox.
  late final OnlineOrdersStore _onlineOrdersStore = widget.onlineOrdersStore ??
      (widget.database == null && _api != null
          ? ApiOnlineOrdersStore(_api!)
          : InMemoryOnlineOrdersStore());

  PosModule _selected = PosModule.dineIn;
  FranchiseTab _activeFranchiseTab = FranchiseTab.dashboard;
  String _selectedBranch = '';
  UserRole? _authenticatedRole;
  String _authenticatedEmail = 'admin@spicybistro.com';

  @override
  void initState() {
    super.initState();
    // On the web an older app tab may have opened the shared database
    // without this version's migration: bring the schema up to date before
    // anything reads or writes it.
    _schemaReady = _db
        .ensureSchema()
        .catchError((Object e) => debugPrint('Schema check failed: $e'));
    // First launch only: fills the Master tables from the approved-design
    // reference data. Screens watch the tables, so they update when done.
    // Skipped for tests that inject their own database.
    // Demo data only in local demo mode: with a backend, a restaurant's
    // data comes from its server (seeded rows would be synced into it).
    if (widget.database == null && !widget.config.usesBackend) {
      unawaited(_schemaReady.then((_) {
        MasterSeeder.seedIfNeeded(_db)
            .catchError((Object e) => debugPrint('Master seed failed: $e'));
        OperationsSeeder.seedIfNeeded(_db)
            .catchError((Object e) => debugPrint('Operations seed failed: $e'));
        SpicyBistroSeeder.seedMasterAndFranchise(
                _db, MultiTenantFranchiseStore())
            .catchError(
                (Object e) => debugPrint('SpicyBistro seed failed: $e'));
      }));
    }
    if (_api != null && _vault != null) {
      _restoring = true;
      unawaited(_restoreSession());
    }
    final savedTab = getPersistedTab();
    if (savedTab != null) {
      final match =
          PosModule.values.where((m) => m.name == savedTab).firstOrNull;
      if (match != null && match != PosModule.pos) {
        _selected = match;
      }
    }
  }

  /// Stable id of this device for sync change ids.
  Future<String> _deviceId() async {
    final row = await (_db.select(_db.appMetadata)
          ..where((m) => m.key.equals('device_id')))
        .getSingleOrNull();
    if (row != null) return row.value;
    final id = const Uuid().v4();
    await _db
        .into(_db.appMetadata)
        .insert(AppMetadataCompanion.insert(key: 'device_id', value: id));
    return id;
  }

  /// Sign-in with a master-admin account. Restaurant accounts land in their
  /// own restaurant; a platform admin picks which restaurant to open.
  Future<UserRole> _backendSignIn(String email, String password) async {
    final api = _api!;
    api.organizationId = null;
    api.locationId = null;
    var me = await api.login(email, password);
    if (!VendorAccount.hasOrganization(me)) {
      try {
        me = await _chooseOrganization(api, me);
      } catch (_) {
        await api.logout();
        rethrow;
      }
    }
    return _activate(me);
  }

  Future<Map<String, dynamic>> _chooseOrganization(
      ProviyaaApiClient api, Map<String, dynamic> me) async {
    if (!VendorAccount.isPlatformAdmin(me)) {
      throw const ApiException(403, 'no_restaurant',
          'This account is not linked to a restaurant. Ask your Proviyaa admin to link it in the master panel.');
    }
    final orgs = VendorAccount.organizationsOf(me)
        .where((o) => (o.status ?? 'Active').toLowerCase() == 'active')
        .toList();
    if (orgs.isEmpty) {
      throw const ApiException(404, 'no_restaurants',
          'No active restaurants yet. Create one in the Proviyaa master panel first.');
    }
    OrganizationRef? chosen = orgs.length == 1 ? orgs.single : null;
    final context = _navigatorKey.currentContext;
    if (chosen == null && context != null && context.mounted) {
      chosen = await showDialog<OrganizationRef>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Open which restaurant?'),
          children: [
            for (final o in orgs)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(o),
                child: Text(o.name),
              ),
          ],
        ),
      );
    }
    if (chosen == null) {
      throw const ApiException(
          400, 'cancelled', 'Pick a restaurant to continue.');
    }
    api.organizationId = chosen.id;
    return api.me();
  }

  /// Opens the restaurant `me` describes and starts syncing this device
  /// with its branch.
  Future<UserRole> _activate(Map<String, dynamic> me,
      {DateTime? verifiedAt}) async {
    await _schemaReady;
    final api = _api!;
    var account = VendorAccount.fromMe(me);
    // A device stays with the branch it was set up for whenever the
    // account may act for it: adding a branch in master must not move
    // this till to another outlet.
    final bound = await DeviceBinding(_db).current();
    if (bound.organizationId == account.organizationId &&
        bound.locationId != null &&
        bound.locationId != account.location?.id) {
      final keep = account.locations
          .where((l) => l.id == bound.locationId)
          .firstOrNull;
      if (keep != null) account = account.actingFor(keep);
    }
    api.locationId = account.location?.id;
    // Corrections (cancel, void, discount, verification) name who made them.
    _opsStore.actorName =
        account.fullName.isNotEmpty ? account.fullName : account.email;
    if (account.platformAdmin) api.organizationId = account.organizationId;
    await _bindDevice(account);
    final session = api.session;
    if (session != null) {
      _saved = SavedLogin(
          session: session,
          organizationId: api.organizationId,
          locationId: api.locationId,
          me: me,
          verifiedAt: verifiedAt ?? DateTime.now());
      await _vault?.write(_saved);
    }
    Set<SyncModule> modules(String action) => {
          for (final m in SyncModule.values)
            if (account.can(m.name, action)) m
        };
    final sync = CloudSyncService(
        db: _db,
        api: api,
        deviceId: await _deviceId(),
        pushModules: modules('write'),
        pullModules: modules('read'));
    await _syncSub?.cancel();
    _syncSub = sync.watchStatus().listen((s) {
      if (mounted) setState(() => _syncStatus = s);
    });
    setState(() {
      _account = account;
      _sync = sync;
      _franchiseRepo = ApiFranchiseRepository(api);
      _staffRepo = ApiStaffRepository(api);
      // Land on the first screen the role opens.
      _activeFranchiseTab = firstAllowedFranchiseTab(account.screens);
      final modules = _posModules;
      if (modules.isNotEmpty && !modules.contains(_selected)) {
        _selected = modules.first;
      }
    });
    if (account.mustChangePassword) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_promptPasswordChange()));
    }
    sync.start();
    _grantTimer?.cancel();
    _grantTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkOfflineGrant());
    if (account.can('franchise', 'read')) unawaited(_loadFranchise());
    return account.isVendorPanel ? UserRole.superAdmin : UserRole.posOperator;
  }

  /// Reopens the last login. Offline, the saved `me` is used so the POS
  /// still starts; an expired or revoked login falls back to the sign-in
  /// screen.
  Future<void> _restoreSession() async {
    final api = _api!;
    await _schemaReady;
    try {
      final saved = await _vault!.read();
      if (saved == null) return;
      _saved = saved;
      Map<String, dynamic> me;
      try {
        me = await api.resume(saved.session,
            organizationId: saved.organizationId, locationId: saved.locationId);
      } on ApiException catch (e) {
        if (!e.isNetwork || saved.me == null) rethrow;
        if (saved.offlineExpired(DateTime.now())) {
          _offlineMessage =
              'You have been offline for more than 24 hours. Connect to the internet and sign in again.';
          rethrow;
        }
        me = saved.me!;
        final role = await _activate(me, verifiedAt: saved.verifiedAt);
        if (mounted) {
          setState(() {
            _authenticatedRole = role;
            _authenticatedEmail = _account?.email ?? _authenticatedEmail;
          });
        }
        return;
      }
      final role = await _activate(me);
      if (mounted) {
        setState(() {
          _authenticatedRole = role;
          _authenticatedEmail = _account?.email ?? _authenticatedEmail;
        });
      }
    } catch (e) {
      debugPrint('Saved sign-in not restored: $e');
      _saved = null;
      api.session = null;
      await _vault?.write(null);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// Every minute: record the last server contact in the saved login, and
  /// lock the app once it has been offline past the grant.
  void _checkOfflineGrant() {
    final saved = _saved;
    final api = _api;
    if (saved == null || api == null || _account == null) return;
    final contact = api.lastServerContact;
    if (contact != null &&
        (saved.verifiedAt == null || contact.isAfter(saved.verifiedAt!))) {
      _saved = saved.copyWith(verifiedAt: contact);
      unawaited(_vault?.write(_saved));
    }
    final expired = _saved!.offlineExpired(DateTime.now());
    if (expired != _offlineLocked && mounted) {
      setState(() => _offlineLocked = expired);
    }
  }

  Future<void> _retryConnection() async {
    try {
      await _api!.me();
      _checkOfflineGrant();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(_navigatorKey.currentContext!)?.showSnackBar(
          SnackBar(content: Text('Still offline: ${e.message}')));
    }
  }

  /// Keeps the saved login current when the backend refreshes the token.
  void _onSessionChanged(ApiSession? session) {
    if (session == null) {
      _saved = null;
      unawaited(_vault?.write(null));
    } else if (_saved != null) {
      _saved = _saved!.copyWith(session: session);
      unawaited(_vault?.write(_saved));
    }
  }

  /// Keeps this device's local data for one restaurant branch: the first
  /// sign-in binds it; another restaurant or branch wipes it first — unless
  /// unsent changes of the previous one would be lost.
  Future<void> _bindDevice(VendorAccount account) async {
    final binding = DeviceBinding(_db);
    final current = await binding.current();
    final location = account.location?.id;
    final label = [account.organizationName, account.location?.name]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    if (binding.matches(current, account.organizationId, location)) return;
    if (current.organizationId != null) {
      final pending = await CloudSyncService(
        db: _db,
        api: _api!,
        deviceId: await _deviceId(),
        pushModules: SyncModule.values.toSet(),
        pullModules: const {},
      ).pendingChanges();
      if (pending > 0) {
        await _api!.logout();
        throw ApiException(409, 'device_bound',
            'This device still has $pending unsent change(s) for ${current.label ?? 'another restaurant'}. Sign in to it and sync first, then switch.');
      }
    }
    // Rows from demo mode or another restaurant never reach this one.
    if (await binding.hasLocalData()) await binding.wipe();
    await binding.bind(account.organizationId, location, label);
  }

  /// An admin reset this login's password: set a new one before working.
  Future<void> _promptPasswordChange() async {
    final context = _navigatorKey.currentContext;
    final api = _api;
    if (context == null || api == null || !context.mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(api: api),
    );
    if (changed != true) await _signOut();
  }

  /// What the signed-in role may do with orders and money (mirrors
  /// backend/src/permissions.ts; the server enforces the same rules).
  /// Local demo sign-ins: the vendor panel acts as the owner, the POS as a
  /// cashier.
  bool get _canVerifyPayments => _account == null
      ? _authenticatedRole == UserRole.superAdmin
      : _account!.platformAdmin || PosRoles.canVerifyPayments(_account!.role);
  bool get _canTakePayments => _account == null
      ? true
      : _account!.platformAdmin || PosRoles.canTakePayments(_account!.role);
  bool get _canPlaceOrders => _account == null
      ? true
      : _account!.platformAdmin || PosRoles.canPlaceOrders(_account!.role);

  /// POS sidebar modules the role opens, in sidebar order.
  List<PosModule> get _posModules => [
        for (final m in PosModule.values)
          if (_canOpen(_posModuleScreens[m]!)) m
      ];

  static const _posModuleScreens = {
    PosModule.pos: Screens.posBilling,
    PosModule.tables: Screens.posTables,
    PosModule.allOrders: Screens.posAllOrders,
    PosModule.dineIn: Screens.posDineIn,
    PosModule.takeaway: Screens.posTakeaway,
    PosModule.delivery: Screens.posDelivery,
    PosModule.online: Screens.posOnline,
    PosModule.menu: Screens.posMenu,
  };

  static const _staffTabFor = {
    FranchiseTab.staff: StaffTab.dashboard,
    FranchiseTab.staffRoles: StaffTab.roles,
    FranchiseTab.staffAttendance: StaffTab.attendance,
    FranchiseTab.staffTraining: StaffTab.training,
  };

  FranchiseTab _sidebarTabFor(StaffTab tab) => switch (tab) {
        StaffTab.roles => FranchiseTab.staffRoles,
        StaffTab.attendance => FranchiseTab.staffAttendance,
        StaffTab.training => FranchiseTab.staffTraining,
        _ => FranchiseTab.staff,
      };

  /// The pages built from the chain data ([_franchise]).
  static const _chainTabs = {
    FranchiseTab.dashboard,
    FranchiseTab.commandCenter,
    FranchiseTab.branchPerformance,
    FranchiseTab.branchDetail,
    FranchiseTab.inventorySupply,
    FranchiseTab.exceptions,
    FranchiseTab.targetsBenchmarking,
    FranchiseTab.complianceAudit,
  };

  Future<void> _loadFranchise() async {
    final repo = _franchiseRepo;
    if (repo == null) return;
    try {
      final data = await repo.load();
      if (mounted) setState(() => _franchise = data);
    } catch (e) {
      debugPrint('Franchise data load failed: $e');
    }
  }

  Future<String> _syncNow() async {
    final sync = _sync;
    if (sync == null) return 'Not signed in to the Proviyaa server.';
    final report = await sync.syncNow();
    await _loadFranchise();
    final status = sync.status;
    if (status.phase == SyncPhase.offline) {
      return 'Offline — changes are saved on this device and will sync when the connection returns.';
    }
    if (status.phase == SyncPhase.error) {
      return 'Sync failed: ${status.message}';
    }
    return 'Synced: ${report.accepted + report.duplicates} sent, ${report.pulled} received'
        '${status.needsReview > 0 ? ', ${status.needsReview} need review' : ''}.';
  }

  Future<void> _signOut() async {
    _grantTimer?.cancel();
    _grantTimer = null;
    _offlineLocked = false;
    await _sync?.stop();
    await _syncSub?.cancel();
    _syncSub = null;
    await _api?.logout();
    _opsStore.actorName = '';
    setState(() {
      _authenticatedRole = null;
      _account = null;
      _sync = null;
      _syncStatus = null;
      _franchise = null;
      _staffRepo = null;
      _activeFranchiseTab = FranchiseTab.dashboard;
      _staffOpenTab = StaffTab.dashboard;
    });
  }

  @override
  void dispose() {
    _grantTimer?.cancel();
    _sync?.dispose();
    _syncSub?.cancel();
    _api?.close();
    if (widget.onlineOrdersStore == null &&
        _onlineOrdersStore is ApiOnlineOrdersStore) {
      (_onlineOrdersStore as ApiOnlineOrdersStore).dispose();
    }
    if (widget.database == null) {
      _db.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Proviyaa POS',
      theme: viniiLightTheme(),
      themeMode: ThemeMode.light,
      home: Builder(builder: (innerContext) {
        if (_restoring) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_authenticatedRole != null && _offlineLocked) {
          return _OfflineExpired(
              onRetry: _retryConnection, onSignOut: _signOut);
        }
        if (_authenticatedRole == null) {
          return LoginScreen(
            notice: _offlineMessage,
            onBackendSignIn: _api == null ? null : _backendSignIn,
            onLoginSuccess: ({required role, required email}) {
              // A backend sign-in already named the actor in _activate; the
              // demo name is only for the offline demo accounts.
              if (_account == null) _opsStore.actorName = _demoStaffName;
              setState(() {
                _authenticatedRole = role;
                _authenticatedEmail = email;
              });
            },
          );
        }

        if (_authenticatedRole == UserRole.superAdmin) {
          return _buildFranchiseVendorShell(innerContext);
        }

        // POS roles: only the modules their role opens. Kitchen staff get
        // the kitchen display and nothing else.
        final modules = _posModules;
        if (modules.isEmpty) {
          return _canOpen(Screens.posKitchen)
              ? _buildKitchenOnly()
              : _NoScreens(onSignOut: _signOut);
        }
        final selected =
            modules.contains(_selected) ? _selected : modules.first;
        return PosShell(
            selected: selected,
            modules: modules,
            onSelect: (m) => _onSelect(innerContext, m),
            onNewOrder: _canOpen(Screens.posBilling)
                ? () => _openOrder(innerContext, null)
                : null,
            onOpenKitchen: _canOpen(Screens.posKitchen)
                ? () => _openKitchen(innerContext)
                : null,
            onSignOut: _signOut,
            staffName: _account?.fullName.isNotEmpty == true
                ? _account!.fullName
                : _demoStaffName,
            branchName: _account?.location?.name ?? _demoBranchName,
            content: _content(innerContext, selected));
      }));

  Widget _buildKitchenOnly() => Scaffold(
        appBar: AppBar(
          title: Text(
              'Kitchen Display · ${_account?.location?.name ?? _demoBranchName}'),
          actions: [
            Center(
                child: Text(_account?.fullName ?? '',
                    style: const TextStyle(fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: _signOut,
            ),
          ],
        ),
        body: KitchenDisplayScreen(
            kitchenService: _kitchenService,
            localStore: _localStore,
            ops: _opsStore),
      );

  Widget _buildFranchiseVendorShell(BuildContext context) {
    return FranchiseVendorShell(
      activeTab: _activeFranchiseTab,
      selectedBranchId: _selectedBranch,
      userEmail: _authenticatedEmail,
      userName: _account?.fullName,
      roleName: _account?.roleName,
      organizationName: _account?.organizationName,
      allowedScreens: _screens,
      onSignOut: _signOut,
      onSync: _api == null ? null : _syncNow,
      syncLabel: _syncStatus?.label,
      onTabChanged: (tab) => setState(() {
        _activeFranchiseTab = tab;
        _opsFocusOrderId = null;
        final staffTab = _staffTabFor[tab];
        if (staffTab != null) {
          _staffOpenTab = staffTab;
          _staffNav++;
        }
        // The chain figures are fetched at sign-in; opening a chain page
        // fetches them again so today's sales are current.
        if (_chainTabs.contains(tab)) unawaited(_loadFranchise());
      }),
      onSelectBranch: (branch) {
        setState(() {
          _selectedBranch = branch;
          _activeFranchiseTab = FranchiseTab.branchDetail;
        });
      },
      content: !franchiseTabAllowed(_activeFranchiseTab, _screens)
          ? const _NoAccess()
          : switch (_activeFranchiseTab) {
              FranchiseTab.staff ||
              FranchiseTab.staffRoles ||
              FranchiseTab.staffAttendance ||
              FranchiseTab.staffTraining =>
                StaffManagementScreen(
                  key: ValueKey('staff-$_staffNav'),
                  repository: _staff,
                  initialTab: _staffOpenTab,
                  allowedScreens: _screens,
                  branches: _branches,
                  defaultBranchId: _account?.location?.id,
                  onTabChanged: (t) =>
                      setState(() => _activeFranchiseTab = _sidebarTabFor(t)),
                ),
              FranchiseTab.dashboard => RestaurantDashboardScreen(
                  ops: _opsStore,
                  inventory: _inventoryStore,
                  // Attendance only for roles that may see the staff
                  // dashboard (the server checks the same screen).
                  staff: _canOpen(Screens.staffDashboard) ? _staff : null,
                  franchise: _franchise,
                  branchName: _account?.location?.name,
                  onNavigateToActionCenter: () {
                    setState(() {
                      _activeFranchiseTab = FranchiseTab.exceptions;
                    });
                  },
                ),
              FranchiseTab.commandCenter => FranchiseCommandCenterScreen(
                  data: _franchise,
                  onInitiateTransfer: _franchiseRepo == null
                      ? null
                      : (rec) async {
                          await _franchiseRepo!.initiateTransfer(rec);
                          unawaited(_syncNow());
                        },
                  onNavigateToInventory: () {
                    setState(() {
                      _activeFranchiseTab = FranchiseTab.inventorySupply;
                    });
                  },
                  onNavigateToExceptions: () => setState(
                      () => _activeFranchiseTab = FranchiseTab.exceptions),
                  onSelectBranch: (branch) {
                    setState(() {
                      _selectedBranch = branch;
                      _activeFranchiseTab = FranchiseTab.branchDetail;
                    });
                  },
                ),
              FranchiseTab.branchPerformance => BranchPerformanceScreen(
                  data: _franchise,
                  onSelectBranch: (branch) {
                    setState(() {
                      _selectedBranch = branch;
                      _activeFranchiseTab = FranchiseTab.branchDetail;
                    });
                  },
                ),
              FranchiseTab.branchDetail => BranchDetailScreen(
                  data: _franchise,
                  branchName: _selectedBranch,
                  onSelectBranch: (b) => setState(() => _selectedBranch = b),
                  onOpenInventory: () => setState(
                      () => _activeFranchiseTab = FranchiseTab.inventorySupply),
                  onOpenExceptions: () => setState(
                      () => _activeFranchiseTab = FranchiseTab.exceptions),
                ),
              FranchiseTab.inventorySupply => FranchiseInventoryScreen(
                  key: ValueKey(_franchise),
                  data: _franchise,
                  repository: _franchiseRepo,
                  onChanged: _loadFranchise,
                ),
              FranchiseTab.exceptions => FranchiseExceptionsScreen(
                  key: ValueKey(_franchise),
                  data: _franchise,
                  repository: _franchiseRepo,
                  onChanged: _loadFranchise,
                  onTriggerTransfer: () {
                    setState(() {
                      _activeFranchiseTab = FranchiseTab.inventorySupply;
                    });
                  },
                ),
              FranchiseTab.targetsBenchmarking => TargetsBenchmarkingScreen(
                  repository: _franchiseRepo, data: _franchise),
              FranchiseTab.complianceAudit => ComplianceAuditScreen(
                  repository: _franchiseRepo,
                  locations: _account?.locations ?? const [],
                ),
              FranchiseTab.masterMenuItems => MasterMenuItemsScreen(
                  store: _masterStore,
                  ops: _opsStore,
                  allowDemoSeed: !widget.config.usesBackend),
              FranchiseTab.masterProductsOnline => MasterProductsOnlineScreen(
                  store: _masterStore,
                  ops: _opsStore,
                  allowDemoSeed: !widget.config.usesBackend),
              FranchiseTab.masterMedia =>
                MasterMediaScreen(store: _masterStore),
              FranchiseTab.masterOffers =>
                MasterOffersScreen(store: _masterStore),
              FranchiseTab.masterInventory => MasterInventoryScreen(
                  inventory: _inventoryStore,
                  master: _masterStore,
                  currentUserName: _userName),
              FranchiseTab.masterRecipes => MasterRecipesScreen(
                  master: _masterStore,
                  inventory: _inventoryStore,
                  staff: _staff),
              FranchiseTab.masterSuppliers => MasterSuppliersScreen(
                  inventory: _inventoryStore, master: _masterStore),
              FranchiseTab.masterPurchaseOrders => MasterPurchaseOrdersScreen(
                  inventory: _inventoryStore,
                  currentUserName: _userName,
                  branches: _branches),
              FranchiseTab.opsLiveOperations => OpsLiveOperationsScreen(
                  ops: _opsStore,
                  master: _masterStore,
                  onOpenBilling: _openOpsBilling,
                  canVerifyPayments: _canVerifyPayments,
                  canTakePayments: _canTakePayments,
                  staff: _staff),
              FranchiseTab.opsCaptainOrders => OpsCaptainOrdersScreen(
                  ops: _opsStore,
                  master: _masterStore,
                  onOpenBilling: _openOpsBilling,
                  staff: _staff),
              FranchiseTab.opsKitchen =>
                OpsKitchenScreen(ops: _opsStore, master: _masterStore),
              FranchiseTab.opsDineIn => OpsDineInScreen(
                  ops: _opsStore,
                  master: _masterStore,
                  onOpenBilling: _openOpsBilling,
                  staff: _staff),
              FranchiseTab.opsReservations =>
                OpsReservationsScreen(ops: _opsStore),
              FranchiseTab.opsPosBilling => OpsPosBillingScreen(
                  key: ValueKey(_opsFocusOrderId),
                  ops: _opsStore,
                  master: _masterStore,
                  focusOrderId: _opsFocusOrderId,
                  canVerifyPayments: _canVerifyPayments,
                  canTakePayments: _canTakePayments,
                  canPlaceOrders: _canPlaceOrders),
              FranchiseTab.opsDelivery => OpsDeliveryScreen(
                  ops: _opsStore, onOpenBilling: _openOpsBilling, staff: _staff),
              FranchiseTab.opsOnlineOrders => OnlineOrdersScreen(
                  ordersStore: _onlineOrdersStore, menuStore: _menuStore),
              FranchiseTab.opsQrOrdering => OpsQrOrderingScreen(
                  ops: _opsStore, onOpenBilling: _openOpsBilling),
              FranchiseTab.taskManager =>
                _business('Task Manager',
                    (api) => TasksScreen(api: api, branches: _branches)),
              FranchiseTab.crmCustomers ||
              FranchiseTab.crmGroups ||
              FranchiseTab.crmFeedback ||
              FranchiseTab.crmLoyalty =>
                _business(
                    'Customers & CRM',
                    (api) => CrmScreen(
                          api: api,
                          branches: _branches,
                          initialTab: switch (_activeFranchiseTab) {
                            FranchiseTab.crmGroups => CrmTab.segments,
                            FranchiseTab.crmFeedback => CrmTab.feedback,
                            FranchiseTab.crmLoyalty => CrmTab.loyalty,
                            _ => CrmTab.dashboard,
                          },
                        )),
              FranchiseTab.marketingCampaigns ||
              FranchiseTab.marketingPromotions ||
              FranchiseTab.marketingNotifications =>
                _business(
                    'Marketing',
                    (api) => MarketingScreen(
                          api: api,
                          initialTab: switch (_activeFranchiseTab) {
                            FranchiseTab.marketingPromotions =>
                              MarketingTab.promotions,
                            FranchiseTab.marketingNotifications =>
                              MarketingTab.ads,
                            _ => MarketingTab.dashboard,
                          },
                        )),
              FranchiseTab.financePayments ||
              FranchiseTab.financeTransactions ||
              FranchiseTab.financeExpenses ||
              FranchiseTab.financeSettlements ||
              FranchiseTab.financeDocuments =>
                _business(
                    'Finance',
                    (api) => FinanceScreen(
                          api: api,
                          branches: _branches,
                          canDelete: const {'org_owner', 'org_admin'}
                              .contains(_account?.role),
                          initialTab: switch (_activeFranchiseTab) {
                            FranchiseTab.financePayments => FinanceTab.payments,
                            FranchiseTab.financeExpenses => FinanceTab.expenses,
                            FranchiseTab.financeSettlements =>
                              FinanceTab.settlements,
                            FranchiseTab.financeDocuments =>
                              FinanceTab.documents,
                            _ => FinanceTab.dashboard,
                          },
                        )),
              FranchiseTab.integrationsZomato ||
              FranchiseTab.integrationsSwiggy ||
              FranchiseTab.integrationsPayment ||
              FranchiseTab.integrationsOther =>
                _business(
                    'Integrations',
                    (api) => IntegrationsScreen(
                          api: api,
                          initialTab: _activeFranchiseTab ==
                                  FranchiseTab.integrationsOther
                              ? IntegrationsTab.overview
                              : IntegrationsTab.apps,
                          category: switch (_activeFranchiseTab) {
                            FranchiseTab.integrationsZomato ||
                            FranchiseTab.integrationsSwiggy =>
                              'delivery',
                            FranchiseTab.integrationsPayment => 'payments',
                            _ => null,
                          },
                        )),
              FranchiseTab.settingsRestaurant ||
              FranchiseTab.settingsPos ||
              FranchiseTab.settingsOrder ||
              FranchiseTab.settingsNotifications ||
              FranchiseTab.settingsAccount ||
              FranchiseTab.settingsUpdates =>
                _business(
                    'Settings',
                    (api) => SettingsScreen(
                          api: api,
                          branches: _branches,
                          initialTab: switch (_activeFranchiseTab) {
                            FranchiseTab.settingsPos => SettingsTab.devices,
                            FranchiseTab.settingsOrder => SettingsTab.order,
                            FranchiseTab.settingsNotifications =>
                              SettingsTab.notifications,
                            FranchiseTab.settingsAccount =>
                              SettingsTab.subscription,
                            FranchiseTab.settingsUpdates =>
                              SettingsTab.overview,
                            _ => SettingsTab.outlet,
                          },
                        )),
              FranchiseTab.reports ||
              FranchiseTab.pageBuilder ||
              FranchiseTab.support =>
                ComingSoonScreen(
                    section: comingSoonSections[
                        franchiseTabScreens[_activeFranchiseTab]]!),
            },
    );
  }

  /// A business section: it keeps its data on the Proviyaa server, so the
  /// local demo (no server) shows a note instead.
  Widget _business(String name, Widget Function(ProviyaaApiClient api) build) {
    final api = _api;
    return api == null ? ServerRequiredPanel(section: name) : build(api);
  }

  /// Opens an order in Operations → POS Billing.
  void _openOpsBilling(String orderId) => setState(() {
        _opsFocusOrderId = orderId;
        _activeFranchiseTab = FranchiseTab.opsPosBilling;
      });

  void _onSelect(BuildContext context, PosModule module) {
    if (module == PosModule.pos) {
      _openOrder(context, null);
    } else {
      persistTab(module.name);
      setState(() => _selected = module);
    }
  }

  Widget _content(BuildContext context, PosModule selected) =>
      switch (selected) {
        PosModule.tables => TablesScreen(
            tableStore: _tableStore,
            ops: _opsStore,
            onOpenTable: (t) => _openOrder(context, t),
            onStartOrder: (t) => _openOrder(context, t)),
        PosModule.dineIn => DineInScreen(
            tableStore: _tableStore,
            ops: _opsStore,
            canTakePayments: _canTakePayments,
            onOpenOrder: (t) => _openOrder(context, _asRestaurantTable(t)),
            onStartOrder: (t) => _openOrder(context, _asRestaurantTable(t))),
        PosModule.allOrders => AllOrdersScreen(
            ordersStore: _allOrdersStore,
            ops: _opsStore,
            onOpenOrder: (id) => _resumeOrder(context, id)),
        PosModule.takeaway => TakeawayScreen(
            ops: _opsStore,
            canTakePayments: _canTakePayments,
            onNewTakeaway: _canOpen(Screens.posBilling)
                ? () => _openOrder(context, null)
                : null,
            onOpenOrder: (id) => _resumeOrder(context, id)),
        PosModule.delivery => DeliveryScreen(
            ops: _opsStore,
            staff: _staff,
            canTakePayments: _canTakePayments,
            onNewDelivery: _canOpen(Screens.posBilling)
                ? () => _openOrder(context, null, channel: OpsChannel.delivery)
                : null,
            onOpenOrder: (id) => _resumeOrder(context, id)),
        PosModule.online => OnlineOrdersScreen(
            ordersStore: _onlineOrdersStore, menuStore: _menuStore),
        PosModule.menu => MenuManagementScreen(menuStore: _menuStore),
        PosModule.pos => PosModulePlaceholder(
            title: 'POS',
            ops: _opsStore,
            onNewOrder: () => _openOrder(context, null),
            onResumeOrder: (id) => _resumeOrder(context, id)),
      };

  /// PosOrderScreen (an existing, tested, full-route flow with its own
  /// AppBar and its own push to PaymentScreen) only ever reads
  /// `table.label` — see the call sites in pos_order_screen.dart. Rather
  /// than reshaping DineInTable into the Tables page's different
  /// 4-status RestaurantTable model, a minimal bridge value carries just
  /// the label across.
  RestaurantTable _asRestaurantTable(DineInTable t) => RestaurantTable(
      id: t.label,
      label: t.label,
      seats: t.seats ?? t.guestCount ?? 0,
      zone: TableZone.indoor,
      status: TableStatus.occupied);

  /// Opens the POS order screen: a table's order, a new order of
  /// [channel], or [resumeOrderId] (a held or open order).
  void _openOrder(BuildContext context, RestaurantTable? table,
      {OpsChannel? channel, String? resumeOrderId}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PosOrderScreen(
            opsStore: _opsStore,
            allOrdersStore: _allOrdersStore,
            tableStore: _tableStore,
            menuStore: _menuStore,
            locationId: _demoLocationId,
            table: table,
            channel: channel,
            resumeOrderId: resumeOrderId,
            canTakePayments: _canTakePayments)));
  }

  void _resumeOrder(BuildContext context, String orderId) =>
      _openOrder(context, null, resumeOrderId: orderId);

  void _openKitchen(BuildContext context) {
    if (!_canOpen(Screens.posKitchen)) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Kitchen Display')),
            body: KitchenDisplayScreen(
                kitchenService: _kitchenService,
                localStore: _localStore,
                ops: _opsStore))));
  }
}

/// A vendor-panel tab the signed-in role may not open.
class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text('Your role does not have access to this screen.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Ask your restaurant admin to change your role.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}

/// A POS login whose role opens no screens at all.
class _NoScreens extends StatelessWidget {
  const _NoScreens({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Your role has no POS screens yet.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
          ]),
        ),
      );
}

/// The app ran offline past the 24-hour grant: nothing protected works
/// until the server confirms the login again.
class _OfflineExpired extends StatelessWidget {
  const _OfflineExpired({required this.onRetry, required this.onSignOut});
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Offline access has expired',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'This device has not reached the Proviyaa server for more than 24 hours. Your unsent work is kept on this device; connect to the internet to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FilledButton(
                    onPressed: onRetry, child: const Text('Retry connection')),
                const SizedBox(width: 12),
                OutlinedButton(
                    onPressed: onSignOut, child: const Text('Sign out')),
              ]),
            ]),
          ),
        ),
      );
}
