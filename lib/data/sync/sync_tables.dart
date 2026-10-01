import 'package:drift/drift.dart';

/// Sync bookkeeping (schema v6): for every device row that has been
/// synchronized with the backend, the hash of its content at that moment
/// and the server's version. A row whose current hash differs has local
/// changes to push; a row with a state but no longer on the device was
/// deleted locally. Stays on the device — it is never synced itself.
@DataClassName('SyncRowStateRow')
class SyncRowStates extends Table {
  /// Drift table name of the synced row.
  TextColumn get localTable => text()();

  /// Primary-key values joined with "|".
  TextColumn get rowKey => text()();

  /// The primary-key columns as JSON (for building delete changes).
  TextColumn get keyJson => text()();

  /// Content hash when last in sync with the server.
  TextColumn get rowHash => text()();

  /// Server version (update timestamp) last seen, for conflict checks.
  TextColumn get serverVersion => text().nullable()();

  /// synced | conflict | rejected
  TextColumn get status => text().withDefault(const Constant('synced'))();

  /// Content hash the server refused (conflict / permanent rejection);
  /// that exact content isn't re-sent until it changes.
  TextColumn get rejectedHash => text().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localTable, rowKey};
}
