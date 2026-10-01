import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/application/kitchen_service.dart';
import 'package:proviyaa_pos/application/order_service.dart';
import 'package:proviyaa_pos/application/payment_service.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_all_orders_store.dart';
import 'package:proviyaa_pos/data/drift_kitchen_store.dart';
import 'package:proviyaa_pos/data/drift_local_store.dart';
import 'package:proviyaa_pos/data/drift_menu_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/drift_payment_store.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/domain/menu.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/domain/restaurant_table.dart';
import 'package:proviyaa_pos/presentation/pos_order_screen.dart';

void main() {
  group('POS Save & Hold Flow', () {
    late AppDatabase db;
    late DriftTableStore tableStore;
    late DriftAllOrdersStore allOrdersStore;
    late DriftMenuStore menuStore;
    late DriftLocalStore localStore;
    late OrderService orderService;
    late KitchenService kitchenService;
    late PaymentService paymentService;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tableStore = DriftTableStore(db);
      allOrdersStore = DriftAllOrdersStore(db);
      menuStore = DriftMenuStore(db);
      localStore = DriftLocalStore(db);
      orderService = OrderService(localStore);
      kitchenService = KitchenService(DriftKitchenStore(db));
      paymentService = PaymentService(DriftPaymentStore(db));

      await menuStore.insertCategory(
          const MenuCategory(id: 'main-course', name: 'Main Course'));
      await menuStore.insertItem(const MenuItem(
        id: 'paneer-butter-masala',
        categoryId: 'main-course',
        name: 'Paneer Butter Masala',
        priceMinor: 32000,
        isVeg: true,
        available: true,
      ));
    });

    tearDown(() => db.close());

    testWidgets('shows warning when Save & Hold is clicked with empty cart',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PosOrderScreen(
            orderService: orderService,
            kitchenService: kitchenService,
            paymentService: paymentService,
            allOrdersStore: allOrdersStore,
            tableStore: tableStore,
            menuStore: menuStore,
            locationId: 'demo-loc',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveHoldBtn = find.widgetWithText(TextButton, 'Save & Hold');
      expect(saveHoldBtn, findsOneWidget);

      await tester.tap(saveHoldBtn);
      await tester.pump();

      expect(
          find.text(
              'Warning: No items added. Please add items to the order before saving.'),
          findsOneWidget);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'saves new order on Hold and updates table to occupied for Dine In',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const initialTable = RestaurantTable(
        id: 'T5',
        label: 'T5',
        seats: 4,
        zone: TableZone.indoor,
        status: TableStatus.available,
      );
      await tableStore.insertTable(initialTable);

      final tablesBefore = await tableStore.getAllTables();
      expect(tablesBefore.first.status, TableStatus.available);

      await tester.pumpWidget(
        MaterialApp(
          home: PosOrderScreen(
            orderService: orderService,
            kitchenService: kitchenService,
            paymentService: paymentService,
            allOrdersStore: allOrdersStore,
            tableStore: tableStore,
            menuStore: menuStore,
            locationId: 'demo-loc',
            table: initialTable,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final item = find.text('Paneer Butter Masala');
      expect(item, findsOneWidget);
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.text('Paneer Butter Masala'), findsWidgets);

      final saveHoldBtn = find.widgetWithText(TextButton, 'Save & Hold');
      await tester.tap(saveHoldBtn);
      await tester.pumpAndSettle();

      // Held = one real order (from the device's ORD- sequence) with no
      // KOT, linked to its table and listed as held.
      final ops = DriftOperationsStore(db);
      final held = await ops.watchHeldOrders().first;
      expect(held, hasLength(1));
      final heldOrder = held.single;
      expect(heldOrder.id, startsWith('ORD-'));
      expect(heldOrder.channel, OpsChannel.dineIn);
      expect(heldOrder.tableLabel, 'T5');
      expect(heldOrder.sentToKitchen, isFalse);
      expect(heldOrder.lines.single.name, 'Paneer Butter Masala');
      expect(heldOrder.grandTotalMinor, 33600); // ₹320 + 5% GST
      expect(await ops.getKots(), isEmpty, reason: 'no KOT on hold');

      final allOrders = await allOrdersStore.getAllOrders();
      expect(allOrders.length, 1);
      expect(allOrders.first.orderId, heldOrder.id);
      expect(allOrders.first.status, 'Held');
      expect(allOrders.first.amountMinor, greaterThan(0));

      final tablesAfter = await tableStore.getAllTables();
      expect(tablesAfter.first.status, TableStatus.occupied);
      expect((await ops.getTable('T5'))!.currentOrderId, heldOrder.id);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('a held order resumes from its table and Send KOT sends it',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const table = RestaurantTable(
          id: 'T6',
          label: 'T6',
          seats: 4,
          zone: TableZone.indoor,
          status: TableStatus.available);
      await tableStore.insertTable(table);
      final ops = DriftOperationsStore(db);
      final id = await ops.placeOrder(
          channel: OpsChannel.dineIn,
          tableId: 'T6',
          lines: const [
            OpsOrderLine(
                itemId: 'paneer-butter-masala',
                name: 'Paneer Butter Masala',
                unitMinor: 32000,
                quantity: 1)
          ],
          sendToKitchen: false);

      await tester.pumpWidget(MaterialApp(
          home: PosOrderScreen(
              orderService: orderService,
              kitchenService: kitchenService,
              paymentService: paymentService,
              allOrdersStore: allOrdersStore,
              tableStore: tableStore,
              menuStore: menuStore,
              locationId: 'demo-loc',
              table: table)));
      await tester.pumpAndSettle();

      // Opening the table loads its open (held) order instead of a new one.
      expect(find.textContaining(id), findsWidgets);
      expect(find.text('SAVED (NOT SENT)'), findsOneWidget);

      // Add one more item and send: one KOT for the order.
      await tester.tap(find.text('Paneer Butter Masala').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Send KOT'));
      await tester.pumpAndSettle();

      final o = (await ops.getOrder(id))!;
      expect(o.lines.single.quantity, 2);
      expect(o.sentToKitchen, isTrue);
      expect(
          (await ops.getKots()).where((k) => k.order.id == id), hasLength(1));
      expect(await ops.watchHeldOrders().first, isEmpty);
      expect((await ops.getOrders()).length, 1, reason: 'no second order');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
