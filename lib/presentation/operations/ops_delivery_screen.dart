import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/staff_repository.dart' show StaffRepository;
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

/// Operations → Delivery (v1/operations/OPS-DELIVERY-OPERATIONS-DEFAULT.png).
/// Live view over `deliveries`: KPIs, filter chips, a paginated table and a
/// detail side sheet with rider assignment and status progression.
///
/// A delivery has no number of its own: people know it by its order's
/// number (and customer), so that is what every row, title and message
/// shows — never the delivery or order key.
class OpsDeliveryScreen extends StatefulWidget {
  const OpsDeliveryScreen(
      {super.key,
      required this.ops,
      this.master,
      this.focusOrderId,
      this.onOpenBilling,
      this.staff});
  final DriftOperationsStore ops;
  final DriftMasterStore? master;
  final String? focusOrderId;
  final ValueChanged<String>? onOpenBilling;

  /// The staff list: riders are picked from the active staff with
  /// delivery enabled. Without it (or when nobody has delivery enabled)
  /// the rider is typed, with the riders already used as suggestions.
  final StaffRepository? staff;

  @override
  State<OpsDeliveryScreen> createState() => _OpsDeliveryScreenState();
}

enum _Chip { all, active, inTransit, delayed, delivered }

const _indigo = Color(0xFF4F46E5);
const _cyan = Color(0xFF0891B2);
const _orange = Color(0xFFEA580C);

class _OpsDeliveryScreenState extends State<OpsDeliveryScreen> {
  late final Stream<List<OpsDelivery>> _stream;
  StreamSubscription<List<OpsOrder>>? _ordersSub;

  /// Orders on this device by key — to show a delivery's order number.
  Map<String, OpsOrder> _orders = const {};
  Timer? _ticker;
  DateTime _now = DateTime.now();

  _Chip _chip = _Chip.all;
  String? _merchant;
  String? _rider; // '' = unassigned
  DeliveryStatus? _status;
  bool _todayOnly = true;
  int _rowsPerPage = 25;
  int _page = 0;
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.ops.watchDeliveries();
    _ordersSub = widget.ops.watchOrders().listen((v) {
      if (mounted) setState(() => _orders = {for (final o in v) o.id: o});
    }, onError: (Object _) {});
    _ticker = Timer.periodic(const Duration(seconds: 30),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String _labelOf(OpsDelivery d) => _orderLabel(d, _orders[d.orderId]);

  bool _isToday(DateTime d) =>
      d.year == _now.year && d.month == _now.month && d.day == _now.day;

  int get _activeFilterCount =>
      (_merchant != null ? 1 : 0) +
      (_rider != null ? 1 : 0) +
      (_status != null ? 1 : 0) +
      (_todayOnly ? 0 : 1);

  bool _chipMatch(OpsDelivery d, _Chip c) => switch (c) {
        _Chip.all => true,
        _Chip.active => d.isOpen,
        _Chip.inTransit => d.status == DeliveryStatus.inTransit,
        _Chip.delayed => d.isDelayed(_now),
        _Chip.delivered => d.status == DeliveryStatus.delivered,
      };

  bool _filterMatch(OpsDelivery d) =>
      (_merchant == null || d.merchant == _merchant) &&
      (_rider == null ||
          (_rider!.isEmpty ? d.riderName == null : d.riderName == _rider)) &&
      (_status == null || d.status == _status);

  void _maybeFocus(List<OpsDelivery> all) {
    if (_focusHandled || widget.focusOrderId == null) return;
    _focusHandled = true;
    final match = all.where((d) => d.orderId == widget.focusOrderId);
    if (match.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(match.first.id);
    });
  }

  void _openDetail(String id) => _showDeliverySheet(context,
      ops: widget.ops,
      deliveryId: id,
      onOpenBilling: widget.onOpenBilling,
      staff: widget.staff);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OpsDelivery>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <OpsDelivery>[];
        _maybeFocus(all);
        // Today's deliveries, plus anything still open from earlier.
        final scoped = _todayOnly
            ? all.where((d) => _isToday(d.createdAt) || d.isOpen).toList()
            : all;
        final filtered = scoped.where(_filterMatch).toList();
        final rows = filtered.where((d) => _chipMatch(d, _chip)).toList();
        final pages = math.max(1, (rows.length / _rowsPerPage).ceil());
        final page = _page.clamp(0, pages - 1);
        final start = page * _rowsPerPage;
        final visible =
            rows.skip(start).take(_rowsPerPage).toList(growable: false);

