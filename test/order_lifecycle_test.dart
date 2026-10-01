import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/domain/order_audit.dart';
import 'package:proviyaa_pos/domain/payment.dart';
import 'package:proviyaa_pos/domain/receipt.dart';
import 'package:proviyaa_pos/domain/restaurant_table.dart';

/// Order lifecycle on the shared POS / Operations tables: totals in paise,
/// payment states (cash settled, UPI pending verification, verified),
/// never-overwritten payments, cancel with reason, held-order resume,
/// open-order reuse per table, and the correction audit trail.
void main() {
  late AppDatabase db;
  late DriftOperationsStore ops;
  var now = DateTime(2026, 9, 29, 12, 0);

  const dal = OpsOrderLine(
      itemId: 'dal', name: 'Dal Makhani', unitMinor: 29000, quantity: 2);
  const naan = OpsOrderLine(
      itemId: 'naan', name: 'Butter Naan', unitMinor: 5000, quantity: 3);

  setUp(() async {
    now = DateTime(2026, 9, 29, 12, 0);
    db = AppDatabase(NativeDatabase.memory());
    ops = DriftOperationsStore(db, clock: () => now, actorName: 'Asha');
    for (final id in ['T1', 'T2']) {
      await DriftTableStore(db).insertTable(RestaurantTable(
          id: id,
          label: id,
          seats: 4,
          zone: TableZone.indoor,
          status: TableStatus.available));
    }
  });
  tearDown(() => db.close());

  group('totals (integer paise)', () {
    test('discount and GST are each rounded to the paisa', () {
      final o = OpsOrder(
          id: 'X',
          channel: OpsChannel.takeaway,
          status: OpsOrderStatus.open,
          createdAt: now,
          discountPct: 7.5,
          lines: const [
            OpsOrderLine(itemId: 'a', name: 'A', unitMinor: 33333, quantity: 1),
            OpsOrderLine(itemId: 'b', name: 'B', unitMinor: 1999, quantity: 3),
          ]);
      expect(o.subtotalMinor, 39330);
      // 39330 × 7.5% = 2949.75 → 2950
      expect(o.discountMinor, 2950);
      // (39330 − 2950) × 5% = 1819
      expect(o.taxMinor, 1819);
      expect(o.grandTotalMinor, 39330 - 2950 + 1819);
      expect(o.itemCount, 4);
    });

    test('stored tax % is used (default 5%)', () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      final o = (await ops.getOrder(id))!;
      expect(o.taxPct, 5);
      expect(o.taxMinor, 2900);
      expect(o.grandTotalMinor, 60900);
    });
  });

  group('payment state', () {
    test('derivation: cash paid, UPI / card / split pending, settled paid', () {
      expect(derivePaymentState(settled: false, recordedMethod: null),
          OrderPaymentState.unpaid);
      expect(derivePaymentState(settled: false, recordedMethod: 'cash'),
          OrderPaymentState.paid);
      for (final m in ['upi', 'card', 'split: cash ₹100 + upi ₹50']) {
        expect(derivePaymentState(settled: false, recordedMethod: m),
            OrderPaymentState.pendingVerification,
            reason: m);
      }
      expect(derivePaymentState(settled: true, recordedMethod: 'upi'),
          OrderPaymentState.paid);
    });

    test('cash settles the order and frees the table', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T1', lines: const [dal]);
      final state = await ops.settleOrder(id, 'cash', receivedMinor: 70000);
      expect(state, OrderPaymentState.paid);
      final o = (await ops.getOrder(id))!;
      expect(o.status, OpsOrderStatus.settled);
      expect(o.settledAt, now);
      expect(o.paymentState, OrderPaymentState.paid);
      expect(o.paymentLabel, 'Paid · Cash');
      expect(o.payment!.receivedMinor, 70000);
      final t = (await ops.getTable('T1'))!;
      expect(t.status, OpsTableStatus.cleaning);
      expect(t.currentOrderId, isNull);
    });

    test('UPI is recorded pending verification until verified', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T1', lines: const [dal]);
      await ops.generateBill(id);
      final state = await ops.settleOrder(id, 'upi');
      expect(state, OrderPaymentState.pendingVerification);
      var o = (await ops.getOrder(id))!;
      expect(o.status, OpsOrderStatus.billed);
      expect(o.settledAt, isNull);
      expect(o.paymentLabel, 'UPI · pending verification');
      expect(o.payment!.method, 'upi');
      // The guests left: the table is released for the next party.
      expect((await ops.getTable('T1'))!.currentOrderId, isNull);
      // Still listed with the open bills.
      expect(
          (await ops.getOrders(openOnly: true)).map((o) => o.id), contains(id));

      now = now.add(const Duration(minutes: 30));
      await ops.verifyPayment(id, note: 'seen in bank app', by: 'Manager Ravi');
      o = (await ops.getOrder(id))!;
      expect(o.status, OpsOrderStatus.settled);
      expect(o.settledAt, now);
      expect(o.paymentState, OrderPaymentState.paid);
      expect(o.auditLog.last.actor, 'Manager Ravi');
      expect(o.auditLog.last.text, startsWith('Payment verified: UPI ₹609'));
      // The payment row is unchanged.
      final pay = await db.select(db.payments).getSingle();
      expect(pay.method, 'upi');
      expect(pay.amountMinor, 60900);
      expect(() => ops.verifyPayment(id), throwsStateError);
    });

    test('cash cannot be "verified"; unpaid orders cannot be verified',
        () async {
      final a = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      expect(() => ops.verifyPayment(a), throwsStateError);
      await ops.settleOrder(a, 'cash');
      expect(() => ops.verifyPayment(a), throwsStateError);
    });

    test('a recorded payment is never overwritten', () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      await ops.settleOrder(id, 'upi');
      await expectLater(ops.settleOrder(id, 'cash'), throwsStateError);
      final pays = await db.select(db.payments).get();
      expect(pays, hasLength(1));
      expect(pays.single.method, 'upi');
      // Nor can the discount change under a recorded payment.
      await expectLater(
          ops.setDiscount(id, 10, reason: 'late'), throwsStateError);
    });

    test('split with UPI is one payment row, pending verification', () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      final state = await ops.settleOrder(id, 'split: cash ₹300 + upi ₹309');
      expect(state, OrderPaymentState.pendingVerification);
      expect(await db.select(db.payments).get(), hasLength(1));
    });
  });

  group('cancel', () {
    test('needs a reason, is audited, and leaves the kitchen queue', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn,
          tableId: 'T2',
          lines: const [dal],
          notes: 'less spicy');
      final kot = (await ops.getKots()).singleWhere((k) => k.order.id == id);
      await ops.advanceKot(kot.ticketId); // preparing

      await expectLater(ops.cancelOrder(id, reason: '  '), throwsArgumentError);
      await ops.cancelOrder(id, reason: 'guest left');

      final o = (await ops.getOrder(id))!;
      expect(o.status, OpsOrderStatus.cancelled);
      expect(o.notes, 'less spicy', reason: 'audit lines are not notes');
      expect(o.auditLog.single.text, 'Cancelled: guest left');
      expect(o.auditLog.single.actor, 'Asha');
      final raw = await db.select(db.orders).getSingle();
      expect(raw.notes,
          'less spicy\n[2026-09-29 12:00 · Asha] Cancelled: guest left');

      // KOT keeps its status (no "completed"/served), is out of the
      // queue, and is listed as cancelled for the kitchen.
      final row = await db.select(db.kitchenTickets).getSingle();
      expect(row.status, 'preparing');
      expect(row.completedAt, isNull);
      expect((await ops.getKots()).where((k) => k.order.id == id), isEmpty);
      final cancelled = await ops.getCancelledKots();
      expect(cancelled.single.ticketId, kot.ticketId);
      expect(cancelled.single.orderCancelled, isTrue);
      expect(cancelled.single.cancelledAt, now);
      await expectLater(ops.advanceKot(kot.ticketId), throwsStateError);

      final t = (await ops.getTable('T2'))!;
      expect(t.currentOrderId, isNull);
      expect(t.status, OpsTableStatus.cleaning);
      await expectLater(ops.cancelOrder(id, reason: 'again'), throwsStateError);
    });

    test('refused once a payment is recorded', () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      await ops.settleOrder(id, 'upi');
      await expectLater(
          ops.cancelOrder(id, reason: 'mistake'), throwsStateError);
    });
  });

  group('corrections', () {
    test('reducing an item after the KOT needs a reason and is audited',
        () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal, naan]);
      await expectLater(
          ops.setLineQuantity(id, 'naan', 1), throwsArgumentError);
      await ops.setLineQuantity(id, 'naan', 1, reason: 'guest changed mind');
      await ops.setLineQuantity(id, 'dal', 0, reason: 'out of stock');
      final o = (await ops.getOrder(id))!;
      expect(o.lines.single.itemId, 'naan');
      expect(o.lines.single.quantity, 1);
      expect(o.auditLog.map((e) => e.text), [
        'Reduced Butter Naan 3 → 1: guest changed mind',
        'Voided Dal Makhani (×2): out of stock',
      ]);
    });

    test('a held order (no KOT) is edited freely', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.takeaway,
          lines: const [dal],
          sendToKitchen: false);
      await ops.setLineQuantity(id, 'dal', 1);
      expect((await ops.getOrder(id))!.auditLog, isEmpty);
    });

    test('discount is audited and refused on settled / cancelled orders',
        () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      await ops.setDiscount(id, 10, reason: 'regular guest');
      var o = (await ops.getOrder(id))!;
      expect(o.discountMinor, 5800);
      expect(o.auditLog.single.text, 'Discount 0% → 10%: regular guest');
      await ops.settleOrder(id, 'cash');
      await expectLater(ops.setDiscount(id, 20, reason: 'x'), throwsStateError);

      final c = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      await ops.cancelOrder(c, reason: 'duplicate');
      await expectLater(ops.setDiscount(c, 5, reason: 'x'), throwsStateError);
      o = (await ops.getOrder(c))!;
      expect(o.discountPct, 0);
    });

    test('reprint is recorded in the audit trail', () async {
      final id = await ops
          .placeOrder(channel: OpsChannel.takeaway, lines: const [dal]);
      await ops.generateBill(id);
      await ops.recordReprint(id, by: 'Asha');
      expect((await ops.getOrder(id))!.auditLog.single.text,
          startsWith('Bill reprint requested'));
    });

    test('bill preview text shows lines, discount, GST and payment state',
        () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.takeaway,
          customerName: 'Anita',
          lines: const [dal, naan]);
      await ops.setDiscount(id, 10, reason: 'regular');
      var text = receiptText((await ops.getOrder(id))!);
      expect(text, contains('DRAFT BILL'));
      expect(text, contains('2 x Dal Makhani'));
      expect(text, contains('Discount (10%)'));
      expect(text, contains('-₹73.00')); // 10% of ₹730
      expect(text, contains('GST (5%)'));
      expect(text, contains('₹32.85')); // 5% of ₹657
      expect(text, contains('₹689.85'));
      expect(text, contains('Payment: Unpaid'));
      await ops.generateBill(id);
      await ops.settleOrder(id, 'upi');
      text = receiptText((await ops.getOrder(id))!);
      expect(text, contains('Bill #'));
      expect(text, contains('Payment: UPI · pending verification'));
    });

    test('audit lines round-trip and plain notes stay separate', () {
      final raw = appendAuditLine(
          'Extra spicy', DateTime(2026, 9, 29, 9, 5), '', 'Cancelled: x');
      expect(raw, 'Extra spicy\n[2026-09-29 09:05] Cancelled: x');
      final parsed = parseOrderNotes(raw);
      expect(parsed.plain, 'Extra spicy');
      expect(parsed.entries.single.actor, '');
      expect(parsed.entries.single.at, DateTime(2026, 9, 29, 9, 5));
    });
  });

  group('held orders and tables', () {
    test('Save & Hold keeps the order out of the kitchen until resumed',
        () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn,
          tableId: 'T1',
          guests: 3,
          lines: const [dal],
          sendToKitchen: false);
      var o = (await ops.getOrder(id))!;
      expect(o.isHeld, isTrue);
      expect(o.kitchenState, OpsKitchenState.notSent);
      expect(await ops.getKots(), isEmpty);
      expect((await ops.watchHeldOrders().first).map((o) => o.id), [id]);
      expect((await ops.getTable('T1'))!.currentOrderId, id);

      // Resume: add an item, still held, then send the KOT.
      await ops.addLines(id, const [naan], sendToKitchen: false);
      final ticket = await ops.sendKot(id);
      o = (await ops.getOrder(id))!;
      expect(o.isHeld, isFalse);
      expect(o.lines, hasLength(2));
      expect((await ops.getKots()).single.ticketId, ticket);
      expect(await ops.watchHeldOrders().first, isEmpty);
      final t = (await ops.getTable('T1'))!;
      expect(t.status, OpsTableStatus.occupied);
      expect(t.currentOrderId, id);
      await expectLater(ops.sendKot(id), throwsStateError);
    });

    test(
        'opening a table with an open order adds to it; new KOT lists '
        'only the new items', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T2', lines: const [dal]);
      final first = (await ops.getKots()).single;
      await ops.advanceKot(first.ticketId);
      await ops.advanceKot(first.ticketId); // ready
      final again = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T2', lines: const [naan]);
      expect(again, id);
      final kots = await ops.getKots();
      expect(kots, hasLength(2));
      final followUp = kots.firstWhere((k) => k.ticketId != first.ticketId);
      expect(followUp.notes, 'Additional items: 3× Butter Naan');
      expect(followUp.status, OpsKotStatus.newTicket);
      expect((await ops.getOrder(id))!.kitchenState, OpsKitchenState.queued);
    });

    test('tables with an open order cannot be freed or deleted', () async {
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T2', lines: const [dal]);
      final tables = DriftTableStore(db);
      await expectLater(
          tables.updateStatus('T2', TableStatus.available), throwsStateError);
      await expectLater(tables.deleteTable('T2'), throwsStateError);
      await expectLater(
          ops.setTableStatus('T2', OpsTableStatus.cleaning), throwsStateError);
      await ops.settleOrder(id, 'cash');
      await tables.updateStatus('T2', TableStatus.available);
      expect((await ops.getTable('T2'))!.status, OpsTableStatus.available);
    });

    test('dine-in board status follows the order', () async {
      expect(deriveDineInBoardStatus(OpsTableStatus.reserved, null),
          DineInBoardStatus.reserved);
      expect(deriveDineInBoardStatus(OpsTableStatus.cleaning, null),
          DineInBoardStatus.cleaning);
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn, tableId: 'T1', lines: const [dal]);
      Future<DineInBoardStatus> board() async => deriveDineInBoardStatus(
          (await ops.getTable('T1'))!.status, await ops.getOrder(id));
      expect(await board(), DineInBoardStatus.waitingKot);
      final k = (await ops.getKots()).single.ticketId;
      await ops.advanceKot(k);
      expect(await board(), DineInBoardStatus.preparing);
      await ops.advanceKot(k);
      expect(await board(), DineInBoardStatus.ready);
      await ops.advanceKot(k);
      expect(await board(), DineInBoardStatus.served);
      await ops.generateBill(id);
      expect(await board(), DineInBoardStatus.paymentPending);
    });
  });
}
