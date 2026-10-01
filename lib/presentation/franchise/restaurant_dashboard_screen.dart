import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_loader.dart';
import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/drift_inventory_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/franchise_repository.dart';
import '../../data/staff_repository.dart';
import '../../domain/inventory.dart';
import '../../domain/operations.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// The vendor panel's landing "Dashboard" tab for owners and managers.
///
/// Every figure is computed by [DashboardMetrics] (which documents each
/// rule) from this device's orders, payments, kitchen tickets and raw
/// materials; staff attendance comes from [staff] and the branch table from
/// [franchise]. Sections without a connected source say so instead of
/// showing numbers.
class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({
    super.key,
    this.ops,
    this.inventory,
    this.staff,
    this.franchise,
    this.branchName,
    this.onNavigateToActionCenter,
    this.clock,
  });

  /// Orders, payments and kitchen tickets. Null = not connected: the
  /// dashboard shows only a "not connected" state.
  final DriftOperationsStore? ops;

  /// Raw materials for the low-stock alerts; null hides the figures.
  final DriftInventoryStore? inventory;

  /// Attendance summary; null = attendance not available here.
  final StaffRepository? staff;

  /// Chain data from the backend: the branch table (2+ branches) and the
  /// open-exceptions link. Null when not signed in to a backend.
  final FranchiseSnapshot? franchise;

  /// The branch whose device data this is, for the header.
  final String? branchName;

  /// Opens Exceptions & Actions.
  final VoidCallback? onNavigateToActionCenter;

  /// Current time — for tests.
  final DateTime Function()? clock;

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  DashboardRange _range = DashboardRange.today;
  StreamSubscription<DashboardInputs>? _sub;
  DashboardInputs? _inputs;
  Object? _error;

  StaffDashboard? _staffData;
  Object? _staffError;
  bool _staffLoading = false;

  /// Re-evaluates time-based figures (delayed tickets, the date span).
  Timer? _tick;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadStaff(initial: true);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(RestaurantDashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.ops != widget.ops || old.inventory != widget.inventory) {
      _inputs = null;
      _subscribe();
    }
    if (old.staff != widget.staff) _loadStaff();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = null;
    _error = null;
    final ops = widget.ops;
    if (ops == null) return;
    _sub = DashboardLoader(ops, inventory: widget.inventory).watch().listen(
      (inputs) {
        if (mounted) {
          setState(() {
            _inputs = inputs;
            _error = null;
          });
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
  }

  Future<void> _loadStaff({bool initial = false}) async {
    final repo = widget.staff;
    _staffData = null;
    _staffError = null;
    if (repo == null) {
      if (!initial && mounted) setState(() {});
      return;
    }
    _staffLoading = true;
    if (!initial && mounted) setState(() {});
    try {
      final data = await repo.dashboard();
      if (!mounted || widget.staff != repo) return;
      setState(() {
        _staffData = data;
        _staffLoading = false;
      });
    } catch (e) {
      if (!mounted || widget.staff != repo) return;
      setState(() {
        _staffError = e;
        _staffLoading = false;
      });
    }
  }

  void _refresh() {
    setState(() {
      _inputs = null;
      _subscribe();
    });
    _loadStaff();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ops == null) {
      return const NoDataView(
        icon: Icons.link_off,
        title: 'Dashboard data is not connected',
        message: 'The dashboard reads the orders, payments, kitchen tickets '
            'and stock recorded on this device. Its data source has not been '
            'connected on this screen.',
      );
    }
    final now = _now;
    final inputs = _inputs;
    final metrics = inputs == null
        ? null
        : DashboardMetrics.compute(
            orders: inputs.orders,
            kots: inputs.kots,
            materials: inputs.materials ?? const [],
            range: _range,
            now: now,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(now),
          const SizedBox(height: 16),
          _rangePills(),
          const SizedBox(height: 20),
          if (_error != null)
            DashCard(
              title: 'Could not read this device\'s data',
              child: NoDataView(
                compact: true,
                icon: Icons.error_outline,
                title: 'The dashboard could not load',
                message: friendlyErrorText(_error!),
                actionLabel: 'Try again',
                onAction: _refresh,
              ),
            )
          else if (metrics == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._body(metrics, inputs!),
        ],
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────

  String _spanLabel(DateSpan span) {
    final last = span.end.subtract(const Duration(days: 1));
    final first = formatShortDate(span.start);
    return span.start == DateTime(last.year, last.month, last.day)
        ? first
        : '$first – ${formatShortDate(last)}';
  }

  Widget _header(DateTime now) {
    final c = PanelColors.of(context);
    final span = DateSpan.of(_range, now);
    final exceptions = widget.franchise?.exceptions.length ?? 0;
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ViniiColors.successPillBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      size: 20, color: ViniiColors.emeraldText),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Restaurant Dashboard',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Business summary — ${_range.label} (${_spanLabel(span)})'
              ' · ${widget.branchName ?? 'orders on this device'}',
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exceptions > 0 && widget.onNavigateToActionCenter != null) ...[
              InkWell(
                onTap: widget.onNavigateToActionCenter,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE4E2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECDCA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFD92D20)),
                      const SizedBox(width: 8),
                      Text(
                        exceptions == 1
                            ? '1 open exception needs action'
                            : '$exceptions open exceptions need action',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD92D20)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Color(0xFFD92D20)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rangePills() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in DashboardRange.values)
            InkWell(
              key: ValueKey('dashboard-range-${r.name}'),
              onTap: () => setState(() => _range = r),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      r == _range ? ViniiColors.brandGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: r == _range
                          ? ViniiColors.brandGreen
                          : Colors.grey[300]!),
                ),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: r == _range ? FontWeight.bold : FontWeight.w500,
                    color: r == _range ? Colors.black : Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      );

  // ── body ──────────────────────────────────────────────────────────────

  List<Widget> _body(DashboardMetrics m, DashboardInputs inputs) {
    final branches = widget.franchise?.branches ?? const [];
    return [
      _kpiRow(m),
      if (!m.hasPeriodActivity) ...[
        const SizedBox(height: 12),
        _hint('No orders in this period yet. Orders taken in POS Billing, '
            'Captain Orders or Dine In appear here as soon as they are saved.'),
      ],
      const SizedBox(height: 20),
      ResponsiveRow(
        flex: const [6, 5],
        children: [_paymentCard(m), _liveCard(m)],
      ),
      const SizedBox(height: 20),
      ResponsiveRow(
        breakpoint: 1000,
        children: [
          _kitchenCard(m),
          _stockCard(m, inputs.materials),
          _staffCard(),
        ],
      ),
      if (branches.length > 1) ...[
        const SizedBox(height: 20),
        _branchCard(widget.franchise!),
      ],
    ];
  }

  Widget _hint(String text) {
    final c = PanelColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: c.muted),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(text, style: TextStyle(fontSize: 12, color: c.muted))),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> tiles,
          {int maxColumns = 4, double minTile = 200}) =>
      LayoutBuilder(builder: (context, constraints) {
        const gap = 12.0;
        var columns = maxColumns;
        while (columns > 1 &&
            (constraints.maxWidth - gap * (columns - 1)) / columns < minTile) {
          columns--;
        }
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      });

  Widget _kpiRow(DashboardMetrics m) {
    final aov = m.aovMinor;
    return _grid([
      StatTile(
        large: true,
        label: 'Sales',
        value: formatPaise(m.salesMinor),
        valueColor: ViniiColors.emeraldText,
        sub: 'Settled bills only · ${_range.label}',
      ),
      StatTile(
        large: true,
        label: 'Settled orders',
        value: '${m.settledCount}',
        sub: '${m.placedCount} placed · ${m.cancelledCount} cancelled'
            '${m.cancelledCount > 0 ? ' (${formatPaise(m.cancelledMinor)})' : ''}',
      ),
      StatTile(
        large: true,
        label: 'Average order value',
        value: aov == null ? null : formatPaise(aov),
        emptyTooltip: '$kNotEnoughData — no settled orders in this period',
        sub: 'Sales ÷ settled orders',
      ),
      StatTile(
        large: true,
        label: 'Pending verification',
        value: formatPaise(m.pendingVerificationMinor),
        valueColor: m.pendingVerificationCount > 0 ? Colors.orange[800] : null,
        sub: '${m.pendingVerificationCount} card/UPI '
            '${m.pendingVerificationCount == 1 ? 'payment' : 'payments'} '
            'not yet verified',
      ),
    ]);
  }

  Widget _paymentCard(DashboardMetrics m) {
    final c = PanelColors.of(context);
    final rows = m.paymentMethods;
    TextStyle head() =>
        TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.muted);
    return DashCard(
      title: 'Payment summary',
      subtitle: 'Settled sales by payment method — ${_range.label}',
      trailing: Text(formatPaise(m.salesMinor),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: ViniiColors.emeraldText)),
      child: rows.isEmpty
          ? Text('No payments recorded in this period.',
              style: TextStyle(fontSize: 12, color: c.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2.4),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: c.border))),
                      children: [
                        _cell(Text('METHOD', style: head())),
                        _cell(Text('SETTLED', style: head())),
                        _cell(Text('PENDING VERIFICATION', style: head())),
                      ],
                    ),
                    for (final r in rows)
                      TableRow(children: [
                        _cell(Text(r.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600))),
                        _cell(Text(
                            r.settledCount == 0
                                ? '—'
                                : '${formatPaise(r.settledMinor)} · ${r.settledCount}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold))),
                        _cell(Text(
                            r.pendingCount == 0
                                ? '—'
                                : '${formatPaise(r.pendingMinor)} · ${r.pendingCount}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: r.pendingCount == 0
                                    ? c.muted
                                    : Colors.orange[800]))),
                      ]),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Card, UPI and split payments stay pending verification '
                  'until an authorised user verifies them, and are not '
                  'counted as sales until then.',
                  style: TextStyle(fontSize: 11, color: c.muted),
                ),
              ],
            ),
    );
  }

  Widget _cell(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: child);

  Widget _liveCard(DashboardMetrics m) => DashCard(
        title: 'Open orders',
        subtitle: 'Live now — not affected by the date filter',
        child: _grid(maxColumns: 2, minTile: 130, [
          StatTile(label: 'Open', value: '${m.openCount}'),
          StatTile(
              label: 'Billed, awaiting payment', value: '${m.billedCount}'),
          StatTile(
              label: 'Open bill value', value: formatPaise(m.openValueMinor)),
          StatTile(
            label: 'Payments to verify',
            value: '${m.livePendingVerificationCount}',
            sub: m.livePendingVerificationCount == 0
                ? null
                : formatPaise(m.livePendingVerificationMinor),
            valueColor:
                m.livePendingVerificationCount > 0 ? Colors.orange[800] : null,
          ),
        ]),
      );

  Widget _kitchenCard(DashboardMetrics m) {
    final k = m.kitchen;
    return DashCard(
      title: 'Kitchen status',
      subtitle: 'Live — kitchen tickets (KOTs) on this device',
      child: _grid(maxColumns: 2, minTile: 110, [
        StatTile(label: 'New', value: '${k.newTickets}'),
        StatTile(label: 'Preparing', value: '${k.preparing}'),
        StatTile(label: 'Ready', value: '${k.ready}'),
        StatTile(
          label: 'Delayed',
          value: '${k.delayed}',
          valueColor: k.delayed > 0 ? ViniiColors.redSolid : null,
          sub: 'Not ready after ${OpsKot.delayedAfterMinutes} min',
        ),
        StatTile(label: 'Served today', value: '${k.servedToday}'),
      ]),
    );
  }

  Widget _stockCard(DashboardMetrics m, List<RawMaterial>? materials) {
    final c = PanelColors.of(context);
    if (materials == null) {
      return const DashCard(
        title: 'Inventory alerts',
        child: NoDataView(
          compact: true,
          icon: Icons.inventory_2_outlined,
          title: 'Stock is not connected here',
          message: 'Raw-material stock is not available on this screen.',
        ),
      );
    }
    return DashCard(
      title: 'Inventory alerts',
      subtitle: 'At or below the reorder level',
      child: materials.isEmpty
          ? Text(
              'No raw materials set up yet — add them in Master → '
              'Inventory.',
              style: TextStyle(fontSize: 12, color: c.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grid(maxColumns: 2, minTile: 110, [
                  StatTile(
                    label: 'Low stock',
                    value: '${m.lowStock.length - m.outOfStockCount}',
                    valueColor: m.lowStock.length > m.outOfStockCount
                        ? Colors.orange[800]
                        : null,
                  ),
                  StatTile(
                    label: 'Out of stock',
                    value: '${m.outOfStockCount}',
                    valueColor:
                        m.outOfStockCount > 0 ? ViniiColors.redSolid : null,
                  ),
                ]),
                const SizedBox(height: 10),
                if (m.lowStock.isEmpty)
                  Text(
                      'All ${materials.length} materials are above their '
                      'reorder level.',
                      style: TextStyle(fontSize: 12, color: c.muted))
                else ...[
                  for (final item in m.lowStock.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                              item.stockQty <= 0
                                  ? Icons.remove_circle_outline
                                  : Icons.warning_amber_rounded,
                              size: 14,
                              color: item.stockQty <= 0
                                  ? ViniiColors.redSolid
                                  : Colors.orange[800]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(item.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '${formatQty(item.stockQty)} ${item.unit}'
                            ' / reorder ${formatQty(item.reorderLevel)}',
                            style: TextStyle(fontSize: 11, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  if (m.lowStock.length > 6)
                    Text(
                        '+ ${m.lowStock.length - 6} more in Master → Inventory',
                        style: TextStyle(fontSize: 11, color: c.muted)),
                ],
              ],
            ),
    );
  }

  Widget _staffCard() {
    final c = PanelColors.of(context);
    final repo = widget.staff;
    final Widget body;
    if (repo == null) {
      body = const NoDataView(
        compact: true,
        icon: Icons.badge_outlined,
        title: 'Attendance not available',
        message: 'Staff attendance is not connected on this screen.',
      );
    } else if (_staffLoading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_staffError != null) {
      body = NoDataView(
        compact: true,
        icon: Icons.error_outline,
        title: 'Attendance could not load',
        message: friendlyErrorText(_staffError!),
        actionLabel: 'Try again',
        onAction: _loadStaff,
      );
    } else {
      final d = _staffData!;
      final unmarked = d.active - d.presentToday - d.absentToday;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _grid(maxColumns: 2, minTile: 110, [
            StatTile(
                label: 'Present today',
                value: '${d.presentToday}',
                valueColor: ViniiColors.emeraldText),
            StatTile(
                label: 'Absent today',
                value: '${d.absentToday}',
                valueColor: d.absentToday > 0 ? Colors.orange[800] : null),
            StatTile(label: 'Active staff', value: '${d.active}'),
            StatTile(label: 'On shift now', value: '${d.onShift}'),
          ]),
          if (unmarked > 0) ...[
            const SizedBox(height: 8),
            Text('$unmarked not marked yet today',
                style: TextStyle(fontSize: 11, color: c.muted)),
          ],
        ],
      );
    }
    return DashCard(
      title: 'Staff attendance',
      subtitle: 'Today',
      trailing: repo != null && !repo.live
          ? const StatusPill('Demo data', color: ViniiColors.amberSolid)
          : null,
      child: body,
    );
  }

  Widget _branchCard(FranchiseSnapshot data) {
    final c = PanelColors.of(context);
    TextStyle head() =>
        TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.muted);
    return DashCard(
      title: 'Branches',
      subtitle: 'Today, from the Proviyaa server',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text('BRANCH', style: head())),
            DataColumn(label: Text('SALES', style: head()), numeric: true),
            DataColumn(label: Text('ORDERS', style: head()), numeric: true),
            DataColumn(label: Text('AOV', style: head()), numeric: true),
            DataColumn(label: Text('TARGET MET', style: head())),
            DataColumn(label: Text('OPEN EXCEPTIONS', style: head())),
          ],
          rows: [
            for (final b in data.branches)
              () {
                final k = data.kpisFor(b);
                final aov = k == null ? b.aovInr * 100 : k.aovMinor;
                final target =
                    k == null ? b.targetMetPercent : k.targetMetPercent;
                final exceptions = data.exceptions
                    .where((e) => e.location == b.branchName)
                    .length;
                return DataRow(cells: [
                  DataCell(Text(b.branchName,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(
                      formatPaise(k?.revenueMinor ?? b.todayRevenue * 100))),
                  DataCell(KpiText(k == null ? null : '${k.orders}')),
                  DataCell(KpiText(aov == null ? null : formatPaise(aov))),
                  DataCell(KpiText(target == null ? null : '$target%',
                      emptyTooltip: '$kNotEnoughData — no sales target set')),
                  DataCell(Text('$exceptions')),
                ]);
              }(),
          ],
        ),
      ),
    );
  }
}
