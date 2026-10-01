import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_local_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/data/operations_seeder.dart';
import 'package:proviyaa_pos/domain/operations.dart';

void main() {
  late AppDatabase db;
  late DriftOperationsStore ops;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ops = DriftOperationsStore(db);
    await OperationsSeeder.seedIfNeeded(db);
  });
  tearDown(() => db.close());

  test('seed fills floors, orders, KOTs, deliveries, reservations, QR',
      () async {
    await OperationsSeeder.seedIfNeeded(db); // no-op second time
    expect(await ops.getFloors(),
        ['Ground Floor', 'First Floor', 'Terrace', 'Private Cabanas']);
    final t2 = (await ops.getTable('T2'))!;
    expect(t2.status, OpsTableStatus.occupied);
    expect((await ops.getTable('T4'))!.status, OpsTableStatus.billing);
    final kots = await ops.getKots();
    expect(kots.map((k) => k.status).toSet(), containsAll(OpsKotStatus.values));
    expect((await ops.getDeliveries()).length, 6);
    expect((await ops.getReservations()).length, 11);
    expect((await ops.getQrCodes()).length, 20);
  });

  test('placing, billing and settling a dine-in order uses the POS tables',
      () async {
    final id = await ops.placeOrder(
        channel: OpsChannel.dineIn,
        tableId: 'T9',
        guests: 2,
        source: 'Captain',
        lines: const [
          OpsOrderLine(
              itemId: 'dal',
              name: 'Dal Makhani',
              unitMinor: 29000,
              quantity: 2),
        ]);
    // Visible to the POS through its own stores.
    expect((await DriftLocalStore(db).findOrder(id))!.tableLabel, 'T9');
    expect(
        (await DriftTableStore(db).getAllTables())
            .firstWhere((t) => t.id == 'T9')
            .status
            .name,
        'occupied');
    expect((await ops.getKots()).any((k) => k.order.id == id), isTrue);

    // Adding items to the same table joins the open order.
    final again = await ops
        .placeOrder(channel: OpsChannel.dineIn, tableId: 'T9', lines: const [
      OpsOrderLine(
          itemId: 'dal', name: 'Dal Makhani', unitMinor: 29000, quantity: 1),
    ]);
    expect(again, id);
    expect((await ops.getOrder(id))!.lines.single.quantity, 3);

    await ops.setDiscount(id, 10, reason: 'regular guest');
    final billNo = await ops.generateBill(id);
    expect((await ops.getTable('T9'))!.status, OpsTableStatus.billing);

    final order = (await ops.getOrder(id))!;
    // 87000 - 10% = 78300, + 5% GST = 82215
    expect(order.grandTotalMinor, 82215);
    // UPI is recorded, but the device cannot confirm it: the order waits
    // for verification by an authorised user before it is settled.
    expect(await ops.settleOrder(id, 'upi'),
        OrderPaymentState.pendingVerification);
    expect((await ops.getOrder(id))!.status, OpsOrderStatus.billed);
    await ops.verifyPayment(id);
    final settled = (await ops.getOrder(id))!;
    expect(settled.status, OpsOrderStatus.settled);
    expect(settled.billNo, billNo);
    final pay = await (db.select(db.payments)
          ..where((p) => p.clientOrderId.equals(id)))
        .getSingle();
    expect(pay.method, 'upi');
    expect(pay.amountMinor, 82215);
    expect((await ops.getTable('T9'))!.status, OpsTableStatus.cleaning);
    expect(() => ops.settleOrder(id, 'cash'), throwsStateError);
  });

  test('KOT moves New → Preparing → Ready → Served and cannot go further',
      () async {
    final kot = (await ops.getKots())
        .firstWhere((k) => k.status == OpsKotStatus.newTicket);
    expect(await ops.advanceKot(kot.ticketId), OpsKotStatus.preparing);
    expect(await ops.advanceKot(kot.ticketId), OpsKotStatus.ready);
    final ready =
        (await ops.getKots()).firstWhere((k) => k.ticketId == kot.ticketId);
    expect(ready.order.lines.every((l) => l.done), isTrue);
    expect(await ops.advanceKot(kot.ticketId), OpsKotStatus.completed);
    expect(() => ops.advanceKot(kot.ticketId), throwsStateError);
  });

  test('transfer, reservations and deliveries enforce their rules', () async {
    await ops.transferTable('T2', 'T11');
    expect((await ops.getTable('T11'))!.currentOrderId, isNotNull);
    expect((await ops.getTable('T2'))!.status, OpsTableStatus.cleaning);
    expect(() => ops.transferTable('T11', 'T6'), throwsStateError);

    // RSV-102 (2 guests) can't be seated before a table is assigned.
    expect(() => ops.seatReservation('RSV-102'), throwsStateError);
    expect(() => ops.assignReservationTable('RSV-107', 'T8'), throwsStateError);
    await ops.assignReservationTable('RSV-102', 'T14');
    await ops.seatReservation('RSV-102');
    expect((await ops.getTable('T14'))!.status, OpsTableStatus.occupied);

    expect(() => ops.setDeliveryStatus('DLV-1029', DeliveryStatus.pickedUp),
        throwsStateError);
    await ops.assignRider('DLV-1029', 'Ramesh P.', etaMinutes: 15);
    await ops.setDeliveryStatus('DLV-1029', DeliveryStatus.delivered);
    expect(() => ops.setDeliveryStatus('DLV-1029', DeliveryStatus.failed),
        throwsStateError);
  });

  test('a v3 database upgrades to v4 keeping POS orders', () async {
    // Simulated by the column defaults: an order written by the POS
    // (no Operations fields) reads as an open dine-in order.
    await db.into(db.orders).insert(OrdersCompanion.insert(
        clientOrderId: 'pos-1',
        locationId: 'x',
        currencyCode: 'INR',
        status: 'pendingUpload',
        orderType: 'takeaway'));
    final o = (await ops.getOrder('pos-1'))!;
    expect(o.status, OpsOrderStatus.open);
    expect(o.channel, OpsChannel.takeaway);
    expect(o.taxPct, 5);
  });
}
