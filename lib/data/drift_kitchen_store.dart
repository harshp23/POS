import 'package:drift/drift.dart';

import '../application/kitchen_service.dart';
import '../domain/kitchen_ticket.dart';
import 'app_database.dart';
import 'drift_operations_store.dart';

class DriftKitchenStore implements KitchenLocalStore {
  DriftKitchenStore(this._db);
  final AppDatabase _db;

  @override
  Future<void> createTicket(KitchenTicket ticket) async {
    await _db.into(_db.kitchenTickets).insert(
        KitchenTicketsCompanion.insert(
            ticketId: ticket.ticketId,
            clientOrderId: ticket.clientOrderId,
            status: ticket.status.name,
            createdAt: Value(ticket.createdAt)),
        mode: InsertMode.insertOrIgnore);
  }

  @override
  Future<KitchenTicket?> findTicket(String ticketId) async {
    final row = await (_db.select(_db.kitchenTickets)
          ..where((t) => t.ticketId.equals(ticketId)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Moves a ticket one step forward — the same transition the Operations
  /// kitchen screens make (Served stamps completed_at, Ready ticks the
  /// order's items done, a cancelled order's ticket is refused). [to] must
  /// be the ticket's next status; anything else is rejected.
  @override
  Future<void> advanceStatus(String ticketId, KitchenTicketStatus to) async {
    await _db.transaction(() async {
      final current = await findTicket(ticketId);
      if (current == null) throw ArgumentError('No kitchen ticket $ticketId.');
      final next = kitchenTicketForwardTransitions[current.status];
      if (next != to) {
        throw StateError('Ticket $ticketId cannot move from '
            '${current.status.name} to ${to.name}.');
      }
      await DriftOperationsStore(_db).advanceKot(ticketId);
    });
  }

  @override
  Future<List<KitchenTicket>> listOpen() async {
    final rows = await (_db.select(_db.kitchenTickets)
          ..where(
              (t) => t.status.isNotValue(KitchenTicketStatus.completed.name))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  KitchenTicket _toDomain(KitchenTicketRow row) => KitchenTicket(
      ticketId: row.ticketId,
      clientOrderId: row.clientOrderId,
      status: KitchenTicketStatus.values.byName(row.status),
      createdAt: row.createdAt);
}
