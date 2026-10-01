import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// One branch of the chain, built only from that branch's row in
/// [FranchiseSnapshot.branches] (its KPIs), its stock rows, its open
/// exceptions, transfer suggestions and pending purchase orders.
class BranchDetailScreen extends StatefulWidget {
  const BranchDetailScreen({
    super.key,
    this.data,
    this.branchId,
    this.branchName,
    this.onSelectBranch,
    this.onOpenInventory,
    this.onOpenExceptions,
  });

  /// Chain data from the backend; null shows the "connect" empty state.
  final FranchiseSnapshot? data;

  /// The branch to show — matched on [BranchPerformanceRow.id] first, then
  /// on [branchName].
  final String? branchId;
  final String? branchName;

  /// Called with the branch name when the user switches branch here.
  final ValueChanged<String>? onSelectBranch;

  /// Opens Inventory & Supply / Exceptions (navigation only).
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenExceptions;

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  /// Branch picked on this screen (id), overriding the widget's.
  String? _picked;

  @override
  void didUpdateWidget(BranchDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId ||
        old.branchName != widget.branchName) {
      _picked = null;
    }
  }

  BranchPerformanceRow? _resolve(FranchiseSnapshot data) {
    final rows = data.branches;
    BranchPerformanceRow? byId(String? id) =>
        id == null ? null : rows.where((b) => b.id == id).firstOrNull;
    return byId(_picked) ??
        byId(widget.branchId) ??
        rows.where((b) => b.branchName == widget.branchName).firstOrNull ??
        (rows.length == 1 ? rows.single : null);
  }

  void _pick(BranchPerformanceRow row) {
    setState(() => _picked = row.id);
    widget.onSelectBranch?.call(row.branchName);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const FranchiseNoData();
    if (data.branches.isEmpty) {
      return const NoDataView(
        icon: Icons.storefront_outlined,
        title: 'No branches yet',
        message: 'This organization has no branches with data. Branches are '
            'added in the Proviyaa master panel.',
      );
    }
    final row = _resolve(data);
    if (row == null) return _picker(data);
    return _detail(data, row);
  }

  Widget _picker(FranchiseSnapshot data) {
    final c = PanelColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: DashCard(
        title: 'Choose a branch',
        subtitle: widget.branchName == null || widget.branchName!.isEmpty
            ? 'Pick the branch to open.'
            : '"${widget.branchName}" is not one of this organization\'s '
                'branches. Pick one below.',
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (final b in data.branches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined,
                      color: ViniiColors.emeraldText),
                  title: Text(b.branchName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: b.city.isEmpty
                      ? null
                      : Text('Code ${b.city}',
                          style: TextStyle(fontSize: 11, color: c.muted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pick(b),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'Success' => ViniiColors.emeraldText,
        'Warning' => ViniiColors.amberSolid,
        FranchiseSnapshot.notScored => ViniiColors.graySolid,
        _ => ViniiColors.redSolid,
      };

  static String _statusLabel(String status) => switch (status) {
        'Success' => 'Healthy',
        'Warning' => 'Needs attention',
        'Critical' => 'Critical',
        _ => status,
      };

  Widget _detail(FranchiseSnapshot data, BranchPerformanceRow row) {
    final c = PanelColors.of(context);
    final k = data.kpisFor(row);
    final name = row.branchName;

    bool atBranch(BranchStock s) =>
        (s.locationId != null && s.locationId == row.id) ||
        s.branchName == name;
    final stock = [
      for (final m in data.inventory)
        for (final s in m.branches)
          if (atBranch(s)) (material: m, stock: s),
    ]..sort((a, b) {
        int rank(String s) => switch (s) {
              'Critical' => 0,
              'Low' => 1,
              _ => 2,
            };
        final r = rank(a.stock.status).compareTo(rank(b.stock.status));
        return r != 0 ? r : a.material.name.compareTo(b.material.name);
      });
    final shortCount = stock
        .where((s) => s.stock.status == 'Critical' || s.stock.status == 'Low')
        .length;
    final exceptions =
        data.exceptions.where((e) => e.location == name).toList();
    final transfersIn =
        data.recommendations.where((r) => r.targetBranch == name).toList();
    final purchases =
        data.purchaseRequirements.where((p) => p.branch == name).toList();

    final health = k == null
        ? row.healthIndex
        : (k.healthMeaningful ? k.healthIndex : null);
    final targetMet = k == null ? row.targetMetPercent : k.targetMetPercent;
    final foodCost = k == null ? row.foodCostPercent : k.foodCostPercent;
    final aov = k == null ? row.aovInr * 100 : k.aovMinor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ViniiColors.successPillBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront,
                          size: 28, color: ViniiColors.emeraldText),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            StatusPill(_statusLabel(data.statusOf(row)),
                                color: _statusColor(data.statusOf(row))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              row.city.isEmpty
                                  ? 'Health index: '
                                  : 'Code ${row.city}  ·  Health index: ',
                              style: TextStyle(fontSize: 12, color: c.muted),
                            ),
                            KpiText(
                              health == null ? null : '$health / 10',
                              emptyTooltip: '$kNotEnoughData — set a sales '
                                  'target or record food costs',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: c.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (data.branches.length > 1)
                      DropdownButton<String>(
                        key: const Key('branch-detail-picker'),
                        value: row.id,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final b in data.branches)
                            DropdownMenuItem(
                                value: b.id,
                                child: Text(b.branchName,
                                    style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (id) {
                          final b = data.branches
                              .where((x) => x.id == id)
                              .firstOrNull;
                          if (b != null) _pick(b);
                        },
                      ),
                    if (widget.onOpenInventory != null)
                      OutlinedButton(
                        onPressed: widget.onOpenInventory,
                        child: const Text('Inventory & Supply',
                            style: TextStyle(fontSize: 12)),
                      ),
                    if (widget.onOpenExceptions != null)
                      OutlinedButton(
                        onPressed: widget.onOpenExceptions,
                        child: const Text('Exceptions',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KPIs
          LayoutBuilder(builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 1000
                ? 6
                : constraints.maxWidth >= 600
                    ? 3
                    : 2;
            final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
            Widget tile(Widget t) => SizedBox(width: w, child: t);
            return Wrap(spacing: gap, runSpacing: gap, children: [
              tile(StatTile(
                large: true,
                label: 'Sales today',
                value: formatPaise(k?.revenueMinor ?? row.todayRevenue * 100),
                valueColor: ViniiColors.emeraldText,
                sub: 'Settled orders',
              )),
              tile(StatTile(
                large: true,
                label: 'Orders today',
                value: k == null ? null : '${k.orders}',
              )),
              tile(StatTile(
                large: true,
                label: 'Average order value',
                value: aov == null ? null : formatPaise(aov),
                emptyTooltip: '$kNotEnoughData — no paid orders today',
              )),
              tile(StatTile(
                large: true,
                label: 'Target met',
                value: targetMet == null ? null : '$targetMet%',
                emptyTooltip: '$kNotEnoughData — no sales target set',
                sub: k?.targetMinor == null
                    ? null
                    : 'Target ${formatPaise(k!.targetMinor!)}',
              )),
              tile(StatTile(
                large: true,
                label: 'Food cost',
                value: foodCost == null ? null : '$foodCost%',
                emptyTooltip: '$kNotEnoughData — no sales with food costs',
              )),
              tile(StatTile(
                large: true,
                label: 'Stock alerts',
                value: '$shortCount',
                valueColor: shortCount > 0 ? Colors.orange[800] : null,
                sub: 'Critical or low materials',
              )),
            ]);
          }),
          const SizedBox(height: 20),

          ResponsiveRow(
            flex: const [7, 5],
            children: [
              _stockCard(stock, transfersIn),
              _exceptionsCard(exceptions, purchases),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockCard(List<({ChainStockRow material, BranchStock stock})> stock,
      List<HighImpactRecommendation> transfersIn) {
    final c = PanelColors.of(context);
    return DashCard(
      title: 'Stock at this branch',
      subtitle: 'Raw materials, most urgent first',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stock.isEmpty)
            Text('No raw materials are recorded for this branch.',
                style: TextStyle(fontSize: 12, color: c.muted))
          else
            for (final s in stock.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.material.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      [
                        quantityWithUnit(
                            formatQty(s.stock.stockQty), s.material.unit),
                        if (s.stock.reorderLevel != null)
                          'reorder ${quantityWithUnit(formatQty(s.stock.reorderLevel!), s.material.unit)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(s.stock.status,
                        color: switch (s.stock.status) {
                          'Critical' => ViniiColors.redSolid,
                          'Low' => ViniiColors.amberSolid,
                          _ => ViniiColors.emeraldText,
                        }),
                  ],
                ),
              ),
          if (stock.length > 12)
            Text('+ ${stock.length - 12} more in Inventory & Supply',
                style: TextStyle(fontSize: 11, color: c.muted)),
          if (transfersIn.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Suggested transfers into this branch',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final t in transfersIn)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t.recommendedAction,
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }

  /// "PO-0012 from Fresh Dairy Co (₹4,500)" — or just the supplier when
  /// the order has no number yet.
  static String _poLabel(PurchaseRequirement p) {
    final n = p.poNumber?.trim() ?? '';
    final amount = p.amountMinor == null ? '' : ' (${formatPaise(p.amountMinor!)})';
    return n.isEmpty ? '${p.supplier}$amount' : '$n from ${p.supplier}$amount';
  }

  Widget _exceptionsCard(
      List<OperationalException> exceptions, List<PurchaseRequirement> pos) {
    final c = PanelColors.of(context);
    return DashCard(
      title: 'Open exceptions',
      subtitle: 'Unresolved issues raised for this branch',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exceptions.isEmpty)
            Text('No open exceptions for this branch.',
                style: TextStyle(fontSize: 12, color: c.muted))
          else
            for (final e in exceptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.severityStatus == 'Critical'
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: e.severityStatus == 'Critical'
                          ? ViniiColors.redSolid
                          : Colors.orange[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.rootCause,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          if (e.recommendedAction.isNotEmpty)
                            Text(e.recommendedAction,
                                style: TextStyle(fontSize: 11, color: c.muted)),
                          if (e.bottomLineImpact.isNotEmpty)
                            Text(e.bottomLineImpact,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.red[700])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 24),
          Text(
            pos.isEmpty
                ? 'No purchase orders waiting for approval.'
                : '${pos.length} purchase '
                    '${pos.length == 1 ? 'order' : 'orders'} waiting for '
                    'approval (${pos.map(_poLabel).toSet().join(', ')}).',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    );
  }
}
