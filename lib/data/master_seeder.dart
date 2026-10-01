import 'package:drift/drift.dart';

import '../domain/inventory.dart';
import '../domain/master.dart';
import 'app_database.dart';
import 'drift_inventory_store.dart';
import 'drift_master_store.dart';
import 'inventory_catalog.dart';
import 'master_catalog.dart';

/// One-time seed of the Master tables from the approved-design reference
/// data, so a fresh install shows the same screens as Figma. Runs once
/// per database (guarded by an app_metadata flag); after that the
/// database is the only source of truth and the reference catalogs are
/// never read again by the Master screens.
class MasterSeeder {
  static const _flag = 'master_seed_v1';

  static Future<void> seedIfNeeded(AppDatabase db) async {
    final done = await (db.select(db.appMetadata)
          ..where((t) => t.key.equals(_flag)))
        .getSingleOrNull();
    final existingCount = (await db.select(db.menuItemsTable).get()).length;
    if (done != null && existingCount > 0) return;

    final inventory = DriftInventoryStore(db);
    final master = DriftMasterStore(db);

    await db.transaction(() async {
      for (final s in InventoryCatalog.suppliers) {
        await inventory.upsertSupplier(s);
      }
      for (final m in InventoryCatalog.rawMaterials) {
        await inventory.upsertMaterial(m);
      }
      const priceMaterial = {
        'sp-paneer': 'rm-paneer',
        'sp-butter': 'rm-butter',
        'sp-tomato': 'rm-tomato',
      };
      for (final q in InventoryCatalog.supplierPrices) {
        await inventory.upsertSupplierPrice(SupplierPriceQuote(
            id: q.id,
            ingredientName: q.ingredientName,
            emoji: q.emoji,
            linkedTo: q.linkedTo,
            supplierId: q.supplierId,
            unit: q.unit,
            lastPrice: q.lastPrice,
            currentPrice: q.currentPrice,
            lowestWeek: q.lowestWeek,
            source: q.source,
            priority: q.priority,
            skuId: q.skuId,
            materialId: priceMaterial[q.id]));
      }
      for (final po in InventoryCatalog.purchaseOrders) {
        await inventory.savePurchaseOrder(PurchaseOrder(
          number: po.number,
          supplierId: po.supplierId,
          orderDate: po.orderDate,
          expectedDelivery: po.expectedDelivery,
          status: po.status,
          createdBy: po.createdBy,
          deliveryAddress: po.deliveryAddress,
          deliveryCity: po.deliveryCity,
          taxPct: po.taxPct,
          lines: [
            for (final l in po.lines)
              PurchaseOrderLine(
                  materialName: l.materialName,
                  materialId: switch (l.materialName) {
                    'Fresh Paneer' => 'rm-paneer',
                    'Tomato' => 'rm-tomato',
                    'Fresh Cream' => 'rm-cream',
                    _ => null,
                  },
                  code: l.code,
                  unit: l.unit,
                  unitCost: l.unitCost,
                  orderedQty: l.orderedQty,
                  receivedQty: l.receivedQty,
                  rejectedQty: l.rejectedQty),
          ],
        ));
      }

      // Menu items: only add the Master reference dishes that aren't in
      // the POS menu yet — never overwrite rows the POS already owns.
      final existing =
          (await db.select(db.menuItemsTable).get()).map((r) => r.id).toSet();
      for (final d in MasterCatalogData.sampleDishes) {
        if (!existing.contains(d.id)) await master.upsertDish(d);
      }

      for (final o in _offers) {
        await master.upsertOffer(o);
      }
      for (final m in MasterCatalogData.sampleMedia) {
        await db.into(db.mediaAssetsTable).insert(
            MediaAssetsTableCompanion.insert(
                id: m.id,
                fileName: m.fileName,
                fileType: m.fileType,
                sizeBytes: Value(_parseSize(m.fileSize)),
                folder: m.folder,
                usageLabel: Value(m.usageLabel),
                imageUrl: Value(m.imageUrl)),
            mode: InsertMode.insertOrIgnore);
      }
      for (final r in _recipes) {
        await master.saveRecipe(r);
      }
      await db.into(db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(
              key: _flag, value: DateTime.now().toIso8601String()));
    });
  }

  static int _parseSize(String label) {
    final v = double.tryParse(label.split(' ').first) ?? 0;
    return label.contains('MB') ? (v * 1048576).round() : (v * 1024).round();
  }

