import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../data/staff_repository.dart' show StaffRepository;
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

/// Operations → Dine In. Floor plan of every restaurant table (the same
/// restaurant_tables rows the POS uses) with a detail panel for the
/// selected table: seat guests, take an order, view the order / KOT in
/// POS Billing, generate the bill, transfer, edit and delete tables.
class OpsDineInScreen extends StatefulWidget {
  const OpsDineInScreen(
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

  /// The restaurant's staff: the server for seated guests is picked from
  /// its active people. Null (no staff list) → typed, with the names
  /// already used on tables suggested.
  final StaffRepository? staff;

  @override
  State<OpsDineInScreen> createState() => _OpsDineInScreenState();
}

const _lime = ViniiColors.brandGreen;
const _limeText = Color(0xFF5CC800);
const _border = MasterStyle.cardBorder;
const _canvas = Color(0xFFE9E9E9);
const _canvasLine = Color(0xFFDCDCDC);

/// "MAIN COURSE" → "Main Course" (Master stores some categories in caps).
String _titleCase(String s) => s != s.toUpperCase()
    ? s
    : s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

String _money(int minor) => formatInr(minor / 100, decimals: 0);

/// "T2" → "Table 2"; custom labels are shown as-is.
String _tableTitle(OpsTable t) {
  final m = RegExp(r'^[Tt](\d+)$').firstMatch(t.label.trim());
  return m == null ? t.label : 'Table ${m.group(1)}';
}

/// Card colours per status, as in the Dining Areas design.
({Color bg, Color border, Color text, String label}) _statusStyle(
        OpsTableStatus s) =>
    switch (s) {
      OpsTableStatus.available => (
          bg: const Color(0xFFEEFCDD),
          border: _lime,
          text: _limeText,
          label: 'AVAILABLE'
        ),
      OpsTableStatus.occupied => (
          bg: const Color(0xFFE3EEFD),
          border: ViniiColors.blueSolid,
          text: ViniiColors.blueSolid,
          label: 'OCCUPIED'
        ),
      OpsTableStatus.reserved => (
          bg: const Color(0xFFF1E8FD),
          border: ViniiColors.purpleSolid,
          text: ViniiColors.purpleSolid,
          label: 'RESERVED'
        ),
      OpsTableStatus.billing => (
          bg: const Color(0xFFFFF3DD),
          border: ViniiColors.amberSolid,
          text: ViniiColors.amberSolid,
          label: 'PAYMENT PENDING'
        ),
      OpsTableStatus.cleaning => (
          bg: const Color(0xFFF1F1F2),
          border: const Color(0xFF9CA3AF),
          text: ViniiColors.graySolid,
          label: 'CLEANING'
        ),
    };

/// Header pill in the detail panel.
({Color bg, Color fg}) _pillStyle(OpsTableStatus s) => switch (s) {
      OpsTableStatus.available => (
          bg: const Color(0xFFEEFCDD),
          fg: const Color(0xFF3F9A00)
        ),
      OpsTableStatus.occupied => (
          bg: ViniiColors.blueTint,
          fg: ViniiColors.blueSolid
        ),
      OpsTableStatus.reserved => (
          bg: const Color(0xFFF1E8FD),
          fg: ViniiColors.purpleSolid
        ),
      OpsTableStatus.billing => (
          bg: ViniiColors.amberTint,
          fg: ViniiColors.amberSolid
        ),
      OpsTableStatus.cleaning => (
          bg: ViniiColors.grayTint,
          fg: ViniiColors.graySolid
        ),
    };

enum _Filter { all, available, occupied, reserved, paymentPending }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All Tables',
        _Filter.available => 'Available',
        _Filter.occupied => 'Occupied',
        _Filter.reserved => 'Reserved',
        _Filter.paymentPending => 'Payment Pending',
      };
  bool matches(OpsTable t) => switch (this) {
        _Filter.all => true,
        _Filter.available => t.status == OpsTableStatus.available,
        _Filter.occupied => t.status == OpsTableStatus.occupied,
        _Filter.reserved => t.status == OpsTableStatus.reserved,
        _Filter.paymentPending => t.status == OpsTableStatus.billing,
      };
}

List<String> _floorsOf(List<OpsTable> tables) {
  final used = tables.map((t) => t.floor).toSet();
  return [
    ...DriftOperationsStore.defaultFloors.where(used.contains),
    ...used.where((f) => !DriftOperationsStore.defaultFloors.contains(f)),
  ];
}

class _OpsDineInScreenState extends State<OpsDineInScreen> {
  late final Stream<List<OpsTable>> _tables$ = widget.ops.watchTables();
  late final Stream<List<OpsOrder>> _orders$ = widget.ops.watchOrders();
  late final Stream<List<OpsReservation>> _res$ =
      widget.ops.watchReservations();

  /// Tables marked available from this screen → when (for "Last Cleaned").
  final _cleanedAt = <String, DateTime>{};
  late final DriftMasterStore _master =
      widget.master ?? DriftMasterStore(widget.ops.db);

  /// Active staff names for the server picker (loaded once).
  late final Future<List<String>> _staffNames;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  String? _floor;
  _Filter _filter = _Filter.all;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _staffNames =
        loadStaffNames(widget.staff, include: [widget.ops.actorName]);
    _ticker = Timer.periodic(const Duration(seconds: 20),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OpsTable>>(
      stream: _tables$,
      builder: (context, tSnap) => StreamBuilder<List<OpsOrder>>(
        stream: _orders$,
        builder: (context, oSnap) => StreamBuilder<List<OpsReservation>>(
          stream: _res$,
          builder: (context, rSnap) => _body(context, tSnap, oSnap, rSnap),
        ),
      ),
    );
  }

