import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/franchise_organization_store.dart';
import 'package:proviyaa_pos/data/spicy_bistro_seeder.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_command_center_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/restaurant_dashboard_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_menu_items_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_offers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_recipes_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_kitchen_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_pos_billing_screen.dart';

void main() {
  group(
      'Spicy Bistro (admin@spicybistro.com) End-to-End Master, Franchise & POS Test Suite',
      () {
    late AppDatabase db;
    late DriftMasterStore masterStore;
    late DriftInventoryStore inventoryStore;
    late DriftOperationsStore opsStore;
    late MultiTenantFranchiseStore franchiseStore;

    setUp(() async {
      db = AppDatabase(DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ));
      masterStore = DriftMasterStore(db);
      inventoryStore = DriftInventoryStore(db);
      opsStore = DriftOperationsStore(db);
      franchiseStore = MultiTenantFranchiseStore();

      await SpicyBistroSeeder.seedMasterAndFranchise(db, franchiseStore);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    test(
        '1. Verify Master Dishes, Recipes, Offers, Suppliers & Inventory for Spicy Bistro',
        () async {
      final dishes = await masterStore.getDishes();
      expect(dishes.length, greaterThanOrEqualTo(7));

      final dishNames = dishes.map((d) => d.name).toList();
      expect(dishNames, contains('Spicy Butter Chicken'));
      expect(dishNames, contains('Paneer Butter Masala'));
      expect(dishNames, contains('Garlic Butter Naan'));
      expect(dishNames, contains('Paneer Tikka Special'));
      expect(dishNames, contains('Mango Lassi'));

      final butterChicken =
          dishes.firstWhere((d) => d.name == 'Spicy Butter Chicken');
      expect(butterChicken.sellingPrice, equals(380.0));
      expect(butterChicken.category, equals('MAIN COURSE'));
      expect(butterChicken.isVeg, isFalse);

      final recipes = await masterStore.getRecipes();
      expect(recipes.length, greaterThanOrEqualTo(4));
      final recipeNames = recipes.map((r) => r.name).toList();
      expect(recipeNames, contains('Spicy Butter Chicken'));
      expect(recipeNames, contains('Paneer Butter Masala'));

      final offers = await masterStore.getOffers();
      expect(offers.length, greaterThanOrEqualTo(2));
      expect(offers.any((o) => o.code == 'SPICYFEST25'), isTrue);

      final suppliers = await inventoryStore.getSuppliers();
      expect(suppliers.isNotEmpty, isTrue);

      final materials = await inventoryStore.getMaterials();
      expect(materials.isNotEmpty, isTrue);
    });

    test(
        '2. Verify Franchise Multi-Tenant Records & Security Isolation for Spicy Bistro',
        () async {
      const orgId = SpicyBistroSeeder.orgId;

      final records =
          await franchiseStore.getRecordsForOrganization(callerOrgId: orgId);
      expect(records.length, equals(3));
      expect(records.any((r) => r.recordType == 'stock_transfer'), isTrue);
      expect(records.any((r) => r.recordType == 'safety_stock_adjustment'),
          isTrue);
      expect(records.any((r) => r.recordType == 'target_amendment'), isTrue);

      final menuItems =
          await franchiseStore.getMenuItemsForOrganization(callerOrgId: orgId);
      expect(menuItems.length, greaterThanOrEqualTo(7));
      expect(menuItems.any((i) => i.name == 'Spicy Butter Chicken'), isTrue);

      // Verify Cross-Tenant Isolation Enforcement
      const hackItem = MultiTenantMenuItemRecord(
        id: 'hack_01',
        organizationId: 'org_spicy_bistro_001',
        name: 'Unauthorized Write',
        category: 'Hack',
        priceInr: 999.0,
        isVeg: false,
        available: false,
      );

      expect(
        () async => await franchiseStore.saveMenuItem(
          callerOrgId: 'org_burger_express_002', // Unauthorized caller
          item: hackItem,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test(
        '3. End-to-End Operations POS Flow: Dine-In Table Order, KOT Creation, Kitchen Update & Settlement',
        () async {
      // 1. Fetch available table T1
      final t1 = await opsStore.getTable('T1');
      expect(t1, isNotNull);
      expect(t1!.status, equals(OpsTableStatus.available));

      // 2. Place Order for 2 guests on Table T1 (Spicy Butter Chicken + Garlic Naan + Mango Lassi)
      final orderId = await opsStore.placeOrder(
        channel: OpsChannel.dineIn,
        tableId: 'T1',
        guests: 2,
        serverName: 'Chef Rahul',
        source: 'Captain Tablet',
        notes: 'Extra butter on Naan',
        lines: const [
          OpsOrderLine(
              itemId: 'dish_sb_01',
              name: 'Spicy Butter Chicken',
              quantity: 1,
              unitMinor: 38000),
          OpsOrderLine(
              itemId: 'dish_sb_03',
              name: 'Garlic Butter Naan',
              quantity: 2,
              unitMinor: 6000),
          OpsOrderLine(
              itemId: 'dish_sb_06',
              name: 'Mango Lassi',
              quantity: 2,
              unitMinor: 18000),
        ],
      );

      expect(orderId, isNotNull);

      // 3. Verify Order Created & Table Marked Occupied
      final order = await opsStore.getOrder(orderId);
      expect(order, isNotNull);
      expect(order!.tableLabel, equals('T1'));
      expect(order.guests, equals(2));
      expect(order.lines.length, equals(3));
      // Subtotal = 38000 + (2 * 6000) + (2 * 18000) = 38000 + 12000 + 36000 = 86000 minor units (₹860.00)
      expect(order.subtotalMinor, equals(86000));

      final updatedTable = await opsStore.getTable('T1');
      expect(updatedTable!.status, equals(OpsTableStatus.occupied));

      // 4. Verify KOT Ticket created for Kitchen
      final kots = await opsStore.getKots();
      expect(kots.isNotEmpty, isTrue);
      final kot = kots.firstWhere((k) => k.order.id == orderId);
      expect(kot.status, equals(OpsKotStatus.newTicket));

      // 5. Update Kitchen Status to Preparing then Ready
      await opsStore.advanceKot(kot.ticketId); // newTicket -> preparing
      await opsStore.advanceKot(kot.ticketId); // preparing -> ready
      final updatedKot = (await opsStore.getKots())
          .firstWhere((k) => k.ticketId == kot.ticketId);
      expect(updatedKot.status, equals(OpsKotStatus.ready));

      // 6. Settle Order Payment
      await opsStore.settleOrder(orderId, 'Cash',
          receivedMinor: order.grandTotalMinor);
      final settledOrder = await opsStore.getOrder(orderId);
      expect(settledOrder!.status, equals(OpsOrderStatus.settled));

      // Table should be released for cleaning
      final finalTable = await opsStore.getTable('T1');
      expect(finalTable!.status, equals(OpsTableStatus.cleaning));
    });

    testWidgets(
        '4. Verify UI Master & Operations Screens Render for Spicy Bistro',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 1. Render Master Menu Items Screen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MasterMenuItemsScreen(store: masterStore)),
      ));
      await settle(tester);
      expect(find.byType(MasterMenuItemsScreen), findsOneWidget);
      expect(find.text('Spicy Butter Chicken'), findsOneWidget);

      // 2. Render Master Recipes Screen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MasterRecipesScreen(
                master: masterStore, inventory: inventoryStore)),
      ));
      await settle(tester);
      expect(find.byType(MasterRecipesScreen), findsOneWidget);

      // 3. Render Master Offers Screen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MasterOffersScreen(store: masterStore)),
      ));
      await settle(tester);
      expect(find.byType(MasterOffersScreen), findsOneWidget);

      // 4. Render Restaurant Dashboard Screen on Spicy Bistro's own
      //    device data (orders, KOTs, stock) — no simulated figures.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RestaurantDashboardScreen(
                ops: opsStore,
                inventory: inventoryStore,
                onNavigateToActionCenter: () {})),
      ));
      await settle(tester);
      expect(find.byType(RestaurantDashboardScreen), findsOneWidget);
      expect(find.text('Restaurant Dashboard'), findsOneWidget);
      expect(find.text('Inventory alerts'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 5. Render Franchise Command Center Screen — no backend here, so it
      //    shows the empty state rather than reference numbers.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FranchiseCommandCenterScreen(
                onNavigateToInventory: () {}, onSelectBranch: (_) {})),
      ));
      await settle(tester);
      expect(find.byType(FranchiseCommandCenterScreen), findsOneWidget);
      expect(find.text('No branch data yet'), findsOneWidget);

      // 6. Render POS Billing Screen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OpsPosBillingScreen(ops: opsStore, master: masterStore)),
      ));
      await settle(tester);
      expect(find.byType(OpsPosBillingScreen), findsOneWidget);

      // 7. Render Kitchen Display Screen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: OpsKitchenScreen(ops: opsStore)),
      ));
      await settle(tester);
      expect(find.byType(OpsKitchenScreen), findsOneWidget);
    });
  });
}
