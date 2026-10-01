import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// Today's KPIs of every branch, side by side, as the Proviyaa backend
/// computed them. A KPI without data shows "—".
class BranchPerformanceScreen extends StatefulWidget {
  final ValueChanged<String> onSelectBranch;

  /// Branch performance from the backend; null shows the empty state.
  final FranchiseSnapshot? data;

  const BranchPerformanceScreen({
    super.key,
    required this.onSelectBranch,
    this.data,
  });

  @override
  State<BranchPerformanceScreen> createState() =>
      _BranchPerformanceScreenState();
}

class _BranchPerformanceScreenState extends State<BranchPerformanceScreen> {
  String _searchQuery = '';

  static TextStyle get _head =>
      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold);

  static Color _statusColor(String status) => switch (status) {
        'Success' => ViniiColors.emeraldText,
        'Warning' => ViniiColors.amberSolid,
        FranchiseSnapshot.notScored => ViniiColors.graySolid,
        _ => ViniiColors.redSolid,
      };

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const FranchiseNoData();
    final c = PanelColors.of(context);
    final q = _searchQuery.trim().toLowerCase();
    final rows = data.branches
        .where((b) =>
            q.isEmpty ||
            b.branchName.toLowerCase().contains(q) ||
            b.city.toLowerCase().contains(q))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparative Leaderboard & Normalized Rankings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Today\'s figures per branch, highest sales first. Tap a branch '
            'to open its detail.',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search branch name or code…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: c.subtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: data.branches.isEmpty
                ? const NoDataView(
                    compact: true,
                    icon: Icons.storefront_outlined,
                    title: 'No branches yet',
                    message: 'Branches are added in the Proviyaa master '
                        'panel.',
                  )
                : rows.isEmpty
                    ? NoDataView(
                        compact: true,
                        icon: Icons.search_off,
                        title: 'No branch matches "$_searchQuery"',
                        message: 'Try another name or code.',
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 56,
                          showCheckboxColumn: false,
                          columns: [
                            DataColumn(
                                label: Text('BRANCH NAME', style: _head)),
                            DataColumn(label: Text('CODE', style: _head)),
                            DataColumn(
                                label: Text('TODAY SALES', style: _head),
                                numeric: true),
                            DataColumn(
                                label: Text('ORDERS', style: _head),
                                numeric: true),
                            DataColumn(label: Text('TARGET MET', style: _head)),
                            DataColumn(label: Text('AOV', style: _head)),
                            DataColumn(
                                label: Text('FOOD COST %', style: _head)),
                            DataColumn(
                                label: Text('HEALTH INDEX', style: _head)),
                            DataColumn(label: Text('STATUS', style: _head)),
                          ],
                          rows: [for (final b in rows) _row(data, b)],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  DataRow _row(FranchiseSnapshot data, BranchPerformanceRow b) {
    final k = data.kpisFor(b);
    final targetMet = k == null ? b.targetMetPercent : k.targetMetPercent;
    final aov = k == null ? b.aovInr * 100 : k.aovMinor;
    final foodCost = k == null ? b.foodCostPercent : k.foodCostPercent;
    final health =
        k == null ? b.healthIndex : (k.healthMeaningful ? k.healthIndex : null);
    final status = data.statusOf(b);
    const cell = TextStyle(fontSize: 12);
    return DataRow(
      onSelectChanged: (_) => widget.onSelectBranch(b.branchName),
      cells: [
        DataCell(Text(b.branchName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        DataCell(Text(b.city.isEmpty ? '—' : b.city, style: cell)),
        DataCell(Text(formatPaise(k?.revenueMinor ?? b.todayRevenue * 100),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        DataCell(KpiText(k == null ? null : '${k.orders}', style: cell)),
        DataCell(KpiText(
          targetMet == null ? null : '$targetMet%',
          emptyTooltip: '$kNotEnoughData — no sales target set',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: targetMet == null
                ? null
                : targetMet >= 85
                    ? ViniiColors.emeraldText
                    : targetMet >= 75
                        ? const Color(0xFFF79009)
                        : const Color(0xFFF04438),
          ),
        )),
        DataCell(KpiText(aov == null ? null : formatPaise(aov),
            emptyTooltip: '$kNotEnoughData — no paid orders today',
            style: cell)),
        DataCell(KpiText(foodCost == null ? null : '$foodCost%',
            emptyTooltip: '$kNotEnoughData — no sales with food costs today',
            style: cell)),
        DataCell(KpiText(
          health == null ? null : '$health / 10',
          emptyTooltip: '$kNotEnoughData — set a sales target or record '
              'food costs',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: health == null
                ? null
                : health >= 8.0
                    ? ViniiColors.emeraldText
                    : health >= 6.0
                        ? const Color(0xFFF79009)
                        : const Color(0xFFF04438),
          ),
        )),
        DataCell(StatusPill(status, color: _statusColor(status))),
      ],
    );
  }
}