  /// When the table was last cleaned: its stored lastCleanedAt (set by
  /// Mark Available), or failing that the latest settle at that table.
  DateTime? _lastCleaned(OpsTable t, List<OpsOrder> all) {
    DateTime? best = t.lastCleanedAt ?? _cleanedAt[t.id];
    for (final o in all) {
      if (o.tableLabel != t.label || o.settledAt == null) continue;
      if (best == null || o.settledAt!.isAfter(best)) best = o.settledAt;
    }
    return best;
  }

  Widget _body(
      BuildContext context,
      AsyncSnapshot<List<OpsTable>> tSnap,
      AsyncSnapshot<List<OpsOrder>> oSnap,
      AsyncSnapshot<List<OpsReservation>> rSnap) {
    if (!tSnap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final tables = tSnap.data!;
    final allOrders = oSnap.data ?? const <OpsOrder>[];
    final orders = {
      for (final o in allOrders)
        if (o.status == OpsOrderStatus.open ||
            o.status == OpsOrderStatus.billed)
          o.id: o
    };
    final floors = _floorsOf(tables);
    if (_floor == null || !floors.contains(_floor)) {
      _floor = floors.isEmpty ? null : floors.first;
    }
    final onFloor = tables.where((t) => t.floor == _floor).toList();
    var selected = tables.where((t) => t.id == _selectedId).firstOrNull;
    if (selected == null || selected.floor != _floor) {
      selected = onFloor
              .where((t) =>
                  t.status == OpsTableStatus.occupied ||
                  t.status == OpsTableStatus.billing)
              .firstOrNull ??
          onFloor.firstOrNull;
    }
    final sel = selected;
    final order =
        sel?.currentOrderId == null ? null : orders[sel!.currentOrderId];

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 1000;
      final header = _header(floors, tables);
      final canvas = _FloorCanvas(
        tables: onFloor,
        filter: _filter,
        selectedId: sel?.id,
        onFilter: (f) => setState(() => _filter = f),
        onSelect: (t) => setState(() => _selectedId = t.id),
      );
      final panel = _DetailPanel(
        key: ValueKey(sel?.id),
        table: sel,
        order: order,
        now: _now,
        allTables: tables,
        lastCleaned: sel == null ? null : _lastCleaned(sel, allOrders),
        reservations: [
          for (final r in rSnap.data ?? const <OpsReservation>[])
            if (r.tableId == sel?.id &&
                (r.status == ReservationStatus.pending ||
                    r.status == ReservationStatus.confirmed))
              r
        ],
        onMarkedAvailable: (id) => _cleanedAt[id] = DateTime.now(),
        ops: widget.ops,
        master: _master,
        staffNames: _staffNames,
        onOpenBilling: widget.onOpenBilling,
        onEdit: sel == null ? null : () => _editTable(sel, floors),
        onDelete: sel == null ? null : () => _deleteTable(sel),
      );
      if (narrow) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 24),
              SizedBox(height: 560, child: canvas),
              const SizedBox(height: 20),
              panel,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: canvas),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 280,
                    child: LayoutBuilder(
                      builder: (context, pc) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: pc.maxHeight),
                          child: panel,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _header(List<String> floors, List<OpsTable> tables) => Wrap(
        spacing: 9,
        runSpacing: 9,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final f in floors)
            _FloorTab(
                label: f,
                selected: f == _floor,
                onTap: () => setState(() {
                      _floor = f;
                      _selectedId = null;
                    })),
          _FloorTab(
            label: '+ Add Table',
            selected: false,
            dashed: true,
            onTap: () => _addTable(floors),
          ),
        ],
      );

  Future<void> _addTable(List<String> floors) async {
    final nextLabel = await widget.ops.nextTableId();
    final taken = {
      for (final t in await widget.ops.getTables()) t.label.toLowerCase()
    };
    if (!mounted) return;
    final result = await showDialog<OpsTable>(
      context: context,
      builder: (_) => _TableFormDialog(
        floors: floors,
        initialLabel: nextLabel,
        initialFloor: _floor ?? 'Ground Floor',
        existing: null,
        takenLabels: taken,
      ),
    );
    if (result == null || !mounted) return;
    final ids = {for (final t in await widget.ops.getTables()) t.id};
    var id = nextLabel;
    var n = 1;
    while (ids.contains(id)) {
      id = '$nextLabel-${n++}';
    }
    if (!mounted) return;
    final ok = await runMasterAction(
        context,
        () => widget.ops.upsertTable(OpsTable(
            id: id,
            label: result.label,
            seats: result.seats,
            floor: result.floor,
            shape: result.shape,
            status: OpsTableStatus.available)),
        success: '${result.label} added to ${result.floor}');
    if (ok && mounted) {
      setState(() {
        _floor = result.floor;
        _selectedId = id;
      });
    }
  }

  Future<void> _editTable(OpsTable t, List<String> floors) async {
    final all = await widget.ops.getTables();
    if (!mounted) return;
    final result = await showDialog<OpsTable>(
      context: context,
      builder: (_) => _TableFormDialog(
        floors: floors,
        initialLabel: t.label,
        initialFloor: t.floor,
        existing: t,
        takenLabels: {
          for (final o in all)
            if (o.id != t.id) o.label.toLowerCase()
        },
      ),
    );
    if (result == null || !mounted) return;
    final ok = await runMasterAction(
        context,
        () => widget.ops.upsertTable(OpsTable(
              id: t.id,
              label: result.label,
              seats: result.seats,
              floor: result.floor,
              shape: result.shape,
              status: t.status,
              guests: t.guests,
              serverName: t.serverName,
              seatedAt: t.seatedAt,
              currentOrderId: t.currentOrderId,
              reservedByName: t.reservedByName,
              reservedAt: t.reservedAt,
            )),
        success: '${result.label} updated');
    if (ok && mounted) setState(() => _floor = result.floor);
  }

  Future<void> _deleteTable(OpsTable t) async {
    final yes = await confirmMasterAction(context,
        title: 'Delete ${t.label}?',
        message:
            '${t.label} will be removed from ${t.floor} and its QR code disabled. This cannot be undone.');
    if (!yes || !mounted) return;
    final ok = await runMasterAction(
        context, () => widget.ops.deleteTable(t.id),
        success: '${t.label} deleted');
    if (ok && mounted) setState(() => _selectedId = null);
  }
}