        int count(bool Function(OpsDelivery) t) => scoped.where(t).length;
        return MasterPage(children: [
          MasterPageHeader(
            title: 'Deliveries',
            subtitle: _todayOnly
                ? "Showing today's deliveries"
                : 'Showing all deliveries',
            actions: [
              MasterButton(
                  label: 'New Delivery',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: () =>
                      _editDelivery(context, widget.ops, all: all)),
            ],
          ),
          const SizedBox(height: 8),
          MasterGrid(columns: 7, spacing: 12, minItemWidth: 104, children: [
            _Kpi('ACTIVE', count((d) => d.isOpen)),
            _Kpi('ASSIGNED', count((d) => d.status == DeliveryStatus.assigned)),
            _Kpi(
                'PICKED UP', count((d) => d.status == DeliveryStatus.pickedUp)),
            _Kpi('IN TRANSIT',
                count((d) => d.status == DeliveryStatus.inTransit)),
            _Kpi('DELAYED', count((d) => d.isDelayed(_now)),
                color: ViniiColors.amberSolid),
            _Kpi(
                'DELIVERED', count((d) => d.status == DeliveryStatus.delivered),
                color: ViniiColors.brandGreen),
            _Kpi('FAILED', count((d) => d.status == DeliveryStatus.failed),
                color: ViniiColors.redSolid),
          ]),
          const SizedBox(height: 24),
          MasterCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in _Chip.values)
                          _FilterChip(
                            label: switch (c) {
                              _Chip.all => 'All',
                              _Chip.active =>
                                'Active (${filtered.where((d) => _chipMatch(d, c)).length})',
                              _Chip.inTransit =>
                                'In Transit (${filtered.where((d) => _chipMatch(d, c)).length})',
                              _Chip.delayed =>
                                'Delayed (${filtered.where((d) => _chipMatch(d, c)).length})',
                              _Chip.delivered =>
                                'Delivered (${filtered.where((d) => _chipMatch(d, c)).length})',
                            },
                            selected: _chip == c,
                            onTap: () => setState(() {
                              _chip = c;
                              _page = 0;
                            }),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    _OutlineIconButton(
                      icon: Icons.filter_alt_outlined,
                      label: _activeFilterCount == 0
                          ? 'Filters'
                          : 'Filters ($_activeFilterCount)',
                      onTap: () => _openFilters(all),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _DeliveryTable(
                    rows: visible,
                    now: _now,
                    orderFor: (d) => _orders[d.orderId],
                    onOpen: (d) => _openDetail(d.id),
                    menuFor: (d) => _DeliveryMenu(
                        ops: widget.ops,
                        delivery: d,
                        orderLabel: _labelOf(d),
                        all: all,
                        staff: widget.staff,
                        onView: () => _openDetail(d.id),
                        onOpenBilling: widget.onOpenBilling),
                    emptyText: all.isEmpty
                        ? 'No deliveries yet — create one with New Delivery.'
                        : 'No deliveries match these filters.',
                  ),
                  const SizedBox(height: 16),
                  _Pager(
                    rowsPerPage: _rowsPerPage,
                    start: rows.isEmpty ? 0 : start + 1,
                    end: start + visible.length,
                    total: rows.length,
                    canPrev: page > 0,
                    canNext: page < pages - 1,
                    onRowsPerPage: (v) => setState(() {
                      _rowsPerPage = v;
                      _page = 0;
                    }),
                    onPrev: () => setState(() => _page = page - 1),
                    onNext: () => setState(() => _page = page + 1),
                  ),
                ]),
          ),
        ]);
      },
    );
  }

  Future<void> _openFilters(List<OpsDelivery> all) async {
    final merchants = {for (final d in all) d.merchant}.toList()..sort();
    final riders = {
      for (final d in all)
        if (d.riderName != null) d.riderName!
    }.toList()
      ..sort();
    final r = await showDialog<_FilterResult>(
      context: context,
      builder: (_) => _FiltersDialog(
        merchants: merchants,
        riders: riders,
        initial: _FilterResult(_merchant, _rider, _status, _todayOnly),
      ),
    );
    if (r == null) return;
    setState(() {
      _merchant = r.merchant;
      _rider = r.rider;
      _status = r.status;
      _todayOnly = r.todayOnly;
      _page = 0;
    });
  }
}

// ---------------------------------------------------------------------------
// Shared actions (used by the row menu and the detail sheet)
// ---------------------------------------------------------------------------

DeliveryStatus? _nextStep(DeliveryStatus s) => switch (s) {
      DeliveryStatus.assigned => DeliveryStatus.pickedUp,
      DeliveryStatus.pickedUp => DeliveryStatus.inTransit,
      DeliveryStatus.inTransit => DeliveryStatus.delivered,
      _ => null,
    };

String _stepLabel(DeliveryStatus s) => switch (s) {
      DeliveryStatus.pickedUp => 'Mark Picked Up',
      DeliveryStatus.inTransit => 'Mark In Transit',
      DeliveryStatus.delivered => 'Mark Delivered',
      DeliveryStatus.failed => 'Mark Failed',
      _ => s.label,
    };

bool _canAssign(OpsDelivery d) =>
    d.status == DeliveryStatus.unassigned ||
    d.status == DeliveryStatus.assigned;

/// The order a delivery is for, as people know it: the order's number
/// when it is on this device, else its reference (never a database id).
String _orderLabel(OpsDelivery d, OpsOrder? o) =>
    o?.number ?? orderNumberLabel(d.orderId, null);

/// The delivery's customer, or the order's when the delivery has none.
String _customerOf(OpsDelivery d, OpsOrder? o) {
  final name = d.customerName.trim();
  return name.isNotEmpty ? name : (o?.customerName.trim() ?? '');
}

String _inr(int minor) => formatInr(minor / 100, decimals: 0);

Future<void> _assignRider(
    BuildContext context, DriftOperationsStore ops, OpsDelivery d,
    {required String orderLabel,
    StaffRepository? staff,
    List<OpsDelivery> all = const []}) async {
  // Created once per dialog: the delivery-enabled staff, if any.
  final names = loadStaffNames(staff, deliveryOnly: true);
  final r = await showDialog<(String, int?)>(
      context: context,
      builder: (_) => _AssignRiderDialog(
          delivery: d,
          orderLabel: orderLabel,
          namesFuture: names,
          suggestions: distinctNames(all.map((x) => x.riderName))));
  if (r == null || !context.mounted) return;
  await runMasterAction(
      context, () => ops.assignRider(d.id, r.$1, etaMinutes: r.$2),
      success: '${r.$1} assigned to $orderLabel');
}

