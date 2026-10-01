import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// One device keeps the local data of one restaurant branch.
///
/// The POS works offline from its local database, so a device signed in to
/// restaurant A must never show A's orders to restaurant B, nor upload them
/// into B. The first sign-in binds the device to its organization and
/// branch; signing in to another one wipes the local data first — and is
/// refused while the device still holds unsent changes of the previous one.
class DeviceBinding {
  DeviceBinding(this.db);
  final AppDatabase db;

  static const _org = 'bound_organization_id';
  static const _location = 'bound_location_id';
  static const _label = 'bound_label';

  Future<String?> _get(String key) async =>
      (await (db.select(db.appMetadata)..where((m) => m.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Future<({String? organizationId, String? locationId, String? label})>
      current() async => (
            organizationId: await _get(_org),
            locationId: await _get(_location),
            label: await _get(_label),
          );

  bool matches(({String? organizationId, String? locationId, String? label}) b,
          String organizationId, String? locationId) =>
      b.organizationId == organizationId &&
      (b.locationId ?? '') == (locationId ?? '');

  Future<void> bind(
      String organizationId, String? locationId, String label) async {
    for (final (k, v) in [
      (_org, organizationId),
      (_location, locationId ?? ''),
      (_label, label),
    ]) {
      await db.into(db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(key: k, value: v));
    }
  }

  /// Tables that exist in the database file (an older file may lack some).
  Future<Set<String>> _existing() async => {
        for (final r in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
          r.read<String>('name')
      };

  /// True when any business table holds rows.
  Future<bool> hasLocalData() async {
    final existing = await _existing();
    for (final t in db.allTables) {
      final name = t.actualTableName;
      if (name == 'app_metadata' || name == 'sync_row_states') continue;
      if (!existing.contains(name)) continue;
      final r = await db.customSelect(
          'SELECT EXISTS(SELECT 1 FROM "$name") AS x',
          readsFrom: {t}).getSingle();
      if (r.read<int>('x') == 1) return true;
    }
    return false;
  }

  /// Deletes every business row and every setting except this device's id.
  Future<void> wipe() => db.transaction(() async {
        final existing = await _existing();
        for (final t in db.allTables) {
          if (t.actualTableName == 'app_metadata') continue;
          if (!existing.contains(t.actualTableName)) continue;
          await db.delete(t).go();
        }
        await (db.delete(db.appMetadata)
              ..where((m) => m.key.equals('device_id').not()))
            .go();
      });
}
