import 'package:drift/drift.dart';

import '../domain/inventory.dart';
import '../domain/master.dart';
import '../domain/operations.dart';
import 'app_database.dart';
import 'drift_inventory_store.dart';
import 'drift_master_store.dart';
import 'drift_operations_store.dart';
import 'franchise_organization_store.dart';
import 'inventory_catalog.dart';
import 'master_catalog.dart';

/// Complete Seeder for Restaurant Vendor "Spicy Bistro" (admin@spicybistro.com / org_spicy_bistro_001).
/// Seeds Master Items, Recipes, Offers, Suppliers, Inventory, Franchise Outlets,
/// and Operations POS floor plan tables & orders.
class SpicyBistroSeeder {
  static const String orgId = 'org_spicy_bistro_001';
  static const String orgName = 'Spicy Bistro';
  static const String seedFlag = 'spicy_bistro_seed_v1';

  /// Master Dishes for Spicy Bistro catalog
  static const List<MasterDishItem> masterDishes = [
    MasterDishItem(
      id: 'dish_sb_01',
      name: 'Spicy Butter Chicken',
      category: 'MAIN COURSE',
      sellingPrice: 380.0,
      foodCost: 114.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'North Indian Curry Counter',
      status: 'Active',
      sku: 'SB-BC-001',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=500',
      isVeg: false,
      isNonVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_02',
      name: 'Paneer Butter Masala',
      category: 'MAIN COURSE',
      sellingPrice: 340.0,
      foodCost: 102.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'North Indian Curry Counter',
      status: 'Active',
      sku: 'SB-PBM-002',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_03',
      name: 'Garlic Butter Naan',
      category: 'BREADS',
      sellingPrice: 60.0,
      foodCost: 12.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'Tandoor Station',
      status: 'Active',
      sku: 'SB-GBN-003',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_04',
      name: 'Paneer Tikka Special',
      category: 'STARTERS',
      sellingPrice: 290.0,
      foodCost: 87.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'Tandoor Station',
      status: 'Active',
      sku: 'SB-PTS-004',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_05',
      name: 'Chicken Malai Tikka',
      category: 'STARTERS',
      sellingPrice: 320.0,
      foodCost: 96.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'Tandoor Station',
      status: 'Active',
      sku: 'SB-CMT-005',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=500',
      isVeg: false,
      isNonVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_06',
      name: 'Mango Lassi',
      category: 'BEVERAGES',
      sellingPrice: 180.0,
      foodCost: 36.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'App', 'Web', 'Dine-In'],
      kitchenStation: 'Beverage Bar',
      status: 'Active',
      sku: 'SB-ML-006',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1553787499-6f9133860278?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish_sb_07',
      name: 'Gulab Jamun (2 pcs)',
      category: 'DESSERTS',
      sellingPrice: 120.0,
      foodCost: 24.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy', 'Dine-In'],
      kitchenStation: 'Dessert Station',
      status: 'Active',
      sku: 'SB-GJ-007',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=500',
      isVeg: true,
    ),
  ];

  /// Master Recipes for Spicy Bistro
  static final List<Recipe> recipes = [
    const Recipe(
      id: 'rcp_sb_01',
      code: 'RCP-SB-BC-01',
      name: 'Spicy Butter Chicken',
      version: 'v1.4',
      linkedMenuItemId: 'dish_sb_01',
      linkedMenuItemName: 'Spicy Butter Chicken (Full)',
      category: 'North Indian Curry',
      portion: 'Standard portion (450g)',
      targetPrice: 380,
      laborCost: 15,
      packagingCost: 12,
      trialResult: 'Pass (v1.4)',
      trainingDone: 5,
      trainingTotal: 5,
      status: 'Active',
      prepMethod:
          'Marinate chicken in spiced yogurt for 4 hours. Tandoor roast, then simmer in tomato cashew makhani gravy.',
      allergens: 'Dairy (Butter, Cream, Yogurt), Cashew Nuts',
      activeChannels: 'Swiggy, Zomato, Dine-In',
      lines: [
        RecipeLine(
            materialId: 'rm-chicken',
            name: 'Raw Chicken Breast',
            qty: 0.25,
            unit: 'kg',
            wastagePct: 4,
            isKey: true),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.04,
            unit: 'kg',
            isKey: true),
        RecipeLine(
            materialId: 'rm-cream', name: 'Fresh Cream', qty: 0.05, unit: 'L'),
        RecipeLine(
            materialId: 'rm-tomato',
            name: 'Tomato Puree',
            qty: 0.15,
            unit: 'kg',
            wastagePct: 3),
        RecipeLine(
            materialId: 'rm-spices',
            name: 'Garam Masala Blend',
            qty: 0.02,
            unit: 'kg'),
      ],
    ),
    const Recipe(
      id: 'rcp_sb_02',
      code: 'RCP-SB-PBM-02',
      name: 'Paneer Butter Masala',
      version: 'v1.3',
      linkedMenuItemId: 'dish_sb_02',
      linkedMenuItemName: 'Paneer Butter Masala (Full)',
      category: 'North Indian Curry',
      portion: 'Standard portion (420g)',
      targetPrice: 340,
      laborCost: 10,
      packagingCost: 10,
      trialResult: 'Pass (v1.3)',
      trainingDone: 5,
      trainingTotal: 5,
      status: 'Active',
      prepMethod:
          'Sauté fresh cottage cheese cubes in butter, mix into rich tomato-cashew gravy.',
      allergens: 'Dairy (Paneer, Butter, Cream)',
      activeChannels: 'Swiggy, Zomato, Dine-In',
      lines: [
        RecipeLine(
            materialId: 'rm-paneer',
            name: 'Fresh Paneer Block',
            qty: 0.18,
            unit: 'kg',
            wastagePct: 2,
            isKey: true),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.035,
            unit: 'kg',
            isKey: true),
        RecipeLine(
            materialId: 'rm-cream', name: 'Fresh Cream', qty: 0.04, unit: 'L'),
        RecipeLine(
            materialId: 'rm-tomato',
            name: 'Ripe Red Tomato',
            qty: 0.12,
            unit: 'kg'),
      ],
    ),
    const Recipe(
      id: 'rcp_sb_03',
      code: 'RCP-SB-GBN-03',
      name: 'Garlic Butter Naan',
      version: 'v1.1',
      linkedMenuItemId: 'dish_sb_03',
      linkedMenuItemName: 'Garlic Butter Naan (Single)',
      category: 'Breads',
      portion: '1 Piece (100g)',
      targetPrice: 60,
      laborCost: 5,
      packagingCost: 3,
      trialResult: 'Pass (v1.1)',
      trainingDone: 5,
      trainingTotal: 5,
      status: 'Active',
      allergens: 'Gluten, Dairy',
      lines: [
        RecipeLine(
            name: 'Refined Wheat Flour (Maida)',
            qty: 0.09,
            unit: 'kg',
            fallbackUnitCost: 45,
            isKey: true),
        RecipeLine(
            materialId: 'rm-butter',
            name: 'Amul Butter Block',
            qty: 0.015,
            unit: 'kg',
            isKey: true),
        RecipeLine(
            name: 'Chopped Garlic',
            qty: 0.01,
            unit: 'kg',
            fallbackUnitCost: 160),
      ],
    ),
    const Recipe(
      id: 'rcp_sb_06',
      code: 'RCP-SB-ML-06',
      name: 'Mango Lassi',
      version: 'v1.2',
      linkedMenuItemId: 'dish_sb_06',
      linkedMenuItemName: 'Mango Lassi (350ml)',
      category: 'Beverages',
      portion: '1 Glass (350ml)',
      targetPrice: 180,
      laborCost: 4,
      packagingCost: 8,
      trialResult: 'Pass (v1.2)',
      trainingDone: 5,
      trainingTotal: 5,
      status: 'Active',
      allergens: 'Dairy (Yogurt/Curd)',
      lines: [
        RecipeLine(
            name: 'Fresh Curd / Yogurt',
            qty: 0.20,
            unit: 'kg',
            fallbackUnitCost: 65,
            isKey: true),
        RecipeLine(
            name: 'Alphonso Mango Pulp',
            qty: 0.08,
            unit: 'kg',
            fallbackUnitCost: 180,
            isKey: true),
        RecipeLine(
            name: 'Sugar Syrup', qty: 0.03, unit: 'kg', fallbackUnitCost: 40),
      ],
    ),
  ];

  /// Master Offers for Spicy Bistro
  static final List<MasterOffer> offers = [
    MasterOffer(
      id: 'OFF-SB-2026-001',
      title: 'Spicy Bistro Weekend Fest',
      code: 'SPICYFEST25',
      campaignType: 'Flat Discount',
      discountRule: '25% OFF (Upto ₹100)',
      minOrder: 300,
      maxDiscount: 100,
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 10, 10),
      channels: 'POS Dine-In, Zomato, Swiggy',
      linkedItems: 'Spicy Butter Chicken, Paneer Butter Masala',
      status: 'Active',
      usageCount: 284,
    ),
    MasterOffer(
      id: 'OFF-SB-2026-002',
      title: 'Free Garlic Naan Combo',
      code: 'NAANFREE',
      campaignType: 'BOGO Free',
      discountRule: 'Free Garlic Naan on ₹350+',
      minOrder: 350,
      startDate: DateTime(2026, 9, 22),
      endDate: DateTime(2026, 10, 15),
      channels: 'POS Dine-In, Web Portal',
      linkedItems: 'Garlic Butter Naan',
      status: 'Active',
      usageCount: 156,
    ),
  ];

  /// Master Media Assets for Spicy Bistro
  static const List<MasterMediaAsset> mediaAssets = [
    MasterMediaAsset(
      id: 'med_sb_01',
      fileName: 'butter_chicken_hero.png',
      fileType: 'PNG',
      fileSize: '2.4 MB',
      usageLabel: 'Menu Header & POS Display',
      imageUrl:
          'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=500',
      folder: 'Dishes',
    ),
    MasterMediaAsset(
      id: 'med_sb_02',
      fileName: 'spicy_bistro_logo.png',
      fileType: 'PNG',
      fileSize: '1.1 MB',
      usageLabel: 'Brand Logo & Receipt Header',
      imageUrl:
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500',
      folder: 'Branding',
    ),
  ];

  /// Main Seeding function for Spicy Bistro
  static Future<void> seedMasterAndFranchise(
      AppDatabase db, MultiTenantFranchiseStore franchiseStore) async {
    // Once per database, like the other seeders (it used to run on every
    // launch and overwrite the demo restaurant's own edits).
    final done = await (db.select(db.appMetadata)
          ..where((m) => m.key.equals(seedFlag)))
        .getSingleOrNull();
    if (done != null) return;
    final inventory = DriftInventoryStore(db);
    final master = DriftMasterStore(db);
    final ops = DriftOperationsStore(db);

    await db.transaction(() async {
      // 1. Seed Inventory Suppliers & Materials
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
          materialId: priceMaterial[q.id],
        ));
      }

      // 2. Seed Master Dishes into SQLite (Master Store)
      for (final d in masterDishes) {
        await master.upsertDish(d);
      }

      // 3. Seed Master Recipes
      for (final r in recipes) {
        await master.saveRecipe(r);
      }

      // 4. Seed Master Offers
      for (final o in offers) {
        await master.upsertOffer(o);
      }

      // 5. Seed Media Assets
      for (final m in mediaAssets) {
        await db.into(db.mediaAssetsTable).insert(
              MediaAssetsTableCompanion.insert(
                id: m.id,
                fileName: m.fileName,
                fileType: m.fileType,
                sizeBytes: Value(2457600),
                folder: m.folder,
                usageLabel: Value(m.usageLabel),
                imageUrl: Value(m.imageUrl),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      // 6. Seed Operations Floor Plan & Initial Orders for Spicy Bistro
      final tables = [
        const OpsTable(
            id: 'T1',
            label: 'T1',
            seats: 4,
            floor: 'Ground Floor',
            shape: 'square',
            status: OpsTableStatus.available),
        const OpsTable(
            id: 'T2',
            label: 'T2',
            seats: 4,
            floor: 'Ground Floor',
            shape: 'square',
            status: OpsTableStatus.occupied,
            guests: 3,
            serverName: 'Chef Rahul'),
        const OpsTable(
            id: 'T3',
            label: 'T3',
            seats: 2,
            floor: 'Ground Floor',
            shape: 'round',
            status: OpsTableStatus.reserved,
            reservedByName: 'Aman Deep'),
        const OpsTable(
            id: 'T4',
            label: 'T4',
            seats: 6,
            floor: 'Ground Floor',
            shape: 'square',
            status: OpsTableStatus.available),
        const OpsTable(
            id: 'T5',
            label: 'T5',
            seats: 4,
            floor: 'First Floor',
            shape: 'round',
            status: OpsTableStatus.available),
      ];
      for (final t in tables) {
        await ops.upsertTable(t);
      }
      await db.into(db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(
              key: seedFlag, value: DateTime.now().toIso8601String()));
    });

    // 7. Seed Multi-Tenant Franchise Items & Operational Records into Franchise Store
    for (final dish in masterDishes) {
      await franchiseStore.saveMenuItem(
        callerOrgId: orgId,
        item: MultiTenantMenuItemRecord(
          id: dish.id,
          organizationId: orgId,
          name: dish.name,
          category: dish.category,
          priceInr: dish.sellingPrice,
          isVeg: dish.isVeg,
          available: dish.availability == 'In Stock',
        ),
      );
    }

    // Seed Franchise Operations Records
    final franchiseRecords = [
      FranchiseOrganizationRecord(
        id: 'SB-STOCK-TRANSFER-01',
        organizationId: orgId,
        organizationName: orgName,
        locationId: 'loc_delhi_cp',
        recordType: 'stock_transfer',
        details: {
          'item': 'Raw Chicken Breast',
          'source_branch': 'Spicy Bistro - Noida Warehouse (Sector 62)',
          'target_branch': 'Spicy Bistro - Delhi Connaught Place',
          'quantity_kg': 35.0,
          'status': 'Completed',
          'transfer_date': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdByStaff: 'Chef Rahul',
      ),
      FranchiseOrganizationRecord(
        id: 'SB-SAFETY-STOCK-02',
        organizationId: orgId,
        organizationName: orgName,
        locationId: 'loc_delhi_cp',
        recordType: 'safety_stock_adjustment',
        details: {
          'item': 'Fresh Paneer Block',
          'previous_threshold_kg': 20.0,
          'new_threshold_kg': 40.0,
          'reason': 'High demand on weekend festival promo',
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        createdByStaff: 'Manager Priya',
      ),
      FranchiseOrganizationRecord(
        id: 'SB-TARGET-AMENDMENT-03',
        organizationId: orgId,
        organizationName: orgName,
        locationId: 'loc_bengaluru_indiranagar',
        recordType: 'target_amendment',
        details: {
          'target_revenue_lakhs': 2.8,
          'achieved_revenue_lakhs': 2.52,
          'target_met_pct': 90.0,
        },
        createdAt: DateTime.now(),
        createdByStaff: 'Region Head Abhishek',
      ),
    ];

    for (final rec in franchiseRecords) {
      await franchiseStore.saveRecord(callerOrgId: orgId, record: rec);
    }
  }
}