Future<void> _setStatus(BuildContext context, DriftOperationsStore ops,
    OpsDelivery d, DeliveryStatus to,
    {required String orderLabel}) async {
  if (to == DeliveryStatus.failed) {
    final ok = await confirmMasterAction(context,
        title: 'Mark the delivery of $orderLabel as failed?',
        message: 'The delivery of $orderLabel will be closed as failed. '
            'This cannot be moved back to an active state.',
        confirmLabel: 'Mark Failed');
    if (!ok || !context.mounted) return;
  }
  await runMasterAction(context, () => ops.setDeliveryStatus(d.id, to),
      success: '$orderLabel marked ${to.label.toLowerCase()}');
}

Future<void> _openInBilling(BuildContext context, DriftOperationsStore ops,
    OpsDelivery d, ValueChanged<String> onOpenBilling) async {
  OpsOrder? o;
  try {
    o = await ops.getOrder(d.orderId);
  } catch (e) {
    if (context.mounted) showMasterError(context, friendlyError(e));
    return;
  }
  if (!context.mounted) return;
  if (o == null) {
    showMasterNotice(context,
        '${_orderLabel(d, null)} is not in POS Billing on this device.');
    return;
  }
  onOpenBilling(o.id);
}

/// Create (when [existing] is null) or edit a delivery. [all] is every
/// delivery (newest first): orders that already have an open delivery are
/// not offered again, and a known address is filled in.
Future<void> _editDelivery(BuildContext context, DriftOperationsStore ops,
    {OpsDelivery? existing, List<OpsDelivery> all = const []}) async {
  var next = existing?.id ?? '';
  var orders = const <OpsOrder>[];
  try {
    if (next.isEmpty) next = await ops.nextDeliveryId();
    orders = await ops.getOrders();
  } catch (e) {
    if (context.mounted) showMasterError(context, friendlyError(e));
    return;
  }
  if (!context.mounted) return;
  final id = next;
  final d = await showDialog<OpsDelivery>(
      context: context,
      builder: (_) => _DeliveryFormDialog(
          id: id, existing: existing, orders: orders, deliveries: all));
  if (d == null || !context.mounted) return;
  final label =
      _orderLabel(d, orders.where((o) => o.id == d.orderId).firstOrNull);
  await runMasterAction(context, () => ops.upsertDelivery(d),
      success: existing == null
          ? 'Delivery created for $label'
          : 'Delivery for $label updated');
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.color});
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color ?? ViniiColors.textPrimaryLight)),
        ]),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: selected
                      ? ViniiColors.brandGreen
                      : MasterStyle.cardBorder),
            ),
            child: Align(
                widthFactor: 1,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ViniiColors.textPrimaryLight))),
          ),
        ),
      );
}

class _OutlineIconButton extends StatelessWidget {
  const _OutlineIconButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MasterStyle.cardBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: ViniiColors.textPrimaryLight),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight)),
            ]),
          ),
        ),
      );
}

/// Status pill: ⚠ DELAYED 8M, ● IN TRANSIT, ● ASSIGNED, ✓ DELIVERED, × FAILED.
class _DeliveryStatusPill extends StatelessWidget {
  const _DeliveryStatusPill(this.delivery, this.now);
  final OpsDelivery delivery;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final delayed = d.isDelayed(now);
    final (String text, Color fg, Color bg, Widget lead) = delayed
        ? (
            'DELAYED ${math.max(1, d.delayMinutes(now))}M',
            ViniiColors.amberSolid,
            const Color(0xFFFEF3C7),
            const Icon(Icons.warning_rounded,
                size: 12, color: ViniiColors.amberSolid)
          )
        : switch (d.status) {
            DeliveryStatus.unassigned => (
                'UNASSIGNED',
                ViniiColors.graySolid,
                ViniiColors.grayTint,
                const _Dot(ViniiColors.graySolid)
              ),
            DeliveryStatus.assigned => (
                'ASSIGNED',
                _indigo,
                const Color(0xFFEEF2FF),
                const _Dot(_indigo)
              ),
            DeliveryStatus.pickedUp => (
                'PICKED UP',
                _cyan,
                const Color(0xFFECFEFF),
                const _Dot(_cyan)
              ),
            DeliveryStatus.inTransit => (
                'IN TRANSIT',
                ViniiColors.blueSolid,
                ViniiColors.blueTint,
                const _Dot(ViniiColors.blueSolid)
              ),
            DeliveryStatus.delivered => (
                'DELIVERED',
                ViniiColors.greenSolid,
                const Color(0xFFDCFCE7),
                const Icon(Icons.check, size: 11, color: ViniiColors.greenSolid)
              ),
            DeliveryStatus.failed => (
                'FAILED',
                ViniiColors.redSolid,
                const Color(0xFFFEE2E2),
                const Icon(Icons.close, size: 11, color: ViniiColors.redSolid)
              ),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        lead,
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.1)),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _Col {
  const _Col(this.label, this.flex, {this.end = false});
  final String label;
  final int flex;
  final bool end;
}

// A delivery has no number of its own, so the first column is its order
// (number and customer) and takes the width of both old id columns.
const _cols = [
  _Col('ORDER', 23),
  _Col('MERCHANT', 13),
  _Col('RIDER', 12),
  _Col('STATUS', 14),
  _Col('ETA', 8),
  _Col('DISTANCE', 9),
  _Col('CREATED', 10),
  _Col('LAST UPDATE', 10),
  _Col('ACTIONS', 7, end: true),
];

