import 'package:drift/drift.dart';

import '../domain/operations.dart' show orderNumberLabel;
import '../domain/restaurant_table.dart';
import 'app_database.dart';

class DriftTableStore {
  DriftTableStore(this.db);
  final AppDatabase db;

  RestaurantTable _toDomain(RestaurantTableRow r) {
    final zone = TableZone.values.firstWhere(
      (z) => z.name == r.zone,
      orElse: () => TableZone.indoor,
    );
    final status = TableStatus.values.firstWhere(
      (s) => s.name == r.status,
      orElse: () => TableStatus.available,
    );
    return RestaurantTable(
      id: r.id,
      label: r.label,
      seats: r.seats,
      zone: zone,
      status: status,
      guestCount: r.guestCount,
      elapsedMinutes: r.elapsedMinutes,
      orderTotalMinor: r.orderTotalMinor,
      reservedByName: r.reservedByName,
      reservedAt: r.reservedAt,
    );
  }

  /// Real-time stream of all tables from SQLite.
  Stream<List<RestaurantTable>> watchTables() {
    return db.select(db.restaurantTables).watch().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  /// Fetch all tables once.
  Future<List<RestaurantTable>> getAllTables() async {
    final rows = await db.select(db.restaurantTables).get();
    return rows.map(_toDomain).toList();
  }

  /// The id of the open (or awaiting-payment) order [tableId] is holding,
  /// null when it has none. A link to an order that is already settled or
  /// cancelled does not count.
  Future<String?> openOrderIdOf(String tableId) async {
    final row = await (db.select(db.restaurantTables)
          ..where((t) => t.id.equals(tableId)))
        .getSingleOrNull();
    final orderId = row?.currentOrderId;
    if (orderId == null) return null;
    final order = await (db.select(db.orders)
          ..where((o) => o.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    if (order == null) return null;
    return order.opsStatus == 'open' || order.opsStatus == 'billed'
        ? orderId
        : null;
  }

  /// Freeing, re-reserving or deleting a table that still holds an open
  /// order would hide that order from the floor — refused with a message.
  Future<void> _refuseWithOpenOrder(String tableId, String action) async {
    final orderId = await openOrderIdOf(tableId);
    if (orderId != null) {
      final table = await (db.select(db.restaurantTables)
            ..where((t) => t.id.equals(tableId)))
          .getSingleOrNull();
      final order = await (db.select(db.orders)
            ..where((o) => o.clientOrderId.equals(orderId)))
          .getSingleOrNull();
      final label = table?.label.trim() ?? '';
      throw StateError('${label.isEmpty ? 'This table' : label} has open '
          'order ${orderNumberLabel(orderId, order?.displayNo)} — settle, '
          'cancel or move it before you $action.');
    }
  }

  static String _statusWord(TableStatus s) => switch (s) {
        TableStatus.available => 'available',
        TableStatus.occupied => 'occupied',
        TableStatus.reserved => 'reserved',
        TableStatus.cleaning => 'for cleaning',
      };

  /// CREATE: Insert a new table.
  Future<void> insertTable(RestaurantTable table) async {
    await db.into(db.restaurantTables).insertOnConflictUpdate(
          RestaurantTablesCompanion.insert(
            id: table.id,
            label: table.label,
            seats: table.seats,
            zone: table.zone.name,
            status: table.status.name,
            guestCount: Value(table.guestCount),
            elapsedMinutes: Value(table.elapsedMinutes),
            orderTotalMinor: Value(table.orderTotalMinor),
            reservedByName: Value(table.reservedByName),
            reservedAt: Value(table.reservedAt),
          ),
        );
  }

  /// UPDATE: Update an existing table. While the table holds an open order
  /// its status cannot move away from occupied and it cannot be renamed
  /// (the order refers to the table by its label).
  Future<void> updateTable(RestaurantTable table) async {
    if (table.status != TableStatus.occupied) {
      await _refuseWithOpenOrder(
          table.id, 'mark it ${_statusWord(table.status)}');
    }
    final current = await (db.select(db.restaurantTables)
          ..where((t) => t.id.equals(table.id)))
        .getSingleOrNull();
    if (current != null && current.label != table.label) {
      await _refuseWithOpenOrder(table.id, 'rename it');
    }
    await (db.update(db.restaurantTables)..where((t) => t.id.equals(table.id)))
        .write(
      RestaurantTablesCompanion(
        label: Value(table.label),
        seats: Value(table.seats),
        zone: Value(table.zone.name),
        status: Value(table.status.name),
        guestCount: Value(table.guestCount),
        elapsedMinutes: Value(table.elapsedMinutes),
        orderTotalMinor: Value(table.orderTotalMinor),
        reservedByName: Value(table.reservedByName),
        reservedAt: Value(table.reservedAt),
      ),
    );
  }

  /// UPDATE: Quick status update (e.g. Cleaning -> Available). Refused
  /// while the table holds an open order (except to mark it occupied).
  /// Freeing a table (available / cleaning) also clears its guests and
  /// seating time; marking it available stamps when it was cleaned.
  Future<void> updateStatus(String tableId, TableStatus status) async {
    if (status != TableStatus.occupied) {
      await _refuseWithOpenOrder(tableId, 'mark it ${_statusWord(status)}');
    }
    final freed =
        status == TableStatus.available || status == TableStatus.cleaning;
    await (db.update(db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(
      RestaurantTablesCompanion(
        status: Value(status.name),
        guestCount: freed ? const Value(null) : const Value.absent(),
        seatedAt: freed ? const Value(null) : const Value.absent(),
        elapsedMinutes: freed ? const Value(null) : const Value.absent(),
        orderTotalMinor: freed ? const Value(null) : const Value.absent(),
        currentOrderId: freed ? const Value(null) : const Value.absent(),
        paymentPending: freed ? const Value(false) : const Value.absent(),
        lastCleanedAt: status == TableStatus.available
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
  }

  /// DELETE: Remove a table from SQLite. Refused while it holds an open
  /// order.
  Future<void> deleteTable(String tableId) async {
    await _refuseWithOpenOrder(tableId, 'delete it');
    await (db.delete(db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .go();
  }
}