// ---------------------------------------------------------------------------
// Header tabs
// ---------------------------------------------------------------------------

class _FloorTab extends StatelessWidget {
  const _FloorTab(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.dashed = false});
  final String label;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _lime : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected
                      ? _lime
                      : dashed
                          ? const Color(0xFFBDBDBD)
                          : _border),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? ViniiColors.textPrimaryLight
                        : dashed
                            ? ViniiColors.textSecondaryLight
                            : const Color(0xFF3A3A40))),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Floor canvas
// ---------------------------------------------------------------------------

class _FloorCanvas extends StatelessWidget {
  const _FloorCanvas(
      {required this.tables,
      required this.filter,
      required this.selectedId,
      required this.onFilter,
      required this.onSelect});
  final List<OpsTable> tables;
  final _Filter filter;
  final String? selectedId;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<OpsTable> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        color: _canvas,
        child: CustomPaint(
          painter: _GridLinesPainter(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterBar(),
                const SizedBox(height: 44),
                if (tables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                        'No tables on this floor yet — use “+ Add Table”.',
                        style: MasterStyle.muted),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Wrap(
                      spacing: 40,
                      runSpacing: 70,
                      children: [
                        for (final t in tables)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: filter.matches(t) ? 1 : 0.25,
                            child: _TableCard(
                              table: t,
                              selected: t.id == selectedId,
                              onTap: () => onSelect(t),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _filterBar() => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))
          ],
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final f in _Filter.values)
              Material(
                color: f == filter ? _lime : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onFilter(f),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      f.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: f == filter
                              ? Colors.white
                              : const Color(0xFF3A3A40)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _canvasLine
      ..strokeWidth = 1;
    for (var y = 78.0; y < size.height; y += 78) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TableCard extends StatelessWidget {
  const _TableCard(
      {required this.table, required this.selected, required this.onTap});
  final OpsTable table;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = table;
    final s = _statusStyle(t.status);
    final round = t.shape == 'round';
    final big = t.seats >= 6;
    final width = round ? (big ? 116.0 : 100.0) : (big ? 140.0 : 100.0);
    final height = round ? width : 100.0;
    final reserved = t.status == OpsTableStatus.reserved;
    final shape = round
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return Tooltip(
      message: '${t.label} · ${t.status.label}',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: s.bg,
        shape: shape.copyWith(
            side: BorderSide(color: s.border, width: selected ? 3 : 2)),
        elevation: selected ? 6 : 0,
        shadowColor: s.border.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.label,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ViniiColors.textPrimaryLight)),
                    const SizedBox(height: 2),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_outline,
                          size: 12, color: Color(0xFF3A3A40)),
                      const SizedBox(width: 3),
                      Text(
                          '${t.status == OpsTableStatus.occupied || t.status == OpsTableStatus.billing ? (t.guests ?? t.seats) : t.seats} Pax',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF3A3A40))),
                    ]),
                    if (reserved && (t.reservedByName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width - 16),
                        child: Text(t.reservedByName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: ViniiColors.textPrimaryLight)),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(s.label,
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: s.text)),
                    ),
                    if (reserved && t.reservedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(formatClock(t.reservedAt!),
                          style: const TextStyle(
                              fontSize: 8.5, color: Color(0xFFA1A1AA))),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail panel
// ---------------------------------------------------------------------------

class _DetailPanel extends StatefulWidget {
  const _DetailPanel(
      {super.key,
      required this.table,
      required this.order,
      required this.now,
      required this.allTables,
      required this.lastCleaned,
      required this.reservations,
      required this.onMarkedAvailable,
      required this.ops,
      required this.master,
      required this.onOpenBilling,
      required this.onEdit,
      required this.onDelete,
      this.staffNames});
  final OpsTable? table;
  final OpsOrder? order;
  final DateTime now;
  final List<OpsTable> allTables;
  final DateTime? lastCleaned;

  /// Open (pending / confirmed) reservations held on this table.
  final List<OpsReservation> reservations;
  final ValueChanged<String> onMarkedAvailable;
  final DriftOperationsStore ops;
  final DriftMasterStore master;
  final ValueChanged<String>? onOpenBilling;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Active staff names for the server picker (see [loadStaffNames]).
  final Future<List<String>>? staffNames;

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  OpsTable get t => widget.table!;
  DriftOperationsStore get ops => widget.ops;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: table == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                  'Select a table on the floor plan to see its details.',
                  textAlign: TextAlign.center,
                  style: MasterStyle.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleRow(),
                const SizedBox(height: 14),
                ..._body(),
                const SizedBox(height: 18),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    _textAction(
                        Icons.edit_outlined, 'Edit Table', widget.onEdit),
                    _textAction(Icons.delete_outline, 'Delete', widget.onDelete,
                        color: ViniiColors.redSolid),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _titleRow() {
    final p = _pillStyle(t.status);
    return Row(children: [
      Expanded(
        child: Text(_tableTitle(t),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textPrimaryLight)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(4)),
        child: Text(t.status.label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: p.fg)),
      ),
    ]);
  }

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.5),
        child: Row(children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 13, color: ViniiColors.textSecondaryLight)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color ?? ViniiColors.textPrimaryLight)),
          ),
        ]),
      );

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
        height: 40,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: ViniiColors.textPrimaryLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4))),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _outline(String label, VoidCallback onTap, {Color? color}) => SizedBox(
        height: 40,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: color ?? const Color(0xFF3A3A40),
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4))),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _textAction(IconData icon, String label, VoidCallback? onTap,
          {Color? color}) =>
      TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
            foregroundColor: color ?? ViniiColors.textSecondaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 6)),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );

  List<Widget> _body() {
    switch (t.status) {
      case OpsTableStatus.occupied:
      case OpsTableStatus.billing:
        return _occupiedBody();
      case OpsTableStatus.available:
      case OpsTableStatus.reserved:
        return _seatBody();
      case OpsTableStatus.cleaning:
        return [
          _kv('Capacity', '${t.seats} Seats'),
          _kv('Floor', t.floor),
          const SizedBox(height: 12),
          const Text(
              'Guests have left — mark the table available once it has been cleaned and reset.',
              style: TextStyle(
                  fontSize: 12.5, color: ViniiColors.textSecondaryLight)),
          const SizedBox(height: 16),
          _primary('Mark Available', () async {
            final id = t.id;
            final ok = await runMasterAction(
                context, () => ops.setTableStatus(id, OpsTableStatus.available),
                success: '${t.label} is available');
            if (ok) widget.onMarkedAvailable(id);
          }),
        ];
    }
  }

  List<Widget> _occupiedBody() {
    final order = widget.order;
    final mins = t.elapsedMinutes(widget.now);
    return [
      _kv('Capacity', '${t.seats} Seats'),
      _kv('Guests', '${t.guests ?? '—'} People'),
      _kv('Time Elapsed', mins == null ? '—' : '$mins min'),
      _kv('Server', t.serverName.isEmpty ? '—' : t.serverName),
      if (order?.billNo != null)
        _kv('Bill No.', '#${order!.billNo}', color: ViniiColors.amberSolid),
      const SizedBox(height: 10),
      const Divider(height: 1, color: _border),
      const SizedBox(height: 16),
      if (order == null) ...[
        const Text('CURRENT ORDER',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A3A40))),
        const SizedBox(height: 8),
        const Text('No items ordered yet.', style: MasterStyle.muted),
        const SizedBox(height: 20),
        _primary('Take Order', _takeOrder),
        const SizedBox(height: 8),
        _outline('Transfer Table', _transfer),
        const SizedBox(height: 8),
        _outline('Free Table', () async {
          final yes = await confirmMasterAction(context,
              title: 'Free ${t.label}?',
              message:
                  'The guests are removed from ${t.label} and it goes to cleaning.',
              confirmLabel: 'Free Table');
          if (!yes || !mounted) return;
          await runMasterAction(
              context, () => ops.setTableStatus(t.id, OpsTableStatus.cleaning),
              success: '${t.label} sent to cleaning');
        }),
      ] else ...[
        Text('CURRENT ORDER (${order.itemCount} ITEMS)',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A3A40))),
        const SizedBox(height: 8),
        for (final l in order.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text('${l.quantity}x ${l.name}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: ViniiColors.textPrimaryLight)),
              ),
              Text(_money(l.totalMinor),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.textPrimaryLight)),
            ]),
          ),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(
            child: Text('Total',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
          ),
          Text(_money(order.grandTotalMinor),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _limeText)),
        ]),
        const SizedBox(height: 22),
        _primary('View Order & KOT', () {
          final cb = widget.onOpenBilling;
          if (cb == null) {
            showMasterNotice(context, 'POS Billing is not available here.');
          } else {
            cb(order.id);
          }
        }),
        const SizedBox(height: 8),
        _outline(
            order.billNo == null ? 'Generate Bill' : 'Bill #${order.billNo}',
            () async {
          var billNo = 0;
          await runMasterAction(context, () async {
            billNo = await ops.generateBill(order.id);
          });
          if (mounted && billNo > 0) {
            showMasterNotice(context,
                'Bill #$billNo generated for ${t.label} — ${_money(order.grandTotalMinor)}, payment pending');
          }
        }),
        const SizedBox(height: 8),
        _outline('Transfer Table', _transfer),
        if (order.status == OpsOrderStatus.open) ...[
          const SizedBox(height: 8),
          _outline('Add Items', _takeOrder),
        ],
      ],
    ];
  }

  /// Available / reserved table: the "No Active Order" panel.
  List<Widget> _seatBody() {
    final reserved = t.status == OpsTableStatus.reserved;
    final r = widget.reservations.firstOrNull;
    final cleaned = widget.lastCleaned;
    final arrival = t.reservedAt ?? r?.dateTime;
    return [
      _kv('Capacity', '${t.seats} Seats'),
      _kv('Zone', t.floor),
      if (reserved) ...[
        _kv('Reserved For', t.reservedByName ?? r?.guestName ?? '—',
            color: ViniiColors.purpleSolid),
        _kv('Arrival', arrival == null ? '—' : formatClock(arrival)),
        if (r != null) _kv('Party Size', '${r.guests} People'),
      ] else
        _kv(
            'Last Cleaned',
            cleaned == null
                ? '—'
                : formatAgo(cleaned, widget.now)
                    .replaceAll('just now', 'Just now')),
      _kv('Server Assigned',
          t.serverName.isEmpty ? 'None (On Seating)' : t.serverName),
      const SizedBox(height: 10),
      const Divider(height: 1, color: _border),
      const SizedBox(height: 18),
      CustomPaint(
        painter: _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 20),
          child: Column(children: [
            const Icon(Icons.restaurant_outlined,
                size: 26, color: Color(0xFFB0B3BA)),
            const SizedBox(height: 10),
            const Text('No Active Order',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A40))),
            const SizedBox(height: 4),
            Text(
                reserved
                    ? 'Seat the reserved party to initiate billing, kots, and orders'
                    : 'Assign guests to initiate billing, kots, and orders',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: ViniiColors.textMutedLight)),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      _primary('Start Ordering', () => _startOrdering(r)),
      const SizedBox(height: 8),
      if (reserved)
        _outline('Cancel Reservation', () => _cancelReservation(r),
            color: ViniiColors.redSolid)
      else
        _outline('Reserve Table', _reserve),
    ];
  }

  Future<void> _startOrdering(OpsReservation? r) async {
    final table = t;
    // Suggested when there is no staff list: the servers already on
    // tables and the signed-in person.
    final servers = distinctNames([
      for (final o in widget.allTables) o.serverName,
      ops.actorName,
    ]);
    final seat = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _SeatDialog(
          table: table,
          initialGuests: r?.guests ?? (table.seats < 2 ? table.seats : 2),
          servers: servers,
          staffNames: widget.staffNames,
          defaultServer: ops.actorName),
    );
    if (seat == null || !mounted) return;
    final ok = await runMasterAction(context, () async {
      await ops.seatTable(table.id, guests: seat.$1, serverName: seat.$2);
      if (r != null) {
        await ops.setReservationStatus(r.id, ReservationStatus.seated);
      }
    }, success: '${seat.$1} guests seated at ${table.label}');
    if (ok && mounted) await _takeOrder(table: table);
  }

  Future<void> _cancelReservation(OpsReservation? r) async {
    final table = t;
    final who = table.reservedByName ?? r?.guestName ?? 'the guest';
    final yes = await confirmMasterAction(context,
        title: 'Cancel reservation?',
        message: r == null
            ? '${table.label} will no longer be held for $who.'
            : '${table.label} will no longer be held for $who and the reservation is marked cancelled.',
        confirmLabel: 'Cancel Reservation');
    if (!yes || !mounted) return;
    await runMasterAction(context, () async {
      if (r != null) {
        await ops.setReservationStatus(r.id, ReservationStatus.cancelled);
      }
      await ops.setTableStatus(table.id, OpsTableStatus.available);
    }, success: 'Reservation cancelled — ${table.label} is available');
  }

  Future<void> _reserve() async {
    final table = t;
    final res = await showDialog<OpsReservation>(
        context: context, builder: (_) => _ReserveDialog(table: table));
    if (res == null || !mounted) return;
    await runMasterAction(context, () async {
      final existing = await ops.getReservations();
      var max = 100;
      for (final e in existing) {
        final n = int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (n > max && n < 1000000) max = n;
      }
      await ops.upsertReservation(OpsReservation(
          id: 'RSV-${max + 1}',
          guestName: res.guestName,
          phone: res.phone,
          guests: res.guests,
          dateTime: res.dateTime,
          status: ReservationStatus.confirmed,
          tableId: table.id,
          notes: res.notes));
      await ops.upsertTable(OpsTable(
        id: table.id,
        label: table.label,
        seats: table.seats,
        floor: table.floor,
        shape: table.shape,
        status: OpsTableStatus.reserved,
        serverName: table.serverName,
        reservedByName: res.guestName,
        reservedAt: res.dateTime,
      ));
    },
        success:
            '${table.label} reserved for ${res.guestName} at ${formatClock(res.dateTime)}');
  }

  Future<void> _takeOrder({OpsTable? table}) async {
    final tb = table ?? t;
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _TakeOrderDialog(
          ops: ops, master: widget.master, table: tb, order: widget.order),
    );
    if (id == null || !mounted) return;
    // The order number people read ("ORD-248"), never the id.
    final current = widget.order;
    var number = orderNumberLabel(id, null);
    if (current != null && current.id == id) {
      number = current.number;
    } else {
      try {
        final placed = await ops.getOrder(id);
        if (placed != null) number = placed.number;
      } catch (_) {
        // Keep the short reference — the order itself was placed.
      }
    }
    if (!mounted) return;
    showMasterNotice(context, 'KOT sent to kitchen for ${tb.label} ($number)');
  }

  Future<void> _transfer() async {
    final free = widget.allTables
        .where((o) => o.status == OpsTableStatus.available && o.id != t.id)
        .toList();
    if (free.isEmpty) {
      showMasterError(context, 'No available tables to transfer to.');
      return;
    }
    final from = t;
    final to = await showDialog<OpsTable>(
        context: context,
        builder: (_) => _TransferDialog(from: from, candidates: free));
    if (to == null || !mounted) return;
    await runMasterAction(context, () => ops.transferTable(from.id, to.id),
        success:
            'Moved ${from.label} → ${to.label}; ${from.label} sent to cleaning');
  }
}