class _DeliveryTable extends StatelessWidget {
  const _DeliveryTable(
      {required this.rows,
      required this.now,
      required this.orderFor,
      required this.onOpen,
      required this.menuFor,
      required this.emptyText});
  final List<OpsDelivery> rows;
  final DateTime now;

  /// The delivery's order when it is on this device.
  final OpsOrder? Function(OpsDelivery) orderFor;
  final ValueChanged<OpsDelivery> onOpen;
  final Widget Function(OpsDelivery) menuFor;
  final String emptyText;

  static const _minWidth = 1020.0;

  Widget _line(List<Widget> cells) => Row(children: [
        for (var i = 0; i < _cols.length; i++)
          Expanded(
            flex: _cols[i].flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                  alignment: _cols[i].end
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: cells[i]),
            ),
          ),
      ]);

  Widget _text(String s, {Color? color, bool bold = false}) => Text(s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? ViniiColors.textPrimaryLight));

  /// Order number (link) with the customer underneath.
  Widget _orderCell(OpsDelivery d) {
    final o = orderFor(d);
    final customer = _customerOf(d, o);
    return InkWell(
      onTap: () => onOpen(d),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(_orderLabel(d, o), color: ViniiColors.blueSolid, bold: true),
            if (customer.isNotEmpty)
              Text(customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: ViniiColors.textSecondaryLight)),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final table =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: MasterStyle.tableHeaderBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: _line([
          for (final c in _cols)
            Text(c.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
        ]),
      ),
      if (rows.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MasterStyle.cardBorder))),
          alignment: Alignment.center,
          child: Text(emptyText, style: MasterStyle.muted),
        ),
      for (final d in rows)
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => onOpen(d),
            child: Container(
              height: 47,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: MasterStyle.cardBorder))),
              child: _line([
                _orderCell(d),
                _text(d.merchant),
                d.riderName == null
                    ? _text('Unassigned', color: _orange, bold: true)
                    : _text(d.riderName!),
                _DeliveryStatusPill(d, now),
                _text(d.isOpen && d.etaMinutes != null
                    ? '${d.etaMinutes} min'
                    : '-'),
                _text('${d.distanceKm.toStringAsFixed(1)} km'),
                _text(formatAgo(d.createdAt, now)),
                _text(formatAgo(d.updatedAt, now)),
                menuFor(d),
              ]),
            ),
          ),
        ),
    ]);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= _minWidth
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: _minWidth, child: table)),
      ),
    );
  }
}

/// The compact "⋯" actions menu in the ACTIONS column.
class _DeliveryMenu extends StatelessWidget {
  const _DeliveryMenu(
      {required this.ops,
      required this.delivery,
      required this.orderLabel,
      required this.onView,
      this.all = const [],
      this.staff,
      this.onOpenBilling});
  final DriftOperationsStore ops;
  final OpsDelivery delivery;

  /// The delivery's order number, for titles and messages.
  final String orderLabel;
  final VoidCallback onView;

  /// Every delivery (riders already used, orders already out).
  final List<OpsDelivery> all;
  final StaffRepository? staff;
  final ValueChanged<String>? onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final next = _nextStep(d.status);
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz,
          size: 20, color: ViniiColors.textSecondaryLight),
      onSelected: (v) {
        switch (v) {
          case 'view':
            onView();
          case 'assign':
            _assignRider(context, ops, d,
                orderLabel: orderLabel, staff: staff, all: all);
          case 'next':
            _setStatus(context, ops, d, next!, orderLabel: orderLabel);
          case 'failed':
            _setStatus(context, ops, d, DeliveryStatus.failed,
                orderLabel: orderLabel);
          case 'edit':
            _editDelivery(context, ops, existing: d, all: all);
          case 'billing':
            _openInBilling(context, ops, d, onOpenBilling!);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: Text('View details')),
        if (_canAssign(d))
          PopupMenuItem(
              value: 'assign',
              child: Text(
                  d.riderName == null ? 'Assign rider' : 'Reassign rider')),
        if (next != null)
          PopupMenuItem(value: 'next', child: Text(_stepLabel(next))),
        if (d.isOpen) ...[
          const PopupMenuItem(value: 'edit', child: Text('Edit details')),
          const PopupMenuItem(
              value: 'failed',
              child: Text('Mark failed',
                  style: TextStyle(color: ViniiColors.redSolid))),
        ],
        if (onOpenBilling != null)
          const PopupMenuItem(
              value: 'billing', child: Text('Open order in POS Billing')),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager(
      {required this.rowsPerPage,
      required this.start,
      required this.end,
      required this.total,
      required this.canPrev,
      required this.canNext,
      required this.onRowsPerPage,
      required this.onPrev,
      required this.onNext});
  final int rowsPerPage;
  final int start;
  final int end;
  final int total;
  final bool canPrev;
  final bool canNext;
  final ValueChanged<int> onRowsPerPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  Widget _navButton(IconData icon, bool enabled, VoidCallback onTap) =>
      Material(
        color: enabled ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MasterStyle.cardBorder)),
            child: Icon(icon,
                size: 16,
                color: enabled
                    ? ViniiColors.textPrimaryLight
                    : ViniiColors.textMutedLight),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rows per page:',
                  style: TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight)),
              const SizedBox(width: 12),
              PopupMenuButton<int>(
                tooltip: 'Rows per page',
                onSelected: onRowsPerPage,
                itemBuilder: (_) => [
                  for (final n in const [10, 25, 50, 100])
                    PopupMenuItem(value: n, child: Text('$n')),
                ],
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: MasterStyle.cardBorder)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$rowsPerPage',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ]),
                ),
              ),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$start-$end of $total',
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight)),
              const SizedBox(width: 16),
              _navButton(Icons.chevron_left, canPrev, onPrev),
              const SizedBox(width: 4),
              _navButton(Icons.chevron_right, canNext, onNext),
            ]),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Detail side sheet
