import 'package:drift/drift.dart';

/// Drift tables behind the Master module (schema v3). They are the local
/// half of the common Inventory architecture (PRD R09): one set of raw
/// material / supplier / purchasing / stock-movement tables shared by
/// Inventory, Recipes, Suppliers and Purchase Orders — never a separate
/// restaurant inventory engine. Master menu items reuse the existing
/// `menu_items_table` (see the v3 columns added in app_database.dart) so
/// an item created in Master is the same row the POS sells.

@DataClassName('RawMaterialEntity')
class RawMaterialsTable extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get unit => text()();
  RealColumn get stockQty => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  RealColumn get maxCapacity => real().withDefault(const Constant(0))();
  RealColumn get purchaseCost => real().withDefault(const Constant(0))();
  RealColumn get lastPurchasePrice => real().nullable()();
  TextColumn get preferredSupplierId => text().nullable()();
  TextColumn get hsn => text().withDefault(const Constant(''))();
  TextColumn get emoji => text().withDefault(const Constant('📦'))();
  IntColumn get leadTimeDays => integer().withDefault(const Constant(2))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SupplierEntity')
class SuppliersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get legalName => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get contactPerson => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get gstin => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  RealColumn get rating => real().withDefault(const Constant(0))();
  TextColumn get paymentTerms =>
      text().withDefault(const Constant('Net 15 Days'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SupplierPriceEntity')
class SupplierPricesTable extends Table {
  TextColumn get id => text()();
  TextColumn get ingredientName => text()();
  TextColumn get materialId => text().nullable()();
  TextColumn get emoji => text().withDefault(const Constant('📦'))();
  TextColumn get linkedTo => text().withDefault(const Constant(''))();
  TextColumn get supplierId => text()();
  TextColumn get unit => text()();
  RealColumn get lastPrice => real()();
  RealColumn get currentPrice => real()();
  RealColumn get lowestWeek => real()();
  TextColumn get source => text()();
  TextColumn get priority => text().withDefault(const Constant('Medium'))();
  TextColumn get skuId => text().withDefault(const Constant(''))();
  BoolColumn get approved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PurchaseOrderEntity')
class PurchaseOrdersTable extends Table {
  TextColumn get number => text()();
  TextColumn get supplierId => text()();
  DateTimeColumn get orderDate => dateTime()();
  DateTimeColumn get expectedDelivery => dateTime()();
  TextColumn get status => text()();
  TextColumn get createdBy => text().withDefault(const Constant(''))();
  TextColumn get deliveryAddress => text().withDefault(const Constant(''))();
  TextColumn get deliveryCity => text().withDefault(const Constant(''))();
  RealColumn get taxPct => real().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {number};
}

@DataClassName('PurchaseOrderLineEntity')
class PurchaseOrderLinesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get poNumber => text()();
  TextColumn get materialId => text().nullable()();
  TextColumn get materialName => text()();
  TextColumn get code => text().withDefault(const Constant(''))();
  TextColumn get unit => text()();
  RealColumn get unitCost => real()();
  RealColumn get orderedQty => real()();
  RealColumn get receivedQty => real().withDefault(const Constant(0))();
  RealColumn get rejectedQty => real().withDefault(const Constant(0))();
}

/// Posted goods receipts (one row per GRN) — the audit record for stock
/// that entered through a purchase order.
@DataClassName('GoodsReceiptEntity')
class GoodsReceiptsTable extends Table {
  TextColumn get id => text()();
  TextColumn get poNumber => text()();
  DateTimeColumn get receivedAt => dateTime()();
  RealColumn get subtotal => real()();
  RealColumn get tax => real()();
  RealColumn get total => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Every stock change (GRN, manual adjustment, wastage) — stock on hand
/// in raw_materials_table is always the running result of these rows.
@DataClassName('StockMovementEntity')
class StockMovementsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get materialId => text()();
  RealColumn get qtyDelta => real()();
  TextColumn get reason => text()();
  TextColumn get reference => text().withDefault(const Constant(''))();
  RealColumn get unitCost => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('OfferEntity')
class OffersTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get code => text()();
  TextColumn get campaignType => text()();
  TextColumn get discountRule => text()();
  RealColumn get minOrder => real().withDefault(const Constant(0))();
  RealColumn get maxDiscount => real().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get channels => text().withDefault(const Constant(''))();
  TextColumn get linkedItems => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MediaAssetEntity')
class MediaAssetsTable extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get fileType => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get folder => text()();
  TextColumn get usageLabel => text().withDefault(const Constant(''))();

  /// Remote image for seeded assets; null for uploaded files.
  TextColumn get imageUrl => text().nullable()();

  /// Uploaded file content (kept small — the upload path caps size).
  BlobColumn get bytes => blob().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecipeEntity')
class RecipesTable extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get version => text().withDefault(const Constant('v1.0'))();
  TextColumn get linkedMenuItemId => text().nullable()();
  TextColumn get linkedMenuItemName => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get portion => text().withDefault(const Constant(''))();
  RealColumn get targetPrice => real().withDefault(const Constant(0))();
  RealColumn get laborCost => real().withDefault(const Constant(0))();
  RealColumn get packagingCost => real().withDefault(const Constant(0))();
  TextColumn get trialResult => text().withDefault(const Constant('Pending'))();
  IntColumn get trainingDone => integer().withDefault(const Constant(0))();
  IntColumn get trainingTotal => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Draft'))();
  TextColumn get prepMethod => text().withDefault(const Constant(''))();
  TextColumn get allergens => text().withDefault(const Constant(''))();
  TextColumn get activeChannels => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecipeLineEntity')
class RecipeLinesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recipeId => text()();
  TextColumn get materialId => text().nullable()();
  TextColumn get name => text()();

  /// Quantity per portion in the material's own unit (kg / L / pcs).
  RealColumn get qty => real()();
  TextColumn get unit => text()();
  RealColumn get wastagePct => real().withDefault(const Constant(0))();

  /// Price used when the line has no linked raw material.
  RealColumn get fallbackUnitCost => real().withDefault(const Constant(0))();
  BoolColumn get isKey => boolean().withDefault(const Constant(false))();
  TextColumn get substitute => text().withDefault(const Constant(''))();
}