InputDecoration _inputDecoration(String hint, {String? error}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      errorText: error,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border)),
    );

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged, this.min = 0});
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? f) => InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(4)),
            child: Icon(i, size: 14),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
      SizedBox(
        width: 34,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
      btn(Icons.add, () => onChanged(value + 1)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.from, required this.candidates});
  final OpsTable from;
  final List<OpsTable> candidates;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  OpsTable? _to;

  @override
  Widget build(BuildContext context) {
    final byFloor = <String, List<OpsTable>>{};
    for (final t in widget.candidates) {
      byFloor.putIfAbsent(t.floor, () => []).add(t);
    }
    final guests = widget.from.guests ?? 0;
    return AlertDialog(
      title: Text('Transfer ${widget.from.label}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Move ${guests > 0 ? '$guests guests' : 'the guests'} and the open order to an available table. ${widget.from.label} will be sent to cleaning.',
                  style: MasterStyle.subtitle.copyWith(fontSize: 13)),
              for (final e in byFloor.entries) ...[
                const SizedBox(height: 14),
                Text(e.key.toUpperCase(),
                    style: MasterStyle.label.copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in e.value)
                    ChoiceChip(
                      label: Text(
                          '${t.label} · ${t.seats} seats${t.seats < guests ? ' (small)' : ''}'),
                      selected: _to?.id == t.id,
                      selectedColor: const Color(0xFFEEFCDD),
                      onSelected: (_) => setState(() => _to = t),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: ViniiColors.textPrimaryLight),
          onPressed: _to == null ? null : () => Navigator.pop(context, _to),
          child:
              Text(_to == null ? 'Pick a table' : 'Transfer to ${_to!.label}'),
        ),
      ],
    );
  }
}