// ---------------------------------------------------------------------------

void _showDeliverySheet(BuildContext context,
    {required DriftOperationsStore ops,
    required String deliveryId,
    ValueChanged<String>? onOpenBilling,
    StaffRepository? staff}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: math.min(460, MediaQuery.of(ctx).size.width),
        height: double.infinity,
        child: Material(
          color: Colors.white,
          elevation: 12,
          child: _DeliverySheet(
              ops: ops,
              deliveryId: deliveryId,
              onOpenBilling: onOpenBilling,
              staff: staff),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _DeliverySheet extends StatefulWidget {
  const _DeliverySheet(
      {required this.ops,
      required this.deliveryId,
      this.onOpenBilling,
      this.staff});
  final DriftOperationsStore ops;
  final String deliveryId;
  final ValueChanged<String>? onOpenBilling;
  final StaffRepository? staff;

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  late final Stream<List<OpsDelivery>> _deliveries =
      widget.ops.watchDeliveries();

  /// The delivery's order, looked up once per order key.
  String? _orderKey;
  Future<OpsOrder?>? _order;

  DriftOperationsStore get ops => widget.ops;
  ValueChanged<String>? get onOpenBilling => widget.onOpenBilling;

  Future<OpsOrder?> _orderFor(String orderId) {
    final cached = _order;
    if (cached != null && _orderKey == orderId) return cached;
    _orderKey = orderId;
    final f = ops.getOrder(orderId).then<OpsOrder?>((o) => o,
        onError: (Object _) => null);
    _order = f;
    return f;
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight))),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color ?? ViniiColors.textPrimaryLight)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OpsDelivery>>(
      stream: _deliveries,
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final match = list.where((d) => d.id == widget.deliveryId);
        if (match.isEmpty) {
          return const Center(child: Text('Delivery not found'));
        }
        final d = match.first;
        return FutureBuilder<OpsOrder?>(
          future: _orderFor(d.orderId),
          builder: (context, orderSnap) =>
              _sheet(context, d, orderSnap.data, list),
        );
      },
    );
  }

  Widget _sheet(BuildContext context, OpsDelivery d, OpsOrder? o,
      List<OpsDelivery> all) {
    final now = DateTime.now();
    final next = _nextStep(d.status);
    final label = _orderLabel(d, o);
    final customer = _customerOf(d, o);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery · $label', style: MasterStyle.title),
              const SizedBox(height: 6),
              _DeliveryStatusPill(d, now),
            ]),
          ),
          IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(
                    'Order',
                    o == null
                        ? '$label · not on this device'
                        : '${o.number} · ${o.channel.label} · '
                            '${_inr(o.grandTotalMinor)}',
                    color: ViniiColors.blueSolid),
                _row('Merchant', d.merchant),
                _row('Customer', customer),
                _row('Address', d.address),
                _row('Rider', d.riderName ?? 'Unassigned',
                    color: d.riderName == null ? _orange : null),
                _row('Status', d.status.label),
                _row(
                    'ETA',
                    d.isOpen && d.etaMinutes != null
                        ? '${d.etaMinutes} min'
                        : '-'),
                _row('Distance', '${d.distanceKm.toStringAsFixed(1)} km'),
                _row(
                    'Promised by',
                    d.promisedAt == null
                        ? ''
                        : '${formatClock(d.promisedAt!)}'
                            '${d.isDelayed(now) ? '  (late ${d.delayMinutes(now)} min)' : ''}',
                    color: d.isDelayed(now) ? ViniiColors.amberSolid : null),
                _row('Created',
                    '${formatClock(d.createdAt)} · ${formatAgo(d.createdAt, now)}'),
                _row('Last update',
                    '${formatClock(d.updatedAt)} · ${formatAgo(d.updatedAt, now)}'),
                if (!d.isOpen) ...[
                  const SizedBox(height: 16),
                  MasterBanner(
                      tone: d.status == DeliveryStatus.failed
                          ? PillTone.red
                          : PillTone.green,
                      message:
                          'This delivery is ${d.status.label.toLowerCase()} — no further actions.'),
                ],
                if (d.status == DeliveryStatus.unassigned) ...[
                  const SizedBox(height: 16),
                  const MasterBanner(
                      tone: PillTone.amber,
                      message:
                          'Assign a rider before the order can be picked up.'),
                ],
              ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MasterStyle.cardBorder))),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          if (_canAssign(d))
            MasterButton(
                label: d.riderName == null ? 'Assign Rider' : 'Reassign',
                icon: Icons.two_wheeler,
                kind: d.riderName == null
                    ? MasterButtonKind.primary
                    : MasterButtonKind.outline,
                onPressed: () => _assignRider(context, ops, d,
                    orderLabel: label, staff: widget.staff, all: all)),
          if (next != null)
            MasterButton(
                label: _stepLabel(next),
                kind: MasterButtonKind.primary,
                onPressed: () =>
                    _setStatus(context, ops, d, next, orderLabel: label)),
          if (d.isOpen) ...[
            MasterButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    _editDelivery(context, ops, existing: d, all: all)),
            MasterButton(
                label: 'Mark Failed',
                kind: MasterButtonKind.dangerOutline,
                onPressed: () => _setStatus(
                    context, ops, d, DeliveryStatus.failed,
                    orderLabel: label)),
          ],
          if (onOpenBilling != null)
            MasterButton(
                label: 'Open Order',
                icon: Icons.receipt_long_outlined,
                onPressed: () => _openInBilling(context, ops, d, (id) {
                      Navigator.pop(context);
                      onOpenBilling!(id);
                    })),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

