import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/api/api_client.dart';
import '../data/app_database.dart';
import '../data/drift_operations_store.dart';
import '../data/sync/sync_contract.dart';

enum SyncPhase { idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus(
      {required this.phase,
      this.lastSyncedAt,
      this.waiting = 0,
      this.needsReview = 0,
      this.message});
  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// Local changes not yet accepted by the server.
  final int waiting;

  /// Changes the server refused or flagged as conflicts.
  final int needsReview;
  final String? message;

  String get label => switch (phase) {
        SyncPhase.syncing => 'Syncing…',
        SyncPhase.offline =>
          'Offline${waiting > 0 ? ' · $waiting waiting' : ''}',
        SyncPhase.error => message ?? 'Sync error',
        SyncPhase.idle => needsReview > 0
            ? 'Synced · $needsReview need review'
            : lastSyncedAt == null
                ? 'Not synced yet'
                : 'Synced',
      };
}

class SyncReport {
  int pushed = 0, accepted = 0, duplicates = 0, rejected = 0, conflicts = 0;
  int pulled = 0, deleted = 0;
  @override
  String toString() =>
      'pushed $pushed (accepted $accepted, duplicate $duplicates, rejected $rejected, conflict $conflicts), pulled $pulled, deleted $deleted';
}

/// Keeps the device's Drift tables and the central database in step,
/// through the backend's /v1/sync API — the app never writes to Supabase
/// itself (PRD §6: one local write path; the sync adapter uploads).
///
/// Each run pulls first (the central record wins for rows this device has
/// never synchronized — e.g. a fresh install enrolling into a branch), then
/// pushes local changes in dependency order. A row changed locally since
/// its last sync is never overwritten by a pull; a rejected or conflicting
/// change stays on the device, flagged for review, never deleted.
class CloudSyncService {
  CloudSyncService({
    required this.db,
    required this.api,
    required this.deviceId,
    Set<SyncModule>? pushModules,
    Set<SyncModule>? pullModules,
    DateTime Function()? clock,
  })  : pushModules = pushModules ?? SyncModule.values.toSet(),
        pullModules = pullModules ?? SyncModule.values.toSet(),
        _now = clock ?? DateTime.now;

  final AppDatabase db;
  final ProviyaaApiClient api;
  final String deviceId;
  Set<SyncModule> pushModules;
  Set<SyncModule> pullModules;
  final DateTime Function() _now;

  static const _batch = 200;
  static const _transient = {
    'reference_missing',
    'database_error',
    'internal',
    'schema_mismatch',
    'network',
    'timeout',
  };

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus(phase: SyncPhase.idle);
  SyncStatus get status => _status;
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  Future<SyncReport>? _running;
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<Set<TableUpdate>>? _updates;
  bool _applying = false;

  static const _bookkeepingTables = {'sync_row_states', 'app_metadata'};

  late final Map<String, TableInfo> _tables = {
    for (final t in db.allTables) t.actualTableName: t
  };

  void _emit(SyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  /// Syncs now, every [every], and a few seconds after local edits.
  void start({Duration every = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => syncNow());
    _updates?.cancel();
    _updates = db.tableUpdates().listen((updates) {
      if (_applying) return;
      // The sync's own bookkeeping (row states, cursors) is not a local
      // edit: reacting to it would re-sync every few seconds forever.
      if (updates.every((u) => _bookkeepingTables.contains(u.table))) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), syncNow);
    });
    syncNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _debounce?.cancel();
    await _updates?.cancel();
    _timer = null;
    _updates = null;
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  /// One sync run; concurrent callers share the run in progress.
  Future<SyncReport> syncNow() =>
      _running ??= _run().whenComplete(() => _running = null);

