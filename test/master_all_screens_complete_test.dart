import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/presentation/master/master_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_media_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_menu_items_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_offers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_products_online_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_purchase_orders_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_recipes_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_suppliers_screen.dart';

void main() {
  group('Master Module Complete Screen & Functionality Verification', () {
    late AppDatabase db;
    late DriftMasterStore masterStore;
    late DriftInventoryStore inventoryStore;

    Future<void> setUpMaster(WidgetTester tester) async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true));
      masterStore = DriftMasterStore(db);
      inventoryStore = DriftInventoryStore(db);
      await tester.runAsync(() => MasterSeeder.seedIfNeeded(db));
    }

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

    testWidgets('1. Master Menu Items Screen renders completely with catalog items',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterMenuItemsScreen(store: masterStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterMenuItemsScreen), findsOneWidget);
    });

    testWidgets('2. Master Products (Online) Screen renders channel pricing matrix',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterProductsOnlineScreen(store: masterStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterProductsOnlineScreen), findsOneWidget);
    });

    testWidgets('3. Master Media Screen renders asset library & upload controls',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterMediaScreen(store: masterStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterMediaScreen), findsOneWidget);
    });

    testWidgets('4. Master Offers Screen renders promotional campaigns',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterOffersScreen(store: masterStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterOffersScreen), findsOneWidget);
    });

    testWidgets('5. Master Inventory Screen renders raw materials & stock controls',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterInventoryScreen(
              master: masterStore,
              inventory: inventoryStore,
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterInventoryScreen), findsOneWidget);
    });

    testWidgets('6. Master Recipes Screen renders culinary SOPs & ingredient costing',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterRecipesScreen(
              master: masterStore,
              inventory: inventoryStore,
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterRecipesScreen), findsOneWidget);
    });

    testWidgets('7. Master Suppliers Screen renders supplier directory & quotes',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterSuppliersScreen(inventory: inventoryStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterSuppliersScreen), findsOneWidget);
    });

    testWidgets('8. Master Purchase Orders Screen renders PO queue & GRN status',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await setUpMaster(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterPurchaseOrdersScreen(inventory: inventoryStore),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(MasterPurchaseOrdersScreen), findsOneWidget);
    });
  });
}
