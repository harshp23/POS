import 'package:drift/drift.dart';

import '../application/order_service.dart';
import '../domain/order.dart';
import 'app_database.dart';

/// [PosLocalStore] backed by the on-device Drift/SQLite database
/// ([AppDatabase]). Central Postgres remains the reconciled business
/// record — this only holds this device's working data and unsent
/// pending-upload intents until the sync adapter ships them.
class DriftLocalStore implements PosLocalStore {
  DriftLocalStore(this._db);
  final AppDatabase _db;

  /// The device database (screens that only receive this store build the
  /// Operations store on it).
  AppDatabase get db => _db;

  @override
  Future<void> saveOrderWithPendingIntent(LocalOrder order) {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.orders)
            ..where((t) => t.clientOrderId.equals(order.clientOrderId)))
          .getSingleOrNull();
      if (existing != null) {
        // We already have this order locally: a retried/replayed save is
        // a no-op, so duplicate submission produces one business effect.
        return;
      }

      await _db.into(_db.orders).insert(OrdersCompanion.insert(
          clientOrderId: order.clientOrderId,
          locationId: order.locationId,
          currencyCode: order.currencyCode,
          status: order.status.name,
          orderType: order.orderType.name,
          tableLabel: Value(order.tableLabel)));

      for (final line in order.lines) {
        await _db.into(_db.orderLines).insert(OrderLinesCompanion.insert(
            clientOrderId: order.clientOrderId,
            itemId: line.itemId,
            name: line.name,
            unitMinor: line.unitMinor,
            quantity: line.quantity));
      }

      await _db.into(_db.pendingUploadIntents).insert(
          PendingUploadIntentsCompanion.insert(
              intentId: '${order.clientOrderId}:create-order',
              clientOrderId: order.clientOrderId,
              operation: 'create-order',
              payloadHash: _payloadHash(order)),
          mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<LocalOrder?> findOrder(String clientOrderId) async {
    final row = await (_db.select(_db.orders)
          ..where((t) => t.clientOrderId.equals(clientOrderId)))
        .getSingleOrNull();
    if (row == null) return null;

    final lineRows = await (_db.select(_db.orderLines)
          ..where((t) => t.clientOrderId.equals(clientOrderId)))
        .get();

    return LocalOrder(
        clientOrderId: row.clientOrderId,
        locationId: row.locationId,
        currencyCode: row.currencyCode,
        status: LocalOrderStatus.values.byName(row.status),
        orderType: OrderType.values.byName(row.orderType),
        tableLabel: row.tableLabel,
        lines: lineRows
            .map((l) => OrderLine(
                itemId: l.itemId,
                name: l.name,
                unitMinor: l.unitMinor,
                quantity: l.quantity))
            .toList(growable: false));
  }

  /// Sum of order subtotals for orders created at/after [since]. Used to
  /// compute a shift's expected cash (PRD §9: "Shift expected cash
  /// equals opening float plus cash receipts"). V1 treats every locally
  /// saved order as a cash receipt (cash-first pilot, D03) — this will
  /// need to exclude non-cash tenders once digital payment capture
  /// exists.
  Future<int> cashReceiptsMinorSince(DateTime since) async {
    final orders = await (_db.select(_db.orders)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(since)))
        .get();
    var total = 0;
    for (final order in orders) {
      final lines = await (_db.select(_db.orderLines)
            ..where((t) => t.clientOrderId.equals(order.clientOrderId)))
          .get();
      total += lines.fold(0, (sum, l) => sum + l.unitMinor * l.quantity);
    }
    return total;
  }

  /// Not a security hash — just enough to tell "same order content" apart
  /// from "same id, different content" if that ever needs auditing later.
  static String _payloadHash(LocalOrder order) {
    final buffer = StringBuffer()
      ..write(order.clientOrderId)
      ..write('|')
      ..write(order.locationId)
      ..write('|')
      ..write(order.currencyCode);
    for (final line in order.lines) {
      buffer
        ..write('|')
        ..write(line.itemId)
        ..write(':')
        ..write(line.quantity)
        ..write(':')
        ..write(line.unitMinor);
    }
    return buffer.toString().hashCode.toRadixString(16);
  }
}
