import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/presentation/operations/ops_kitchen_screen.dart';
import 'package:proviyaa_pos/presentation/vinii_theme.dart';

/// Orders and KOTs made on the server (online orders, the back office) have
/// a database id as their device key. People see the server's numbers
/// instead — "ORD-248", "KOT #37" — never the id.
void main() {
  const orderId = '5e2f888f-fe28-4d7f-be11-2c1c7e1f9a30';
  const ticketId = '252cdf22-2192-497a-9c4e-6d1b8a2f0c11';

  group('labels', () {
    test('the server number wins; a device key shows as is; an id never shows',
        () {
      expect(orderNumberLabel(orderId, 'ORD-248'), 'ORD-248');
      expect(orderNumberLabel('ORD-A1B2C-7', 'ORD-A1B2C-7'), 'ORD-A1B2C-7');
      expect(orderNumberLabel('ORD-A1B2C-7', null), 'ORD-A1B2C-7');
      expect(orderNumberLabel(orderId, null), 'Order 5E2F88');
      expect(orderNumberLabel(orderId, orderId), 'Order 5E2F88');
      expect(kotNumberLabel(ticketId, 37), 'KOT #37');
      expect(kotNumberLabel('KOT-A1B2C-3', null), 'KOT-A1B2C-3');
      expect(kotNumberLabel(ticketId, null), 'KOT 252CDF');
    });
  });

  testWidgets('the kitchen shows KOT and order numbers for a server-made order',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    final ops = DriftOperationsStore(db);
    await tester.runAsync(() async {
      await db.into(db.orders).insert(OrdersCompanion.insert(
            clientOrderId: orderId,
            locationId: 'branch-1',
            currencyCode: 'INR',
            status: 'synchronized',
            orderType: 'takeaway',
            channel: const Value('takeaway'),
            displayNo: const Value('ORD-248'),
          ));
      await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            clientOrderId: orderId,
            itemId: 'qa-thali',
            name: 'QA Thali',
            unitMinor: 42000,
            quantity: 1,
          ));
      await db.into(db.kitchenTickets).insert(KitchenTicketsCompanion.insert(
            ticketId: ticketId,
            clientOrderId: orderId,
            status: 'newTicket',
            kotNo: const Value(37),
          ));
    });

    final kots = (await tester.runAsync(ops.getKots))!;
    expect(kots.single.label, 'KOT #37');
    expect(kots.single.order.number, 'ORD-248');

    await tester.pumpWidget(MaterialApp(
        theme: viniiLightTheme(),
        home: Scaffold(
            body: OpsKitchenScreen(ops: ops, master: DriftMasterStore(db)))));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('KOT #37'), findsWidgets);
    expect(find.textContaining('ORD-248'), findsWidgets);
    expect(find.textContaining('252cdf22'), findsNothing);
    expect(find.textContaining('5e2f888f'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
