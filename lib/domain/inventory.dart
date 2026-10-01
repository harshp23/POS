/// Common Inventory domain — the single shared model for raw materials,
/// suppliers, supplier prices, purchase orders and goods receipt.
///
/// PRD R09 / S1 Phase 5: the restaurant must NOT get its own inventory
/// engine. Inventory, Recipes, Suppliers and Purchase Orders screens all
/// read these types (via lib/data/inventory_catalog.dart today, a shared
/// inventory projection later) instead of defining screen-local shapes.
library;

enum StockStatus { inStock, lowStock, criticalLow, outOfStock }

/// The one stock-status rule for every screen: out at zero, critical
/// below 30% of the reorder level, low below the reorder level.
StockStatus stockStatusFor(double stockQty, double reorderLevel) {
  if (stockQty <= 0) return StockStatus.outOfStock;
  if (reorderLevel > 0 && stockQty < reorderLevel * 0.3) {
    return StockStatus.criticalLow;
  }
  if (stockQty < reorderLevel) return StockStatus.lowStock;
  return StockStatus.inStock;
}

extension StockStatusLabel on StockStatus {
  String get label => switch (this) {
        StockStatus.inStock => 'In Stock',
        StockStatus.lowStock => 'Low Stock',
        StockStatus.criticalLow => 'Critical Low',
        StockStatus.outOfStock => 'Out of Stock',
      };
}

class RawMaterial {
  const RawMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQty,
    required this.reorderLevel,
    required this.maxCapacity,
    required this.purchaseCostPerUnit,
    required this.preferredSupplierId,
    required this.status,
    this.hsn = '',
    this.emoji = '📦',
    this.leadTimeDays = 2,
    this.lastPurchasePrice,
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double stockQty;
  final double reorderLevel;
  final double maxCapacity;
  final double purchaseCostPerUnit;
  final String preferredSupplierId;
  final StockStatus status;
  final String hsn;
  final String emoji;
  final int leadTimeDays;
  final double? lastPurchasePrice;

  /// Quantity needed to get back to the reorder level (never negative).
  double get suggestedOrderQty =>
      (reorderLevel - stockQty).clamp(0, double.infinity).toDouble();
}

/// How a recipe consumes a raw material (the BOM line, seen from the
/// material's side).
class MaterialRecipeLink {
  const MaterialRecipeLink({
    required this.materialId,
    required this.recipeName,
    required this.menuGroup,
    required this.qtyPerPortion,
    required this.costContribution,
    required this.prepYieldPct,
    this.impact = 'High',
  });
  final String materialId;
  final String recipeName;
  final String menuGroup;
  final String qtyPerPortion;
  final String costContribution;
  final int prepYieldPct;
  final String impact;
}

class InventorySupplier {
  const InventorySupplier({
    required this.id,
    required this.name,
    required this.legalName,
    required this.category,
    required this.contactPerson,
    required this.phone,
    required this.gstin,
    required this.city,
    required this.rating,
    this.paymentTerms = 'Net 15 Days',
    this.email = '',
    this.active = true,
  });
  final String id;
  final String name;
  final String legalName;
  final String category;
  final String contactPerson;
  final String phone;
  final String gstin;
  final String city;
  final double rating;
  final String paymentTerms;
  final String email;

  /// False once the supplier is archived: it stays readable (old orders and
  /// prices still name it) but is no longer offered in pickers.
  final bool active;

  /// The name as shown on screen — "(archived)" once it is archived.
  String get displayName => active ? name : '$name (archived)';

  /// "Pune · Ramesh Patil" — city and contact person, for picker captions.
  String get caption => [city, contactPerson]
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(' · ');
}

/// How a supplier id reads on screen: its name ("(archived)" when archived),
/// [none] when no supplier is set, and "Unknown supplier" only when the
/// record is really gone. Pass the full supplier list, archived included.
String supplierLabel(Iterable<InventorySupplier> suppliers, String id,
    {String none = 'Not set'}) {
  if (id.trim().isEmpty) return none;
  for (final s in suppliers) {
    if (s.id == id) return s.displayName;
  }
  return 'Unknown supplier';
}

enum PriceSource { merchantEntered, observed, imported, aiInferred, estimated }

PriceSource priceSourceFromLabel(String label) => PriceSource.values
    .firstWhere((s) => s.label == label, orElse: () => PriceSource.estimated);

extension PriceSourceLabel on PriceSource {
  String get label => switch (this) {
        PriceSource.merchantEntered => 'Merchant Entered',
        PriceSource.observed => 'Observed',
        PriceSource.imported => 'Imported',
        PriceSource.aiInferred => 'AI Inferred',
        PriceSource.estimated => 'Estimated',
      };
}

