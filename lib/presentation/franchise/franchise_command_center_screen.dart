import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// Chain-wide overview: every figure comes from [FranchiseSnapshot]
/// (computed by the Proviyaa backend from this organization's data).
class FranchiseCommandCenterScreen extends StatefulWidget {
  final VoidCallback onNavigateToInventory;
  final ValueChanged<String> onSelectBranch;

  /// Chain data from the backend; null shows the "connect" empty state.
  final FranchiseSnapshot? data;

  /// Executes a recommended stock transfer centrally. Null disables the
  /// Transfer Stock buttons.
  final Future<void> Function(HighImpactRecommendation rec)? onInitiateTransfer;

  /// Opens Exceptions & Actions from the open-exceptions banner.
  final VoidCallback? onNavigateToExceptions;

  const FranchiseCommandCenterScreen({
    super.key,
    required this.onNavigateToInventory,
    required this.onSelectBranch,
    this.data,
    this.onInitiateTransfer,
    this.onNavigateToExceptions,
  });

  @override
  State<FranchiseCommandCenterScreen> createState() =>
      _FranchiseCommandCenterScreenState();
}

class _FranchiseCommandCenterScreenState
    extends State<FranchiseCommandCenterScreen> {
  late List<HighImpactRecommendation> _recommendations =
      List.of(widget.data?.recommendations ?? const []);

  /// Recommendation ids with a transfer request in flight.
  final Set<String> _busy = {};

  @override
  void didUpdateWidget(FranchiseCommandCenterScreen old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _recommendations = List.of(widget.data?.recommendations ?? const []);
    }
  }

  static String? _pct(double? v) => v == null ? null : '$v%';

  /// "+6.2% vs target"; null when the comparison is unknown.
  static String? _diff(double? v, String what) =>
      v == null ? null : '${v > 0 ? '+' : ''}$v% $what';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const FranchiseNoData();
    final overview = data.overview;
    final c = PanelColors.of(context);
    final openExceptions = data.exceptions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Open exceptions banner
          InkWell(
            onTap: openExceptions > 0 ? widget.onNavigateToExceptions : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: openExceptions > 0
                    ? const Color(0xFFFFF3E0)
                    : ViniiColors.successPillBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: openExceptions > 0
                        ? const Color(0xFFFFB74D)
                        : ViniiColors.brandGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                      openExceptions > 0
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      color: openExceptions > 0
                          ? const Color(0xFFE65100)
                          : ViniiColors.emeraldText,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      openExceptions == 0
                          ? 'No open chain-level exceptions'
                          : openExceptions == 1
                              ? '1 chain-level exception requires action'
                              : '$openExceptions chain-level exceptions require action',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: openExceptions > 0
                            ? Colors.orange[900]
                            : ViniiColors.emeraldText,
                      ),
                    ),
                  ),
                  if (openExceptions > 0 &&
                      widget.onNavigateToExceptions != null)
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFE65100), size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              const Text(
                'Real-Time System Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Today, across ${data.branches.length} '
                '${data.branches.length == 1 ? 'branch' : 'branches'}',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
              final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
              Widget card(String label, String? value, String? sub,
                      {String? emptyTooltip}) =>
                  SizedBox(
                    width: w,
                    child: StatTile(
                      large: true,
                      label: label,
                      value: value,
                      sub: sub ?? '—',
                      emptyTooltip: emptyTooltip,
                    ),
                  );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  card(
                    'Total sales',
                    formatPaise(data.totalSalesMinor ??
                        (overview.totalSalesLakhs * 10000000).round()),
                    _diff(overview.salesTargetVsPercent, 'vs target'),
                  ),
                  card(
                    'Operating profit',
                    data.operatingProfitMinor != null
                        ? formatPaise(data.operatingProfitMinor!)
                        : overview.operatingProfitLakhs == null
                            ? null
                            : '₹${overview.operatingProfitLakhs}L',
                    _diff(overview.profitVsPriorPercent, 'vs prior'),
                    emptyTooltip: '$kNotEnoughData — needs labour cost in '
                        'branch targets',
                  ),
                  card(
                    'Orders',
                    '${overview.totalOrders}',
                    _diff(overview.ordersVsLastYearPercent, 'vs prior period'),
                  ),
                  card(
                    'Average order value',
                    data.averageOrderValueMinor == null
                        ? null
                        : formatPaise(data.averageOrderValueMinor!),
                    _diff(overview.aovVsTargetPercent, 'vs target'),
                    emptyTooltip: '$kNotEnoughData — no paid orders today',
                  ),
                  card(
                    'Food cost',
                    _pct(overview.foodCostPercent),
                    _diff(overview.foodCostVsTargetDiff, 'vs target'),
                  ),
                  card(
                    'Labour cost',
                    _pct(overview.labourCostPercent),
                    _diff(overview.labourVsBenchmarkDiff, 'vs benchmark'),
                    emptyTooltip: '$kNotEnoughData — no labour cost in '
                        'branch targets',
                  ),
                  card(
                    'Inventory value',
                    formatPaise(data.inventoryValueMinor ??
                        (overview.inventoryValueLakhs * 10000000).round()),
                    '${overview.criticalItemsCount} critical items',
                  ),
                  card(
                    'Customer rating',
                    overview.customerRating?.toString(),
                    overview.totalReviews == null
                        ? null
                        : '${overview.totalReviews} reviews',
                    emptyTooltip: '$kNotEnoughData — no reviews connected',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Flexible(
                child: Text(
                  'Active High-Impact Recommendations Queue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill('${_recommendations.length}',
                  color: _recommendations.isEmpty
                      ? ViniiColors.emeraldText
                      : ViniiColors.redSolid),
            ],
          ),
          const SizedBox(height: 12),
          if (_recommendations.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: const Center(
                child: Text('No stock transfers are recommended right now.'),
              ),
            )
          else
            for (final rec in _recommendations) _recommendationCard(rec),
          const SizedBox(height: 24),

          ResponsiveRow(
            children: [
              _leaderboardCard(data),
              _healthCard(data),
            ],
          ),
        ],
      ),
    );
  }

  bool _canTransfer(HighImpactRecommendation rec) =>
      widget.onInitiateTransfer != null &&
      rec.materialId != null &&
      rec.fromLocationId != null &&
      rec.toLocationId != null;

  Future<void> _transfer(HighImpactRecommendation rec) async {
    setState(() => _busy.add(rec.id));
    try {
      await widget.onInitiateTransfer!(rec);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(rec.id));
      showResultSnack(context, 'Transfer failed: ${friendlyErrorText(e)}',
          error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(rec.id);
      _recommendations.removeWhere((r) => r.id == rec.id);
    });
    showResultSnack(context,
        'Transfer recorded: ${quantityWithUnit(formatQty(rec.quantityKg), rec.unit)} ${rec.item} from ${rec.sourceBranch} to ${rec.targetBranch}.');
    widget.onNavigateToInventory();
  }

  Widget _recommendationCard(HighImpactRecommendation rec) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final busy = _busy.contains(rec.id);
    Widget line(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: color ?? textColor),
              children: [
                TextSpan(
                    text: label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B1C1C) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'STOCK BELOW REORDER LEVEL',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(rec.title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          line('Root cause: ', rec.rootCause),
          line('Where: ', rec.whereLocation),
          line('Value: ', rec.financialImpact, color: Colors.red[700]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: textColor),
                    children: [
                      const TextSpan(
                        text: 'Recommended: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ViniiColors.emeraldText),
                      ),
                      TextSpan(text: rec.recommendedAction),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              withTooltip(
                _canTransfer(rec)
                    ? null
                    : 'Transfers need the Proviyaa server connection.',
                ElevatedButton(
                  onPressed:
                      _canTransfer(rec) && !busy ? () => _transfer(rec) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViniiColors.brandGreen,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(busy ? 'Transferring…' : 'Transfer Stock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leaderboardCard(FranchiseSnapshot data) {
    final c = PanelColors.of(context);
    return DashCard(
      title: 'Branch Rank Leaderboard',
      subtitle: 'Top branches by sales today',
      child: data.leaderboard.isEmpty
          ? Text('No branch sales yet today.',
              style: TextStyle(fontSize: 12, color: c.muted))
          : Column(
              children: [
                for (final item in data.leaderboard)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => widget.onSelectBranch(item.branchName),
                      child: Row(
                        children: [
                          Text('#${item.rank}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.branchName,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Text(_branchSales(data, item),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 6),
                          KpiText(
                            _branchTarget(data, item),
                            emptyTooltip:
                                '$kNotEnoughData — no sales target set',
                            style: const TextStyle(
                                fontSize: 11, color: ViniiColors.emeraldText),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  BranchKpis? _kpisByName(FranchiseSnapshot data, String name) {
    final row = data.branches.where((b) => b.branchName == name).firstOrNull;
    return row == null ? null : data.kpisFor(row);
  }

  String _branchSales(FranchiseSnapshot data, BranchRankItem item) {
    final k = _kpisByName(data, item.branchName);
    return k != null ? formatPaise(k.revenueMinor) : '₹${item.revenueLakhs}L';
  }

  String? _branchTarget(FranchiseSnapshot data, BranchRankItem item) {
    final k = _kpisByName(data, item.branchName);
    if (k == null) return '(${item.targetAchievedPercent}% target)';
    return k.targetMetPercent == null
        ? null
        : '(${k.targetMetPercent}% target)';
  }

  Widget _healthCard(FranchiseSnapshot data) {
    final statuses = data.branches.map(data.statusOf).toList();
    final attention = statuses
        .where((s) => s != 'Success' && s != FranchiseSnapshot.notScored)
        .length;
    final unscored =
        statuses.where((s) => s == FranchiseSnapshot.notScored).length;
    Widget row(String label, String value, {bool alert = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500))),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          alert ? Colors.red[700] : ViniiColors.emeraldText)),
            ],
          ),
        );
    return DashCard(
      title: 'Operational Health',
      subtitle: 'Open issues across the chain',
      child: Column(
        children: [
          row('Open exceptions', '${data.exceptions.length}',
              alert: data.exceptions.isNotEmpty),
          row('Materials at or below reorder level',
              '${data.overview.criticalItemsCount}',
              alert: data.overview.criticalItemsCount > 0),
          row('Branches needing attention',
              '$attention of ${data.branches.length}',
              alert: attention > 0),
          if (unscored > 0)
            row('Branches not scored (no target or food-cost data)',
                '$unscored'),
          row('Purchase orders awaiting approval',
              '${data.purchaseRequirements.length}',
              alert: false),
        ],
      ),
    );
  }
}
