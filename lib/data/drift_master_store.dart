import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/master.dart';
import 'app_database.dart';
import 'master_catalog.dart';

/// Master-module store for everything that isn't inventory: the master
/// menu catalogue, offers, media and recipes. Inventory data lives in
/// DriftInventoryStore; recipes only reference raw materials by id.
class DriftMasterStore {
  DriftMasterStore(this.db);
  final AppDatabase db;

  /// Upload cap for media stored in the local database.
  static const maxMediaBytes = 5 * 1024 * 1024;

  // ---------------------------------------------------------------------
  // Master menu items (same rows the POS sells — menu_items_table)
  // ---------------------------------------------------------------------

  static String categoryIdFor(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  /// Shown for a dish whose menu category row is missing — never the
  /// internal category id.
  static const uncategorised = 'Uncategorised';

  MasterDishItem _dish(MenuItemEntity r, Map<String, String> categoryNames) {
    final price = r.priceMinor / 100;
    final cost = r.foodCostMinor / 100;
    Map<String, Object?> details;
    try {
      details = (jsonDecode(r.detailsJson) as Map).cast<String, Object?>();
    } catch (_) {
      details = const {};
    }
    return MasterDishItem(
      id: r.id,
      name: r.name,
      category: _categoryName(categoryNames[r.categoryId]),
      sellingPrice: price,
      foodCost: cost,
      marginPercent: price > 0 ? (price - cost) / price * 100 : 0,
      availability: r.available ? r.availabilityLabel : 'Unavailable',
      channels: r.channels
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(),
      kitchenStation: r.kitchenStation,
      status: r.menuStatus,
      sku: r.sku,
      hsn: r.hsn,
      imageUrl: r.imageUrl,
      isVeg: r.dietType == 'veg',
      isNonVeg: r.dietType == 'non-veg',
      isEgg: r.dietType == 'egg',
      details: details,
    );
  }

  static String _categoryName(String? name) =>
      name == null || name.trim().isEmpty ? uncategorised : name;

  /// Emits when items or categories change.
  Stream<List<MasterDishItem>> watchDishes() => db
      .customSelect('SELECT 1',
          readsFrom: {db.menuItemsTable, db.menuCategoriesTable})
      .watch()
      .asyncMap((_) => getDishes());

  Future<List<MasterDishItem>> getDishes() async {
    final cats = await db.select(db.menuCategoriesTable).get();
    final names = {for (final c in cats) c.id: c.name};
    final rows = await (db.select(db.menuItemsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map((r) => _dish(r, names)).toList();
  }

  Future<void> upsertDish(MasterDishItem d) async {
    await db.transaction(() async {
      var categoryId = categoryIdFor(d.category);
      var keepMissingCategory = false;
      if (d.category == uncategorised) {
        // "Uncategorised" is only a label for a dish whose category row is
        // missing: keep pointing at the original category id so it comes
        // back when that category syncs, instead of moving the dish.
        final current = await (db.select(db.menuItemsTable)
              ..where((t) => t.id.equals(d.id)))
            .getSingleOrNull();
        if (current != null) {
          final currentCat = await (db.select(db.menuCategoriesTable)
                ..where((t) => t.id.equals(current.categoryId)))
              .getSingleOrNull();
          if (currentCat == null) {
            categoryId = current.categoryId;
            keepMissingCategory = true;
          }
        }
      }
      final cat = keepMissingCategory
          ? null
          : await (db.select(db.menuCategoriesTable)
                ..where((t) => t.id.equals(categoryId)))
              .getSingleOrNull();
      if (cat == null && !keepMissingCategory) {
        await db.into(db.menuCategoriesTable).insert(
            MenuCategoriesTableCompanion.insert(
                id: categoryId, name: d.category.trim()));
      }
      final unavailable =
          d.availability == 'Unavailable' || d.availability == 'Out of Stock';
      await db
          .into(db.menuItemsTable)
          .insertOnConflictUpdate(MenuItemsTableCompanion.insert(
            id: d.id,
            categoryId: categoryId,
            name: d.name.trim(),
            priceMinor: (d.sellingPrice * 100).round(),
            isVeg: Value(d.isVeg),
            available: Value(!unavailable),
            sku: Value(d.sku),
            hsn: Value(d.hsn),
            foodCostMinor: Value((d.foodCost * 100).round()),
            channels: Value(d.channels.join(', ')),
            kitchenStation: Value(d.kitchenStation),
            menuStatus: Value(d.status),
            availabilityLabel: Value(unavailable ? 'In Stock' : d.availability),
            imageUrl: Value(d.imageUrl),
            dietType: Value(d.isNonVeg
                ? 'non-veg'
                : d.isEgg
                    ? 'egg'
                    : 'veg'),
            detailsJson: Value(jsonEncode(d.details)),
          ));
    });
  }

  Future<void> deleteDishes(Iterable<String> ids) async {
    await (db.delete(db.menuItemsTable)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> setDishesAvailable(Iterable<String> ids, bool available) async {
    await (db.update(db.menuItemsTable)..where((t) => t.id.isIn(ids))).write(
        MenuItemsTableCompanion(
            available: Value(available),
            unavailableReason:
                Value(available ? null : 'Marked unavailable in Master')));
  }

  Future<void> setDishesStatus(Iterable<String> ids, String status) async {
    await (db.update(db.menuItemsTable)..where((t) => t.id.isIn(ids)))
        .write(MenuItemsTableCompanion(menuStatus: Value(status)));
  }

  /// Adds [delta] rupees (or [pct] percent) to the selling price of [ids].
  Future<void> adjustDishPrices(Iterable<String> ids,
      {double delta = 0, double pct = 0}) async {
    await db.transaction(() async {
      final rows = await (db.select(db.menuItemsTable)
            ..where((t) => t.id.isIn(ids)))
          .get();
      for (final r in rows) {
        final price = r.priceMinor / 100;
        final next = ((price + delta) * (1 + pct / 100)).clamp(0, 1e9);
        await (db.update(db.menuItemsTable)..where((t) => t.id.equals(r.id)))
            .write(MenuItemsTableCompanion(
                priceMinor: Value((next * 100).round())));
      }
    });
  }

  // ---------------------------------------------------------------------
  // Offers
  // ---------------------------------------------------------------------

  MasterOffer _offer(OfferEntity r) => MasterOffer(
        id: r.id,
        title: r.title,
        code: r.code,
        campaignType: r.campaignType,
        discountRule: r.discountRule,
        status: r.status,
        minOrder: r.minOrder,
        maxDiscount: r.maxDiscount,
        startDate: r.startDate,
        endDate: r.endDate,
        channels: r.channels,
        linkedItems: r.linkedItems,
        usageCount: r.usageCount,
      );

  Stream<List<MasterOffer>> watchOffers() => (db.select(db.offersTable)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch()
      .map((rows) => rows.map(_offer).toList());

  Future<List<MasterOffer>> getOffers() async =>
      (await db.select(db.offersTable).get()).map(_offer).toList();

  /// Coupon codes must be unique (case-insensitive).
  Future<void> upsertOffer(MasterOffer o) async {
    final code = o.code.trim().toUpperCase();
    final clash = await (db.select(db.offersTable)
          ..where((t) => t.code.upper().equals(code) & t.id.equals(o.id).not()))
        .getSingleOrNull();
    if (clash != null) {
      throw StateError(
          'Coupon code $code is already used by "${clash.title}".');
    }
    await db.into(db.offersTable).insertOnConflictUpdate(
        OffersTableCompanion.insert(
            id: o.id,
            title: o.title.trim(),
            code: code,
            campaignType: o.campaignType,
            discountRule: o.discountRule,
            minOrder: Value(o.minOrder),
            maxDiscount: Value(o.maxDiscount),
            startDate: Value(o.startDate),
            endDate: Value(o.endDate),
            channels: Value(o.channels),
            linkedItems: Value(o.linkedItems),
            status: o.status,
            usageCount: Value(o.usageCount),
            updatedAt: Value(DateTime.now())));
  }

  Future<void> setOfferStatus(String id, String status) async {
    await (db.update(db.offersTable)..where((t) => t.id.equals(id))).write(
        OffersTableCompanion(
            status: Value(status), updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteOffer(String id) async {
    await (db.delete(db.offersTable)..where((t) => t.id.equals(id))).go();
  }

  /// Copies an offer as a new Draft with a unique code.
  Future<MasterOffer> cloneOffer(String id) async {
    final src = _offer(await (db.select(db.offersTable)
          ..where((t) => t.id.equals(id)))
        .getSingle());
    final existing = (await getOffers()).map((o) => o.code).toSet();
    var n = 2;
    while (existing.contains('${src.code}$n')) {
      n++;
    }
    final copy = src.copyWith(
        id: 'OFF-${DateTime.now().millisecondsSinceEpoch}',
        title: '${src.title} (Copy)',
        code: '${src.code}$n',
        status: 'Draft',
        usageCount: 0);
    await upsertOffer(copy);
    return copy;
  }

  // ---------------------------------------------------------------------
  // Media
  // ---------------------------------------------------------------------

  MediaAssetRecord _media(MediaAssetEntity r) => MediaAssetRecord(
        id: r.id,
        fileName: r.fileName,
        fileType: r.fileType,
        folder: r.folder,
        sizeBytes: r.sizeBytes,
        usageLabel: r.usageLabel,
        imageUrl: r.imageUrl,
        bytes: r.bytes,
        createdAt: r.createdAt,
      );

  Stream<List<MediaAssetRecord>> watchMedia() => (db.select(db.mediaAssetsTable)
        ..where((t) => t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(_media).toList());

  static String fileTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'PNG Image',
      'jpg' || 'jpeg' => 'JPG Image',
      'webp' => 'WEBP Image',
      'gif' => 'GIF Image',
      'mp4' => 'MP4 Video',
      'mov' => 'MOV Video',
      'webm' => 'WEBM Video',
      _ => '${ext.toUpperCase()} File',
    };
  }

  Future<void> addMedia({
    required String fileName,
    required Uint8List bytes,
    required String folder,
    String usageLabel = '',
  }) async {
    if (bytes.length > maxMediaBytes) {
      throw StateError(
          '$fileName is ${(bytes.length / 1048576).toStringAsFixed(1)} MB; the limit is 5 MB.');
    }
    await db.into(db.mediaAssetsTable).insert(MediaAssetsTableCompanion.insert(
          id: 'media-${DateTime.now().microsecondsSinceEpoch}',
          fileName: fileName,
          fileType: fileTypeFor(fileName),
          sizeBytes: Value(bytes.length),
          folder: folder,
          usageLabel: Value(usageLabel),
          bytes: Value(bytes),
        ));
  }

  Future<void> updateMedia(String id,
      {String? fileName, String? folder, String? usageLabel}) async {
    await (db.update(db.mediaAssetsTable)..where((t) => t.id.equals(id)))
        .write(MediaAssetsTableCompanion(
      fileName: fileName == null ? const Value.absent() : Value(fileName),
      folder: folder == null ? const Value.absent() : Value(folder),
      usageLabel: usageLabel == null ? const Value.absent() : Value(usageLabel),
    ));
  }

  Future<void> replaceMediaFile(
      String id, String fileName, Uint8List bytes) async {
    if (bytes.length > maxMediaBytes) {
      throw StateError('$fileName is larger than the 5 MB limit.');
    }
    await (db.update(db.mediaAssetsTable)..where((t) => t.id.equals(id)))
        .write(MediaAssetsTableCompanion(
      fileName: Value(fileName),
      fileType: Value(fileTypeFor(fileName)),
      sizeBytes: Value(bytes.length),
      bytes: Value(bytes),
      imageUrl: const Value(null),
    ));
  }

  Future<void> archiveMedia(Iterable<String> ids) async {
    await (db.update(db.mediaAssetsTable)..where((t) => t.id.isIn(ids)))
        .write(const MediaAssetsTableCompanion(archived: Value(true)));
  }

  /// Folder names with their (non-archived) file counts.
  Stream<Map<String, int>> watchFolders() => watchMedia().map((items) {
        final counts = <String, int>{};
        for (final m in items) {
          counts[m.folder] = (counts[m.folder] ?? 0) + 1;
        }
        return counts;
      });

  // ---------------------------------------------------------------------
  // Recipes
  // ---------------------------------------------------------------------

  Recipe _recipe(RecipeEntity r, List<RecipeLineEntity> lines) => Recipe(
        id: r.id,
        code: r.code,
        name: r.name,
        version: r.version,
        linkedMenuItemId: r.linkedMenuItemId,
        linkedMenuItemName: r.linkedMenuItemName,
        category: r.category,
        portion: r.portion,
        targetPrice: r.targetPrice,
        laborCost: r.laborCost,
        packagingCost: r.packagingCost,
        trialResult: r.trialResult,
        trainingDone: r.trainingDone,
        trainingTotal: r.trainingTotal,
        status: r.status,
        prepMethod: r.prepMethod,
        allergens: r.allergens,
        activeChannels: r.activeChannels,
        lines: [
          for (final l in lines)
            RecipeLine(
                id: l.id,
                materialId: l.materialId,
                name: l.name,
                qty: l.qty,
                unit: l.unit,
                wastagePct: l.wastagePct,
                fallbackUnitCost: l.fallbackUnitCost,
                isKey: l.isKey,
                substitute: l.substitute),
        ],
      );

  Stream<List<Recipe>> watchRecipes() => db
      .customSelect('SELECT 1',
          readsFrom: {db.recipesTable, db.recipeLinesTable})
      .watch()
      .asyncMap((_) => getRecipes());

  Future<List<Recipe>> getRecipes() async {
    final rs = await (db.select(db.recipesTable)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    final lines = await db.select(db.recipeLinesTable).get();
    return [
      for (final r in rs)
        _recipe(r, lines.where((l) => l.recipeId == r.id).toList()),
    ];
  }

  /// Saves the recipe header and replaces its BOM lines.
  Future<void> saveRecipe(Recipe r) async {
    await db.transaction(() async {
      await db.into(db.recipesTable).insertOnConflictUpdate(
          RecipesTableCompanion.insert(
              id: r.id,
              code: r.code,
              name: r.name.trim(),
              version: Value(r.version),
              linkedMenuItemId: Value(r.linkedMenuItemId),
              linkedMenuItemName: Value(r.linkedMenuItemName),
              category: Value(r.category),
              portion: Value(r.portion),
              targetPrice: Value(r.targetPrice),
              laborCost: Value(r.laborCost),
              packagingCost: Value(r.packagingCost),
              trialResult: Value(r.trialResult),
              trainingDone: Value(r.trainingDone),
              trainingTotal: Value(r.trainingTotal),
              status: Value(r.status),
              prepMethod: Value(r.prepMethod),
              allergens: Value(r.allergens),
              activeChannels: Value(r.activeChannels),
              updatedAt: Value(DateTime.now())));
      await (db.delete(db.recipeLinesTable)
            ..where((t) => t.recipeId.equals(r.id)))
          .go();
      for (final l in r.lines) {
        await db.into(db.recipeLinesTable).insert(
            RecipeLinesTableCompanion.insert(
                recipeId: r.id,
                materialId: Value(l.materialId),
                name: l.name,
                qty: l.qty,
                unit: l.unit,
                wastagePct: Value(l.wastagePct),
                fallbackUnitCost: Value(l.fallbackUnitCost),
                isKey: Value(l.isKey),
                substitute: Value(l.substitute)));
      }
    });
  }

  Future<void> deleteRecipe(String id) async {
    await db.transaction(() async {
      await (db.delete(db.recipeLinesTable)
            ..where((t) => t.recipeId.equals(id)))
          .go();
      await (db.delete(db.recipesTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Menu activation: pushes an approved recipe's cost and target price to
  /// its linked menu item (the row the POS sells) and records channels.
  Future<void> activateRecipe(String recipeId,
      {required double foodCost, required List<String> channels}) async {
    await db.transaction(() async {
      final r = await (db.select(db.recipesTable)
            ..where((t) => t.id.equals(recipeId)))
          .getSingle();
      await (db.update(db.recipesTable)..where((t) => t.id.equals(recipeId)))
          .write(RecipesTableCompanion(
              status: const Value('Active'),
              activeChannels: Value(channels.join(', ')),
              updatedAt: Value(DateTime.now())));
      if (r.linkedMenuItemId != null) {
        await (db.update(db.menuItemsTable)
              ..where((t) => t.id.equals(r.linkedMenuItemId!)))
            .write(MenuItemsTableCompanion(
          priceMinor: Value((r.targetPrice * 100).round()),
          foodCostMinor: Value((foodCost * 100).round()),
          channels: Value(channels.join(', ')),
          menuStatus: const Value('Active'),
        ));
      }
    });
  }
}