InputDecoration _decoration(String? hint, {String? suffix}) => InputDecoration(
      isDense: true,
      hintText: hint,
      suffixText: suffix,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
    );

Widget _labelled(String label, Widget field) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ViniiColors.textPrimaryLight)),
        const SizedBox(height: 6),
        field,
      ]),
    );

/// The drop-down list under a search / suggestion field.
Widget _optionsList(List<Widget> tiles, {double maxWidth = 340}) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 240, maxWidth: maxWidth),
          child: ListView(
              padding: EdgeInsets.zero, shrinkWrap: true, children: tiles),
        ),
      ),
    );

class _AssignRiderDialog extends StatefulWidget {
  const _AssignRiderDialog(
      {required this.delivery,
      required this.orderLabel,
      this.namesFuture,
      this.suggestions = const []});
  final OpsDelivery delivery;

  /// The delivery's order number, for the title.
  final String orderLabel;

  /// Delivery-enabled staff ([loadStaffNames]): picked from a list. When
  /// it is empty the rider is typed.
  final Future<List<String>>? namesFuture;

  /// Riders already used on deliveries, suggested while typing.
  final List<String> suggestions;

  @override
  State<_AssignRiderDialog> createState() => _AssignRiderDialogState();
}

class _AssignRiderDialogState extends State<_AssignRiderDialog> {
  final _form = GlobalKey<FormState>();
  late final _rider =
      TextEditingController(text: widget.delivery.riderName ?? '');
  late final _eta =
      TextEditingController(text: widget.delivery.etaMinutes?.toString() ?? '');
  final _riderFocus = FocusNode();

  /// Staff riders; empty = type the name.
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    widget.namesFuture?.then((n) {
      if (mounted && n.isNotEmpty) setState(() => _names = n);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _rider.dispose();
    _eta.dispose();
    _riderFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
        context, (_rider.text.trim(), int.tryParse(_eta.text.trim())));
  }

