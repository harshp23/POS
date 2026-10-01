library;

/// Domain models for Franchise / Chain Vendor Panel screens:
/// - Command Center
/// - Branch Performance
/// - Branch Detail
/// - Exceptions & Actions
/// - Inventory & Supply Command Center

class ChainSystemOverview {
  final double totalSalesLakhs;
  final double? salesTargetVsPercent;
  final double? operatingProfitLakhs;
  final double? profitVsPriorPercent;
  final int totalOrders;
  final double? ordersVsLastYearPercent;
  final int averageOrderValue;
  final double? aovVsTargetPercent;
  final double? foodCostPercent;
  final double? foodCostVsTargetDiff;
  final double? labourCostPercent;
  final double? labourVsBenchmarkDiff;
  final double inventoryValueLakhs;
  final int criticalItemsCount;
  final double? customerRating;
  final int? totalReviews;

  const ChainSystemOverview({
    required this.totalSalesLakhs,
    this.salesTargetVsPercent,
    this.operatingProfitLakhs,
    this.profitVsPriorPercent,
    required this.totalOrders,
    this.ordersVsLastYearPercent,
    required this.averageOrderValue,
    this.aovVsTargetPercent,
    this.foodCostPercent,
    this.foodCostVsTargetDiff,
    this.labourCostPercent,
    this.labourVsBenchmarkDiff,
    required this.inventoryValueLakhs,
    required this.criticalItemsCount,
    this.customerRating,
    this.totalReviews,
  });
}

class HighImpactRecommendation {
  final String id;
  final String title;
  final String rootCause;
  final String whereLocation;
  final String financialImpact;
  final String recommendedAction;
  final String sourceBranch;
  final String targetBranch;
  final String item;
  final double quantityKg;
  final String owner;

  /// Unit of [quantityKg] ("kg", "ltr", "pcs"); empty when unknown.
  final String unit;

  /// Set when the recommendation comes from the backend (live data).
  final String? materialId;
  final String? fromLocationId;
  final String? toLocationId;

  const HighImpactRecommendation({
    required this.id,
    required this.title,
    required this.rootCause,
    required this.whereLocation,
    required this.financialImpact,
    required this.recommendedAction,
    required this.sourceBranch,
    required this.targetBranch,
    required this.item,
    required this.quantityKg,
    required this.owner,
    this.unit = '',
    this.materialId,
    this.fromLocationId,
    this.toLocationId,
  });
}

class BranchRankItem {
  final int rank;
  final String branchName;
  final double revenueLakhs;
  final int targetAchievedPercent;

  const BranchRankItem({
    required this.rank,
    required this.branchName,
    required this.revenueLakhs,
    required this.targetAchievedPercent,
  });
}

class BranchPerformanceRow {
  final String id;
  final String branchName;
  final String city;
  final int todayRevenue;
  final double targetMetPercent;
  final int aovInr;
  final double foodCostPercent;
  final double healthIndex;
  final String status;

  const BranchPerformanceRow({
    required this.id,
    required this.branchName,
    required this.city,
    required this.todayRevenue,
    required this.targetMetPercent,
    required this.aovInr,
    required this.foodCostPercent,
    required this.healthIndex,
    required this.status,
  });
}

class BranchIncident {
  final String time;
  final String description;
  final String severity; // 'critical', 'warning', 'info'

  const BranchIncident({
    required this.time,
    required this.description,
    required this.severity,
  });
}

class OperationalException {
  final String id;
  final String severityStatus; // 'Success', 'Warning', 'Critical'
  final String rootCause;
  final String location;
  final String bottomLineImpact;
  final String recommendedAction;
  final String actionType; // 'Transfer', 'Review', 'Reorder'

  const OperationalException({
    required this.id,
    required this.severityStatus,
    required this.rootCause,
    required this.location,
    required this.bottomLineImpact,
    required this.recommendedAction,
    required this.actionType,
  });
}

