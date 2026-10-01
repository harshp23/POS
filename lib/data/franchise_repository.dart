import '../domain/franchise_models.dart';
import '../domain/inventory.dart' show formatInr;
import 'api/api_client.dart';

/// Wire values the chain screens show. A missing or odd field becomes "—"
/// (or the given fallback) instead of a cast error.
String _txt(Object? v, [String fallback = '—']) {
  final s = v == null ? '' : '$v'.trim();
  return s.isEmpty || s == 'null' ? fallback : s;
}

String? _optTxt(Object? v) {
  final s = v == null ? '' : '$v'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

double? _dbl(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int? _round(Object? v) => _dbl(v)?.round();

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// "12", "12.5" — a quantity without trailing zeros.
String _qty(num v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// A chain record (audit, target amendment, compliance task…) as saved in
/// pos_franchise_records.
class FranchiseRecord {
  const FranchiseRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.details,
    this.locationId,
    this.createdAt,
    this.createdByName,
  });

  final String id;
  final String type;
  final String title;
  final String status;
  final Map<String, dynamic> details;
  final String? locationId;
  final DateTime? createdAt;
  final String? createdByName;

  factory FranchiseRecord.fromJson(Map<String, dynamic> j) => FranchiseRecord(
        id: '${j['id']}',
        type: _txt(j['record_type'], ''),
        title: _txt(j['title']),
        status: _txt(j['status'], 'open'),
        details: j['details'] is Map
            ? (j['details'] as Map).cast<String, dynamic>()
            : const {},
        locationId: _optTxt(j['location_id']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        createdByName: _optTxt(j['created_by_name']),
      );
}

/// One branch's KPIs exactly as the backend computed them. The
/// [BranchPerformanceRow] domain rows use 0 for a missing value; these keep
/// "no data" (null) apart from a real zero so the screens can show "—".
class BranchKpis {
  const BranchKpis({
    this.locationId,
    this.code,
    this.revenueMinor = 0,
    this.orders = 0,
    this.targetMinor,
    this.targetMetPercent,
    this.aovMinor,
    this.foodCostPercent,
    this.criticalItems = 0,
    this.healthIndex,
  });

  final String? locationId;
  final String? code;

  /// Sales of the period (settled orders), in paise.
  final int revenueMinor;

  /// Orders placed in the period (cancelled excluded).
  final int orders;

  /// Sales target of the period in paise; null = no target set.
  final int? targetMinor;

  /// Sales ÷ target; null without a target.
  final double? targetMetPercent;

  /// Sales ÷ paid orders; null without paid orders.
  final int? aovMinor;

  /// Food cost ÷ net sales; null without sales.
  final double? foodCostPercent;

  /// Materials at or below their reorder level at this branch.
  final int criticalItems;

  /// The backend's 0–10 health index.
  final double? healthIndex;

  /// The backend scores a missing sales target or food cost as a neutral
  /// default; with neither, the health index says nothing about the branch.
  bool get healthMeaningful =>
      healthIndex != null &&
      (targetMetPercent != null || foodCostPercent != null);

  factory BranchKpis.fromJson(Map<String, dynamic> b) => BranchKpis(
        locationId: _optTxt(b['location_id']),
        code: _optTxt(b['code']),
        revenueMinor: _round(b['revenue_minor']) ?? 0,
        orders: _round(b['orders']) ?? 0,
        targetMinor: _round(b['target_minor']),
        targetMetPercent: _dbl(b['target_met_pct']),
        aovMinor: _round(b['aov_minor']),
        foodCostPercent: _dbl(b['food_cost_pct']),
        criticalItems: _round(b['critical_items']) ?? 0,
        healthIndex: _dbl(b['health_index']),
      );
}

/// What the Franchise / Chain screens show — always this organization's
/// own data from the Proviyaa backend. There is no reference/demo snapshot:
/// without a backend the chain screens show an empty state.
class FranchiseSnapshot {
  const FranchiseSnapshot({
    required this.overview,
    required this.recommendations,
    required this.leaderboard,
    required this.branches,
    required this.exceptions,
    required this.purchaseRequirements,
    this.inventory = const [],
    required this.live,
    this.branchKpis = const {},
    this.totalSalesMinor,
    this.averageOrderValueMinor,
    this.operatingProfitMinor,
    this.inventoryValueMinor,
    this.purchasesWithoutQuote = const {},
  });

  final ChainSystemOverview overview;
  final List<HighImpactRecommendation> recommendations;
  final List<BranchRankItem> leaderboard;
  final List<BranchPerformanceRow> branches;

  /// Open exceptions.
  final List<OperationalException> exceptions;
  final List<PurchaseRequirement> purchaseRequirements;

  /// Every material across the chain's branches.
  final List<ChainStockRow> inventory;

  /// true = computed by the backend from this organization's data.
  final bool live;

  /// Nullable KPIs of each [branches] row, keyed by [BranchPerformanceRow.id].
  final Map<String, BranchKpis> branchKpis;

  /// Exact chain figures in paise ([overview] rounds them to lakhs).
  /// Null = not reported (e.g. no paid orders → no AOV).
  final int? totalSalesMinor;
  final int? averageOrderValueMinor;
  final int? operatingProfitMinor;
  final int? inventoryValueMinor;

  /// [PurchaseRequirement.rowId]s with no supplier price quote on file —
  /// their last/current price and variance are unknown, not zero.
  final Set<String> purchasesWithoutQuote;

  BranchKpis? kpisFor(BranchPerformanceRow row) => branchKpis[row.id];

  /// The row's status ('Success', 'Warning', 'Critical'), or 'Not scored'
  /// when the backend had neither a sales target nor food-cost data for it
  /// (its health index is then only a neutral default).
  String statusOf(BranchPerformanceRow row) {
    final k = kpisFor(row);
    return k != null && !k.healthMeaningful ? notScored : row.status;
  }

  static const notScored = 'Not scored';
}

abstract interface class FranchiseRepository {
  Future<FranchiseSnapshot> load();
  Future<void> initiateTransfer(HighImpactRecommendation rec);
  Future<void> resolveException(String id);
  Future<void> resolveAllExceptions();

  /// Approves or rejects a pending purchase order. Throws when [req] has no
  /// server row id.
  Future<void> decidePurchase(PurchaseRequirement req, {required bool approve});

  /// Appends a chain record (audit, target amendment, safety-stock change…).
  Future<void> logRecord(
      String type, String title, Map<String, Object?> details,
      {String? status, String? locationId});

  /// Newest-first records of [type].
  Future<List<FranchiseRecord>> records(String type, {int limit = 50});

  /// Moves a record to `open`, `in_progress`, `completed` or `cancelled`.
  Future<void> updateRecordStatus(String id, String status);
}

/// Franchise data from the Proviyaa backend (/v1/franchise/*), computed
/// from the organization's real orders, stock, targets and exceptions.
class ApiFranchiseRepository implements FranchiseRepository {
  ApiFranchiseRepository(this.api);
  final ProviyaaApiClient api;

  static double _lakhs(Object? minor) {
    final m = _dbl(minor);
    return m == null ? 0 : ((m / 100) / 100000 * 100).roundToDouble() / 100;
  }

  static List<Map<String, dynamic>> _rows(Object? v) => [
        for (final e in (v is List ? v : const []))
          if (e is Map) e.cast<String, dynamic>(),
      ];

  static Map<String, dynamic> _object(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  /// The supplier's name — never its id or the text "null".
  static String _supplierName(Map<String, dynamic> p) {
    final name = _optTxt(p['supplier_name']);
    if (name == null ||
        name == _optTxt(p['supplier_id']) ||
        _uuid.hasMatch(name)) {
      return 'Unknown supplier';
    }
    return name;
  }

  @override
  Future<FranchiseSnapshot> load() async {
    final results = await Future.wait([
      api.get('v1/franchise/overview'),
      api.get('v1/franchise/branch-performance'),
      api.get('v1/franchise/inventory'),
      api.get('v1/franchise/exceptions', query: {'status': 'open'}),
      api.get('v1/franchise/purchase-requirements'),
    ]);
    final o = _object(results[0]);
    final perf = _rows(_object(results[1])['branches']);
    final inv = _object(results[2]);
    final exceptions = _rows(results[3]);
    final purchases = _rows(results[4]);
    final names = <Object?, String>{
      for (final b in perf)
        b['location_id']: _txt(b['branch_name'], 'Unknown branch')
    };
    String branchId(Map<String, dynamic> b) =>
        '${b['location_id'] ?? 'unassigned'}';

    return FranchiseSnapshot(
      live: true,
      totalSalesMinor: _round(o['total_sales_minor']),
      averageOrderValueMinor: _round(o['average_order_value_minor']),
      operatingProfitMinor: _round(o['operating_profit_minor']),
      inventoryValueMinor: _round(o['inventory_value_minor']),
      branchKpis: {for (final b in perf) branchId(b): BranchKpis.fromJson(b)},
      purchasesWithoutQuote: {
        for (final p in purchases)
          if (p['row_id'] != null &&
              (p['last_price'] == null || p['current_price'] == null))
            '${p['row_id']}',
      },
      overview: ChainSystemOverview(
        totalSalesLakhs: _lakhs(o['total_sales_minor']),
        salesTargetVsPercent: _dbl(o['sales_vs_target_pct']),
        operatingProfitLakhs: o['operating_profit_minor'] == null
            ? null
            : _lakhs(o['operating_profit_minor']),
        profitVsPriorPercent: null,
        totalOrders: _round(o['total_orders']) ?? 0,
        ordersVsLastYearPercent: _dbl(o['orders_vs_prior_pct']),
        averageOrderValue:
            ((_dbl(o['average_order_value_minor']) ?? 0) / 100).round(),
        aovVsTargetPercent: _dbl(o['aov_vs_target_pct']),
        foodCostPercent: _dbl(o['food_cost_pct']),
        foodCostVsTargetDiff: _dbl(o['food_cost_vs_target_diff']),
        labourCostPercent: _dbl(o['labour_cost_pct']),
        labourVsBenchmarkDiff: null,
        inventoryValueLakhs: _lakhs(o['inventory_value_minor']),
        criticalItemsCount: _round(o['critical_items']) ?? 0,
        customerRating: _dbl(o['customer_rating']),
        totalReviews: _round(o['total_reviews']),
      ),
      inventory: [
        for (final m in _rows(inv['materials'])) _stockRow(m),
      ],
      recommendations: [
        for (final (i, s) in _rows(inv['transfer_suggestions']).indexed)
          _recommendation(i, s),
      ],
      leaderboard: [
        for (final (i, b) in perf.take(3).indexed)
          BranchRankItem(
            rank: i + 1,
            branchName: _txt(b['branch_name'], 'Unknown branch'),
            revenueLakhs: _lakhs(b['revenue_minor']),
            targetAchievedPercent: _round(b['target_met_pct']) ?? 0,
          ),
      ],
      branches: [
        for (final b in perf)
          BranchPerformanceRow(
            id: branchId(b),
            branchName: _txt(b['branch_name'], 'Unknown branch'),
            // The branch code (shown as "Code LTR-1"); empty when unset.
            city: _txt(b['code'], ''),
            todayRevenue: ((_dbl(b['revenue_minor']) ?? 0) / 100).round(),
            targetMetPercent: _dbl(b['target_met_pct']) ?? 0,
            aovInr: ((_dbl(b['aov_minor']) ?? 0) / 100).round(),
            foodCostPercent: _dbl(b['food_cost_pct']) ?? 0,
            healthIndex: _dbl(b['health_index']) ?? 0,
            status: _txt(b['status'], FranchiseSnapshot.notScored),
          ),
      ],
      exceptions: [
        for (final e in exceptions)
          OperationalException(
            id: '${e['id']}',
            severityStatus: switch (e['severity']) {
              'critical' => 'Critical',
              'warning' => 'Warning',
              _ => 'Success',
            },
            rootCause: _txt(e['root_cause']),
            location: e['location_id'] == null
                ? 'Organization'
                : names[e['location_id']] ??
                    _optTxt(e['branch_name']) ??
                    'Unknown branch',
            bottomLineImpact: _txt(e['impact'], ''),
            recommendedAction: _txt(e['recommended_action'], ''),
            actionType: _txt(e['action_type'], 'Review'),
          ),
      ],
      purchaseRequirements: [
        for (final p in purchases)
          PurchaseRequirement(
            branch: _txt(p['branch_name'], 'Unknown branch'),
            supplier: _supplierName(p),
            quantityKg: _dbl(p['quantity']) ?? 0,
            lastPricePerKg: _round(p['last_price']) ?? 0,
            currentPricePerKg: _round(p['current_price']) ?? 0,
            variancePercent: _dbl(p['variance_pct']) ?? 0,
            rowId: _optTxt(p['row_id']),
            poNumber: _optTxt(p['po_number']),
            orderDate: DateTime.tryParse('${p['order_date'] ?? ''}'),
            amountMinor: _round(p['amount_minor']),
            unit: _optTxt(p['unit']),
            locationId: _optTxt(p['location_id']),
          ),
      ],
    );
  }

  ChainStockRow _stockRow(Map<String, dynamic> m) {
    final branches = [
      for (final j in _rows(m['branches']))
        BranchStock(
          locationId: _optTxt(j['location_id']),
          branchName: _txt(j['branch_name'], 'Organization'),
          stockQty: _dbl(j['stock_qty']) ?? 0,
          reorderLevel: _dbl(j['reorder_level']),
          status: _txt(j['status'], 'Normal'),
        ),
    ];
    return ChainStockRow(
      materialId: _optTxt(m['material_id']),
      category: _txt(m['category']),
      name: _txt(m['name']),
      unit: _txt(m['unit'], ''),
      chainStock: _dbl(m['chain_stock']) ?? 0,
      chainTarget: _dbl(m['chain_target']) ?? 0,
      branches: branches,
      suggestion: ChainStockRow.suggest(branches),
    );
  }

  HighImpactRecommendation _recommendation(int i, Map<String, dynamic> s) {
    final item = _txt(s['material_name'], 'Stock');
    final to = _txt(s['to_branch'], 'Unknown branch');
    final from = _txt(s['from_branch'], 'Unknown branch');
    final reason = _txt(s['reason']);
    final quantity = _dbl(s['quantity']) ?? 0;
    final unit = _txt(s['unit'], '');
    final impact = formatInr((_dbl(s['impact_minor']) ?? 0) / 100, decimals: 0);
    return HighImpactRecommendation(
      id: 'TRF-${i + 1}',
      title: '$item low at $to — $reason',
      rootCause: reason,
      whereLocation: to,
      financialImpact: '$impact of stock to move',
      recommendedAction:
          'Transfer ${quantityWithUnit(_qty(quantity), unit)} from $from',
      sourceBranch: from,
      targetBranch: to,
      item: item,
      quantityKg: quantity,
      unit: unit,
      owner: 'Chain operations',
      materialId: _optTxt(s['material_id']),
      fromLocationId: _optTxt(s['from_location_id']),
      toLocationId: _optTxt(s['to_location_id']),
    );
  }

  @override
  Future<void> initiateTransfer(HighImpactRecommendation rec) async {
    if (rec.materialId == null ||
        rec.fromLocationId == null ||
        rec.toLocationId == null) {
      throw const ApiException(
          422, 'not_live', 'This recommendation is reference data only.');
    }
    await api.post('v1/franchise/stock-transfers', {
      'material_id': rec.materialId,
      'from_location_id': rec.fromLocationId,
      'to_location_id': rec.toLocationId,
      'quantity': rec.quantityKg,
    });
  }

  @override
  Future<void> resolveException(String id) =>
      api.patch('v1/franchise/exceptions/$id', {'status': 'resolved'});

  @override
  Future<void> resolveAllExceptions() =>
      api.post('v1/franchise/exceptions/resolve-all');

  @override
  Future<void> decidePurchase(PurchaseRequirement req,
      {required bool approve}) async {
    if (req.rowId == null) {
      throw const ApiException(422, 'no_row_id',
          'This purchase order has not reached the Proviyaa server yet.');
    }
    await api.post('v1/franchise/purchase-orders/${req.rowId}/decision',
        {'decision': approve ? 'approve' : 'reject'});
  }

  @override
  Future<void> updateRecordStatus(String id, String status) =>
      api.patch('v1/franchise/records/$id', {'status': status});

  @override
  Future<void> logRecord(
          String type, String title, Map<String, Object?> details,
          {String? status, String? locationId}) =>
      api.post('v1/franchise/records', {
        'record_type': type,
        'title': title,
        'details': details,
        if (status != null) 'status': status,
        if (locationId != null) 'location_id': locationId,
      });

  @override
  Future<List<FranchiseRecord>> records(String type, {int limit = 50}) async {
    final rows = await api.get('v1/franchise/records',
        query: {'record_type': type, 'limit': '$limit'});
    return [
      for (final r in (rows as List? ?? const []))
        FranchiseRecord.fromJson((r as Map).cast<String, dynamic>()),
    ];
  }
}
