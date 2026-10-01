import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/api/session_vault.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/main.dart';
import 'package:proviyaa_pos/presentation/business/crm_screen.dart';
import 'package:proviyaa_pos/presentation/business/finance_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_vendor_shell.dart';
import 'package:proviyaa_pos/presentation/kitchen_display_screen.dart';
import 'package:proviyaa_pos/presentation/pos_shell.dart';

import 'support/local_platform.dart';
import 'support/visible_text.dart';

/// The vendor panel's business sections end to end, nothing faked: the POS
/// backend and master-admin run on one temporary local Postgres, the owner
/// signs in on the real login page and works through the UI, and every
/// write is read back from the server:
///
///   Customers & CRM → a customer · Marketing → an offer (also in Master →
///   Offers) · Finance → a money entry · Task Manager → a task for a staff
///   member · Integrations → an API key (shown once) · Settings → the
///   outlet profile (renames the restaurant).
///
/// A branch manager then sees Customers & CRM and Finance only.
///
/// Needs `npm install` in backend/ and master-admin/backend/; skipped
/// otherwise.
void main() {
  final ready =
      LocalPlatform.posBackendInstalled && LocalPlatform.masterAdminInstalled;
  final platform = LocalPlatform();

  const restaurant = 'Proviyaa Business Kitchen';
  const ownerEmail = 'owner@businesskitchen.test';
  const ownerPassword = 'Owner-Pass-2026';
  const managerEmail = 'manager@businesskitchen.test';
  const managerPassword = 'Manager-Pass-2026';

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (!ready) return;
    await platform.start();
    final admin = (await platform.master('POST', '/auth/login', body: {
      'email': platform.platformEmail,
      'password': platform.platformPassword,
    }))['token'] as String;
    final org =
        (await platform.master('POST', '/organizations', token: admin, body: {
      'business_name': restaurant,
      'domain': 'businesskitchen',
      'email': 'hello@businesskitchen.test',
      'phone_number': '+91 98220 44444',
    }))['organization'] as Map;
    final orgId = org['id'] as String;
    final branch = (await platform.master(
        'POST', '/organizations/$orgId/locations',
        token: admin,
        body: {'name': 'Latur Main', 'code': 'LTR-1'}))['location'] as Map;
    for (final (email, password, role, phone, first, last) in [
      (
        ownerEmail,
        ownerPassword,
        'org_owner',
        '+91 98220 55555',
        'Meera',
        'Deshmukh'
      ),
      (
        managerEmail,
        managerPassword,
        'manager',
        '+91 98220 66666',
        'Kiran',
        'Jadhav'
      ),
    ]) {
      await platform.master('POST', '/organizations/$orgId/accounts',
          token: admin,
          body: {
            'first_name': first,
            'last_name': last,
            'email': email,
            'phone_number': phone,
            'password': password,
            'pos_role': role,
            'location_id': branch['id'],
          });
    }
    // Staff a task can be assigned to.
    final api = ProviyaaApiClient(
        baseUrl: platform.posUrl, httpClient: IOClient(realHttpClient()));
    await api.login(ownerEmail, ownerPassword);
    final raju = await api.post('v1/staff/employees', {
      'full_name': 'Raju Patil',
      'designation': 'Captain',
      'location_id': branch['id'],
    }) as Map;
    // A salary advance paid by UPI, an expense, and a campaign whose
    // customer group was deleted afterwards.
    final now = DateTime.now();
    await api.post('v1/staff/advances', {
      'staff_id': raju['id'],
      'amount': 2000,
      'mode': 'upi',
      'deduct_month': now.month,
      'deduct_year': now.year,
    });
    await api.post('v1/finance/entries', {
      'direction': 'out',
      'kind': 'expense',
      'account': 'cash',
      'category': 'Packaging',
      'amount': 150,
    });
    final group = await api.post('v1/crm/segments', {
      'name': 'Weekend regulars',
      'rules': {'min_orders': 2},
    }) as Map;
    await api.post('v1/marketing/campaigns', {
      'name': 'Weekend thali',
      'channel': 'whatsapp',
      'segment': group['id'],
      'message': 'Hi {name}, thali at 20% off this weekend',
      'action': 'draft',
    });
    await api.delete('v1/crm/segments/${group['id']}');
    // Records made on the server (their keys are database ids): a dine-in
    // order with its KOT, a UPI takeaway waiting for verification, a
    // Zomato order, a settlement and a document.
    final table = await api.post(
        'v1/operations/dining-tables', {'label': 'T1', 'seats': 4}) as Map;
    final dineIn = await api.post('v1/operations/orders', {
      'channel': 'dine_in',
      'table_id': table['id'],
      'customer_name': 'Walk-in Guest',
      'customer_phone': '9822077777',
      'gst_pct': 5,
      'items': [
        {'name': 'Paneer Tikka', 'unit_price': 240, 'qty': 1}
      ],
    }) as Map;
    expect(dineIn['display_no'], startsWith('ORD-'));
    final pickup = await api.post('v1/operations/orders', {
      'channel': 'pickup',
      'gst_pct': 0,
      'items': [
        {'name': 'Masala Chai', 'unit_price': 30, 'qty': 2}
      ],
    }) as Map;
    await api.post('v1/operations/orders/${pickup['id']}/payments',
        {'method': 'upi', 'amount': pickup['total']});
    await api.post('v1/operations/online-orders', {
      'platform': 'Zomato',
      'customer': 'Anita',
      'items_label': 'Veg Biryani x1',
      'amount_minor': 22000,
    });
    await api.post('v1/finance/settlements',
        {'source': 'pos_collections', 'amount': 500, 'method': 'bank_deposit'});
    await api.post('v1/finance/documents', {
      'name': 'FSSAI Food License',
      'doc_type': 'food_safety',
      'expiry_date': '2030-12-31'
    });
    api.close();
  });

  tearDownAll(() async {
    if (ready) await platform.stop();
  });

  Future<ProviyaaApiClient> signedIn(String email, String password) async {
    final api = ProviyaaApiClient(
        baseUrl: platform.posUrl, httpClient: IOClient(realHttpClient()));
    await api.login(email, password);
    return api;
  }

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
    throw TestFailure(
        'Timed out waiting for $finder\nOn screen: $onScreen\n${platform.posLog}');
  }

  Future<AppDatabase> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
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
      apiClient: ProviyaaApiClient(
          baseUrl: platform.posUrl, httpClient: IOClient(realHttpClient())),
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
    await pumpUntil(tester, find.byType(FranchiseVendorShell));
  }

  Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 3);
    await tester.runAsync(db.close);
  }

  Finder sidebar() => find
      .descendant(
          of: find.byType(FranchiseVendorShell),
          matching: find.byType(Scrollable))
      .first;
  Finder inSidebar(String text) =>
      find.descendant(of: sidebar(), matching: find.text(text));

  Future<bool> revealInSidebar(WidgetTester tester, String text) async {
    for (final delta in [120.0, -120.0]) {
      try {
        await tester.scrollUntilVisible(inSidebar(text), delta,
            scrollable: sidebar(), maxScrolls: 60);
        await tester.pump(const Duration(seconds: 2));
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> tapSidebar(WidgetTester tester, String text) async {
    if (!await revealInSidebar(tester, text)) {
      throw TestFailure('No sidebar entry "$text".');
    }
    await tester.tap(inSidebar(text).first);
    await settle(tester, rounds: 3);
  }

  Future<void> openFromSidebar(
      WidgetTester tester, String group, String item) async {
    if (!await revealInSidebar(tester, item)) await tapSidebar(tester, group);
    await tapSidebar(tester, item);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await pumpUntil(tester, f);
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle(tester, rounds: 3);
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final f = find.byKey(Key(key));
    await pumpUntil(tester, f);
    await tester.ensureVisible(f.first);
    await tester.enterText(f.first, text);
    await tester.pump();
  }

  /// Reads the server with a separate signed-in client (retrying while the
  /// UI's write is still in flight).
  Future<T> eventually<T>(WidgetTester tester, Future<T> Function() read,
      bool Function(T) ok) async {
    late T last;
    for (var i = 0; i < 40; i++) {
      last = (await tester.runAsync(read)) as T;
      if (ok(last)) return last;
      await settle(tester, rounds: 2);
    }
    return last;
  }

  testWidgets(
      'the owner uses every business section and the data is on the server',
      (tester) async {
    final db = await openApp(tester);
    await signIn(tester, ownerEmail, ownerPassword);
    final api =
        (await tester.runAsync(() => signedIn(ownerEmail, pw(ownerEmail, ownerPassword))))!;

    // ── Customers & CRM ──
    await openFromSidebar(tester, 'Customers & CRM', 'Customers');
    await pumpUntil(tester, find.byType(CrmScreen));
    await tapKey(tester, 'crm-add-customer');
    await type(tester, 'customer-first-name', 'Vaishnavi');
    await type(tester, 'customer-phone', '+91 85302 30230');
    await type(tester, 'customer-email', 'vaishnavi@example.com');
    await tapKey(tester, 'customer-save');
    final customers = await eventually(
        tester,
        () async => await api.get('v1/crm/customers') as List,
        (List l) => l.isNotEmpty);
    expect(customers.single['phone'], '8530230230');
    expect(customers.single['email'], 'vaishnavi@example.com');
    await tapKey(tester, 'crm-tab-Customers');
    await pumpUntil(tester, find.byKey(const Key('customer-row-8530230230')));

    // ── Marketing → Promotions: the offer is Master → Offers' offer too ──
    await openFromSidebar(tester, 'Marketing', 'Promotions');
    await tapKey(tester, 'marketing-create-offer');
    await type(tester, 'offer-name', 'Monsoon Feast Special');
    await type(tester, 'offer-code', 'MONSOON50');
    await type(tester, 'offer-discount-value', '50');
    await tapKey(tester, 'offer-save');
    final offers = await eventually(
        tester,
        () async => await api.get('v1/master/offers') as List,
        (List l) => l.isNotEmpty);
    expect(offers.single['code'], 'MONSOON50');
    expect(offers.single['discount_rule'], startsWith('50% OFF'));

    // ── Finance → a money entry ──
    await openFromSidebar(tester, 'Finance', 'Transactions');
    await pumpUntil(tester, find.byType(FinanceScreen));
    await tapKey(tester, 'finance-record-transaction');
    await type(tester, 'entry-amount', '750');
    await type(tester, 'entry-category', 'Packaging');
    await tapKey(tester, 'entry-save');
    final entries = await eventually(
        tester,
        () async => await api.get('v1/finance/entries') as List,
        (List l) => l.any((e) => num.parse('${e['amount']}') == 750));
    final entry =
        entries.firstWhere((e) => num.parse('${e['amount']}') == 750) as Map;
    expect(entry['category'], 'Packaging');

    // ── Task Manager → a task for Raju ──
    await tapSidebar(tester, 'Task Manager');
    await tapKey(tester, 'task-create');
    await type(tester, 'task-title', 'Fire Extinguisher Check');
    // The staff list loads with the form: open the menu once it has Raju.
    for (var i = 0; i < 10; i++) {
      await tapKey(tester, 'task-assignee');
      if (find.textContaining('Raju Patil').evaluate().isNotEmpty) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester, rounds: 3);
    }
    await tester.tap(find.textContaining('Raju Patil').last);
    await settle(tester, rounds: 3);
    await tapKey(tester, 'task-assign');
    final tasks = await eventually(
        tester,
        () async => await api.get('v1/tasks/tasks') as List,
        (List l) => l.isNotEmpty);
    expect(tasks.single['title'], 'Fire Extinguisher Check');
    expect(tasks.single['assignee_name'], 'Raju Patil');
    expect(tasks.single['status'], 'assigned');

    // ── Integrations → an API key, shown once and stored as a hash ──
    await openFromSidebar(tester, 'Integrations', 'Other Integrations');
    await tapKey(tester, 'integrations-tab-API keys');
    await tapKey(tester, 'api-key-generate');
    await type(tester, 'api-key-name', 'Accounting export');
    await tapKey(tester, 'api-key-scope-payments:read');
    await tapKey(tester, 'api-key-save');
    await pumpUntil(tester, find.byKey(const Key('api-key-value')));
    final shown = (tester.widget(find.byKey(const Key('api-key-value')))
            as SelectableText)
        .data!;
    expect(shown, startsWith('pv_live_'));
    final keys = await tester.runAsync(
        () async => await api.get('v1/integrations/api-keys') as List);
    expect(keys!.single['name'], 'Accounting export');
    expect(shown, startsWith(keys.single['prefix'] as String));
    expect(keys.toString(), isNot(contains(shown)));
    await tapKey(tester, 'secret-done');

    // ── Settings → outlet profile renames the restaurant ──
    await openFromSidebar(tester, 'Settings', 'Restaurant Settings');
    await type(tester, 'outlet-name', 'Business Kitchen Latur');
    await type(tester, 'outlet-phone', '+91 90123 45678');
    await type(tester, 'outlet-email', 'hello@businesskitchen.test');
    await type(tester, 'outlet-address', 'Gandhi Road, Latur 413512');
    await tapKey(tester, 'outlet-save');
    final outlet = await eventually(
        tester,
        () async => jsonOf(await api.get('v1/settings/outlet')),
        (Map o) => o['name'] == 'Business Kitchen Latur');
    expect(outlet['address'], 'Gandhi Road, Latur 413512');
    final me = await tester.runAsync(() => api.me());
    expect((me!['organization'] as Map)['name'], 'Business Kitchen Latur');

    api.close();
    await closeApp(tester, db);
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('every page shows real data — no database ids or internal codes',
      (tester) async {
    final db = await openApp(tester);
    await signIn(tester, ownerEmail, ownerPassword);
    // Let the device pull the server's orders and KOTs.
    await settle(tester, rounds: 20);

    final problems = <String, List<String>>{};
    Future<void> check(String where) async {
      await settle(tester, rounds: 8);
      final found = internalValuesOnScreen(tester);
      if (found.isNotEmpty) problems[where] = found;
    }

    Future<void> tabs(String prefix, List<String> labels) async {
      for (final l in labels) {
        await tapKey(tester, '$prefix-$l');
        await check('$prefix $l');
      }
    }

    await check('Dashboard');
    for (final (group, items) in [
      (
        'Franchise / Chain',
        [
          'Command Center',
          'Branch Performance',
          'Branch Detail',
          'Inventory & Supply',
          'Exceptions',
          'Targets & Benchmarking',
          'Compliance & Audit'
        ]
      ),
      (
        'Master',
        [
          'Menu Items',
          'Products (Online)',
          'Media',
          'Offers',
          'Inventory',
          'Recipes',
          'Suppliers',
          'Purchase Orders'
        ]
      ),
      (
        'Operations',
        [
          'Live Operations',
          'Captain Orders',
          'KOT / Kitchen',
          'Dine In',
          'Reservations',
          'POS Billing',
          'Delivery',
          'Online Orders',
          'QR Ordering'
        ]
      ),
      (
        'Staff & Users',
        ['Staff', 'Roles & Permissions', 'Attendance', 'Training']
      ),
    ]) {
      for (final item in items) {
        await openFromSidebar(tester, group, item);
        await check('$group → $item');
      }
    }

    await openFromSidebar(tester, 'Customers & CRM', 'Customers');
    await tabs('crm-tab', [
      'Dashboard',
      'Customers',
      'Segments',
      'Loyalty',
      'Wallet',
      'Feedback',
      'Ideas'
    ]);
    await openFromSidebar(tester, 'Marketing', 'Campaigns');
    await tabs('marketing-tab',
        ['Dashboard', 'Campaigns', 'Promotions', 'Ads & notifications']);
    await openFromSidebar(tester, 'Finance', 'Transactions');
    await tabs('finance-tab',
        ['Dashboard', 'Payments', 'Expenses', 'Settlements', 'Documents']);
    await tapSidebar(tester, 'Task Manager');
    await check('Task Manager');
    await tapKey(tester, 'task-row-Fire Extinguisher Check');
    await check('Task detail');
    await openFromSidebar(tester, 'Integrations', 'Other Integrations');
    await tabs('integrations-tab', [
      'Overview',
      'Connected apps',
      'Sync engine',
      'Webhooks',
      'API keys',
      'Logs'
    ]);
    await openFromSidebar(tester, 'Settings', 'Restaurant Settings');
    for (final t in [
      'outlet',
      'order',
      'devices',
      'printers',
      'billFormat',
      'notifications',
      'subscription'
    ]) {
      await tapKey(tester, 'settings-tab-$t');
      await check('Settings $t');
    }
    await tapKey(tester, 'settings-group-1');
    for (final t in ['overview', 'kds', 'operations', 'updates']) {
      await tapKey(tester, 'settings-tab-$t');
      await check('Settings $t');
    }
    await closeApp(tester, db);
    expect(problems, isEmpty,
        reason: 'pages showing internal values instead of real data');
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets(
      'a branch manager sees Customers & CRM and Finance, not the restaurant-wide sections',
      (tester) async {
    final db = await openApp(tester);
    await signIn(tester, managerEmail, managerPassword);
    Finder inShell(String t) => find.descendant(
        of: find.byType(FranchiseVendorShell), matching: find.text(t));
    for (final s in ['Customers & CRM', 'Finance']) {
      expect(await revealInSidebar(tester, s), isTrue, reason: s);
    }
    for (final s in ['Task Manager', 'Marketing', 'Integrations', 'Settings']) {
      expect(inShell(s), findsNothing, reason: s);
    }
    await openFromSidebar(tester, 'Finance', 'Payments');
    await pumpUntil(tester, find.byType(FinanceScreen));
    final api =
        (await tester.runAsync(() => signedIn(managerEmail, pw(managerEmail, managerPassword))))!;
    final denied = await tester.runAsync(() async {
      try {
        await api.get('v1/marketing/dashboard');
        return 200;
      } on ApiException catch (e) {
        return e.status;
      }
    });
    expect(denied, 403);
    api.close();
    await closeApp(tester, db);
  }, skip: !ready, timeout: const Timeout(Duration(minutes: 3)));
}

Map<String, dynamic> jsonOf(dynamic v) => (v as Map).cast<String, dynamic>();