class SupplierPriceQuote {
  const SupplierPriceQuote({
    required this.id,
    required this.ingredientName,
    required this.emoji,
    required this.linkedTo,
    required this.supplierId,
    required this.unit,
    required this.lastPrice,
    required this.currentPrice,
    required this.lowestWeek,
    required this.source,
    required this.priority,
    this.skuId = '',
    this.materialId,
    this.approved = false,
  });
  final String id;
  final String ingredientName;
  final String emoji;
  final String linkedTo;
  final String supplierId;
  final String unit;
  final double lastPrice;
  final double currentPrice;
  final double lowestWeek;
  final PriceSource source;
  final String priority;
  final String skuId;
  final String? materialId;
  final bool approved;

  double get changePct =>
      lastPrice == 0 ? 0 : (currentPrice - lastPrice) / lastPrice * 100;
}

enum PurchaseOrderStatus {
  draft,
  pending,
  approved,
  partiallyReceived,
  received,
  cancelled
}

PurchaseOrderStatus purchaseOrderStatusFromLabel(String label) =>
    PurchaseOrderStatus.values.firstWhere((s) => s.label == label,
        orElse: () => PurchaseOrderStatus.draft);

extension PurchaseOrderStatusLabel on PurchaseOrderStatus {
  String get label => switch (this) {
        PurchaseOrderStatus.draft => 'Draft',
        PurchaseOrderStatus.pending => 'Pending',
        PurchaseOrderStatus.approved => 'Approved',
        PurchaseOrderStatus.partiallyReceived => 'Partially Received',
        PurchaseOrderStatus.received => 'Received',
        PurchaseOrderStatus.cancelled => 'Cancelled',
      };
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.materialName,
    required this.unit,
    required this.unitCost,
    required this.orderedQty,
    this.receivedQty = 0,
    this.rejectedQty = 0,
    this.code = '',
    this.id,
    this.materialId,
  });
  final int? id;
  final String? materialId;
  final String materialName;
  final String code;
  final String unit;
  final double unitCost;
  final double orderedQty;
  final double receivedQty;
  final double rejectedQty;

  double get total => unitCost * orderedQty;

  /// Quantity still expected from the supplier. Rejected quantity counts
  /// as settled (it was delivered and sent back), matching the store's
  /// "received + rejected >= ordered" completion rule.
  double get outstandingQty => (orderedQty - receivedQty - rejectedQty)
      .clamp(0, double.infinity)
      .toDouble();
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.number,
    required this.supplierId,
    required this.orderDate,
    required this.expectedDelivery,
    required this.status,
    required this.lines,
    this.createdBy = '',
    this.deliveryAddress = '',
    this.deliveryCity = '',
    this.taxPct = 5,
    this.notes = '',
  });
  final String number;
  final String supplierId;
  final String orderDate;
  final String expectedDelivery;
  final PurchaseOrderStatus status;
  final List<PurchaseOrderLine> lines;

  /// Name of the person who raised the order; empty when not recorded.
  final String createdBy;
  final String deliveryAddress;
  final String deliveryCity;
  final double taxPct;
  final String notes;

  double get subtotal => lines.fold(0, (s, l) => s + l.total);
  double get tax => subtotal * taxPct / 100;
  double get total => subtotal + tax;
  String get materialsListed => lines.map((l) => l.materialName).join(', ');
}

/// A single stock change (GRN receipt, manual adjustment, wastage).
class StockMovement {
  const StockMovement({
    required this.materialId,
    required this.qtyDelta,
    required this.reason,
    required this.createdAt,
    this.reference = '',
    this.unitCost,
  });
  final String materialId;
  final double qtyDelta;
  final String reason;
  final String reference;
  final double? unitCost;
  final DateTime createdAt;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// "08 Sep 2026" — the date format used across the Master screens.
String formatShortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

/// Parses [formatShortDate] output (and ISO dates); null if unparseable.
DateTime? parseShortDate(String s) {
  final t = s.trim();
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;
  final parts = t.split(RegExp(r'\s+'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = _months.indexWhere(
          (m) => m.toLowerCase() == parts[1].substring(0, 3).toLowerCase()) +
      1;
  final year = int.tryParse(parts[2]);
  if (day == null || month == 0 || year == null) return null;
  return DateTime(year, month, day);
}

/// Formats rupees the Indian way: ₹1,24,000.00
String formatInr(num value, {int decimals = 2}) {
  final neg = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  final dec = decimals > 0 ? '.${parts[1]}' : '';
  return '${neg ? '-' : ''}₹$whole$dec';
}
