import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/api/session_vault.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/domain/access.dart';
import 'package:proviyaa_pos/domain/vendor_account.dart';
import 'package:proviyaa_pos/main.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_command_center_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_vendor_shell.dart';
import 'package:proviyaa_pos/presentation/kitchen_display_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_menu_items_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_live_operations_screen.dart';
import 'package:proviyaa_pos/presentation/pos_order_screen.dart';
import 'package:proviyaa_pos/presentation/pos_shell.dart';
import 'package:proviyaa_pos/presentation/pos_sidebar.dart';
import 'package:proviyaa_pos/presentation/staff/staff_management_screen.dart';

import 'support/local_platform.dart';

/// The restaurant lifecycle end to end, nothing faked — both backends run
/// on one temporary local Postgres and the app is driven through its UI:
///
///   1. Proviyaa master-admin (its own REST API, as its React panel calls
///      it) creates a test restaurant, two branches and the owner's login.
///   2. The owner signs in on the Flutter login page, lands in the vendor
///      panel, and every module (franchise, master, operations, staff,
///      sync) answers for their restaurant.
///   3. In Staff & Users → Staff the owner adds a cashier, a captain, a
///      chef and a manager, each with an app login and role.
///   4. Each of them signs in on the same login page and gets exactly the
///      screens of their role: cashier → POS billing, captain → tables,
///      chef → kitchen display only, manager → vendor panel without
///      payroll or roles. master-admin lists all of them.
///
/// Needs `npm install` in backend/ and master-admin/backend/; skipped
/// otherwise.
void main() {
  final ready =
      LocalPlatform.posBackendInstalled && LocalPlatform.masterAdminInstalled;
  final platform = LocalPlatform();

  const restaurant = 'Proviyaa Test Kitchen';
  const ownerEmail = 'owner@testkitchen.test';
  const ownerPassword = 'Owner-Pass-2026';
  late String orgId;
  late String adminToken;

  // Staff the owner creates through the Staff screen.
  const staff = <({String name, String email, String role, String title})>[
    (
      name: 'Suresh Kumar',
      email: 'suresh@testkitchen.test',
      role: 'Cashier',
      title: 'Cashier'
    ),
    (
      name: 'Pravin M',
      email: 'pravin@testkitchen.test',
      role: 'Captain',
      title: 'Senior Captain'
    ),
    (
      name: 'Ramesh Singh',
      email: 'ramesh@testkitchen.test',
      role: 'Kitchen (KOT)',
      title: 'Head Chef'
    ),
    (
      name: 'Neha Joshi',
      email: 'neha@testkitchen.test',
      role: 'Branch Manager',
      title: 'Branch Manager'
    ),
  ];
  const staffPassword = 'Staff-Pass-2026';
  // "Ask to change password at first login" is on by default: each staff
  // member sets their own password on first sign-in. Current passwords:
  final passwords = {for (final s in staff) s.email: staffPassword};

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (!ready) return;
    await platform.start();

    // ── 1. master-admin onboards the restaurant ──
    adminToken = (await platform.master('POST', '/auth/login', body: {
      'email': platform.platformEmail,
      'password': platform.platformPassword,
    }))['token'] as String;
    final org = (await platform
        .master('POST', '/organizations', token: adminToken, body: {
      'business_name': restaurant,
      'domain': 'testkitchen',
      'email': 'hello@testkitchen.test',
      'phone_number': '+91 98220 22222',
    }))['organization'] as Map;
    orgId = org['id'] as String;
    final main = (await platform.master(
        'POST', '/organizations/$orgId/locations', token: adminToken, body: {
      'name': 'Latur Main',
      'code': 'LTR-1',
      'area': 'Ganj Golai'
    }))['location'] as Map;
    await platform.master('POST', '/organizations/$orgId/locations',
        token: adminToken,
        body: {'name': 'Latur Station Road', 'code': 'LTR-2'});
    await platform.master('POST', '/organizations/$orgId/accounts',
        token: adminToken,
        body: {
          'first_name': 'Test',
          'last_name': 'Owner',
          'email': ownerEmail,
          'phone_number': '+91 98220 33333',
          'password': ownerPassword,
          'pos_role': 'org_owner',
          'location_id': main['id'],
        });
  });

  tearDownAll(() async {
    if (ready) await platform.stop();
  });

  ProviyaaApiClient client() => ProviyaaApiClient(
      baseUrl: platform.posUrl, httpClient: IOClient(realHttpClient()));

  // ── UI plumbing: real HTTP + the widget test clock ──
  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 40)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    final onScreen = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(80)
        .join(' | ');
    throw TestFailure('Timed out waiting for $finder\n'
        'On screen: $onScreen\n${platform.posLog}');
  }

  Future<AppDatabase> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    await tester.pumpWidget(ProviyaaPosApp(
      config: AppConfig(
          appEnv: 'local',
          dataMode: 'backend',
          apiBaseUrl: platform.posUrl,
          syncEnabled: true),
      database: db,
      apiClient: client(),
      sessionVault: MemorySessionVault(),
    ));
    await settle(tester);
    return db;
  }

  /// Passwords set at a first sign-in (an account made for someone must
  /// choose its own), so later sign-ins use them.
  final changedPasswords = <String, String>{};
  String pw(String email, String fallback) => changedPasswords[email] ?? fallback;

  Future<void> signIn(
      WidgetTester tester, String email, String password) async {
    final current = pw(email, password);
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), current);
    await tester.tap(find.text('Sign In'));
    await settle(tester);
    // First sign-in of an account someone else created: set an own password.
    // The dialog opens a frame after the shell shows; on a busy machine
    // the sign-in itself takes seconds. Wait until a shell has been on
    // screen for a moment with no dialog, or the dialog appears.
    final dialog = find.byKey(const Key('pw-current'));
    var quiet = 0;
    for (var i = 0; i < 120 && dialog.evaluate().isEmpty && quiet < 4; i++) {
      final shellUp = find.byType(FranchiseVendorShell).evaluate().isNotEmpty ||
          find.byType(PosShell).evaluate().isNotEmpty ||
          find.byType(KitchenDisplayScreen).evaluate().isNotEmpty;
      quiet = shellUp ? quiet + 1 : 0;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (dialog.evaluate().isNotEmpty) {
      final fresh = '$current-Own1';
      await tester.enterText(find.byKey(const Key('pw-current')), current);
      await tester.enterText(find.byKey(const Key('pw-new')), fresh);
      await tester.enterText(find.byKey(const Key('pw-confirm')), fresh);
      await tester.tap(find.byKey(const Key('pw-save')));
      // The dialog closes once the server has taken the new password.
      for (var i = 0; i < 150 && dialog.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(dialog, findsNothing, reason: 'the new password was not accepted');
      await settle(tester);
      changedPasswords[email] = fresh;
    }
  }

  Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 3);
    await tester.runAsync(db.close);
  }

  Finder inStaff(String text) => find.descendant(
      of: find.byType(StaffManagementScreen), matching: find.text(text));
  Finder inShell(String text) => find.descendant(
      of: find.byType(FranchiseVendorShell), matching: find.text(text));

  /// The vendor sidebar: a lazily built list — rows off screen don't exist
  /// until scrolled to.
  Finder sidebar() => find
      .descendant(
          of: find.byType(FranchiseVendorShell),
          matching: find.byType(Scrollable))
      .first;
  Finder inSidebar(String text) =>
      find.descendant(of: sidebar(), matching: find.text(text));

  /// Scrolls the sidebar (down, then up) until [text] is built and visible.
  Future<bool> revealInSidebar(WidgetTester tester, String text) async {
    for (final delta in [120.0, -120.0]) {
      try {
        await tester.scrollUntilVisible(inSidebar(text), delta,
            scrollable: sidebar(), maxScrolls: 60);
        // Let the fling finish: a tap on a moving list only stops it.
        await tester.pump(const Duration(seconds: 2));
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Scrolls to and taps a sidebar row, as a user would.
  Future<void> tapSidebar(WidgetTester tester, String text) async {
    if (!await revealInSidebar(tester, text)) {
      final shown = find
          .descendant(of: sidebar(), matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join(' | ');
      throw TestFailure('No sidebar entry "$text". Sidebar shows: $shown');
    }
    await tester.tap(inSidebar(text).first);
    await settle(tester, rounds: 3);
  }

  /// Opens [item] under sidebar [group], expanding the group if needed.
  Future<void> openFromSidebar(
      WidgetTester tester, String group, String item) async {
    if (!await revealInSidebar(tester, item)) await tapSidebar(tester, group);
    await tapSidebar(tester, item);
  }

  testWidgets('the owner signs in, every module works, and staff are created',
      (tester) async {
    final db = await openApp(tester);
    await signIn(tester, ownerEmail, ownerPassword);
    await pumpUntil(tester, find.byType(FranchiseVendorShell));
    expect(inShell(restaurant), findsWidgets);
    for (final group in [
      'Franchise / Chain',
      'Master',
      'Operations',
      'Staff & Users'
    ]) {
      expect(inShell(group), findsOneWidget, reason: group);
    }

    // ── 2. every module answers for this restaurant (same API the screens use) ──
    await tester.runAsync(() async {
      final api = client();
      final me =
          VendorAccount.fromMe(await api.login(ownerEmail, pw(ownerEmail, ownerPassword)));
      expect(me.organizationName, restaurant);
      expect(me.role, 'org_owner');
      expect(me.screens, containsAll(Screens.vendorAll));
      api.locationId = me.location?.id;
      expect(me.locations.map((l) => l.name),
          containsAll(['Latur Main', 'Latur Station Road']));

      final branches = await api.get('v1/franchise/branches') as List;
      expect(branches, hasLength(2));
      final overview = await api.get('v1/franchise/overview') as Map;
      expect(overview['total_orders'], 0);

      final category = await api
          .post('v1/master/menu-categories', {'name': 'Starters'}) as Map;
      final item = await api.post('v1/master/menu-items', {
        'name': 'Paneer Tikka',
        'price': 240,
        'category_id': category['id'],
      }) as Map;
      final items = await api.get('v1/master/menu-items') as List;
      expect(items.map((i) => i['name']), contains('Paneer Tikka'));

      final order = await api.post('v1/operations/orders', {
        'channel': 'dine_in',
        'items': [
          {'menu_item_id': item['id'], 'qty': 2}
        ],
      }) as Map;
      await api.post('v1/operations/orders/${order['id']}/payments',
          {'method': 'upi', 'amount': order['total']});
      // UPI is not counted until someone confirms it reached the account.
      final pending = await api.get('v1/operations/summary') as Map;
      expect(pending['sales_minor'], 0);
      expect((pending['by_status'] as Map)['awaiting_payment'], 1);
      final verified = await api.post(
          'v1/operations/orders/${order['id']}/verify-payment',
          {'reference': 'UPI-E2E-1'}) as Map;
      expect(verified['status'], 'paid');
      final summary = await api.get('v1/operations/summary') as Map;
      expect(summary['orders'], 1);
      expect(summary['sales_minor'], ((order['total'] as num) * 100).round());

      final dashboard = await api.get('v1/staff/dashboard') as Map;
      expect(dashboard['total'], 0);

      // The app's copy of the access table matches the server's.
      final catalogue =
          ((await api.get('v1/staff/roles') as Map)['catalogue'] as Map);
      expect({for (final s in catalogue['screens'] as List) s['id']},
          {for (final s in Screens.all) s.id});
      for (final b in (catalogue['base_roles'] as List).cast<Map>()) {
        expect(PosRoles.defaultScreens(b['key'] as String),
            {for (final s in b['default_screens'] as List) '$s'},
            reason: 'default screens of ${b['key']}');
        expect(PosRoles.panelFor(b['key'] as String), b['panel']);
      }
      api.close();
    });

    // A tour of the vendor panel: each module's screen opens.
    Future<void> open(String group, String item, Type screen) async {
      await openFromSidebar(tester, group, item);
      await pumpUntil(tester, find.byType(screen));
    }

    await open(
        'Franchise / Chain', 'Command Center', FranchiseCommandCenterScreen);
    await open('Master', 'Menu Items', MasterMenuItemsScreen);
    await open('Operations', 'Live Operations', OpsLiveOperationsScreen);
    await open('Staff & Users', 'Staff', StaffManagementScreen);

    // ── 3. the owner adds staff with app logins ──
    await tester.tap(inStaff('Staff').first);
    await pumpUntil(tester, find.byKey(const Key('staff-add-button')));
    for (final s in staff) {
      await tester.tap(find.byKey(const Key('staff-add-button')));
      await pumpUntil(tester, find.byKey(const Key('staff-name')));
      await tester.enterText(find.byKey(const Key('staff-name')), s.name);
      await tester.enterText(
          find.byKey(const Key('staff-mobile')), '+91 90000 00000');
      await tester.enterText(find.byKey(const Key('staff-email')), s.email);
      await tester.enterText(
          find.byKey(const Key('staff-designation')), s.title);
      await tester.ensureVisible(find.byKey(const Key('staff-login-switch')));
      await tester.tap(find.byKey(const Key('staff-login-switch')));
      await settle(tester, rounds: 2);
      final seed = find.byKey(const Key('staff-seed-roles'));
      if (seed.evaluate().isNotEmpty) {
        await tester.ensureVisible(seed);
        await tester.tap(seed);
        await settle(tester);
      }
      await pumpUntil(tester, find.byKey(const Key('staff-login-role')));
      await tester.ensureVisible(find.byKey(const Key('staff-login-role')));
      await tester.tap(find.byKey(const Key('staff-login-role')));
      await settle(tester, rounds: 2);
      await tester.tap(find.text(s.role).last);
      await settle(tester, rounds: 2);
      await tester.ensureVisible(find.byKey(const Key('staff-login-password')));
      await tester.enterText(
          find.byKey(const Key('staff-login-password')), staffPassword);
      await tester.ensureVisible(find.byKey(const Key('staff-create')));
      await tester.tap(find.byKey(const Key('staff-create')));
      await pumpUntil(tester, inStaff(s.name));
      expect(find.byKey(const Key('staff-name')), findsNothing,
          reason: 'the dialog closes after creating ${s.name}');
    }

    // The server has them, each with a login and the chosen role.
    await tester.runAsync(() async {
      final api = client();
      await api.login(ownerEmail, pw(ownerEmail, ownerPassword));
      final logins = (await api.get('v1/staff/logins') as List).cast<Map>();
      for (final s in staff) {
        final l = logins.firstWhere((l) => l['email'] == s.email);
        expect(l['role_name'], s.role, reason: s.email);
        expect(l['staff_name'], s.name);
        expect(l['status'], 'Active');
        expect(l['force_password_change'], isTrue,
            reason: 'new logins must pick their own password');
      }
      api.close();
    });

    await closeApp(tester, db);
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 6)));

  /// Signs [email] in on the login page; on their first sign-in, sets the
  /// new password the app asks for.
  Future<void> staffSignIn(WidgetTester tester, String email) async {
    await signIn(tester, email, pw(email, passwords[email]!));
    await pumpUntil(
        tester,
        find.byWidgetPredicate((w) =>
            w is PosShell ||
            w is FranchiseVendorShell ||
            w is KitchenDisplayScreen));
    await settle(tester);
    if (find.byKey(const Key('pw-save')).evaluate().isNotEmpty) {
      final next = 'Own-${passwords[email]}';
      await tester.enterText(
          find.byKey(const Key('pw-current')), pw(email, passwords[email]!));
      await tester.enterText(find.byKey(const Key('pw-new')), next);
      await tester.enterText(find.byKey(const Key('pw-confirm')), next);
      await tester.tap(find.byKey(const Key('pw-save')));
      await settle(tester);
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (find.byKey(const Key('pw-save')).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await settle(tester, rounds: 2);
      }
      expect(find.byKey(const Key('pw-save')), findsNothing,
          reason: 'the password change is accepted');
      passwords[email] = next;
    }
  }

  Future<void> expectStaffScreens(
      WidgetTester tester, String email, void Function() check) async {
    final db = await openApp(tester);
    await staffSignIn(tester, email);
    check();
    await closeApp(tester, db);
  }

  Finder posNav(String label) =>
      find.descendant(of: find.byType(PosSidebar), matching: find.text(label));

  testWidgets('the cashier gets the POS billing screens only', (tester) async {
    await expectStaffScreens(tester, 'suresh@testkitchen.test', () {
      expect(find.byType(PosShell), findsOneWidget);
      expect(find.byType(FranchiseVendorShell), findsNothing);
      for (final m in [
        'Dine In',
        'Tables',
        'Takeaway',
        'Delivery',
        'Online',
        'All Orders',
        'Menu'
      ]) {
        expect(posNav(m), findsWidgets, reason: m);
      }
      expect(posNav('New Order'), findsOneWidget);
      expect(find.byTooltip('Kitchen Display'), findsNothing);
    });
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('the captain gets tables and dine-in, not takeaway or online',
      (tester) async {
    await expectStaffScreens(tester, 'pravin@testkitchen.test', () {
      expect(find.byType(PosShell), findsOneWidget);
      for (final m in ['Dine In', 'Tables', 'All Orders']) {
        expect(posNav(m), findsWidgets, reason: m);
      }
      for (final m in ['Takeaway', 'Delivery', 'Online', 'Menu']) {
        expect(posNav(m), findsNothing, reason: m);
      }
      expect(posNav('New Order'), findsOneWidget);
    });
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('the captain takes a table order and sends the KOT',
      (tester) async {
    // The back office sets up the floor: one area, one table.
    await tester.runAsync(() async {
      final api = client();
      final me =
          VendorAccount.fromMe(await api.login(ownerEmail, pw(ownerEmail, ownerPassword)));
      api.locationId = me.location?.id;
      final area = await api
          .post('v1/operations/dining-areas', {'name': 'Main Hall'}) as Map;
      await api.post('v1/operations/dining-tables',
          {'label': 'T1', 'seats': 4, 'area_id': area['id']});
      api.close();
    });

    final db = await openApp(tester);
    await staffSignIn(tester, 'pravin@testkitchen.test');
    await pumpUntil(tester, find.byType(PosShell));
    await tester.tap(posNav('Tables').first);
    // The table and the menu arrive with the first sync.
    await pumpUntil(tester, find.text('T1'));
    // An available table opens a new order with its Start Order button.
    await tester.tap(find.text('Start Order').first);
    await pumpUntil(tester, find.byType(PosOrderScreen));
    await pumpUntil(tester, find.text('Paneer Tikka'));
    await tester.tap(find.text('Paneer Tikka').first);
    await settle(tester);
    // Captains take orders; the cashier takes the money.
    expect(find.text('Payment is taken by the cashier'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send KOT'));
    await settle(tester);

    // The order and its KOT reach the server with the captain's sync.
    Map? order;
    final end = DateTime.now().add(const Duration(seconds: 40));
    while (order == null && DateTime.now().isBefore(end)) {
      await settle(tester, rounds: 3);
      await tester.runAsync(() async {
        final api = client();
        await api.login(ownerEmail, pw(ownerEmail, ownerPassword));
        final orders = (await api.get('v1/operations/orders',
                query: {'channel': 'dine_in'}) as List)
            .cast<Map>();
        order = orders.where((o) => o['table_id'] != null).firstOrNull;
        if (order != null) {
          final detail =
              await api.get('v1/operations/orders/${order!['id']}') as Map;
          expect((detail['items'] as List).single['name'], 'Paneer Tikka');
          expect(detail['kot_tickets'] as List, isNotEmpty,
              reason: 'the kitchen gets a KOT');
          expect(detail['status'], isNot('paid'));
        }
        api.close();
      });
    }
    expect(order, isNotNull, reason: 'the captain order reached the server');
    expect(order!['table_id'], isNotNull, reason: 'it is at table T1');
    await closeApp(tester, db);
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('the chef gets the kitchen display and nothing else',
      (tester) async {
    await expectStaffScreens(tester, 'ramesh@testkitchen.test', () {
      expect(find.byType(KitchenDisplayScreen), findsOneWidget);
      expect(find.byType(PosShell), findsNothing);
      expect(find.byType(FranchiseVendorShell), findsNothing);
      expect(find.byTooltip('Sign Out'), findsOneWidget);
    });
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
      'the branch manager runs the branch: no chain views, no payroll or roles',
      (tester) async {
    await expectStaffScreens(tester, 'neha@testkitchen.test', () {
      expect(find.byType(FranchiseVendorShell), findsOneWidget);
      for (final g in ['Master', 'Operations', 'Staff & Users']) {
        expect(inShell(g), findsOneWidget, reason: g);
      }
      expect(inShell('Franchise / Chain'), findsNothing,
          reason: 'chain views are for the owner and restaurant admin');
      // Of the sections still to be built, the branch's own: reports,
      // customers and finance. The restaurant-wide ones are the owners'.
      for (final s in ['Reports', 'Customers & CRM', 'Finance']) {
        expect(inShell(s), findsOneWidget, reason: s);
      }
      for (final s in ['Settings', 'Page Builder', 'Integrations']) {
        expect(inShell(s), findsNothing, reason: s);
      }
    });
    // Staff & Users opens without Salary / Roles tabs; the server agrees.
    final db = await openApp(tester);
    await staffSignIn(tester, 'neha@testkitchen.test');
    await pumpUntil(tester, find.byType(FranchiseVendorShell));
    await tapSidebar(tester, 'Staff & Users');
    expect(await revealInSidebar(tester, 'Attendance'), isTrue);
    expect(await revealInSidebar(tester, 'Roles & Permissions'), isFalse,
        reason: 'branch managers have no Roles & Permissions');
    await tapSidebar(tester, 'Attendance');
    await pumpUntil(tester, find.byType(StaffManagementScreen));
    await settle(tester);
    expect(inStaff('Attendance'), findsWidgets);
    expect(inStaff('Salary'), findsNothing);
    expect(inStaff('Roles & permissions'), findsNothing);
    expect(inStaff('Login security'), findsWidgets,
        reason: 'branch managers look after their staff logins');
    await tester.runAsync(() async {
      final api = client();
      final me = VendorAccount.fromMe(await api.login(
          'neha@testkitchen.test',
          pw('neha@testkitchen.test', passwords['neha@testkitchen.test']!)));
      expect(me.mustChangePassword, isFalse);
      expect(me.screens, isNot(contains(Screens.staffSalary)));
      await expectLater(api.get('v1/staff/salaries'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
      final today = await api.get('v1/staff/attendance') as List;
      expect(today, hasLength(staff.length));
      api.close();
    });
    await closeApp(tester, db);
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('master-admin sees every login the restaurant created',
      (tester) async {
    await tester.runAsync(() async {
      final accounts = (await platform.master(
          'GET', '/organizations/$orgId/accounts',
          token: adminToken))['accounts'] as List;
      final byEmail = {for (final a in accounts.cast<Map>()) a['email']: a};
      expect(byEmail[ownerEmail]?['pos_role'], 'org_owner');
      expect(byEmail['suresh@testkitchen.test']?['pos_role'], 'biller');
      expect(byEmail['pravin@testkitchen.test']?['pos_role'], 'captain');
      expect(byEmail['ramesh@testkitchen.test']?['pos_role'], 'kitchen');
      expect(byEmail['neha@testkitchen.test']?['pos_role'], 'location_manager');
    });
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 1)));
}
