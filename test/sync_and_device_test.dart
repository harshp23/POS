import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proviyaa_pos/application/cloud_sync_service.dart';
import 'package:proviyaa_pos/application/device_binding.dart';
import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/api/session_vault.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/master_catalog.dart';
import 'package:proviyaa_pos/data/sync/sync_contract.dart';
import 'package:proviyaa_pos/domain/operations.dart';

/// Sync change ids, the per-device restaurant binding and the offline
/// session grant — the parts of offline-first safety that live on the device.
void main() {
  AppDatabase memoryDb() =>
      AppDatabase(DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true));

  /// A fake /v1/sync/push that accepts everything (or fails when told to)
  /// and records the change ids it saw.
  ({
    ProviyaaApiClient api,
    List<List<String>> pushes,
    void Function(bool) offline
  }) fakeServer() {
    final pushes = <List<String>>[];
    var down = false;
    var version = 0;
    final client = MockClient((req) async {
      if (down) throw const _Offline();
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (req.url.path.endsWith('/v1/sync/push')) {
        final changes = (body['changes'] as List).cast<Map>();
        pushes.add([for (final c in changes) c['change_id'] as String]);
        return http.Response(
            jsonEncode({
              'data': {
                'results': [
                  for (final c in changes)
                    {
                      'change_id': c['change_id'],
                      'status': 'accepted',
                      'version': 'v${++version}'
                    }
                ]
              }
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
          jsonEncode({
            'data': {'resources': {}}
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final api =
        ProviyaaApiClient(baseUrl: 'http://sync.test', httpClient: client)
          ..session = const ApiSession(
              accessToken: 't',
              refreshToken: 't',
              expiresAt: 4102444800,
              userId: 'u',
              email: 'owner@test');
    return (api: api, pushes: pushes, offline: (v) => down = v);
  }

  group('sync change ids', () {
    test('an edit back to an earlier value is still sent', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final server = fakeServer();
      var t = DateTime.utc(2026, 9, 29, 10);
      final sync = CloudSyncService(
          db: db,
          api: server.api,
          deviceId: 'dev-1',
          pullModules: const {},
          pushModules: {SyncModule.master},
          clock: () => t = t.add(const Duration(seconds: 1)));
      final store = DriftMasterStore(db);
      final dish = MasterCatalogData.sampleDishes.first;
      String dishChange(List<String> ids) =>
          ids.firstWhere((i) => i.contains(':menu_items_table:${dish.id}:'));

      await store.upsertDish(dish);
      await sync.syncNow();
      final first = dishChange(server.pushes.last);

      await store.adjustDishPrices([dish.id], delta: 20);
      await sync.syncNow();
      final second = dishChange(server.pushes.last);

      await store.adjustDishPrices([dish.id], delta: -20); // back to A
      await sync.syncNow();
      final third = dishChange(server.pushes.last);

      expect({first, second, third}, hasLength(3),
          reason: 'A → B → A must be three different changes');
      expect(third.split(':')[3], first.split(':')[3],
          reason: 'same content hash as the first push');
      expect(await sync.pendingChanges(), 0);
    });

    test('a retry after a network failure keeps its change id', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final server = fakeServer();
      final sync = CloudSyncService(
          db: db,
          api: server.api,
          deviceId: 'dev-1',
          pullModules: const {},
          pushModules: {SyncModule.master});
      await DriftMasterStore(db)
          .upsertDish(MasterCatalogData.sampleDishes.first);
      await sync.syncNow(); // first batch accepted
      await DriftMasterStore(db).adjustDishPrices(
          [MasterCatalogData.sampleDishes.first.id],
          delta: 5);
      expect(await sync.pendingChanges(), 1);

      server.offline(true);
      await sync.syncNow();
      expect(sync.status.phase, SyncPhase.offline);
      expect(sync.status.waiting, 1, reason: 'offline shows what is unsent');

      server.offline(false);
      final before = server.pushes.length;
      await sync.syncNow();
      expect(server.pushes.length, before + 1);
      expect(await sync.pendingChanges(), 0);
    });
  });

  group('device binding', () {
    test('first sign-in: demo data on the device is wiped, then bound',
        () async {
      final db = memoryDb();
      addTearDown(db.close);
      await DriftMasterStore(db)
          .upsertDish(MasterCatalogData.sampleDishes.first);
      final binding = DeviceBinding(db);
      expect(await binding.hasLocalData(), isTrue);
      expect((await binding.current()).organizationId, isNull);

      await binding.wipe();
      await binding.bind('org-a', 'branch-1', 'Spicy Bistro · Delhi');
      expect(await binding.hasLocalData(), isFalse);
      final b = await binding.current();
      expect(binding.matches(b, 'org-a', 'branch-1'), isTrue);
      expect(binding.matches(b, 'org-b', 'branch-1'), isFalse);
      expect(binding.matches(b, 'org-a', 'branch-2'), isFalse);
    });

    test('an organization without branches still matches itself', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final binding = DeviceBinding(db);
      await binding.bind('org-a', null, 'Solo Cafe');
      expect(binding.matches(await binding.current(), 'org-a', null), isTrue);
    });

    test('wipe keeps the device id and removes other settings', () async {
      final db = memoryDb();
      addTearDown(db.close);
      for (final (k, v) in [
        ('device_id', 'dev-9'),
        ('sync_cursor:orders', 'x')
      ]) {
        await db
            .into(db.appMetadata)
            .insert(AppMetadataCompanion.insert(key: k, value: v));
      }
      await DeviceBinding(db).wipe();
      final keys = [
        for (final r in await db.select(db.appMetadata).get()) r.key
      ];
      expect(keys, ['device_id']);
    });

    test('an older database file is brought up to date and can be wiped',
        () async {
      // What a web tab of an older app version leaves behind: version 3,
      // without the tables added since.
      final db = memoryDb();
      addTearDown(db.close);
      await DriftMasterStore(db)
          .upsertDish(MasterCatalogData.sampleDishes.first);
      await db.customStatement('DROP TABLE deliveries_table');
      await db.customStatement('DROP TABLE sync_row_states');
      await db.customStatement('PRAGMA user_version = 3');
      Future<Set<String>> tables() async => {
            for (final r in await db
                .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'")
                .get())
              r.read<String>('name')
          };

      // Even before the repair, switching restaurants can wipe it.
      final binding = DeviceBinding(db);
      expect(await binding.hasLocalData(), isTrue);
      await binding.wipe();
      expect(await binding.hasLocalData(), isFalse);

      await db.ensureSchema();
      expect(await tables(),
          containsAll(['deliveries_table', 'sync_row_states']));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), db.schemaVersion);
      await db.ensureSchema(); // a second start changes nothing
    });

    test('two devices of one branch never make the same order or KOT id',
        () async {
      // A till and the owner's laptop, both offline, each take an order.
      const line = OpsOrderLine(
          itemId: 'dosa', name: 'Masala Dosa', unitMinor: 12000, quantity: 1);
      Future<(String, String)> takeOrder(String deviceId) async {
        final db = memoryDb();
        addTearDown(db.close);
        await db.into(db.appMetadata).insert(
            AppMetadataCompanion.insert(key: 'device_id', value: deviceId));
        final ops = DriftOperationsStore(db);
        final order =
            await ops.placeOrder(channel: OpsChannel.takeaway, lines: [line]);
        final kot = (await ops.getKots()).single.ticketId;
        // The other device's orders arrive by sync; this device's own
        // numbering carries on regardless.
        await ops.placeOrder(channel: OpsChannel.takeaway, lines: [line]);
        return (order, kot);
      }

      final till = await takeOrder('a1b2c3d4-0000-4000-8000-000000000001');
      final laptop = await takeOrder('f9e8d7c6-0000-4000-8000-000000000002');
      expect(till.$1, 'ORD-A1B2C-9981');
      expect(laptop.$1, 'ORD-F9E8D-9981');
      expect(till.$2, isNot(laptop.$2));
      expect(till.$2, startsWith('KOT-A1B2C-'));
    });

    test('unsent changes are detected before switching restaurants', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final server = fakeServer();
      final sync = CloudSyncService(
          db: db,
          api: server.api,
          deviceId: 'dev-1',
          pullModules: const {},
          pushModules: SyncModule.values.toSet());
      await DriftMasterStore(db)
          .upsertDish(MasterCatalogData.sampleDishes.first);
      expect(await sync.pendingChanges(), greaterThan(0));
      await sync.syncNow();
      expect(await sync.pendingChanges(), 0);
    });
  });

  group('offline session grant', () {
    SavedLogin saved(DateTime? verifiedAt) => SavedLogin(
        session: const ApiSession(
            accessToken: 't',
            refreshToken: 't',
            expiresAt: 0,
            userId: 'u',
            email: 'e'),
        verifiedAt: verifiedAt);

    test('24 hours after the last server contact the grant expires', () {
      final now = DateTime(2026, 9, 29, 12);
      expect(saved(now.subtract(const Duration(hours: 23))).offlineExpired(now),
          isFalse);
      expect(saved(now.subtract(const Duration(hours: 25))).offlineExpired(now),
          isTrue);
      expect(saved(null).offlineExpired(now), isTrue,
          reason: 'never confirmed by the server');
    });

    test('the confirmation time survives a restart', () {
      final at = DateTime.utc(2026, 9, 29, 8, 30);
      final json = jsonDecode(jsonEncode(saved(at).toJson()));
      expect(SavedLogin.fromJson((json as Map).cast()).verifiedAt, at);
    });
  });
}

class _Offline implements Exception {
  const _Offline();
  @override
  String toString() => 'no route to host';
}