  static final _offers = <MasterOffer>[
    MasterOffer(
        id: 'OFF-2026-0041',
        title: 'Swiggy Super Weekend Fest',
        code: 'SUPERFEST30',
        campaignType: 'Flat Discount',
        discountRule: '30% OFF (Upto ₹75)',
        minOrder: 250,
        maxDiscount: 75,
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 12),
        channels: 'Swiggy Delivery',
        linkedItems: 'Paneer Butter Masala, Chicken Tikka Masala',
        status: 'Active',
        usageCount: 142),
    MasterOffer(
        id: 'OFF-2026-0042',
        title: 'Midweek Paneer Delight Promo',
        code: 'PANEERFREE',
        campaignType: 'BOGO Free',
        discountRule: 'Free item on ₹350+',
        minOrder: 350,
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 18),
        channels: 'POS Dine-In, App',
        linkedItems: 'Paneer Butter Masala',
        status: 'Approved'),
    const MasterOffer(
        id: 'OFF-2026-0043',
        title: 'Latur Special Sweet Treat',
        code: 'SWEETLATUR',
        campaignType: 'Free Item',
        discountRule: 'Free Dessert on ₹199',
        minOrder: 199,
        channels: 'Zomato, Swiggy',
        linkedItems: 'Gulab Jamun (2 pcs)',
        status: 'Draft'),
    MasterOffer(
        id: 'OFF-2026-0039',
        title: 'Independence Day Carnival',
        code: 'LATUR15',
        campaignType: 'Percentage Off',
        discountRule: '15% Off (Upto ₹50)',
        minOrder: 150,
        maxDiscount: 50,
        startDate: DateTime(2026, 8, 12),
        endDate: DateTime(2026, 8, 16),
        channels: 'POS, Web Portal',
        status: 'Inactive',
        usageCount: 318),
  ];

  static const _recipes = <Recipe>[
    Recipe(
      id: 'rcp-pbm',
      code: 'RCP-NI-001',
      name: 'Paneer Butter Masala',
      version: 'v1.4',
      linkedMenuItemId: 'dish-1',
      linkedMenuItemName: 'Paneer Butter Masala (Full)',
      category: 'North Indian Curry',
      portion: 'Standard plate (420g)',
      targetPrice: 320,
      laborCost: 10,
      packagingCost: 8,
      trialResult: 'Pass (v1.3)',
      trainingDone: 5,
      trainingTotal: 5,
      status: 'Active',
      prepMethod:
          'Simmer spices, blend cream at 15m mark, garnish with fresh coriander.',
      allergens: 'Dairy (Cream, Butter, Paneer)',
      activeChannels: 'Swiggy, Zomato, Dine-In',
      lines: [
        RecipeLine(
            materialId: 'rm-paneer',
            name: 'Fresh Paneer (Block)',
            qty: 0.15,
            unit: 'kg',
            wastagePct: 2,
            isKey: true,
            substitute: 'Frozen Paneer Block'),
        RecipeLine(
            materialId: 'rm-tomato',
            name: 'Tomato',
            qty: 0.12,
            unit: 'kg',
            wastagePct: 5,
            isKey: true,
            substitute: 'Tomato Puree'),
        RecipeLine(
            materialId: 'rm-cream', name: 'Fresh Cream', qty: 0.05, unit: 'L'),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.03,
            unit: 'kg',
            isKey: true,
            substitute: 'Salted Butter Blocks'),
        RecipeLine(
            materialId: 'rm-spices',
            name: 'Indian Spices Mix',
            qty: 0.015,
            unit: 'kg',
            substitute: 'Garam Masala Blend'),
      ],
    ),
    Recipe(
      id: 'rcp-dal',
      code: 'RCP-PUL-004',
      name: 'Dal Makhani Premium',
      version: 'v1.0',
      linkedMenuItemName: 'Dal Makhani (Standard)',
      category: 'Dal & Lentils',
      portion: 'Bowl (350g)',
      targetPrice: 240,
      laborCost: 15,
      packagingCost: 8,
      trialResult: 'Needs Changes',
      trainingDone: 1,
      trainingTotal: 5,
      status: 'Needs Attention',
      allergens: 'Dairy (Butter, Cream)',
      lines: [
        RecipeLine(
            name: 'Black Urad Dal',
            qty: 0.12,
            unit: 'kg',
            wastagePct: 3,
            fallbackUnitCost: 140,
            isKey: true),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.04,
            unit: 'kg',
            isKey: true),
        RecipeLine(
            materialId: 'rm-cream', name: 'Fresh Cream', qty: 0.06, unit: 'L'),
        RecipeLine(
            materialId: 'rm-spices',
            name: 'Indian Spices Mix',
            qty: 0.01,
            unit: 'kg'),
      ],
    ),
    Recipe(
      id: 'rcp-naan',
      code: 'RCP-WHT-102',
      name: 'Garlic Butter Naan',
      version: 'v1.1',
      linkedMenuItemId: 'dish-6',
      linkedMenuItemName: 'Garlic Naan (Single)',
      category: 'Breads',
      portion: '1 Piece (90g)',
      targetPrice: 65,
      laborCost: 4,
      packagingCost: 2,
      trialResult: 'Trial Failed',
      trainingTotal: 5,
      status: 'Draft',
      allergens: 'Gluten, Dairy',
      lines: [
        RecipeLine(
            name: 'Maida (Refined Flour)',
            qty: 0.08,
            unit: 'kg',
            fallbackUnitCost: 45,
            isKey: true),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.01,
            unit: 'kg'),
        RecipeLine(
            name: 'Garlic (Chopped)',
            qty: 0.008,
            unit: 'kg',
            wastagePct: 10,
            fallbackUnitCost: 180),
      ],
    ),
  ];
}