/// Add / edit table form. Returns an [OpsTable] carrying only the edited
/// fields (label, seats, floor, shape).
class _TableFormDialog extends StatefulWidget {
  const _TableFormDialog(
      {required this.floors,
      required this.initialLabel,
      required this.initialFloor,
      required this.existing,
      required this.takenLabels});
  final List<String> floors;
  final String initialLabel;
  final String initialFloor;
  final OpsTable? existing;
  final Set<String> takenLabels;

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  static const _newFloor = '\u0000new-floor';
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.initialLabel);
  late final _seats =
      TextEditingController(text: '${widget.existing?.seats ?? 4}');

  /// The chosen floor (picked from [_floors] or typed as a new one).
  late final _floor = TextEditingController(text: widget.initialFloor.trim());
  late String _shape = widget.existing?.shape ?? 'square';

  /// Floors that already have tables, plus this table's own floor.
  late final List<String> _floors = () {
    final out = <String>[];
    for (final f in [...widget.floors, widget.existing?.floor ?? '']) {
      final name = f.trim();
      if (name.isNotEmpty && !out.contains(name)) out.add(name);
    }
    return out;
  }();

  /// Typing the name of a floor that has no tables yet ("Add new
  /// floor…"), or there is no floor to pick from.
  late bool _addingFloor = !_floors.contains(_floor.text.trim());

  @override
  void dispose() {
    _label.dispose();
    _seats.dispose();
    _floor.dispose();
    super.dispose();
  }

  /// The floor to save: a typed name that matches an existing floor
  /// (ignoring case) keeps that floor's spelling.
  String get _chosenFloor {
    final typed = _floor.text.trim();
    for (final f in _floors) {
      if (f.toLowerCase() == typed.toLowerCase()) return f;
    }
    return typed;
  }

  @override
  Widget build(BuildContext context) {
    // Usual floor names not in use yet, offered when adding a new floor.
    final suggested = [
      for (final f in DriftOperationsStore.defaultFloors)
        if (!_floors.contains(f)) f
    ];
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Add Table'
          : 'Edit ${widget.existing!.label}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel('Table label'),
              TextFormField(
                controller: _label,
                decoration: _inputDecoration('e.g. T19'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Enter a label';
                  if (widget.takenLabels.contains(s.toLowerCase())) {
                    return '$s already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _fieldLabel('Seats'),
              TextFormField(
                controller: _seats,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('4'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'At least 1 seat';
                  if (n > 30) return 'At most 30 seats';
                  final g = widget.existing?.guests;
                  if (g != null && n < g) return '$g guests are seated here';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _fieldLabel('Floor'),
              // Existing floors are picked; "Add new floor…" (or no
              // floors yet) opens a field for a new floor's name.
              if (_floors.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _addingFloor ? _newFloor : _floor.text.trim(),
                  isExpanded: true,
                  decoration: _inputDecoration('Pick a floor'),
                  items: [
                    for (final f in _floors)
                      DropdownMenuItem(
                          value: f,
                          child: Text(f, overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(
                        value: _newFloor,
                        child: Text('Add new floor…',
                            style: TextStyle(fontStyle: FontStyle.italic))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (v == _newFloor) {
                        if (!_addingFloor) _floor.clear();
                        _addingFloor = true;
                      } else {
                        _addingFloor = false;
                        _floor.text = v;
                      }
                    });
                  },
                ),
              if (_addingFloor) ...[
                if (_floors.isNotEmpty) const SizedBox(height: 8),
                TextFormField(
                  controller: _floor,
                  autofocus: _floors.isNotEmpty,
                  decoration: _inputDecoration('New floor / area name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a floor name' : null,
                  onChanged: (_) => setState(() {}),
                ),
                if (suggested.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final f in suggested)
                      ChoiceChip(
                        label: Text(f, style: const TextStyle(fontSize: 12)),
                        selected: _floor.text.trim() == f,
                        selectedColor: const Color(0xFFEEFCDD),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _floor.text = f),
                      ),
                  ]),
                ],
              ],
              const SizedBox(height: 14),
              _fieldLabel('Shape'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'square',
                      icon: Icon(Icons.crop_square, size: 16),
                      label: Text('Square')),
                  ButtonSegment(
                      value: 'round',
                      icon: Icon(Icons.circle_outlined, size: 16),
                      label: Text('Round')),
                ],
                selected: {_shape},
                onSelectionChanged: (s) => setState(() => _shape = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: ViniiColors.textPrimaryLight),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
                context,
                OpsTable(
                    id: widget.existing?.id ?? '',
                    label: _label.text.trim(),
                    seats: int.parse(_seats.text),
                    floor: _chosenFloor,
                    shape: _shape,
                    status: OpsTableStatus.available));
          },
          child: Text(widget.existing == null ? 'Add Table' : 'Save'),
        ),
      ],
    );
  }
}