  Future<SyncReport> _run() async {
    final report = SyncReport();
    _emit(SyncStatus(
        phase: SyncPhase.syncing,
        lastSyncedAt: _status.lastSyncedAt,
        waiting: _status.waiting,
        needsReview: _status.needsReview));
    try {
      await _pull(report);
      final waiting = await _push(report);
      _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: _now(),
          waiting: waiting,
          needsReview: await _reviewCount()));
    } on ApiException catch (e) {
      _emit(SyncStatus(
          phase: e.isNetwork ? SyncPhase.offline : SyncPhase.error,
          lastSyncedAt: _status.lastSyncedAt,
          // What is actually still unsent on this device.
          waiting: await pendingChanges().catchError((_) => _status.waiting),
          needsReview: _status.needsReview,
          message: e.message));
    }
    return report;
  }

  // ── row encoding ────────────────────────────────────────────────────

  TableInfo _table(SyncTableSpec spec) => _tables[spec.localTable]!;

  Object? _toWire(GeneratedColumn c, Object? raw) {
    if (raw == null) return null;
    final v = db.typeMapping.read(c.type as DriftSqlType<Object>, raw);
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is Uint8List) return base64Encode(v);
    return v;
  }

  Object? _fromWire(GeneratedColumn c, Object? v) {
    if (v == null) return null;
    final t = c.type;
    if (t == DriftSqlType.dateTime) return DateTime.parse(v as String);
    if (t == DriftSqlType.bool) return v as bool;
    if (t == DriftSqlType.int || t == DriftSqlType.bigInt) {
      return (v as num).toInt();
    }
    if (t == DriftSqlType.double) return (v as num).toDouble();
    if (t == DriftSqlType.blob) return base64Decode(v as String);
    return v.toString();
  }

  static String _canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${_canonical(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_canonical).join(',')}]';
    return jsonEncode(v);
  }

  static String _hash(Map<String, Object?> wire) =>
      sha256.convert(utf8.encode(_canonical(wire))).toString();

  String _key(TableInfo t, Map<String, Object?> wire) =>
      t.$primaryKey.map((c) => '${wire[c.name]}').join('|');

  Map<String, Object?> _keyColumns(TableInfo t, Map<String, Object?> wire) =>
      {for (final c in t.$primaryKey) c.name: wire[c.name]};

  Future<Map<String, Map<String, Object?>>> _localRows(
      SyncTableSpec spec) async {
    final t = _table(spec);
    var sql = 'SELECT * FROM "${t.actualTableName}"';
    final vars = <Variable>[];
    if (spec.onlyKeys != null) {
      sql += ' WHERE "key" IN (${spec.onlyKeys!.map((_) => '?').join(', ')})';
      vars.addAll(spec.onlyKeys!.map(Variable.withString));
    }
    final rows =
        await db.customSelect(sql, variables: vars, readsFrom: {t}).get();
    final out = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final wire = {
        for (final c in t.$columns) c.name: _toWire(c, r.data[c.name])
      };
      out[_key(t, wire)] = wire;
    }
    return out;
  }

  Future<Map<String, SyncRowStateRow>> _states(String table) async {
    final rows = await (db.select(db.syncRowStates)
          ..where((s) => s.localTable.equals(table)))
        .get();
    return {for (final r in rows) r.rowKey: r};
  }

  Future<void> _saveState(TableInfo t, Map<String, Object?> wire,
      {String? version,
      String status = 'synced',
      String? rejectedHash,
      String? error,
      String? hashOverride}) async {
    await db.into(db.syncRowStates).insertOnConflictUpdate(
        SyncRowStatesCompanion.insert(
            localTable: t.actualTableName,
            rowKey: _key(t, wire),
            keyJson: jsonEncode(_keyColumns(t, wire)),
            rowHash: hashOverride ?? _hash(wire),
            serverVersion: Value(version),
            status: Value(status),
            rejectedHash: Value(rejectedHash),
            lastError: Value(error),
            syncedAt: _now()));
  }

  static int _generation(SyncRowStateRow? st) =>
      st?.syncedAt.millisecondsSinceEpoch ?? 0;

  /// A row whose deletion the server accepted: remembered (with an empty
  /// hash) so that re-creating it later is a new change, not a replay.
  Future<void> _tombstone(String table, String key) =>
      (db.update(db.syncRowStates)
            ..where((s) => s.localTable.equals(table) & s.rowKey.equals(key)))
          .write(SyncRowStatesCompanion(
              rowHash: const Value(''),
              status: const Value('deleted'),
              syncedAt: Value(_now())));

  /// Local changes not yet accepted by the server (what a sync would send).
  Future<int> pendingChanges() async {
    var n = 0;
    for (final spec in syncTables) {
      if (!pushModules.contains(spec.module)) continue;
      final local = await _localRows(spec);
      final states = await _states(spec.localTable);
      for (final MapEntry(key: key, value: wire) in local.entries) {
        final hash = _hash(wire);
        final st = states[key];
        if (st != null && st.rowHash == hash) continue;
        if (st?.rejectedHash == hash) continue;
        n++;
      }
      for (final st in states.values) {
        if (!local.containsKey(st.rowKey) && st.status == 'synced') n++;
      }
    }
    return n;
  }

  Future<void> _dropState(String table, String key) =>
      (db.delete(db.syncRowStates)
            ..where((s) => s.localTable.equals(table) & s.rowKey.equals(key)))
          .go();

  Future<int> _reviewCount() async {
    final rows = await (db.select(db.syncRowStates)
          ..where((s) => s.status.isIn(['conflict', 'rejected'])))
        .get();
    return rows.length;
  }

  // ── pull ────────────────────────────────────────────────────────────

  Future<String?> _cursor(String resource) async {
    final row = await (db.select(db.appMetadata)
          ..where((m) => m.key.equals('sync_cursor:$resource')))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setCursor(String resource, String cursor) => db
      .into(db.appMetadata)
      .insertOnConflictUpdate(AppMetadataCompanion.insert(
          key: 'sync_cursor:$resource', value: cursor));

  Future<void> _pull(SyncReport report) async {
    final specs =
        syncTables.where((s) => pullModules.contains(s.module)).toList();
    var pending = {for (final s in specs) s.resource: s};
    final touchedOrders = <String>{};
    for (var round = 0; round < 20 && pending.isNotEmpty; round++) {
      final cursors = <String, String?>{
        for (final r in pending.keys) r: await _cursor(r)
      };
      final data = await api.postLong('v1/sync/pull',
          {'resources': pending.keys.toList(), 'cursors': cursors}) as Map;
      final pages = (data['resources'] as Map).cast<String, dynamic>();
      final next = <String, SyncTableSpec>{};
      for (final entry in pages.entries) {
        final spec = pending[entry.key];
        final page = (entry.value as Map).cast<String, dynamic>();
        if (spec == null || page.containsKey('error')) continue;
        await _applyPage(spec, page, report, touchedOrders);
        final cursor = page['cursor'] as String?;
        if (cursor != null) await _setCursor(spec.resource, cursor);
        if (page['more'] == true) next[spec.resource] = spec;
      }
      pending = next;
    }
    if (touchedOrders.isNotEmpty) {
      final ops = DriftOperationsStore(db);
      for (final id in touchedOrders) {
        await ops.upsertAllOrdersRow(id);
      }
    }
  }

  Future<void> _applyPage(SyncTableSpec spec, Map<String, dynamic> page,
      SyncReport report, Set<String> touchedOrders) async {
    final t = _table(spec);
    final rows = (page['rows'] as List)
        .map((r) => (r as Map).cast<String, Object?>())
        .toList();
    final deleted = (page['deleted'] as List)
        .map((r) => (r as Map).cast<String, Object?>())
        .toList();
    final versions =
        (page['versions'] as Map? ?? const {}).cast<String, dynamic>();
    if (rows.isEmpty && deleted.isEmpty && page['snapshot'] != true) return;

    _applying = true;
    try {
      await db.transaction(() async {
        final states = await _states(spec.localTable);
        final local = await _localRows(spec);
        bool modified(String key) {
          final st = states[key];
          final l = local[key];
          return st != null && l != null && _hash(l) != st.rowHash;
        }

        final seen = <String>{};
        for (final wire in rows) {
          final key = _key(t, wire);
          seen.add(key);
          if (modified(key)) continue; // local edit wins until pushed
          await _write(t, wire);
          final stored = (await _readOne(spec, t, wire)) ?? wire;
          await _saveState(t, stored, version: versions[key] as String?);
          report.pulled++;
          if (spec.localTable == 'orders') {
            touchedOrders.add('${wire['client_order_id']}');
          }
          if (spec.localTable == 'order_lines' ||
              spec.localTable == 'payments') {
            touchedOrders.add('${wire['client_order_id']}');
          }
        }
        for (final keyCols in deleted) {
          final key = _key(t, keyCols);
          if (modified(key)) continue;
          await _deleteRow(t, keyCols);
          await _dropState(spec.localTable, key);
          report.deleted++;
        }
        if (page['snapshot'] == true) {
          for (final st in states.values) {
            if (seen.contains(st.rowKey) || st.status != 'synced') continue;
            if (modified(st.rowKey)) continue;
            final keyCols =
                (jsonDecode(st.keyJson) as Map).cast<String, Object?>();
            await _deleteRow(t, keyCols);
            await _dropState(spec.localTable, st.rowKey);
            report.deleted++;
          }
        }
      });
    } finally {
      _applying = false;
    }
  }

  Future<Map<String, Object?>?> _readOne(
      SyncTableSpec spec, TableInfo t, Map<String, Object?> wire) async {
    final pk = t.$primaryKey.toList();
    final rows = await db.customSelect(
        'SELECT * FROM "${t.actualTableName}" WHERE ${pk.map((c) => '"${c.name}" = ?').join(' AND ')}',
        variables: [
          for (final c in pk) Variable<Object>(_fromWire(c, wire[c.name]))
        ],
        readsFrom: {
          t
        }).get();
    if (rows.isEmpty) return null;
    return {
      for (final c in t.$columns) c.name: _toWire(c, rows.first.data[c.name])
    };
  }

  Future<void> _write(TableInfo t, Map<String, Object?> wire) async {
    final cols = t.$columns.where((c) => wire.containsKey(c.name)).toList();
    await db.customUpdate(
      'INSERT OR REPLACE INTO "${t.actualTableName}" '
      '(${cols.map((c) => '"${c.name}"').join(', ')}) '
      'VALUES (${cols.map((_) => '?').join(', ')})',
      variables: [
        for (final c in cols) Variable<Object>(_fromWire(c, wire[c.name]))
      ],
      updates: {t},
      updateKind: UpdateKind.insert,
    );
  }

  Future<void> _deleteRow(TableInfo t, Map<String, Object?> keyCols) async {
    final pk = t.$primaryKey.toList();
    await db.customUpdate(
      'DELETE FROM "${t.actualTableName}" WHERE ${pk.map((c) => '"${c.name}" = ?').join(' AND ')}',
      variables: [
        for (final c in pk) Variable<Object>(_fromWire(c, keyCols[c.name]))
      ],
      updates: {t},
      updateKind: UpdateKind.delete,
    );
  }

  // ── push ────────────────────────────────────────────────────────────

  /// Returns how many local changes are still waiting after the push.
  Future<int> _push(SyncReport report) async {
    final changes = <Map<String, Object?>>[];
    final meta = <String,
        ({
      SyncTableSpec spec,
      Map<String, Object?> wire,
      String hash,
      bool delete
    })>{};
    for (final spec in syncTables) {
      if (!pushModules.contains(spec.module)) continue;
      final t = _table(spec);
      final local = await _localRows(spec);
      final states = await _states(spec.localTable);
      for (final MapEntry(key: key, value: wire) in local.entries) {
        final hash = _hash(wire);
        final st = states[key];
        if (st != null && st.rowHash == hash) continue;
        // Refused as-is: wait for an edit.
        if (st?.rejectedHash == hash) continue;
        // The generation (time of the row's last accepted change, or its
        // deletion) makes a later change back to an earlier value a new
        // change; a retry of the same unsent change keeps its id.
        final id =
            '$deviceId:${spec.localTable}:$key:${hash.substring(0, 20)}:${_generation(st)}';
        changes.add({
          'change_id': id,
          'resource': spec.resource,
          'op': 'upsert',
          'row': wire,
          'base_version': st?.serverVersion,
        });
        meta[id] = (spec: spec, wire: wire, hash: hash, delete: false);
      }
      for (final st in states.values) {
        if (local.containsKey(st.rowKey) || st.status != 'synced') continue;
        final keyCols = (jsonDecode(st.keyJson) as Map).cast<String, Object?>();
        final id =
            '$deviceId:${spec.localTable}:${st.rowKey}:deleted:${_generation(st)}';
        changes.add({
          'change_id': id,
          'resource': spec.resource,
          'op': 'delete',
          'row': keyCols,
        });
        meta[id] = (spec: spec, wire: keyCols, hash: '', delete: true);
        assert(t.actualTableName == spec.localTable);
      }
    }

    var waiting = 0;
    final syncedOrders = <String>[];
    for (var i = 0; i < changes.length; i += _batch) {
      final chunk = changes.sublist(
          i, i + _batch > changes.length ? changes.length : i + _batch);
      report.pushed += chunk.length;
      final data =
          await api.postLong('v1/sync/push', {'changes': chunk}) as Map;
      final results = (data['results'] as List).cast<Map>();
      for (final r in results) {
        final m = meta[r['change_id']];
        if (m == null) continue;
        final t = _table(m.spec);
        final status = r['status'] as String;
        final err = r['error'] is Map
            ? '${(r['error'] as Map)['code']}: ${(r['error'] as Map)['message']}'
            : null;
        switch (status) {
          case 'accepted':
          case 'duplicate':
            status == 'accepted' ? report.accepted++ : report.duplicates++;
            if (m.delete) {
              await _tombstone(m.spec.localTable, _key(t, m.wire));
            } else {
              await _saveState(t, m.wire, version: r['version'] as String?);
              if (m.spec.localTable == 'orders') {
                syncedOrders.add('${m.wire['client_order_id']}');
              }
            }
          case 'conflict':
            report.conflicts++;
            await _markRefused(t, m.wire, m.hash, 'conflict', err);
          default:
            report.rejected++;
            final code = (r['error'] as Map?)?['code'] as String?;
            if (_transient.contains(code)) {
              waiting++;
            } else {
              await _markRefused(t, m.wire, m.hash, 'rejected', err);
            }
        }
      }
    }
    if (syncedOrders.isNotEmpty) await _markOrdersSynchronized(syncedOrders);
    return waiting;
  }

  Future<void> _markRefused(TableInfo t, Map<String, Object?> wire, String hash,
      String status, String? error) async {
    final existing = await (db.select(db.syncRowStates)
          ..where((s) =>
              s.localTable.equals(t.actualTableName) &
              s.rowKey.equals(_key(t, wire))))
        .getSingleOrNull();
    await _saveState(t, wire,
        // Keep the last in-sync hash so the row still counts as changed.
        hashOverride: existing?.rowHash ?? '',
        version: existing?.serverVersion,
        status: status,
        rejectedHash: hash,
        error: error);
  }

  /// The POS's own sync status on orders (and its upload intents) — the
  /// server now holds them.
  Future<void> _markOrdersSynchronized(List<String> ids) async {
    final spec = syncTables.firstWhere((s) => s.localTable == 'orders');
    final t = _table(spec);
    _applying = true;
    try {
      await (db.update(db.orders)..where((o) => o.clientOrderId.isIn(ids)))
          .write(const OrdersCompanion(status: Value('synchronized')));
      await (db.update(db.pendingUploadIntents)
            ..where(
                (p) => p.clientOrderId.isIn(ids) & p.state.equals('queued')))
          .write(const PendingUploadIntentsCompanion(
              state: Value('synchronized')));
      final states = await _states('orders');
      for (final id in ids) {
        final row = await _readOne(spec, t, {'client_order_id': id});
        final st = states[id];
        if (row != null && st != null) {
          await _saveState(t, row, version: st.serverVersion);
        }
      }
    } finally {
      _applying = false;
    }
  }
}
