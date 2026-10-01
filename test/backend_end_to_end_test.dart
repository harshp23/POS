import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:proviyaa_pos/application/cloud_sync_service.dart';
import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/api/api_online_orders_store.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/franchise_repository.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/data/operations_seeder.dart';
import 'package:proviyaa_pos/data/sync/sync_contract.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/domain/vendor_account.dart';

/// End to end, nothing faked: the POS backend (backend/, local mode = a
/// real Postgres (PGlite) with master-admin's migrations, the live-schema
/// snapshot and the POS migration) runs as its own process, and so does
/// the master-admin backend (master-admin/backend/) on the same database
/// and JWT secret. App "devices" — real Drift databases, the real
/// CloudSyncService and HTTP client — sign in with master-admin accounts
/// and sync through the POS backend.
///
/// Needs Node and `npm install` in backend/ (and in master-admin/backend/
/// for the master-admin part); skipped otherwise.
void main() {
  final backendDir = Directory('backend');
  final ready = File('backend/node_modules/tsx/package.json').existsSync();
  final masterReady =
      File('master-admin/backend/node_modules/ts-node/package.json')
          .existsSync();
  const email = 'admin@spicybistro.com';
  const password = 'E2e-Password-2026';
  const platformEmail = 'superadmin@proviyaa.test';
  const platformPassword = 'E2e-Platform-2026';
  const jwtSecret = 'e2e-shared-jwt-secret-for-both-backends-0123456789';

  late Process server;
  Process? master;
  late String baseUrl;
  late String masterUrl;
  late Directory dataDir;
  final serverLog = StringBuffer();
  final masterLog = StringBuffer();

  Future<void> waitFor(
      Process p, StringBuffer log, String marker, String name) {
    final up = Completer<void>();
    p.stdout.transform(utf8.decoder).listen((s) {
      log.write(s);
      if (s.contains(marker) && !up.isCompleted) up.complete();
    });
    p.stderr.transform(utf8.decoder).listen(log.write);
    return up.future.timeout(const Duration(seconds: 120),
        onTimeout: () => throw StateError('$name did not start:\n$log'));
  }

  Future<void> kill(Process p) async {
    // On Windows the process is a cmd.exe wrapper: kill its whole tree
    // first — killing the wrapper alone orphans the node server.
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/T', '/PID', '${p.pid}']);
    }
    p.kill();
    await p.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
  }

  setUpAll(() async {
    // Two devices = two databases in one process, on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (!ready) return;
    dataDir = Directory.systemTemp.createTempSync('proviyaa_e2e_');
    final random = Random();
    final port = 20000 + random.nextInt(10000);
    final dbPort = 30000 + random.nextInt(10000);
    final masterPort = 40000 + random.nextInt(10000);
    baseUrl = 'http://127.0.0.1:$port';
    masterUrl = 'http://127.0.0.1:$masterPort/api';
    server = await Process.start(
      'node',
      ['--import', 'tsx', 'src/local-server.ts'],
      workingDirectory: backendDir.path,
      environment: {
        'PORT': '$port',
        'LOCAL_DB_PORT': '$dbPort',
        'LOCAL_DATA_DIR': dataDir.path,
        'LOCAL_SEED_EMAIL': email,
        'LOCAL_SEED_PASSWORD': password,
        'LOCAL_PLATFORM_EMAIL': platformEmail,
        'LOCAL_PLATFORM_PASSWORD': platformPassword,
        'JWT_SECRET': jwtSecret,
      },
      runInShell: Platform.isWindows,
    );
    await waitFor(server, serverLog, 'listening', 'POS backend');

    if (!masterReady) return;
    master = await Process.start(
      'node',
      ['-r', 'ts-node/register/transpile-only', 'src/index.ts'],
      workingDirectory: 'master-admin/backend',
      environment: {
        'PORT': '$masterPort',
        'NODE_ENV': 'development',
        'DATABASE_URL':
            'postgresql://postgres:postgres@127.0.0.1:$dbPort/postgres',
        'JWT_SECRET': jwtSecret,
      },
      runInShell: Platform.isWindows,
    );
    await waitFor(master!, masterLog, 'Server running', 'master-admin backend');
  });

  tearDownAll(() async {
    if (!ready) return;
    if (master != null) await kill(master!);
    await kill(server);
    try {
      dataDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<(AppDatabase, ProviyaaApiClient, VendorAccount, CloudSyncService)>
      device(String name) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    final api = ProviyaaApiClient(baseUrl: baseUrl);
    final account = VendorAccount.fromMe(await api.login(email, password));
    api.locationId = account.location?.id;
    final sync = CloudSyncService(db: db, api: api, deviceId: name);
    return (db, api, account, sync);
  }

  test('two devices of one restaurant stay in step through the backend',
      () async {
    // ── Device A: the Delhi CP counter, with the full seeded restaurant ──
    final (dbA, apiA, account, syncA) = await device('device-A');
    addTearDown(dbA.close);
    expect(account.organizationName, 'Spicy Bistro');
    expect(account.role, 'org_owner');
    expect(account.platformAdmin, isFalse);
    expect(account.isVendorPanel, isTrue);
    // No home branch: the owner acts for the branch the restaurant started
    // with (the oldest), not whichever sorts first by name.
    expect(account.location?.name, 'Delhi - Connaught Place');

    await MasterSeeder.seedIfNeeded(dbA);
    await OperationsSeeder.seedIfNeeded(dbA);

    final first = await syncA.syncNow();
    expect(syncA.status.phase, SyncPhase.idle,
        reason: '${syncA.status.message}\n$serverLog');
    final refused = await (dbA.select(dbA.syncRowStates)
          ..where((s) => s.status.isIn(['rejected', 'conflict'])))
        .get();
    expect(refused.map((r) => '${r.localTable} ${r.rowKey}: ${r.lastError}'),
        isEmpty,
        reason: 'every seeded record should be accepted');
    expect(first.accepted, greaterThan(100), reason: '$first');

    // Nothing left to send: a second run is a no-op.
    final again = await syncA.syncNow();
    expect(again.pushed, 0, reason: '$again');

    // ── A takes and settles a new order at a table, offline-first ──
    final opsA = DriftOperationsStore(dbA);
    final table = (await opsA.getTables())
        .firstWhere((t) => t.status == OpsTableStatus.available);
    final dishes = await DriftMasterStore(dbA).getDishes();
    final dish = dishes.first;
    final orderId = await opsA.placeOrder(
      channel: OpsChannel.dineIn,
      tableId: table.id,
      guests: 2,
      lines: [
        OpsOrderLine(
            itemId: dish.id,
            name: dish.name,
            unitMinor: (dish.sellingPrice * 100).round(),
            quantity: 2),
      ],
    );
    await opsA.generateBill(orderId);
    // UPI is recorded pending verification; a manager verifies it, which
    // settles the order.
    await opsA.settleOrder(orderId, 'upi');
    await opsA.verifyPayment(orderId, note: 'seen in UPI app');
    final settled = (await opsA.getOrder(orderId))!;
    final pushNew = await syncA.syncNow();
    expect(pushNew.accepted, greaterThan(0), reason: '$pushNew');

    // The central order, as the back office sees it.
    final central = (await apiA
            .get('v1/operations/orders', query: {'status': 'paid'}) as List)
        .cast<Map>()
        .firstWhere((o) => o['display_no'] == orderId);
    expect(central['total'], settled.grandTotalMinor / 100);
    expect(central['channel'], 'dine_in');
    final detail =
        await apiA.get('v1/operations/orders/${central['id']}') as Map;
    expect((detail['payments'] as List).single['method'], 'upi');
    expect((detail['items'] as List).single['qty'], 2);
    // The local order is now marked synchronized.
    final localRow = await (dbA.select(dbA.orders)
          ..where((o) => o.clientOrderId.equals(orderId)))
        .getSingle();
    expect(localRow.status, 'synchronized');

    // ── Device B: a fresh install of the same branch ──
    final (dbB, _, _, syncB) = await device('device-B');
    addTearDown(dbB.close);
    final pulled = await syncB.syncNow();
    expect(syncB.status.phase, SyncPhase.idle,
        reason: '${syncB.status.message}');
    expect(pulled.pulled, greaterThan(100), reason: '$pulled');

    final dishesB = await DriftMasterStore(dbB).getDishes();
    expect(dishesB.map((d) => d.id).toSet(), dishes.map((d) => d.id).toSet());
    final dishB = dishesB.firstWhere((d) => d.id == dish.id);
    expect(dishB.sellingPrice, dish.sellingPrice);
    expect(dishB.foodCost, dish.foodCost);
    expect(dishB.hsn, dish.hsn);

    final orderB = await DriftOperationsStore(dbB).getOrder(orderId);
    expect(orderB, isNotNull);
    expect(orderB!.status, OpsOrderStatus.settled);
    expect(orderB.grandTotalMinor, settled.grandTotalMinor);
    final allOrdersB = await dbB.select(dbB.allOrdersTable).get();
    expect(allOrdersB.map((o) => o.orderId), contains(orderId));

    final materialsA = await DriftInventoryStore(dbA).getMaterials();
    final materialsB = await DriftInventoryStore(dbB).getMaterials();
    expect(materialsB.map((m) => (m.id, m.stockQty)).toSet(),
        materialsA.map((m) => (m.id, m.stockQty)).toSet());

    // ── An edit on B flows back to A ──
    await DriftMasterStore(dbB).adjustDishPrices([dish.id], delta: 20);
    final bPush = await syncB.syncNow();
    expect(bPush.accepted, greaterThan(0), reason: '$bPush');
    await syncA.syncNow();
    final dishOnA = (await DriftMasterStore(dbA).getDishes())
        .firstWhere((d) => d.id == dish.id);
    expect(dishOnA.sellingPrice, dish.sellingPrice + 20);

    // ── Online orders inbox (One Latur orders seeded on the server) ──
    final inbox = ApiOnlineOrdersStore(apiA, autoStart: false);
    addTearDown(inbox.dispose);
    await inbox.refresh();
    final pending =
        inbox.state.orders.where((o) => o.platform == 'One Latur').toList();
    expect(pending, hasLength(2));
    await inbox.updateStatus(pending.first.orderId, 'Accepted', 'Prepare');
    expect(
        inbox.state.orders
            .firstWhere((o) => o.orderId == pending.first.orderId)
            .status,
        'Accepted');

    // ── Franchise view, computed from the synced data ──
    final franchise = await ApiFranchiseRepository(apiA).load();
    expect(franchise.live, isTrue);
    expect(franchise.overview.totalOrders, greaterThan(0));
    expect(
        franchise.branches.map((b) => b.branchName),
        containsAll([
          'Delhi - Connaught Place',
          'Noida Sector 62',
          'Bengaluru Indiranagar'
        ]));
  },
      skip: ready
          ? false
          : 'backend/node_modules missing — run npm install in backend/',
      timeout: const Timeout(Duration(minutes: 5)));

  test('a back-office table: order, settle, clean — device and server agree',
      () async {
    final (db, api, _, sync) = await device('device-C');
    addTearDown(db.close);
    // The floor plan is made in the back office, not on a device.
    final area = await api
        .post('v1/operations/dining-areas', {'name': 'Patio E2E'}) as Map;
    final made = await api.post('v1/operations/dining-tables',
        {'label': 'P1', 'seats': 4, 'area_id': area['id']}) as Map;
    await sync.syncNow();
    final ops = DriftOperationsStore(db);
    final table = (await ops.getTables()).firstWhere((t) => t.label == 'P1');
    expect(table.id, made['id'], reason: 'the device keeps the server id');

    Future<List<String>> refused() async => [
          for (final r in await (db.select(db.syncRowStates)
                ..where((s) => s.status.isIn(['rejected', 'conflict'])))
              .get())
            '${r.localTable} ${r.rowKey}: ${r.lastError}'
        ];
    Future<String?> serverStatus() async {
      final page = await api.post('v1/sync/pull', {
        'resources': ['tables']
      }) as Map;
      final rows = ((page['resources'] as Map)['tables'] as Map)['rows'] as List;
      return rows.cast<Map>().firstWhere((r) => r['label'] == 'P1')['status']
          as String?;
    }

    final orderId = await ops.placeOrder(
        channel: OpsChannel.dineIn,
        tableId: table.id,
        guests: 2,
        lines: const [
          OpsOrderLine(
              itemId: 'e2e-dosa',
              name: 'Masala Dosa',
              unitMinor: 12000,
              quantity: 1)
        ]);
    await sync.syncNow();
    expect(await refused(), isEmpty, reason: 'seating guests syncs');
    expect(await serverStatus(), 'occupied');

    await ops.settleOrder(orderId, 'cash');
    await sync.syncNow();
    expect((await ops.getTable(table.id))!.status, OpsTableStatus.cleaning);
    expect(await serverStatus(), 'cleaning');

    await ops.setTableStatus(table.id, OpsTableStatus.available);
    await sync.syncNow();
    await sync.syncNow(); // a later run must not bring back the old state
    expect((await ops.getTable(table.id))!.status, OpsTableStatus.available);
    expect(await serverStatus(), 'available');
    expect(await refused(), isEmpty);
  },
      skip: ready
          ? false
          : 'backend/node_modules missing — run npm install in backend/',
      timeout: const Timeout(Duration(minutes: 3)));

  test('a till keeps billing offline and catches up when the network returns',
      () async {
    // The owner gives the branch a cashier login (Staff & Users API).
    final owner = ProviyaaApiClient(baseUrl: baseUrl);
    addTearDown(owner.close);
    final me = VendorAccount.fromMe(await owner.login(email, password));
    owner.locationId = me.location?.id;
    final roles = (await owner.post('v1/staff/roles/seed') as List).cast<Map>();
    final biller = roles.firstWhere((r) => r['base_role'] == 'biller');
    const tillEmail = 'till@spicybistro.test';
    const tillPassword = 'Till-Pass-2026';
    await owner.post('v1/staff/employees', {
      'full_name': 'Till Cashier',
      'mobile': '+91 90000 00000',
      'email': tillEmail,
      'designation': 'Cashier',
      'location_id': me.location?.id,
      'login': {'password': tillPassword, 'role_id': biller['id']},
    });

    // The till: the cashier's own device, syncing what the role may.
    final net = _SwitchableClient();
    final api = ProviyaaApiClient(baseUrl: baseUrl, httpClient: net);
    final cashier =
        VendorAccount.fromMe(await api.login(tillEmail, tillPassword));
    expect(cashier.role, 'biller');
    api.locationId = cashier.location?.id;
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    addTearDown(db.close);
    final sync = CloudSyncService(
        db: db,
        api: api,
        deviceId: 'till-1',
        pushModules: {
          for (final m in SyncModule.values)
            if (cashier.can(m.name, 'write')) m
        },
        pullModules: {
          for (final m in SyncModule.values)
            if (cashier.can(m.name, 'read')) m
        });
    await sync.syncNow();
    expect(sync.status.phase, SyncPhase.idle, reason: sync.status.message);

    // The network drops in the middle of service; billing goes on.
    net.offline = true;
    final ops = DriftOperationsStore(db);
    const dosa = OpsOrderLine(
        itemId: 'till-dosa', name: 'Masala Dosa', unitMinor: 12000, quantity: 2);
    final cashOrder = await ops.placeOrder(
        channel: OpsChannel.takeaway, customerName: 'Walk-in', lines: [dosa]);
    await ops.settleOrder(cashOrder, 'cash');
    final upiOrder =
        await ops.placeOrder(channel: OpsChannel.takeaway, lines: [dosa]);
    await ops.settleOrder(upiOrder, 'upi');
    await sync.syncNow();
    expect(sync.status.phase, SyncPhase.offline);
    expect(sync.status.waiting, greaterThan(0),
        reason: 'the till shows what is waiting to upload');
    expect((await ops.getOrder(cashOrder))!.status, OpsOrderStatus.settled,
        reason: 'cash settles on the till while offline');

    // Back online: everything uploads, nothing is refused.
    net.offline = false;
    await sync.syncNow();
    expect(sync.status.phase, SyncPhase.idle, reason: sync.status.message);
    expect(await sync.pendingChanges(), 0);
    final refused = await (db.select(db.syncRowStates)
          ..where((s) => s.status.isIn(['rejected', 'conflict'])))
        .get();
    expect(refused.map((r) => '${r.localTable} ${r.rowKey}: ${r.lastError}'),
        isEmpty);

    // The back office sees both: cash paid, UPI waiting for verification.
    final central = (await owner.get('v1/operations/orders',
            query: {'limit': '200'}) as List)
        .cast<Map>();
    Map byPos(String id) => central.firstWhere((o) => o['display_no'] == id);
    expect(byPos(cashOrder)['status'], 'paid');
    expect(byPos(cashOrder)['total'], 252);
    expect(byPos(upiOrder)['status'], 'awaiting_payment');

    // The owner verifies the UPI by the id on the till's screen; the till
    // then shows it settled.
    await owner.post('v1/operations/orders/$upiOrder/verify-payment',
        {'note': 'UTR checked'});
    await sync.syncNow();
    expect((await ops.getOrder(upiOrder))!.status, OpsOrderStatus.settled);
  },
      skip: ready
          ? false
          : 'backend/node_modules missing — run npm install in backend/',
      timeout: const Timeout(Duration(minutes: 3)));

  test('a restaurant onboarded in master-admin signs in to the POS', () async {
    // ── master-admin: the platform admin onboards a new restaurant ──
    Future<Map<String, dynamic>> call(String method, String path,
        {String? token, Object? body}) async {
      final req = http.Request(method, Uri.parse('$masterUrl$path'))
        ..headers['Content-Type'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(await req.send());
      expect(res.statusCode, inInclusiveRange(200, 201),
          reason: '$method $path → ${res.statusCode} ${res.body}\n$masterLog');
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    }

    final adminToken = (await call('POST', '/auth/login', body: {
      'email': platformEmail,
      'password': platformPassword
    }))['token'] as String;
    final org = (await call('POST', '/organizations', token: adminToken, body: {
      'business_name': 'Latur Tiffin House',
      'domain': 'laturtiffin',
      'email': 'hello@laturtiffin.test',
      'phone_number': '+91 98220 00000',
    }))['organization'] as Map;
    final location = (await call(
        'POST', '/organizations/${org['id']}/locations',
        token: adminToken,
        body: {
          'name': 'Latur Main',
          'code': 'LTR-1',
          'area': 'Ganj Golai'
        }))['location'] as Map;
    const managerEmail = 'manager@laturtiffin.test';
    const managerPassword = 'Latur-Manager-2026';
    final created = (await call('POST', '/organizations/${org['id']}/accounts',
        token: adminToken,
        body: {
          'first_name': 'Sneha',
          'last_name': 'Kulkarni',
          'email': managerEmail,
          'phone_number': '+91 98220 11111',
          'password': managerPassword,
          'pos_role': 'manager',
          'location_id': location['id'],
        }))['account'] as Map;

    // ── the POS: the new account signs in and lands in its restaurant ──
    final api = ProviyaaApiClient(baseUrl: baseUrl);
    addTearDown(api.close);
    final account =
        VendorAccount.fromMe(await api.login(managerEmail, managerPassword));
    expect(account.organizationName, 'Latur Tiffin House');
    // master-admin's older "manager" value works as a Branch Manager.
    expect(account.role, 'location_manager');
    expect(account.location?.name, 'Latur Main');
    expect(account.locations.map((l) => l.name), ['Latur Main']);
    api.locationId = account.location?.id;

    // It works in its own restaurant only.
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    addTearDown(db.close);
    await MasterSeeder.seedIfNeeded(db);
    final sync = CloudSyncService(db: db, api: api, deviceId: 'latur-counter');
    final report = await sync.syncNow();
    expect(sync.status.phase, SyncPhase.idle, reason: '${sync.status.message}');
    expect(report.accepted, greaterThan(0), reason: '$report');
    expect(await api.get('v1/operations/orders', query: {'status': 'paid'}),
        isEmpty,
        reason: "Spicy Bistro's orders must not be visible");

    // ── a master-admin token opens any restaurant in the POS ──
    final platform = ProviyaaApiClient(baseUrl: baseUrl);
    addTearDown(platform.close);
    final bare = await platform.login(platformEmail, platformPassword);
    expect(VendorAccount.hasOrganization(bare), isFalse);
    expect(VendorAccount.isPlatformAdmin(bare), isTrue);
    final orgs = VendorAccount.organizationsOf(bare);
    expect(orgs.map((o) => o.name),
        containsAll(['Spicy Bistro', 'Latur Tiffin House']));
    final spicy = orgs.firstWhere((o) => o.name == 'Spicy Bistro');
    platform.organizationId = spicy.id;
    final asOwner = VendorAccount.fromMe(await platform.me());
    expect(asOwner.organizationName, 'Spicy Bistro');
    expect(asOwner.role, 'org_owner');
    expect(asOwner.platformAdmin, isTrue);

    // A restaurant account cannot switch itself into another restaurant.
    api.organizationId = spicy.id;
    await expectLater(api.me(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    api.organizationId = null;

    // ── chain records written from the POS are readable back ──
    final repo = ApiFranchiseRepository(platform);
    await repo.logRecord('audit_report',
        'Internal audit: Delhi CP — 92/100 (A)', {'score': 92, 'grade': 'A'},
        status: 'completed');
    final audits = await repo.records('audit_report');
    expect(audits.first.title, contains('92/100'));
    expect(audits.first.createdByName, isNotEmpty);

    // ── a saved session restores in a fresh app process ──
    final restarted = ProviyaaApiClient(baseUrl: baseUrl);
    addTearDown(restarted.close);
    final resumed = VendorAccount.fromMe(
        await restarted.resume(api.session!, locationId: account.location?.id));
    expect(resumed.organizationName, 'Latur Tiffin House');

    // ── suspending the account in master-admin locks the POS out ──
    await call('PATCH', '/organizations/${org['id']}/accounts/${created['id']}',
        token: adminToken, body: {'status': 'Suspended'});
    await expectLater(api.me(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    await expectLater(
        ProviyaaApiClient(baseUrl: baseUrl)
            .login(managerEmail, managerPassword),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
  },
      skip: !ready
          ? 'backend/node_modules missing — run npm install in backend/'
          : !masterReady
              ? 'master-admin/backend/node_modules missing — run npm install in master-admin/backend/'
              : false,
      timeout: const Timeout(Duration(minutes: 5)));
}

/// An HTTP client whose network can be cut, like a till losing Wi-Fi.
class _SwitchableClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool offline = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) throw const SocketException('Network is unreachable');
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