  /// A staff drop-down (with "Other…" for someone not on the list), or —
  /// without a staff list — a text field suggesting the riders used before.
  Widget _riderField() {
    if (_names.isNotEmpty) {
      return FormField<String>(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (_) => _rider.text.trim().isEmpty ? 'Pick the rider' : null,
        builder: (state) => PersonPickerField(
          controller: _rider,
          names: _names,
          decoration: _decoration('Select a rider')
              .copyWith(errorText: state.errorText),
          onChanged: state.didChange,
        ),
      );
    }
    TextFormField field(TextEditingController c, FocusNode f,
            {VoidCallback? onSubmitted}) =>
        TextFormField(
          controller: c,
          focusNode: f,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: _decoration('e.g. Ramesh P.'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the rider name' : null,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        );
    final used = widget.suggestions;
    if (used.isEmpty) return field(_rider, _riderFocus);
    return RawAutocomplete<String>(
      textEditingController: _rider,
      focusNode: _riderFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return [
          for (final n in used)
            if (n.toLowerCase() != q &&
                (q.isEmpty || n.toLowerCase().contains(q)))
              n
        ];
      },
      fieldViewBuilder: (context, c, f, onSubmitted) =>
          field(c, f, onSubmitted: onSubmitted),
      optionsViewBuilder: (context, onSelected, options) => _optionsList([
        for (final n in options)
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline, size: 18),
            title: Text(n, overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(n),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Assign rider · ${widget.orderLabel}'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _labelled('Rider name', _riderField()),
              _labelled(
                  'ETA (optional)',
                  TextFormField(
                    controller: _eta,
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        _decoration('Minutes to delivery', suffix: 'min'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      if (n == null || n < 1 || n > 600) {
                        return 'Enter 1–600 minutes';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  )),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ViniiColors.brandGreen,
                  foregroundColor: Colors.black),
              onPressed: _submit,
              child: const Text('Assign')),
        ],
      );
}

/// Where a delivery order came from; the first is the restaurant's own
/// riders (the value every screen stores for its own deliveries).
const _merchants = [
  ('Restaurant', 'Restaurant (own delivery)'),
  ('Swiggy', 'Swiggy'),
  ('Zomato', 'Zomato'),
  ('Website', 'Website'),
  ('One Latur', 'One Latur'),
];

/// [m] spelled as in [_merchants] when it is one of them.
String _canonicalMerchant(String m) {
  for (final (v, _) in _merchants) {
    if (v.toLowerCase() == m.toLowerCase()) return v;
  }
  return m;
}

/// "ORD-248 · Karan Johar · ₹840" — how an order is listed in the picker.
String _orderOption(OpsOrder o) {
  final who = o.customerName.trim();
  return '${o.number} · ${who.isEmpty ? o.channel.label : who} · '
      '${_inr(o.grandTotalMinor)}';
}

class _DeliveryFormDialog extends StatefulWidget {
  const _DeliveryFormDialog(
      {required this.id,
      this.existing,
      this.orders = const [],
      this.deliveries = const []});
  final String id;
  final OpsDelivery? existing;

  /// Orders on this device; open delivery / takeaway ones are offered.
  final List<OpsOrder> orders;

  /// Every delivery, newest first.
  final List<OpsDelivery> deliveries;

  @override
  State<_DeliveryFormDialog> createState() => _DeliveryFormDialogState();
}

class _DeliveryFormDialogState extends State<_DeliveryFormDialog> {
  final _form = GlobalKey<FormState>();
  late final OpsDelivery? e = widget.existing;

  /// The chosen order's key — what links the delivery to its order. It is
  /// never shown; the field shows the order's number and customer.
  late String? _orderId = e?.orderId;
  late final String _initialOrderText = _textFor(e?.orderId);
  late final _order = TextEditingController(text: _initialOrderText);
  final _orderFocus = FocusNode();

  late final String _storedMerchant =
      _canonicalMerchant(e?.merchant.trim() ?? '');
  late String _merchant =
      _storedMerchant.isEmpty ? _merchants.first.$1 : _storedMerchant;

  /// The merchants, plus an older delivery's own merchant so editing it
  /// does not lose it.
  late final List<(String, String)> _merchantItems = [
    ..._merchants,
    if (_storedMerchant.isNotEmpty &&
        !_merchants.any((m) => m.$1 == _storedMerchant))
      (_storedMerchant, _storedMerchant),
  ];
  late final _customer = TextEditingController(text: e?.customerName ?? '');
  late final _address = TextEditingController(text: e?.address ?? '');
  late final _distance = TextEditingController(
      text: e == null ? '' : e!.distanceKm.toStringAsFixed(1));
  late final _promise = TextEditingController(text: e == null ? '30' : '');

  /// What the picker filled in, so a later pick may replace it (but never
  /// what was typed).
  String _autoCustomer = '';
  String _autoAddress = '';

  /// Open delivery / takeaway orders that have no open delivery yet, plus
  /// this delivery's own order.
  late final List<OpsOrder> _choices = () {
    final busy = {
      for (final d in widget.deliveries)
        if (d.isOpen && d.id != widget.id) d.orderId
    };
    return [
      for (final o in widget.orders)
        if (o.id == e?.orderId ||
            (o.isActive &&
                o.channel != OpsChannel.dineIn &&
                !busy.contains(o.id)))
          o
    ];
  }();

  OpsOrder? _find(String? orderId) => orderId == null
      ? null
      : widget.orders.where((o) => o.id == orderId).firstOrNull;

  String _textFor(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return '';
    final o = _find(orderId);
    return o == null ? orderNumberLabel(orderId, null) : _orderOption(o);
  }

  @override
  void dispose() {
    for (final c in [_order, _customer, _address, _distance, _promise]) {
      c.dispose();
    }
    _orderFocus.dispose();
    super.dispose();
  }

  /// Links [o] and fills in its customer (and the address a previous
  /// delivery of it had) unless something else was typed there.
  void _useOrder(OpsOrder o) {
    setState(() {
      _orderId = o.id;
      final name = o.customerName.trim();
      final typedName = _customer.text.trim();
      if (name.isNotEmpty &&
          (typedName.isEmpty || typedName == _autoCustomer)) {
        _customer.text = name;
        _autoCustomer = name;
      }
      var address = '';
      for (final d in widget.deliveries) {
        if (d.orderId == o.id && d.address.trim().isNotEmpty) {
          address = d.address.trim();
          break;
        }
      }
      final typedAddress = _address.text.trim();
      if (address.isNotEmpty &&
          (typedAddress.isEmpty || typedAddress == _autoAddress)) {
        _address.text = address;
        _autoAddress = address;
      }
    });
  }

  /// Typing an order's exact number (or key) links it too.
  void _orderTyped(String text) {
    final t = text.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
    String? id;
    if (t.isNotEmpty) {
      if (e != null && text.trim() == _initialOrderText.trim()) {
        id = e?.orderId;
      } else {
        for (final o in _choices) {
          if (o.id.toLowerCase() == t ||
              o.number.toLowerCase() == t ||
              _orderOption(o).toLowerCase() == t) {
            id = o.id;
            break;
          }
        }
      }
    }
    if (id == _orderId) return;
    final match = _choices.where((o) => o.id == id).firstOrNull;
    if (match != null) {
      _useOrder(match);
    } else {
      setState(() => _orderId = id);
    }
  }

  String? _validateOrder(String? v) {
    if (_orderId != null) return null;
    if ((v ?? '').trim().isEmpty) {
      return _choices.isEmpty
          ? 'No open delivery or takeaway order — take the order in POS first'
          : 'Pick the order';
    }
    return 'Pick an order from the list';
  }

  Widget _orderField() => RawAutocomplete<OpsOrder>(
        textEditingController: _order,
        focusNode: _orderFocus,
        displayStringForOption: _orderOption,
        optionsBuilder: (value) {
          final q =
              value.text.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
          return _choices.where((o) {
            if (q.isEmpty) return true;
            final text = _orderOption(o).toLowerCase();
            if (o.id == _orderId && text == q) return false;
            return text.contains(q) || o.id.toLowerCase().contains(q);
          }).toList();
        },
        onSelected: _useOrder,
        fieldViewBuilder: (context, c, f, onSubmitted) => TextFormField(
          controller: c,
          focusNode: f,
          style: const TextStyle(fontSize: 13),
          decoration: _decoration(_choices.isEmpty
                  ? 'No open delivery or takeaway orders'
                  : 'Search order number or customer')
              .copyWith(
                  suffixIcon: const Icon(Icons.search,
                      size: 18, color: ViniiColors.textMutedLight)),
          validator: _validateOrder,
          onChanged: _orderTyped,
          onFieldSubmitted: (_) => onSubmitted(),
        ),
        optionsViewBuilder: (context, onSelected, options) => _optionsList([
          for (final o in options)
            ListTile(
              dense: true,
              leading: Icon(
                  o.channel == OpsChannel.delivery
                      ? Icons.delivery_dining_outlined
                      : Icons.shopping_bag_outlined,
                  size: 18),
              title: Text(o.number, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${o.customerName.trim().isEmpty ? o.channel.label : o.customerName.trim()}'
                  ' · ${_inr(o.grandTotalMinor)}',
                  overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(o),
            ),
        ], maxWidth: 420),
      );

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final orderId = _orderId;
    if (orderId == null) return;
    final now = DateTime.now();
    final mins = int.tryParse(_promise.text.trim());
    Navigator.pop(
      context,
      OpsDelivery(
        id: widget.id,
        orderId: orderId,
        merchant: _merchant,
        status: e?.status ?? DeliveryStatus.unassigned,
        createdAt: e?.createdAt ?? now,
        updatedAt: now,
        riderName: e?.riderName,
        etaMinutes: e?.etaMinutes,
        distanceKm: double.parse(_distance.text.trim()),
        customerName: _customer.text.trim(),
        address: _address.text.trim(),
        promisedAt:
            mins == null ? e?.promisedAt : now.add(Duration(minutes: mins)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextFormField field(TextEditingController c, String hint,
            {String? Function(String?)? validator,
            TextInputType? type,
            String? suffix,
            int maxLines = 1}) =>
        TextFormField(
          controller: c,
          style: const TextStyle(fontSize: 13),
          keyboardType: type,
          maxLines: maxLines,
          decoration: _decoration(hint, suffix: suffix),
          validator: validator,
        );
    final existing = e;
    return AlertDialog(
      title: Text(existing == null
          ? 'New Delivery'
          : 'Edit Delivery · ${_orderLabel(existing, _find(existing.orderId))}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _labelled('Order', _orderField()),
              _labelled(
                  'Merchant',
                  DropdownButtonFormField<String>(
                    initialValue: _merchant,
                    isExpanded: true,
                    style: const TextStyle(
                        fontSize: 13, color: ViniiColors.textPrimaryLight),
                    decoration: _decoration(null),
                    items: [
                      for (final (v, l) in _merchantItems)
                        DropdownMenuItem<String>(
                            value: v,
                            child: Text(l, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _merchant = v);
                    },
                  )),
              _labelled('Customer name', field(_customer, 'Optional')),
              _labelled('Delivery address',
                  field(_address, 'Street, area, landmark', maxLines: 2)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _labelled(
                      'Distance',
                      field(_distance, '0.0',
                          suffix: 'km',
                          type: const TextInputType.numberWithOptions(
                              decimal: true), validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n < 0 || n > 100) {
                          return 'Enter 0–100 km';
                        }
                        return null;
                      })),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _labelled(
                      e == null ? 'Promised in' : 'New promise (optional)',
                      field(_promise, e == null ? '30' : 'Keep current',
                          suffix: 'min',
                          type: TextInputType.number, validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) {
                          return e == null ? 'Enter minutes' : null;
                        }
                        final n = int.tryParse(t);
                        if (n == null || n < 1 || n > 600) {
                          return 'Enter 1–600 minutes';
                        }
                        return null;
                      })),
                ),
              ]),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            onPressed: _submit,
            child: Text(e == null ? 'Create Delivery' : 'Save')),
      ],
    );
  }
}

