import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/application/kitchen_service.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_all_orders_store.dart';
import 'package:proviyaa_pos/data/drift_kitchen_store.dart';
import 'package:proviyaa_pos/data/drift_local_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/domain/restaurant_table.dart';
import 'package:proviyaa_pos/presentation/all_orders_screen.dart';
import 'package:proviyaa_pos/presentation/delivery_screen.dart';
import 'package:proviyaa_pos/presentation/dine_in_screen.dart';
import 'package:proviyaa_pos/presentation/kitchen_display_screen.dart';
import 'package:proviyaa_pos/presentation/pos_order_screen.dart';
import 'package:proviyaa_pos/presentation/pos_shell.dart';
import 'package:proviyaa_pos/presentation/takeaway_screen.dart';

/// POS order views on real local orders: Takeaway, Delivery, All Orders,
/// Dine In, the Kitchen Display and the POS home panel — seeded orders and
/// empty states, driven through the real widgets.
void main() {
  late AppDatabase db;
  late DriftOperationsStore ops;

  const biryani = OpsOrderLine(
      itemId: 'biryani', name: 'Veg Biryani', unitMinor: 26000, quantity: 2);
  const coke = OpsOrderLine(
      itemId: 'coke', name: 'Coke Can', unitMinor: 6000, quantity: 1);

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<T> read<T>(WidgetTester tester, Future<T> Function() op) async =>
      (await tester.runAsync(op)) as T;

  /// A store write while a screen watches the database: it runs in the
  /// test zone (like a tap would) and is pumped to completion — a write in
  /// runAsync would wait on the screen's pending queries forever.
  Future<T> write<T>(WidgetTester tester, Future<T> Function() op) async {
    T? result;
    Object? error;
    op().then<void>((v) {
      result = v;
    }, onError: (Object e) {
      error = e;
    });
    await settle(tester);
    if (error != null) throw error!;
    return result as T;
  }

  /// Fresh database; [seed] runs before any widget watches it.
  Future<void> setUpDb(WidgetTester tester,
      [Future<void> Function()? seed]) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    ops = DriftOperationsStore(db);
    await tester.runAsync(() async {
      for (final id in ['T1', 'T2']) {
        await DriftTableStore(db).insertTable(RestaurantTable(
            id: id,
            label: id,
            seats: 4,
            zone: TableZone.indoor,
            status: TableStatus.available));
      }
      await seed?.call();
    });
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  late String held, ready, upi, delivery, dineIn, cancelled;

  Future<void> seedOrders() async {
    held = await ops.placeOrder(
        channel: OpsChannel.takeaway,
        customerName: 'Anita',
        lines: const [biryani],
        sendToKitchen: false);
    ready = await ops.placeOrder(
        channel: OpsChannel.takeaway,
        customerName: 'Ravi',
        lines: const [coke]);
    final k = (await ops.getKots()).singleWhere((k) => k.order.id == ready);
    await ops.advanceKot(k.ticketId);
    await ops.advanceKot(k.ticketId);
    upi = await ops.placeOrder(
        channel: OpsChannel.takeaway,
        customerName: 'Kiran',
        lines: const [biryani]);
    await ops.settleOrder(upi, 'upi');
    delivery = await ops.placeOrder(
        channel: OpsChannel.delivery,
        customerName: 'Meera',
        lines: const [biryani, coke]);
    final now = DateTime.now();
    await ops.upsertDelivery(OpsDelivery(
        id: 'DLV-2001',
        orderId: delivery,
        merchant: 'Restaurant',
        status: DeliveryStatus.unassigned,
        createdAt: now,
        updatedAt: now,
        customerName: 'Meera',
        address: '42 MG Road'));
    await ops.assignRider('DLV-2001', 'Ramesh');
    dineIn = await ops.placeOrder(
        channel: OpsChannel.dineIn, tableId: 'T1', lines: const [biryani]);
    final dk = (await ops.getKots()).singleWhere((k) => k.order.id == dineIn);
    await ops.advanceKot(dk.ticketId);
    cancelled = await ops.placeOrder(
        channel: OpsChannel.takeaway,
        customerName: 'Zoya',
        lines: const [coke]);
    await ops.cancelOrder(cancelled, reason: 'Guest left');
  }

  group('Takeaway', () {
    testWidgets('empty state and not-connected state', (tester) async {
      await setUpDb(tester);
      await show(tester, TakeawayScreen(ops: ops));
      expect(find.textContaining('No takeaway orders today'), findsOneWidget);
      await show(tester, const TakeawayScreen());
      expect(
          find.textContaining('no order store is connected'), findsOneWidget);
      await close(tester);
    });

    testWidgets('queue shows real orders; Send KOT and Hand Over work',
        (tester) async {
      await setUpDb(tester, seedOrders);
      var opened = '';
      await show(
          tester, TakeawayScreen(ops: ops, onOpenOrder: (id) => opened = id));
      for (final id in [held, ready, upi]) {
        expect(find.text(id), findsOneWidget, reason: id);
      }
      expect(find.text(cancelled), findsNothing, reason: 'not active');
      expect(find.text(delivery), findsNothing, reason: 'delivery channel');
      expect(find.text('UPI · pending verification'), findsOneWidget);
      expect(find.text('READY FOR PICKUP'), findsOneWidget);

      await tester.tap(find.text('Hand Over'));
      await settle(tester);
      expect((await read(tester, () => ops.getOrder(ready)))!.kitchenState,
          OpsKitchenState.served);

      await tester.tap(find.text('Send KOT'));
      await settle(tester);
      expect((await read(tester, () => ops.getOrder(held)))!.sentToKitchen,
          isTrue);

      // Filters and search.
      await tester.tap(find.textContaining('Cancelled  1'));
      await settle(tester);
      expect(find.text(cancelled), findsOneWidget);
      await tester.tap(find.textContaining('Active'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'kiran');
      await settle(tester);
      expect(find.text(upi), findsOneWidget);
      expect(find.text(ready), findsNothing);

      // Collect Payment goes to the order screen for an unpaid order.
      await tester.enterText(find.byType(TextField), 'ravi');
      await settle(tester);
      await tester.tap(find.text('Collect Payment'));
      await settle(tester);
      expect(opened, ready);
      await close(tester);
    });
  });

  group('Delivery', () {
    testWidgets('empty state', (tester) async {
      await setUpDb(tester);
      await show(tester, DeliveryScreen(ops: ops));
      expect(find.textContaining('No delivery orders today'), findsOneWidget);
      await close(tester);
    });

    testWidgets('shows the delivery record and dispatches with the rider',
        (tester) async {
      await setUpDb(tester, seedOrders);
      await show(tester, DeliveryScreen(ops: ops));
      expect(find.text(delivery), findsOneWidget);
      expect(find.text(held), findsNothing);
      expect(find.textContaining('Rider Ramesh'), findsOneWidget);
      expect(find.textContaining('42 MG Road'), findsOneWidget);
      // Still in the kitchen: no dispatch yet.
      expect(find.text('Dispatch'), findsNothing);

      await write(tester, () async {
        final k =
            (await ops.getKots()).singleWhere((k) => k.order.id == delivery);
        await ops.advanceKot(k.ticketId);
        await ops.advanceKot(k.ticketId);
      });
      await settle(tester);
      await tester.tap(find.text('Dispatch'));
      await settle(tester);
      final d = (await read(tester, ops.getDeliveries))
          .singleWhere((d) => d.orderId == delivery);
      expect(d.status, DeliveryStatus.pickedUp);
      await tester.tap(find.text('Mark Delivered'));
      await settle(tester);
      expect(
          (await read(tester, ops.getDeliveries))
              .singleWhere((d) => d.orderId == delivery)
              .status,
          DeliveryStatus.delivered);
      await close(tester);
    });
  });

  group('All Orders', () {
    testWidgets('empty state', (tester) async {
      await setUpDb(tester);
      await show(tester, AllOrdersScreen(ordersStore: DriftAllOrdersStore(db)));
      expect(find.text('No orders today yet'), findsOneWidget);
      await close(tester);
    });

    testWidgets('read view over the real orders with filters and CSV export',
        (tester) async {
      await setUpDb(tester, seedOrders);
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await show(tester, AllOrdersScreen(ordersStore: DriftAllOrdersStore(db)));
      for (final id in [held, ready, upi, delivery, dineIn, cancelled]) {
        expect(find.text(id), findsOneWidget, reason: id);
      }
      expect(find.text('Pending verification'), findsOneWidget);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Not uploaded'), findsWidgets);
      // No free editing / deleting of orders.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Edit'), findsNothing);

      await tester.tap(find.textContaining('Delivery  1'));
      await settle(tester);
      expect(find.text(delivery), findsOneWidget);
      expect(find.text(upi), findsNothing);

      await tester.tap(find.text('Export CSV'));
      await settle(tester);
      expect(copied, isNotNull);
      expect(copied!, contains(delivery));
      expect(copied!, isNot(contains(upi)));
      expect(copied!.split('\n').first, startsWith('Order,Bill no,Type'));
      await close(tester);
    });
  });

  group('Dine In', () {
    testWidgets('board and order list show the real orders', (tester) async {
      await setUpDb(tester, seedOrders);
      await show(
          tester,
          DineInScreen(
              tableStore: DriftTableStore(db),
              onOpenOrder: (_) {},
              onStartOrder: (_) {}));
      expect(find.text('T1'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      // T1's order is being prepared; T2 is free.
      expect(find.text('Preparing'), findsWidgets);
      expect(find.text('Start Order'), findsOneWidget);
      expect(find.text('Open Order'), findsOneWidget);

      await tester.tap(find.text('Order List'));
      await settle(tester);
      expect(find.text(dineIn), findsOneWidget);
      expect(find.text(held), findsNothing, reason: 'takeaway');
      await close(tester);
    });

    testWidgets('empty order list', (tester) async {
      await setUpDb(tester);
      await show(
          tester,
          DineInScreen(
              tableStore: DriftTableStore(db),
              onOpenOrder: (_) {},
              onStartOrder: (_) {}));
      await tester.tap(find.text('Order List'));
      await settle(tester);
      expect(find.textContaining('No open dine-in orders'), findsOneWidget);
      await close(tester);
    });
  });

  testWidgets('Kitchen Display updates live and shows cancelled orders',
      (tester) async {
    await setUpDb(tester);
    final localStore = DriftLocalStore(db);
    await show(
        tester,
        KitchenDisplayScreen(
            kitchenService: KitchenService(DriftKitchenStore(db)),
            localStore: localStore));
    expect(find.text('LIVE'), findsOneWidget);

    final id = await write(
        tester,
        () => ops.placeOrder(
            channel: OpsChannel.takeaway,
            lines: const [biryani],
            notes: 'Less spicy'));
    await settle(tester);
    expect(find.textContaining(id), findsOneWidget, reason: 'no refresh');
    expect(find.text('Less spicy'), findsOneWidget);
    await tester.tap(find.text('Start Cooking'));
    await settle(tester);
    expect(find.text('Mark Ready'), findsOneWidget);

    await write(tester, () => ops.cancelOrder(id, reason: 'Guest left'));
    await settle(tester);
    expect(find.text('Order cancelled — stop preparing'), findsOneWidget);
    expect(find.text('Mark Ready'), findsNothing);
    await close(tester);
  });

  group('roles that take orders but not money (captain, waiter)', () {
    testWidgets('Takeaway offers no Collect Payment', (tester) async {
      await setUpDb(tester, seedOrders);
      await show(
          tester,
          TakeawayScreen(
              ops: ops, onOpenOrder: (_) {}, canTakePayments: false));
      expect(find.text(ready), findsOneWidget);
      expect(find.text('Collect Payment'), findsNothing);
      expect(find.text('Collect payment'), findsNothing);
      await close(tester);
    });

    testWidgets('the order screen cannot open payment', (tester) async {
      await setUpDb(tester, seedOrders);
      await show(
          tester,
          PosOrderScreen(
              opsStore: ops,
              locationId: 'demo-loc',
              resumeOrderId: ready,
              canTakePayments: false));
      final pay = find.byKey(const Key('pos-proceed-to-pay'));
      expect(pay, findsOneWidget);
      expect(tester.widget<FilledButton>(pay).onPressed, isNull);
      expect(find.text('Payment is taken by the cashier'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsNothing);
      await close(tester);
    });

    testWidgets('a cashier still gets Proceed to Pay', (tester) async {
      await setUpDb(tester, seedOrders);
      await show(
          tester,
          PosOrderScreen(
              opsStore: ops, locationId: 'demo-loc', resumeOrderId: ready));
      final pay = find.byKey(const Key('pos-proceed-to-pay'));
      expect(tester.widget<FilledButton>(pay).onPressed, isNotNull);
      expect(find.text('Proceed to Pay'), findsOneWidget);
      await close(tester);
    });
  });

  testWidgets('POS home panel lists held orders to resume', (tester) async {
    await setUpDb(tester, seedOrders);
    String? resumed;
    await show(
        tester,
        PosModulePlaceholder(
            title: 'POS',
            ops: ops,
            onNewOrder: () {},
            onResumeOrder: (id) => resumed = id));
    expect(find.text('Start a new order'), findsOneWidget);
    expect(find.textContaining(held), findsOneWidget);
    expect(find.textContaining(ready), findsNothing, reason: 'sent to KOT');
    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(resumed, held);
    await close(tester);
  });
}
