import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/main.dart';
import 'package:proviyaa_pos/presentation/master/master_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_media_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_menu_items_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_offers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_products_online_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_purchase_orders_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_recipes_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_suppliers_screen.dart';

/// Drives the whole app the way the admin does: sign in as
/// admin@onelatur.com, open the Master group in the sidebar and visit
/// every Master page, checking each one renders from the seeded database
/// without errors.
void main() {
  testWidgets('admin can reach every Master page from the sidebar',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    await tester.runAsync(() => MasterSeeder.seedIfNeeded(db));

    // Media thumbnails use network images, which the test binding always
    // answers with HTTP 400; those load errors are expected here.
    // RenderFlex overflows are checked per Master screen, at real content
    // widths, by master_screens_layout_test.dart; this test is about
    // navigation, so it only records them (the test font is wider than
    // Inter, which makes the shell/dashboard report small overflows).
    final overflows = <String>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        overflows.add(details.exceptionAsString());
        return;
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    await tester.pumpWidget(ProviyaaPosApp(
      database: db,
      config: const AppConfig(
        appEnv: 'local',
        dataMode: 'local_demo',
        apiBaseUrl: '',
        syncEnabled: false,
      ),
    ));
    await settle();

    await tester.enterText(find.byType(TextField).first, 'admin@onelatur.com');
    await tester.tap(find.text('Sign In'));
    await settle();

    // Expand the Master group if it's collapsed.
    if (find.text('Purchase Orders').evaluate().isEmpty) {
      await tester.tap(find.text('Master').first);
      await settle();
    }

    final pages = <String, Type>{
      'Menu Items': MasterMenuItemsScreen,
      'Products (Online)': MasterProductsOnlineScreen,
      'Media': MasterMediaScreen,
      'Offers': MasterOffersScreen,
      'Inventory': MasterInventoryScreen,
      'Recipes': MasterRecipesScreen,
      'Suppliers': MasterSuppliersScreen,
      'Purchase Orders': MasterPurchaseOrdersScreen,
    };
    for (final entry in pages.entries) {
      final item = find.text(entry.key).first;
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settle();
      expect(find.byType(entry.value), findsOneWidget,
          reason: '${entry.key} page did not open');
      expect(tester.takeException(), isNull,
          reason: '${entry.key} threw while rendering');
    }

    // Seeded data is actually on screen (read from the database).
    expect(find.textContaining('PO-1042'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