/// Menu picker for a table: add dishes, then "Send to Kitchen (KOT)"
/// places the order (or adds to the table's open order). Pops with the
/// order id.
class _TakeOrderDialog extends StatefulWidget {
  const _TakeOrderDialog(
      {required this.ops,
      required this.master,
      required this.table,
      required this.order});
  final DriftOperationsStore ops;
  final DriftMasterStore master;
  final OpsTable table;
  final OpsOrder? order;

  @override
  State<_TakeOrderDialog> createState() => _TakeOrderDialogState();
}

class _TakeOrderDialogState extends State<_TakeOrderDialog> {
  late final Stream<List<MasterDishItem>> _dishes$ =
      widget.master.watchDishes();
  final _qty = <String, int>{};
  final _notes = TextEditingController();
  String _query = '';
  String? _category;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: StreamBuilder<List<MasterDishItem>>(
          stream: _dishes$,
          builder: (context, snap) {
            final all = (snap.data ?? const <MasterDishItem>[])
                .where((d) =>
                    d.status == 'Active' && d.availability != 'Unavailable')
                .toList();
            final byId = {for (final d in all) d.id: d};
            final cats = {for (final d in all) d.category}.toList()..sort();
            final shown = all
                .where((d) =>
                    (_category == null || d.category == _category) &&
                    (_query.isEmpty ||
                        d.name.toLowerCase().contains(_query.toLowerCase())))
                .toList();
            final lines = [
              for (final e in _qty.entries)
                if (e.value > 0 && byId[e.key] != null) (byId[e.key]!, e.value)
            ];
            final total = lines.fold<int>(
                0, (s, l) => s + (l.$1.sellingPrice * 100).round() * l.$2);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          '${widget.order == null ? 'Take Order' : 'Add Items'} · ${widget.table.label}',
                          style: MasterStyle.sectionTitle),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: _inputDecoration('Search dishes…').copyWith(
                        prefixIcon: const Icon(Icons.search, size: 18)),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in [null, ...cats])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c == null ? 'All' : _titleCase(c),
                                  style: const TextStyle(fontSize: 12)),
                              selected: _category == c,
                              selectedColor: _lime,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _category = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: !snap.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : shown.isEmpty
                            ? const Center(
                                child: Text('No dishes match.',
                                    style: MasterStyle.muted))
                            : ListView.separated(
                                itemCount: shown.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: _border),
                                itemBuilder: (_, i) {
                                  final d = shown[i];
                                  final q = _qty[d.id] ?? 0;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(children: [
                                      _VegMark(veg: d.isVeg && !d.isNonVeg),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(d.name,
                                                style: MasterStyle.value),
                                            Text(_titleCase(d.category),
                                                style: MasterStyle.muted),
                                          ],
                                        ),
                                      ),
                                      Text(
                                          _money(
                                              (d.sellingPrice * 100).round()),
                                          style: MasterStyle.value),
                                      const SizedBox(width: 12),
                                      _Stepper(
                                          value: q,
                                          onChanged: (v) =>
                                              setState(() => _qty[d.id] = v)),
                                    ]),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    decoration: _inputDecoration('Kitchen notes (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Text(
                          lines.isEmpty
                              ? 'No items selected'
                              : '${lines.fold<int>(0, (s, l) => s + l.$2)} items · ${_money(total)}',
                          style: MasterStyle.value),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _lime,
                          foregroundColor: ViniiColors.textPrimaryLight),
                      onPressed: lines.isEmpty || _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              String? id;
                              final ok =
                                  await runMasterAction(context, () async {
                                id = await widget.ops.placeOrder(
                                  channel: OpsChannel.dineIn,
                                  tableId: widget.table.id,
                                  guests: widget.table.guests,
                                  serverName: widget.table.serverName,
                                  source: 'POS',
                                  notes: _notes.text.trim(),
                                  lines: [
                                    for (final (d, q) in lines)
                                      OpsOrderLine(
                                          itemId: d.id,
                                          name: d.name,
                                          unitMinor:
                                              (d.sellingPrice * 100).round(),
                                          quantity: q,
                                          station: stationForDish(
                                              d.category, d.kitchenStation),
                                          isVeg: d.isVeg && !d.isNonVeg),
                                  ],
                                );
                              });
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.pop(context, id);
                              } else {
                                setState(() => _busy = false);
                              }
                            },
                      child: const Text('Send to Kitchen (KOT)'),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VegMark extends StatelessWidget {
  const _VegMark({required this.veg});
  final bool veg;

  @override
  Widget build(BuildContext context) {
    final c = veg ? ViniiColors.greenSolid : ViniiColors.redSolid;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.4),
          borderRadius: BorderRadius.circular(2)),
      alignment: Alignment.center,
      child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(8)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _fieldLabel(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(s,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ViniiColors.textPrimaryLight)),
    );

