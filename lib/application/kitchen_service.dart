import '../domain/kitchen_ticket.dart';
import '../domain/operations.dart' show kotNumberLabel, orderNumberLabel;
import '../domain/order.dart';

abstract interface class KitchenLocalStore {
  Future<void> createTicket(KitchenTicket ticket);
  Future<KitchenTicket?> findTicket(String ticketId);
  Future<void> advanceStatus(String ticketId, KitchenTicketStatus to);
  Future<List<KitchenTicket>> listOpen();
}

class KitchenService {
  const KitchenService(this.store);
  final KitchenLocalStore store;

  /// One ticket per order, PRD §9: "sends KOT locally" right after the
  /// order is saved. The ticket id is derived from the order id so a
  /// retried call is a safe no-op, matching the idempotent-save pattern
  /// already used for pending_upload_intents.
  Future<KitchenTicket> createTicketForOrder(LocalOrder order) async {
    final ticket = KitchenTicket(
        ticketId: '${order.clientOrderId}:kot',
        clientOrderId: order.clientOrderId,
        status: KitchenTicketStatus.newTicket,
        createdAt: DateTime.now());
    await store.createTicket(ticket);
    return (await store.findTicket(ticket.ticketId)) ?? ticket;
  }

  /// Advances one step forward only (queued -> preparing -> ready ->
  /// served). Throws if the ticket is already at its final status or
  /// doesn't exist — the kitchen screen should not offer the action in
  /// that case, but the service enforces it either way.
  Future<KitchenTicket> advance(String ticketId) async {
    final ticket = await store.findTicket(ticketId);
    if (ticket == null) {
      throw ArgumentError(
          'This kitchen ticket was not found — it may have been removed.');
    }
    final next = kitchenTicketForwardTransitions[ticket.status];
    if (next == null) {
      final name = ticketName(ticket.ticketId);
      throw StateError('${name[0].toUpperCase()}${name.substring(1)} is '
          'already ${statusLabel(ticket.status).toLowerCase()}.');
    }
    await store.advanceStatus(ticketId, next);
    return ticket.copyWith(status: next);
  }

  Future<List<KitchenTicket>> openTickets() => store.listOpen();

  /// How people know a ticket: "the KOT for ORD-248" (tickets made here
  /// are keyed `<order>:kot`), else its KOT number / device key.
  static String ticketName(String ticketId) {
    const suffix = ':kot';
    if (ticketId.endsWith(suffix)) {
      final orderId = ticketId.substring(0, ticketId.length - suffix.length);
      return 'the KOT for ${orderNumberLabel(orderId, null)}';
    }
    return kotNumberLabel(ticketId, null);
  }

  /// New / Preparing / Ready / Served.
  static String statusLabel(KitchenTicketStatus s) => switch (s) {
        KitchenTicketStatus.newTicket => 'New',
        KitchenTicketStatus.preparing => 'Preparing',
        KitchenTicketStatus.ready => 'Ready',
        KitchenTicketStatus.completed => 'Served',
      };
}
