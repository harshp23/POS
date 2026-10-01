import 'package:drift/drift.dart';

import 'app_database.dart';
import 'local_all_orders_catalog.dart';

/// The device-only `all_orders_table` summary (not synced). It is kept up
/// to date from the real orders by DriftOperationsStore (and after a sync
/// pull); no screen edits it any more — the All Orders screen reads the
/// orders themselves, and corrections go through the order (cancel / void
/// / discount with a reason). The write methods below remain for the
/// store's own tests and must not be wired to UI that rewrites amounts,
/// statuses or deletes orders.
class DriftAllOrdersStore {
  DriftAllOrdersStore(this.db);
  final AppDatabase db;

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  AllOrdersRow _toDomain(AllOrderEntity r) {
    return AllOrdersRow(
      orderId: r.orderId,
      type: r.type,
      source: r.source,
      tableOrCustomer: r.tableOrCustomer,
      itemsLabel: r.itemsLabel,
      amountMinor: r.amountMinor,
      status: r.status,
      time: _formatTime(r.createdAt),
    );
  }

  /// Real-time stream of all orders from SQLite, newest first.
  Stream<List<AllOrdersRow>> watchAllOrders() {
    return (db.select(db.allOrdersTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  /// Fetch all orders once.
  Future<List<AllOrdersRow>> getAllOrders() async {
    final rows = await (db.select(db.allOrdersTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// CREATE: Insert a new order into SQLite.
  Future<void> insertOrder(AllOrdersRow order) async {
    await db.into(db.allOrdersTable).insertOnConflictUpdate(
          AllOrdersTableCompanion.insert(
            orderId: order.orderId,
            type: order.type,
            source: order.source,
            tableOrCustomer: order.tableOrCustomer,
            itemsLabel: order.itemsLabel,
            amountMinor: order.amountMinor,
            status: order.status,
          ),
        );
  }

  /// UPDATE: Update an existing order.
  Future<void> updateOrder(AllOrdersRow order) async {
    await (db.update(db.allOrdersTable)
          ..where((t) => t.orderId.equals(order.orderId)))
        .write(
      AllOrdersTableCompanion(
        type: Value(order.type),
        source: Value(order.source),
        tableOrCustomer: Value(order.tableOrCustomer),
        itemsLabel: Value(order.itemsLabel),
        amountMinor: Value(order.amountMinor),
        status: Value(order.status),
      ),
    );
  }

  /// UPDATE: Quick status update (e.g. New -> Preparing -> Ready -> Completed).
  Future<void> updateStatus(String orderId, String newStatus) async {
    await (db.update(db.allOrdersTable)
          ..where((t) => t.orderId.equals(orderId)))
        .write(
      AllOrdersTableCompanion(
        status: Value(newStatus),
      ),
    );
  }

  /// DELETE: Remove order from SQLite.
  Future<void> deleteOrder(String orderId) async {
    await (db.delete(db.allOrdersTable)
          ..where((t) => t.orderId.equals(orderId)))
        .go();
  }
}
