import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operations_screens_test.dart' show stretchedWrapChildren;
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/presentation/master/master_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_offer_detail.dart';
import 'package:proviyaa_pos/presentation/master/master_offers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_purchase_order_detail.dart';
import 'package:proviyaa_pos/presentation/master/master_purchase_orders_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_raw_material_detail.dart';
import 'package:proviyaa_pos/presentation/master/master_receiving_grn.dart';
import 'package:proviyaa_pos/presentation/master/master_recipes_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_supplier_price_detail.dart';
import 'package:proviyaa_pos/presentation/master/master_suppliers_screen.dart';
import 'package:proviyaa_pos/presentation/master/recipe_lifecycle_tabs.dart';
import 'package:proviyaa_pos/presentation/master/recipe_workflow_tabs.dart';
import 'package:proviyaa_pos/presentation/vinii_theme.dart';

/// Renders every database-backed Master screen, filled with the seeded
/// reference data, at the shell's content width (1200) and a narrow
/// window (900), and fails on any layout exception such as a RenderFlex
/// overflow. Media screens are excluded: they load network images, which
/// widget tests always answer with HTTP 400.
void main() {
  late AppDatabase db;
  late DriftInventoryStore inv;
  late DriftMasterStore master;
  late RecipeData data;

  Future<void> setUpDb(WidgetTester tester) async {
    // closeStreamsSynchronously: drift otherwise schedules a zero-length
    // timer when a watched query is cancelled, which the test binding
    // reports as a pending-timer leak when the screen is disposed.
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    inv = DriftInventoryStore(db);
    master = DriftMasterStore(db);
    await tester.runAsync(() async {
      await MasterSeeder.seedIfNeeded(db);
      final recipes = await master.getRecipes();
      data = RecipeData(
          master: master,
          inventory: inv,
          recipes: recipes,
          recipe: recipes.firstWhere((r) => r.id == 'rcp-pbm'),
          materials: {for (final m in await inv.getMaterials()) m.id: m},
          quotes: await inv.getSupplierPrices(),
          suppliers: await inv.getSuppliers(),
          dishes: await master.getDishes());
    });
  }

  final screens = <String, Widget Function()>{
    'inventory': () => MasterInventoryScreen(inventory: inv, master: master),
    'raw material detail': () => MasterRawMaterialDetail(
        materialId: 'rm-paneer', inventory: inv, master: master, onBack: () {}),
    'suppliers': () => MasterSuppliersScreen(inventory: inv),
    'supplier price detail': () => MasterSupplierPriceDetail(
        quoteId: 'sp-paneer', inventory: inv, onBack: () {}),
    'purchase orders': () => MasterPurchaseOrdersScreen(inventory: inv),
    'purchase order detail': () => MasterPurchaseOrderDetail(
        poNumber: 'PO-1042',
        inventory: inv,
        onBack: () {},
        onEdit: (_) {},
        onReceiveStock: () {}),
    'receiving grn': () => MasterReceivingGrn(
        poNumber: 'PO-1042', inventory: inv, onBack: () {}, onPosted: (_) {}),
    'offers': () => MasterOffersScreen(store: master),
    'offer detail': () => MasterOfferDetail(
        store: master, offerId: 'OFF-2026-0041', onBack: () {}),
    'new offer form': () => MasterOfferDetail(store: master, onBack: () {}),
    'recipes': () => MasterRecipesScreen(master: master, inventory: inv),
    'recipe overview': () =>
        RecipeOverviewTab(data: data, onOpenRecipe: (_, __) {}),
    'recipe draft': () => RecipeDraftTab(data: data),
    'recipe ingredients': () => RecipeIngredientsTab(data: data),
    'recipe cost calculation': () => RecipeCostCalculationTab(data: data),
    'recipe supplier prices': () => RecipeSupplierPricesTab(data: data),
    'recipe trials': () => RecipeTrialsTab(data: data),
    'recipe staff training': () => RecipeStaffTrainingTab(data: data),
    'recipe feedback': () => RecipeFeedbackApprovalTab(data: data),
    'recipe menu activation': () => RecipeMenuActivationTab(data: data),
    'recipe cost impact': () => RecipeCostImpactTab(data: data),
  };

  for (final width in [1200.0, 900.0]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} lays out at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await setUpDb(tester);
        await tester.pumpWidget(MaterialApp(
            theme: viniiLightTheme(), home: Scaffold(body: e.value())));
        // Let the watched queries deliver their first rows.
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        expect(stretchedWrapChildren(tester), isEmpty,
            reason: 'chips/buttons stretched to full width');
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      });
    }
  }
}