class _FilterResult {
  const _FilterResult(this.merchant, this.rider, this.status, this.todayOnly);
  final String? merchant;
  final String? rider;
  final DeliveryStatus? status;
  final bool todayOnly;
}

class _FiltersDialog extends StatefulWidget {
  const _FiltersDialog(
      {required this.merchants, required this.riders, required this.initial});
  final List<String> merchants;
  final List<String> riders;
  final _FilterResult initial;

  @override
  State<_FiltersDialog> createState() => _FiltersDialogState();
}

class _FiltersDialogState extends State<_FiltersDialog> {
  late String? _merchant = widget.initial.merchant;
  late String? _rider = widget.initial.rider;
  late DeliveryStatus? _status = widget.initial.status;
  late bool _todayOnly = widget.initial.todayOnly;

  Widget _dropdown<T>(String label, T? value, List<(T?, String)> options,
          ValueChanged<T?> onChanged) =>
      _labelled(
          label,
          DropdownButtonFormField<T?>(
            initialValue: value,
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textPrimaryLight),
            decoration: _decoration(null),
            items: [
              for (final (v, l) in options)
                DropdownMenuItem<T?>(value: v, child: Text(l)),
            ],
            onChanged: onChanged,
          ));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Filter deliveries'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dropdown<String>(
                'Merchant',
                _merchant,
                [
                  (null, 'All merchants'),
                  for (final m in widget.merchants) (m, m)
                ],
                (v) => setState(() => _merchant = v)),
            _dropdown<String>(
                'Rider',
                _rider,
                [
                  (null, 'All riders'),
                  ('', 'Unassigned'),
                  for (final r in widget.riders) (r, r)
                ],
                (v) => setState(() => _rider = v)),
            _dropdown<DeliveryStatus>(
                'Status',
                _status,
                [
                  (null, 'All statuses'),
                  for (final s in DeliveryStatus.values) (s, s.label)
                ],
                (v) => setState(() => _status = v)),
            _dropdown<bool>(
                'Date',
                _todayOnly,
                const [(true, "Today's deliveries"), (false, 'All time')],
                (v) => setState(() => _todayOnly = v ?? true)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(
                  context, const _FilterResult(null, null, null, true)),
              child: const Text('Reset')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ViniiColors.brandGreen,
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context,
                  _FilterResult(_merchant, _rider, _status, _todayOnly)),
              child: const Text('Apply')),
        ],
      );
}