/// "Start Ordering": guests + server. Pops with (guests, server).
///
/// The server is picked from [staffNames] (+ "Other…"); without a staff
/// list it is typed, with [servers] suggested. It starts as the table's
/// server, else [defaultServer] (the signed-in person).
class _SeatDialog extends StatefulWidget {
  const _SeatDialog(
      {required this.table,
      required this.initialGuests,
      required this.servers,
      this.staffNames,
      this.defaultServer = ''});
  final OpsTable table;
  final int initialGuests;
  final List<String> servers;
  final Future<List<String>>? staffNames;
  final String defaultServer;

  @override
  State<_SeatDialog> createState() => _SeatDialogState();
}

class _SeatDialogState extends State<_SeatDialog> {
  late int _guests = widget.initialGuests.clamp(1, 99);
  late final _server = TextEditingController(
      text: widget.table.serverName.trim().isNotEmpty
          ? widget.table.serverName.trim()
          : widget.defaultServer.trim());

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  String? get _error => _guests < 1
      ? 'At least one guest'
      : _guests > widget.table.seats
          ? '${widget.table.label} seats ${widget.table.seats} — pick a bigger table'
          : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seat guests · ${widget.table.label}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Guests',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ViniiColors.textPrimaryLight))),
              _Stepper(
                  min: 1,
                  value: _guests,
                  onChanged: (v) => setState(() => _guests = v)),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: ViniiColors.redSolid)),
              ),
            const SizedBox(height: 16),
            _fieldLabel('Server'),
            PersonPickerField(
              controller: _server,
              namesFuture: widget.staffNames,
              suggestions: widget.servers,
              decoration: _inputDecoration('Server name (optional)'),
              otherHint: 'Type the server’s name',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: ViniiColors.textPrimaryLight),
          onPressed: _error != null
              ? null
              : () => Navigator.pop(context, (_guests, _server.text.trim())),
          child: const Text('Seat & Take Order'),
        ),
      ],
    );
  }
}

