import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/csv.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_menu_store.dart';
import 'package:proviyaa_pos/data/master_catalog.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/domain/inventory.dart';
import 'package:proviyaa_pos/domain/master.dart';

void main() {
  late AppDatabase db;
  late DriftInventoryStore inventory;
  late DriftMasterStore master;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    inventory = DriftInventoryStore(db);
    master = DriftMasterStore(db);
    await MasterSeeder.seedIfNeeded(db);
  });
  tearDown(() => db.close());

  test('seeding runs once and fills every Master table', () async {
    await MasterSeeder.seedIfNeeded(db); // second call is a no-op
    expect((await inventory.getMaterials()).length, 6);
    expect((await inventory.getSuppliers()).length, 8);
    expect((await inventory.getSupplierPrices()).length, 5);
    expect((await inventory.getPurchaseOrder('PO-1042'))!.lines.length, 2);
    expect((await master.getOffers()).length, 4);
    expect((await master.getRecipes()).length, 3);
    expect((await master.getDishes()).length, 7);
  });

  test('posting a GRN adds stock, logs movements and closes the PO', () async {
    final po = (await inventory.getPurchaseOrder('PO-1042'))!;
    final paneer = po.lines.firstWhere((l) => l.materialId == 'rm-paneer');
    final tomato = po.lines.firstWhere((l) => l.materialId == 'rm-tomato');
    final before = (await inventory.getMaterial('rm-paneer'))!.stockQty;

    await inventory.postGoodsReceipt('PO-1042', [
      GrnLineInput(
          lineId: paneer.id!, acceptedQty: 6, rejectedQty: 1, unitCost: 290),
      GrnLineInput(
          lineId: tomato.id!, acceptedQty: 25, rejectedQty: 0, unitCost: 40),
    ]);

    final after = (await inventory.getMaterial('rm-paneer'))!;
    expect(after.stockQty, closeTo(before + 6, 1e-9));
    expect(after.lastPurchasePrice, 290);
    final moves = await inventory.watchMovements('rm-paneer').first;
    expect(moves.first.reason, 'GRN Receipt');
    expect(moves.first.qtyDelta, 6);

    var updated = (await inventory.getPurchaseOrder('PO-1042'))!;
    expect(updated.status, PurchaseOrderStatus.partiallyReceived);

    // Receive the remaining 3 kg of paneer — now complete.
    await inventory.postGoodsReceipt('PO-1042', [
      GrnLineInput(
          lineId: paneer.id!, acceptedQty: 3, rejectedQty: 0, unitCost: 290),
    ]);
    updated = (await inventory.getPurchaseOrder('PO-1042'))!;
    expect(updated.status, PurchaseOrderStatus.received);

    // A PO that has received stock can no longer be edited.
    expect(() => inventory.savePurchaseOrder(updated), throwsStateError);
  });

  test('approving a supplier price becomes the costing price for recipes',
      () async {
    final recipe =
        (await master.getRecipes()).firstWhere((r) => r.id == 'rcp-pbm');
    Map<String, RawMaterial> byId(List<RawMaterial> ms) =>
        {for (final m in ms) m.id: m};
    final costBefore = recipe.totalCost(byId(await inventory.getMaterials()));

    await inventory.approveSupplierPrice('sp-paneer'); // ₹410/kg ABC Foods
    final paneer = (await inventory.getMaterial('rm-paneer'))!;
    expect(paneer.purchaseCostPerUnit, 410);
    expect(paneer.preferredSupplierId, 'SPL-0082');

    final costAfter = recipe.totalCost(byId(await inventory.getMaterials()));
    // 0.15 kg * 1.02 wastage * (410 - 300)
    expect(costAfter - costBefore, closeTo(0.15 * 1.02 * 110, 1e-6));
  });

  test('manual stock adjustments never go below zero', () async {
    await inventory.adjustStock('rm-cream', -100, reason: 'Wastage');
    expect((await inventory.getMaterial('rm-cream'))!.stockQty, 0);
    expect((await inventory.getMaterial('rm-cream'))!.status,
        StockStatus.outOfStock);
  });

  test('offer coupon codes are unique', () async {
    expect(
        () => master.upsertOffer(const MasterOffer(
            id: 'new',
            title: 'Dup',
            code: 'superfest30',
            campaignType: 'Flat Discount',
            discountRule: '10%',
            status: 'Draft')),
        throwsStateError);
    final copy = await master.cloneOffer('OFF-2026-0041');
    expect(copy.code, isNot('SUPERFEST30'));
    expect(copy.status, 'Draft');
  });

  test('Master menu items are the same rows the POS menu reads', () async {
    const dish = MasterDishItem(
      id: 'dish-new',
      name: 'Veg Biryani',
      category: 'Rice',
      sellingPrice: 260,
      foodCost: 80,
      marginPercent: 0,
      availability: 'In Stock',
      channels: ['POS', 'Swiggy'],
      kitchenStation: 'Rice Counter',
      status: 'Active',
      sku: 'IN-VB-001',
      hsn: '21069099',
      imageUrl: '',
      details: {'prepTime': 20},
    );
    await master.upsertDish(dish);
    final pos = await DriftMenuStore(db).getAllItems();
    final row = pos.firstWhere((i) => i.id == 'dish-new');
    expect(row.priceMinor, 26000);
    expect(row.categoryId, 'rice');

    final back =
        (await master.getDishes()).firstWhere((d) => d.id == 'dish-new');
    expect(back.details['prepTime'], 20);
    expect(back.channels, ['POS', 'Swiggy']);

    await master.setDishesAvailable(['dish-new'], false);
    expect(
        (await DriftMenuStore(db).getAllItems())
            .firstWhere((i) => i.id == 'dish-new')
            .available,
        isFalse);
  });

  test('a v2 database upgrades to v3 and keeps its menu rows', () async {
    final raw = NativeDatabase.memory(setup: (d) {
      d.execute(
          'CREATE TABLE menu_categories_table (id TEXT NOT NULL PRIMARY KEY, '
          'name TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT '
          "(CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))");
      d.execute('CREATE TABLE menu_items_table (id TEXT NOT NULL PRIMARY KEY, '
          'category_id TEXT NOT NULL, name TEXT NOT NULL, '
          'price_minor INTEGER NOT NULL, is_veg INTEGER NOT NULL DEFAULT 1, '
          'is_bestseller INTEGER NOT NULL DEFAULT 0, '
          'available INTEGER NOT NULL DEFAULT 1, unavailable_reason TEXT, '
          'created_at INTEGER NOT NULL DEFAULT '
          "(CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))");
      d.execute(
          "INSERT INTO menu_items_table (id, category_id, name, price_minor) "
          "VALUES ('old-1', 'mains', 'Old Dish', 19900)");
      d.execute('PRAGMA user_version = 2');
    });
    final old = AppDatabase(raw);
    final store = DriftMasterStore(old);
    final dishes = await store.getDishes();
    expect(dishes.single.name, 'Old Dish');
    expect(dishes.single.status, 'Active');
    await MasterSeeder.seedIfNeeded(old);
    expect((await DriftInventoryStore(old).getMaterials()), isNotEmpty);
    await old.close();
  });

  test('CSV round-trips quotes, commas, newlines and a BOM', () {
    final text = Csv.encode([
      'name',
      'note'
    ], [
      ['Paneer, Block', 'says "fresh"'],
      ['Multi\nline', ' padded '],
    ]);
    final records = Csv.decode('﻿$text');
    expect(records.length, 2);
    expect(records[0]('NAME'), 'Paneer, Block');
    expect(records[0]('note'), 'says "fresh"');
    expect(records[1]('name'), 'Multi\nline');
    expect(records[0].line, 2);
    expect(Csv.decode('price\n"₹1,240.50"\n').first.number('price'), 1240.5);
  });
}