class ChainInventoryItem {
  final String category;
  final String itemName;
  final double delhiCpStockKg;
  final String delhiCpStatus; // 'Critical', 'Normal', 'Low'
  final double noidaS62StockKg;
  final String noidaS62Status; // 'Surplus', 'Excess', 'Normal'
  final double chainTargetKg;
  final String suggestionStatus;

  const ChainInventoryItem({
    required this.category,
    required this.itemName,
    required this.delhiCpStockKg,
    required this.delhiCpStatus,
    required this.noidaS62StockKg,
    required this.noidaS62Status,
    required this.chainTargetKg,
    required this.suggestionStatus,
  });
}

class PurchaseRequirement {
  final String branch;

  /// The supplier's name ("Unknown supplier" when it isn't on file).
  final String supplier;
  final double quantityKg;
  final int lastPricePerKg;
  final int currentPricePerKg;
  final double variancePercent;

  /// Backend purchase-order row id (live data only).
  final String? rowId;

  /// The order's number as people know it (PO-0012).
  final String? poNumber;

  /// When the order was placed.
  final DateTime? orderDate;

  /// Order value in paise (ordered quantity × unit cost).
  final int? amountMinor;

  /// Unit of [quantityKg] when every line uses the same one.
  final String? unit;

  /// The ordering branch's id (not shown; for filtering).
  final String? locationId;

  const PurchaseRequirement({
    required this.branch,
    required this.supplier,
    required this.quantityKg,
    required this.lastPricePerKg,
    required this.currentPricePerKg,
    required this.variancePercent,
    this.rowId,
    this.poNumber,
    this.orderDate,
    this.amountMinor,
    this.unit,
    this.locationId,
  });
}

/// "4 kg" / "4" — a quantity with its unit when one is known.
String quantityWithUnit(String qty, String? unit) {
  final u = unit?.trim() ?? '';
  return u.isEmpty ? qty : '$qty $u';
}

/// One branch's stock of a material (live inventory matrix).
class BranchStock {
  final String? locationId;
  final String branchName;
  final double stockQty;
  final double? reorderLevel;

  /// 'Critical', 'Low', 'Normal', 'Surplus' or 'Excess'.
  final String status;

  const BranchStock({
    this.locationId,
    required this.branchName,
    required this.stockQty,
    this.reorderLevel,
    required this.status,
  });
}

/// A material across every branch of the chain.
class ChainStockRow {
  final String? materialId;
  final String category;
  final String name;
  final String unit;
  final double chainStock;
  final double chainTarget;
  final List<BranchStock> branches;
  final String suggestion;

  const ChainStockRow({
    this.materialId,
    required this.category,
    required this.name,
    required this.unit,
    required this.chainStock,
    required this.chainTarget,
    required this.branches,
    required this.suggestion,
  });

  bool get isShort =>
      branches.any((b) => b.status == 'Critical' || b.status == 'Low');

  /// What the chain should do about this material.
  static String suggest(List<BranchStock> branches) {
    final short =
        branches.any((b) => b.status == 'Critical' || b.status == 'Low');
    final spare =
        branches.any((b) => b.status == 'Surplus' || b.status == 'Excess');
    if (short && spare) return 'Transfer';
    if (short) return 'Reorder';
    return 'Healthy';
  }

  factory ChainStockRow.fromReference(ChainInventoryItem i) => ChainStockRow(
        category: i.category,
        name: i.itemName,
        unit: 'kg',
        chainStock: i.delhiCpStockKg + i.noidaS62StockKg,
        chainTarget: i.chainTargetKg,
        branches: [
          BranchStock(
              branchName: 'Delhi CP',
              stockQty: i.delhiCpStockKg,
              status: i.delhiCpStatus),
          BranchStock(
              branchName: 'Noida S62',
              stockQty: i.noidaS62StockKg,
              status: i.noidaS62Status),
        ],
        suggestion: i.suggestionStatus,
      );
}