/// "Reserve Table": guest name, phone, time, party size. Pops with an
/// [OpsReservation] carrying those fields (id / table filled by caller).
class _ReserveDialog extends StatefulWidget {
  const _ReserveDialog({required this.table});
  final OpsTable table;

  @override
  State<_ReserveDialog> createState() => _ReserveDialogState();
}

class _ReserveDialogState extends State<_ReserveDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  late int _party = widget.table.seats < 2 ? widget.table.seats : 2;
  late DateTime _at = _defaultTime();

  static DateTime _defaultTime() {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour, n.minute < 30 ? 30 : 0)
        .add(Duration(hours: n.minute < 30 ? 0 : 1));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (picked == null) return;
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    setState(() => _at = at);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = _at.day != now.day;
    final partyError = _party > widget.table.seats
        ? '${widget.table.label} seats ${widget.table.seats}'
        : null;
    return AlertDialog(
      title: Text('Reserve ${widget.table.label}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel('Guest name'),
              TextFormField(
                controller: _name,
                decoration: _inputDecoration('e.g. Rahul Sharma'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the guest name' : null,
              ),
              const SizedBox(height: 14),
              _fieldLabel('Phone'),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))
                ],
                decoration: _inputDecoration('+91 98765 43210'),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Time'),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule, size: 16),
                        label: Text(
                            '${formatClock(_at)}${tomorrow ? ' (tomorrow)' : ''}'),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Party size'),
                    _Stepper(
                        min: 1,
                        value: _party,
                        onChanged: (v) => setState(() => _party = v)),
                  ],
                ),
              ]),
              if (partyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(partyError,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, color: ViniiColors.redSolid)),
                ),
              const SizedBox(height: 14),
              _fieldLabel('Notes'),
              TextFormField(
                controller: _notes,
                decoration:
                    _inputDecoration('Occasion, preferences (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: ViniiColors.textPrimaryLight),
          onPressed: partyError != null
              ? null
              : () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(
                      context,
                      OpsReservation(
                          id: '',
                          guestName: _name.text.trim(),
                          phone: _phone.text.trim(),
                          guests: _party,
                          dateTime: _at,
                          status: ReservationStatus.confirmed,
                          notes: _notes.text.trim()));
                },
          child: const Text('Reserve Table'),
        ),
      ],
    );
  }
}
