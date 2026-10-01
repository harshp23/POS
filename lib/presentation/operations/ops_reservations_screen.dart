import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';

// ---------------------------------------------------------------------------
// Local palette (matches OPS-RESERVATIONS-DEFAULT.png)
// ---------------------------------------------------------------------------

const _border = Color(0xFFE5E7EB);
const _pageBg = Color(0xFFF9FAFB);
const _chipGray = Color(0xFFF3F4F6);
const _selBorder = Color(0xFF4ADE80);
const _selTint = Color(0xFFF0FDF4);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _muted = ViniiColors.textMutedLight;
const _secondary = ViniiColors.textSecondaryLight;
const _primary = ViniiColors.textPrimaryLight;

/// How long a booking is assumed to hold its table (timeline blocks,
/// conflict hints in the table picker).
const _slot = Duration(minutes: 90);

enum _Range { today, tomorrow, week, custom }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

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
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "Today", "Tomorrow", "Yesterday" or "Mon, 29 Sep".
String _dayLabel(DateTime d, DateTime now) {
  final diff = _day(d).difference(_day(now)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]}, ${_shortDate(d)}';
}

/// "Today, 7:30 PM".
String _when(DateTime d, DateTime now) =>
    '${_dayLabel(d, now)}, ${formatClock(d)}';

/// Seeded labels are "T8" / "C2"; the design reads "Table 8".
String _tableName(String label) {
  final m = RegExp(r'^[Tt](\d+)$').firstMatch(label.trim());
  return m == null ? label : 'Table ${m.group(1)}';
}

/// What people read for a booking's table when it is not in the table
/// list (deleted, or the list is still loading) — never the table's id.
const _unknownTable = 'Unknown table';

/// Bookings that point at a table which no longer exists.
const _removedTable = 'Removed table';

/// A booking's table as people read it: "Table 8", or "Unknown table"
/// when the table is not in the list. The table id is only for lookups.
String _tableOf(OpsTable? t) => t == null ? _unknownTable : _tableName(t.label);

String _phoneDigits(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

String _formatPhone(String digits) =>
    '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';

(Color, Color) _statusColors(ReservationStatus s) => switch (s) {
      ReservationStatus.confirmed => (const Color(0xFFECFDF3), _green),
      ReservationStatus.pending => (
          const Color(0xFFFFFBEB),
          ViniiColors.amberSolid
        ),
      ReservationStatus.seated => (
          const Color(0xFFEFF6FF),
          ViniiColors.blueSolid
        ),
      ReservationStatus.noShow => (
          const Color(0xFFFEF2F2),
          ViniiColors.redSolid
        ),
      ReservationStatus.cancelled => (_chipGray, ViniiColors.graySolid),
      ReservationStatus.completed => (
          ViniiColors.purpleTint,
          ViniiColors.purpleSolid
        ),
    };

bool _isActive(ReservationStatus s) =>
    s == ReservationStatus.pending || s == ReservationStatus.confirmed;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OpsReservationsScreen extends StatefulWidget {
  const OpsReservationsScreen(
      {super.key,
      required this.ops,
      this.master,
      this.focusOrderId,
      this.onOpenBilling});
  final DriftOperationsStore ops;
  final DriftMasterStore? master;
  final String? focusOrderId;
  final ValueChanged<String>? onOpenBilling;

  @override
  State<OpsReservationsScreen> createState() => _OpsReservationsScreenState();
}

class _OpsReservationsScreenState extends State<OpsReservationsScreen> {
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _ticker;
  DateTime _now = DateTime.now();

  List<OpsReservation> _reservations = const [];
  List<OpsTable> _tables = const [];
  List<OpsOrder> _orders = const [];
  bool _loaded = false;

  bool _timeline = false;
  _Range _range = _Range.today;
  DateTimeRange? _custom;
  String? _selectedId;

  DriftOperationsStore get ops => widget.ops;

  @override
  void initState() {
    super.initState();
    _subs.add(ops.watchReservations().listen((r) {
      if (mounted) {
        setState(() {
          _reservations = r;
          _loaded = true;
        });
      }
    }));
    _subs.add(ops.watchTables().listen((t) {
      if (mounted) setState(() => _tables = t);
    }));
    _subs.add(ops.watchOrders().listen((o) {
      if (mounted) setState(() => _orders = o);
    }));
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    super.dispose();
  }

  // ---- Derived data -------------------------------------------------------

  Map<String, OpsTable> get _tableById => {for (final t in _tables) t.id: t};

  (DateTime, DateTime) get _window {
    final today = _day(_now);
    return switch (_range) {
      _Range.today => (today, today.add(const Duration(days: 1))),
      _Range.tomorrow => (
          today.add(const Duration(days: 1)),
          today.add(const Duration(days: 2))
        ),
      _Range.week => (
          today.subtract(Duration(days: today.weekday - 1)),
          today.add(Duration(days: 8 - today.weekday))
        ),
      _Range.custom => (
          _day(_custom?.start ?? today),
          _day(_custom?.end ?? today).add(const Duration(days: 1))
        ),
    };
  }

  List<OpsReservation> get _filtered {
    final (from, to) = _window;
    return _reservations
        .where((r) => !r.dateTime.isBefore(from) && r.dateTime.isBefore(to))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  OpsReservation? _selected(List<OpsReservation> filtered) {
    for (final r in filtered) {
      if (r.id == _selectedId) return r;
    }
    return filtered.isEmpty ? null : filtered.first;
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _openForm([OpsReservation? existing]) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ReservationFormDialog(
          ops: ops, tables: _tables, existing: existing, now: _now),
    );
    if (saved != null && mounted) setState(() => _selectedId = saved);
  }

  Future<void> _pickTable(OpsReservation r, {bool seatAfter = false}) async {
    final tableId = await showDialog<String>(
      context: context,
      builder: (_) => _TablePickerDialog(
          reservation: r,
          tables: _tables,
          reservations: _reservations,
          now: _now),
    );
    if (tableId == null || !mounted) return;
    final name = _tableOf(_tableById[tableId]);
    await runMasterAction(context, () async {
      await ops.assignReservationTable(r.id, tableId);
      if (seatAfter) await ops.seatReservation(r.id);
    },
        success: seatAfter
            ? '${r.guestName} seated at $name'
            : '$name assigned to ${r.guestName}');
  }

  Future<void> _seat(OpsReservation r) async {
    if (r.tableId == null) return _pickTable(r, seatAfter: true);
    final t = _tableById[r.tableId];
    await runMasterAction(context, () => ops.seatReservation(r.id),
        success: t == null
            ? '${r.guestName} seated'
            : '${r.guestName} seated at ${_tableOf(t)}');
  }

  Future<void> _setStatus(OpsReservation r, ReservationStatus s,
          {String? success}) =>
      runMasterAction(context, () => ops.setReservationStatus(r.id, s),
          success: success);

  Future<void> _cancel(OpsReservation r) async {
    final ok = await confirmMasterAction(context,
        title: 'Cancel reservation?',
        message:
            'Cancel ${r.guestName}\'s booking for ${r.guests} on ${_when(r.dateTime, _now)}?',
        confirmLabel: 'Cancel Reservation');
    if (!ok || !mounted) return;
    await _setStatus(r, ReservationStatus.cancelled,
        success: 'Reservation cancelled');
  }

  Future<void> _noShow(OpsReservation r) async {
    final ok = await confirmMasterAction(context,
        title: 'Mark as no-show?',
        message:
            '${r.guestName} did not arrive for ${formatClock(r.dateTime)}.',
        confirmLabel: 'Mark No-show');
    if (!ok || !mounted) return;
    await _setStatus(r, ReservationStatus.noShow, success: 'Marked as no-show');
  }

  Future<void> _pickCustomRange() async {
    final today = _day(_now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _custom ??
          DateTimeRange(start: today, end: today.add(const Duration(days: 6))),
    );
    if (picked != null && mounted) {
      setState(() {
        _custom = picked;
        _range = _Range.custom;
      });
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final selected = _selected(filtered);
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final left = _leftPane(filtered, selected);
              final detail = _DetailPanel(
                reservation: selected,
                tables: _tableById,
                reservations: _reservations,
                orders: _orders,
                now: _now,
                onConfirm: (r) => _setStatus(r, ReservationStatus.confirmed,
                    success: 'Reservation confirmed'),
                onSeat: _seat,
                onComplete: (r) => _setStatus(r, ReservationStatus.completed,
                    success: 'Reservation completed'),
                onReopen: (r) => _setStatus(r, ReservationStatus.pending,
                    success: 'Reservation reopened as pending'),
                onReassign: (r) => _pickTable(r),
                onNoShow: _noShow,
                onCancel: _cancel,
                onEdit: _openForm,
              );
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _kpis(c.maxWidth),
                    const SizedBox(height: 32),
                    if (wide)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            SizedBox(
                                width: c.maxWidth >= 1150 ? 420 : 360,
                                child: detail),
                          ])
                    else ...[
                      left,
                      const SizedBox(height: 16),
                      detail,
                    ],
                  ]);
            }),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border))),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Reservations',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: _primary)),
                  SizedBox(height: 4),
                  Text('Manage table bookings',
                      style: TextStyle(fontSize: 14, color: _secondary)),
                ]),
            _Btn(
                label: 'New Reservation',
                icon: Icons.add,
                bg: ViniiColors.brandGreen,
                fg: Colors.black,
                height: 36,
                fontSize: 13,
                onTap: () => _openForm()),
          ],
        ),
      );

  Widget _kpis(double width) {
    final today = _day(_now);
    final tomorrow = today.add(const Duration(days: 1));
    bool isToday(OpsReservation r) =>
        !r.dateTime.isBefore(today) && r.dateTime.isBefore(tomorrow);
    final todays = _reservations.where(isToday).toList();
    final horizon = _now.add(const Duration(hours: 48));
    final cards = [
      _KpiCard(
          label: 'TODAY',
          value: todays.length,
          tag: 'Live',
          tagBg: const Color(0xFFEFF6FF),
          tagFg: ViniiColors.blueSolid),
      _KpiCard(
          label: 'UPCOMING',
          value: _reservations
              .where((r) =>
                  _isActive(r.status) &&
                  r.dateTime.isAfter(_now) &&
                  !r.dateTime.isAfter(horizon))
              .length,
          tag: 'Next 48h',
          tagBg: const Color(0xFFECFDF3),
          tagFg: _green),
      _KpiCard(
          label: 'SEATED',
          value: _reservations
              .where((r) => r.status == ReservationStatus.seated)
              .length,
          tag: 'Active',
          tagBg: const Color(0xFFEFF6FF),
          tagFg: ViniiColors.blueSolid),
      _KpiCard(
          label: 'NO-SHOW',
          value:
              todays.where((r) => r.status == ReservationStatus.noShow).length,
          tag: 'Attention',
          tagBg: const Color(0xFFFEF2F2),
          tagFg: ViniiColors.redSolid),
      _KpiCard(
          label: 'CANCELLED',
          value: todays
              .where((r) => r.status == ReservationStatus.cancelled)
              .length,
          tag: 'Today',
          tagBg: _chipGray,
          tagFg: _secondary),
    ];
    if (width >= 760) {
      return Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ]
      ]);
    }
    final w = width >= 480 ? (width - 12) / 2 : width;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final c in cards) SizedBox(width: w, child: c),
    ]);
  }

  Widget _leftPane(List<OpsReservation> filtered, OpsReservation? selected) {
    final (from, to) = _window;
    final customLabel = _custom == null
        ? 'Custom'
        : '${_shortDate(_custom!.start)} – ${_shortDate(_custom!.end)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          _Segmented(
              options: const ['List', 'Timeline'],
              selected: _timeline ? 1 : 0,
              onSelect: (i) => setState(() => _timeline = i == 1)),
          Wrap(spacing: 4, runSpacing: 6, children: [
            _DateChip(
                label: 'Today',
                selected: _range == _Range.today,
                onTap: () => setState(() => _range = _Range.today)),
            _DateChip(
                label: 'Tomorrow',
                selected: _range == _Range.tomorrow,
                onTap: () => setState(() => _range = _Range.tomorrow)),
            _DateChip(
                label: 'This Week',
                selected: _range == _Range.week,
                onTap: () => setState(() => _range = _Range.week)),
            _DateChip(
                label: customLabel,
                icon: Icons.calendar_today_outlined,
                selected: _range == _Range.custom,
                onTap: _pickCustomRange),
          ]),
        ],
      ),
      const SizedBox(height: 16),
      if (!_loaded)
        const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()))
      else if (filtered.isEmpty)
        _EmptyState(
            message: 'No reservations between ${_shortDate(from)} and '
                '${_shortDate(to.subtract(const Duration(days: 1)))}.',
            onCreate: () => _openForm())
      else if (_timeline)
        _Timeline(
          reservations: filtered,
          tables: _tables,
          selectedId: selected?.id,
          now: _now,
          multiDay: to.difference(from).inDays > 1,
          onSelect: (r) => setState(() => _selectedId = r.id),
        )
      else
        for (final r in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BookingCard(
              reservation: r,
              table: r.tableId == null ? null : _tableById[r.tableId],
              now: _now,
              selected: r.id == selected?.id,
              onTap: () => setState(() => _selectedId = r.id),
              onSeat: () => _seat(r),
              onAssign: () => _pickTable(r),
              onEdit: () => _openForm(r),
            ),
          ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.label,
      required this.onTap,
      required this.bg,
      required this.fg,
      this.border,
      this.icon,
      this.height = 30,
      this.fontSize = 12.5,
      this.expand = false});
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border ?? bg)),
            child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: fg)),
                  ),
                ]),
          ),
        ),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.tag,
      required this.tagBg,
      required this.tagFg});
  final String label;
  final int value;
  final String tag;
  final Color tagBg;
  final Color tagFg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: _secondary)),
          const SizedBox(height: 6),
          Row(children: [
            Text('$value',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: _primary)),
            const Spacer(),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: tagBg, borderRadius: BorderRadius.circular(4)),
                child: Text(tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tagFg)),
              ),
            ),
          ]),
        ]),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.options, required this.selected, required this.onSelect});
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < options.length; i++)
            InkWell(
              onTap: () => onSelect(i),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? _chipGray : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(i == 0 ? 5 : 0),
                    right: Radius.circular(i == options.length - 1 ? 5 : 0),
                  ),
                ),
                child: Text(options[i],
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            i == selected ? FontWeight.w600 : FontWeight.w400,
                        color: i == selected ? _primary : _secondary)),
              ),
            ),
        ]),
      );
}

class _DateChip extends StatelessWidget {
  const _DateChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? ViniiColors.brandGreen : _border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null && selected) ...[
                Icon(icon, size: 13, color: _primary),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: _primary)),
            ]),
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: _secondary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, color: _secondary)),
      ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onCreate});
  final String message;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border)),
        child: Column(children: [
          const Icon(Icons.event_busy_outlined, size: 36, color: _muted),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _secondary)),
          const SizedBox(height: 14),
          _Btn(
              label: 'New Reservation',
              icon: Icons.add,
              bg: ViniiColors.brandGreen,
              fg: Colors.black,
              onTap: onCreate),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Booking card (List view)
// ---------------------------------------------------------------------------

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.reservation,
    required this.table,
    required this.now,
    required this.selected,
    required this.onTap,
    required this.onSeat,
    required this.onAssign,
    required this.onEdit,
  });
  final OpsReservation reservation;
  final OpsTable? table;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSeat;
  final VoidCallback onAssign;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final showSeat =
        r.status == ReservationStatus.confirmed && r.tableId != null;
    final showAssign = r.tableId == null && _isActive(r.status);
    return Material(
      color: selected ? _selTint : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? _selBorder : _border,
                width: selected ? 1.3 : 1),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: r.guestName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _primary)),
                    const WidgetSpan(child: SizedBox(width: 10)),
                    TextSpan(
                        text: r.maskedPhone,
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(r.status),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _IconText(Icons.person_outline,
                    '${r.guests} guest${r.guests == 1 ? '' : 's'}'),
                _IconText(Icons.access_time, _when(r.dateTime, now)),
                if (r.tableId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _chipGray,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_tableOf(table),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primary)),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Unassigned',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ViniiColors.amberSolid)),
                  ),
              ],
            ),
            if (r.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8F5EC)
                        : const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(4)),
                child: Text('" ${r.notes.trim()} "',
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: _secondary)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (showSeat)
                  _Btn(
                      label: 'Seat Now',
                      bg: ViniiColors.brandGreen,
                      fg: Colors.black,
                      onTap: onSeat),
                if (showAssign)
                  _Btn(
                      label: 'Assign Table',
                      bg: _orange,
                      fg: Colors.white,
                      onTap: onAssign),
                _Btn(
                    label: 'Edit',
                    bg: Colors.white,
                    fg: _primary,
                    border: _border,
                    onTap: onEdit),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline view
// ---------------------------------------------------------------------------

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.reservations,
    required this.tables,
    required this.selectedId,
    required this.now,
    required this.multiDay,
    required this.onSelect,
  });
  final List<OpsReservation> reservations;
  final List<OpsTable> tables;
  final String? selectedId;
  final DateTime now;
  final bool multiDay;
  final ValueChanged<OpsReservation> onSelect;

  static const _labelW = 110.0;
  static const _rowH = 46.0;

  @override
  Widget build(BuildContext context) {
    // Axis: 5 PM – 11 PM by default, widened to cover every booking.
    var startH = 17, endH = 23;
    for (final r in reservations) {
      final t = r.dateTime.hour + r.dateTime.minute / 60;
      if (t < startH) startH = t.floor();
      final end = t + _slot.inMinutes / 60;
      if (end > endH) endH = end.ceil().clamp(0, 24);
    }
    final hours = endH - startH;

    final byTable = <String?, List<OpsReservation>>{};
    for (final r in reservations) {
      byTable.putIfAbsent(r.tableId, () => []).add(r);
    }
    final rows = <(String, String, List<OpsReservation>)>[
      if (byTable.containsKey(null)) ('Unassigned', '', byTable[null]!),
      for (final t in tables)
        (_tableName(t.label), '${t.seats} seats', byTable[t.id] ?? const []),
      // Bookings pointing at tables that no longer exist (one row per
      // table, so their blocks never overlap). The table id means nothing
      // to people, so the row reads "Removed table".
      for (final e in byTable.entries)
        if (e.key != null && !tables.any((t) => t.id == e.key))
          (_removedTable, '', e.value),
    ];

    final isToday = !multiDay &&
        reservations.isNotEmpty &&
        _day(reservations.first.dateTime) == _day(now);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border)),
      child: LayoutBuilder(builder: (context, c) {
        final width = c.maxWidth < 620 ? 620.0 : c.maxWidth;
        final trackW = width - _labelW - 16;
        final perMin = trackW / (hours * 60);
        double x(DateTime d) => ((d.hour - startH) * 60 + d.minute) * perMin;

        final body = SizedBox(
          width: width,
          child: Column(children: [
            // Hour axis
            SizedBox(
              height: 34,
              child: Row(children: [
                const SizedBox(
                  width: _labelW,
                  child: Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Text('TABLE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _muted)),
                  ),
                ),
                SizedBox(
                  width: trackW,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var h = 0; h <= hours; h++)
                      Positioned(
                        left: h * 60 * perMin - (h == hours ? 34 : 0),
                        top: 10,
                        child: Text(
                            formatClock(DateTime(2000, 1, 1, startH + h))
                                .replaceAll(':00', ''),
                            style: const TextStyle(
                                fontSize: 11, color: _secondary)),
                      ),
                  ]),
                ),
              ]),
            ),
            const Divider(height: 1, color: _border),
            for (final (label, sub, list) in rows)
              Container(
                height: _rowH,
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _chipGray))),
                child: Row(children: [
                  SizedBox(
                    width: _labelW,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: label == 'Unassigned' ||
                                            label == _removedTable
                                        ? ViniiColors.amberSolid
                                        : _primary)),
                            if (sub.isNotEmpty)
                              Text(sub,
                                  style: const TextStyle(
                                      fontSize: 10.5, color: _muted)),
                          ]),
                    ),
                  ),
                  SizedBox(
                    width: trackW,
                    height: _rowH,
                    child: Stack(clipBehavior: Clip.hardEdge, children: [
                      for (var h = 0; h <= hours; h++)
                        Positioned(
                            left: h * 60 * perMin,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 1, color: _chipGray)),
                      for (final r in list)
                        Positioned(
                          left: x(r.dateTime),
                          top: 6,
                          bottom: 6,
                          width: _slot.inMinutes * perMin - 2,
                          child: _TimelineBlock(
                            reservation: r,
                            now: now,
                            multiDay: multiDay,
                            selected: r.id == selectedId,
                            onTap: () => onSelect(r),
                          ),
                        ),
                      if (isToday && now.hour >= startH && now.hour < endH)
                        Positioned(
                            left: x(now),
                            top: 0,
                            bottom: 0,
                            child: Container(
                                width: 2, color: ViniiColors.redSolid)),
                    ]),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
          ]),
        );
        return c.maxWidth < 620
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: body)
            : body;
      }),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock(
      {required this.reservation,
      required this.now,
      required this.multiDay,
      required this.selected,
      required this.onTap});
  final OpsReservation reservation;
  final DateTime now;
  final bool multiDay;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final (bg, fg) = _statusColors(r.status);
    final time = multiDay
        ? '${_dayLabel(r.dateTime, now)} ${formatClock(r.dateTime)}'
        : formatClock(r.dateTime);
    return Tooltip(
      message: '${r.guestName} · ${r.guests} guests · '
          '${_when(r.dateTime, now)} · ${r.status.label}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: selected ? _green : fg.withValues(alpha: 0.35),
                  width: selected ? 2 : 1),
            ),
            alignment: Alignment.centerLeft,
            child: Text('${r.guestName} · ${r.guests}p · $time',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reservation detail panel
// ---------------------------------------------------------------------------

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.reservation,
    required this.tables,
    required this.reservations,
    required this.orders,
    required this.now,
    required this.onConfirm,
    required this.onSeat,
    required this.onComplete,
    required this.onReopen,
    required this.onReassign,
    required this.onNoShow,
    required this.onCancel,
    required this.onEdit,
  });
  final OpsReservation? reservation;
  final Map<String, OpsTable> tables;
  final List<OpsReservation> reservations;
  final List<OpsOrder> orders;
  final DateTime now;
  final ValueChanged<OpsReservation> onConfirm;
  final ValueChanged<OpsReservation> onSeat;
  final ValueChanged<OpsReservation> onComplete;
  final ValueChanged<OpsReservation> onReopen;
  final ValueChanged<OpsReservation> onReassign;
  final ValueChanged<OpsReservation> onNoShow;
  final ValueChanged<OpsReservation> onCancel;
  final ValueChanged<OpsReservation> onEdit;

  static const _sectionLabel = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: _muted);

  /// Other seated/completed bookings by the same phone number, and the
  /// average settled bill of the table they sat at (when one matches).
  (int, int?) _history(OpsReservation r) {
    final phone = _phoneDigits(r.phone);
    if (phone.isEmpty) return (0, null);
    final visits = reservations
        .where((o) =>
            o.id != r.id &&
            _phoneDigits(o.phone) == phone &&
            (o.status == ReservationStatus.seated ||
                o.status == ReservationStatus.completed))
        .toList();
    final spends = <int>[];
    for (final v in visits) {
      final label = v.tableId == null ? null : tables[v.tableId]?.label;
      if (label == null) continue;
      final from = v.dateTime.subtract(const Duration(hours: 1));
      final to = v.dateTime.add(const Duration(hours: 4));
      for (final o in orders) {
        if (o.status == OpsOrderStatus.settled &&
            o.tableLabel == label &&
            !o.createdAt.isBefore(from) &&
            o.createdAt.isBefore(to)) {
          spends.add(o.grandTotalMinor);
        }
      }
    }
    final avg = spends.isEmpty
        ? null
        : (spends.reduce((a, b) => a + b) / spends.length).round();
    return (visits.length, avg);
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border)),
      child: r == null
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text('Reservation Detail',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                  SizedBox(height: 40),
                  Center(
                    child: Text('Select a reservation to see its details.',
                        style: TextStyle(fontSize: 13, color: _muted)),
                  ),
                ])
          : _content(context, r),
    );
  }

  Widget _content(BuildContext context, OpsReservation r) {
    final table = r.tableId == null ? null : tables[r.tableId];
    final (visits, avgSpend) = _history(r);
    const divider = Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, color: _border));

    Widget kv(String k, Widget v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 13, color: _secondary)),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
          ]),
        );
    const kvStyle =
        TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary);

    final active = _isActive(r.status);
    final (primaryLabel, primaryAction) = switch (r.status) {
      ReservationStatus.pending => ('Confirm Reservation', onConfirm),
      ReservationStatus.confirmed => (
          r.tableId == null ? 'Assign Table & Seat' : 'Seat Now',
          onSeat
        ),
      ReservationStatus.seated => ('Mark Completed', onComplete),
      ReservationStatus.noShow || ReservationStatus.cancelled => (
          'Reopen as Pending',
          onReopen
        ),
      ReservationStatus.completed => ('', onComplete),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
          child: Text('Reservation Detail',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _primary)),
        ),
        _StatusPill(r.status),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: _chipGray, shape: BoxShape.circle),
          child: Text(r.initials,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.guestName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
            if (r.email.trim().isNotEmpty)
              Text(r.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _secondary)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text('Phone: ${r.phone}',
          style: const TextStyle(fontSize: 13, color: _primary)),
      divider,
      const Text('BOOKING INFORMATION', style: _sectionLabel),
      kv('Date & Time', Text(_when(r.dateTime, now), style: kvStyle)),
      kv('Party Size',
          Text('${r.guests} Guest${r.guests == 1 ? '' : 's'}', style: kvStyle)),
      kv(
          'Table Assigned',
          r.tableId == null
              ? const Text('Unassigned',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.amberSolid))
              : Text(
                  table == null
                      ? _unknownTable
                      : '${_tableName(table.label)} (${table.floor})',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22A55A)))),
      divider,
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _selTint, borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('GUEST HISTORY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _green)),
          const SizedBox(height: 6),
          Text(
              visits == 0
                  ? 'First visit'
                  : '$visits previous visit${visits == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
          if (avgSpend != null) ...[
            const SizedBox(height: 6),
            Text(
                'Average spend: ${formatInr(avgSpend / 100, decimals: 0)} per visit',
                style: const TextStyle(fontSize: 12, color: _secondary)),
          ],
        ]),
      ),
      divider,
      const Text('NOTES & REQUESTS', style: _sectionLabel),
      const SizedBox(height: 8),
      Text(r.notes.trim().isEmpty ? 'No special requests.' : r.notes.trim(),
          style: TextStyle(
              fontSize: 13,
              color: r.notes.trim().isEmpty ? _muted : _primary,
              height: 1.4)),
      divider,
      if (primaryLabel.isNotEmpty) ...[
        _Btn(
            label: primaryLabel,
            bg: ViniiColors.brandGreen,
            fg: Colors.black,
            height: 40,
            fontSize: 14,
            expand: true,
            onTap: () => primaryAction(r)),
        const SizedBox(height: 8),
      ],
      if (active) ...[
        _Btn(
            label: r.tableId == null ? 'Assign Table' : 'Reassign Table',
            bg: Colors.white,
            fg: _primary,
            border: _border,
            height: 40,
            fontSize: 14,
            expand: true,
            onTap: () => onReassign(r)),
        const SizedBox(height: 8),
      ],
      Row(children: [
        if (active) ...[
          Expanded(
            child: _Btn(
                label: 'Mark No-show',
                bg: Colors.white,
                fg: ViniiColors.redSolid,
                border: const Color(0xFFFCA5A5),
                height: 36,
                fontSize: 13,
                expand: true,
                onTap: () => onNoShow(r)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: _Btn(
              label: 'Edit Details',
              bg: Colors.white,
              fg: _primary,
              border: _border,
              height: 36,
              fontSize: 13,
              expand: true,
              onTap: () => onEdit(r)),
        ),
      ]),
      if (active) ...[
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => onCancel(r),
            style: TextButton.styleFrom(foregroundColor: ViniiColors.redSolid),
            child: const Text('Cancel Reservation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Table picker
// ---------------------------------------------------------------------------

class _TablePickerDialog extends StatelessWidget {
  const _TablePickerDialog({
    required this.reservation,
    required this.tables,
    required this.reservations,
    required this.now,
  });
  final OpsReservation reservation;
  final List<OpsTable> tables;
  final List<OpsReservation> reservations;
  final DateTime now;

  /// Another active booking on [t] whose slot overlaps this one.
  OpsReservation? _clash(OpsTable t) {
    final r = reservation;
    for (final o in reservations) {
      if (o.id == r.id || o.tableId != t.id) continue;
      if (!_isActive(o.status) && o.status != ReservationStatus.seated) {
        continue;
      }
      if (o.dateTime.difference(r.dateTime).abs() < _slot) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final fitting = tables.where((t) => t.seats >= r.guests).toList();
    return AlertDialog(
      title: Text(r.tableId == null ? 'Assign Table' : 'Reassign Table'),
      content: SizedBox(
        width: 460,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  '${r.guestName} · ${r.guests} guests · ${_when(r.dateTime, now)}',
                  style: const TextStyle(fontSize: 13, color: _secondary)),
              const SizedBox(height: 4),
              Text('Tables seating ${r.guests} or more',
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 12),
              if (fitting.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No table is large enough for this party.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _secondary)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: fitting.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final t = fitting[i];
                      final clash = _clash(t);
                      final current = t.id == r.tableId;
                      return Material(
                        color: current ? _selTint : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: current
                              ? null
                              : () => Navigator.pop(context, t.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: current ? _selBorder : _border)),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${_tableName(t.label)}${current ? '  (current)' : ''}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _primary)),
                                      Text('${t.floor} · ${t.seats} seats',
                                          style: const TextStyle(
                                              fontSize: 12, color: _secondary)),
                                      if (clash != null)
                                        Text(
                                            'Booked ${formatClock(clash.dateTime)} by ${clash.guestName}',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: ViniiColors.amberSolid)),
                                    ]),
                              ),
                              MasterStatusPill(t.status.label,
                                  tone: switch (t.status) {
                                    OpsTableStatus.available => PillTone.green,
                                    OpsTableStatus.occupied => PillTone.blue,
                                    OpsTableStatus.reserved => PillTone.amber,
                                    OpsTableStatus.billing => PillTone.purple,
                                    OpsTableStatus.cleaning => PillTone.gray,
                                  }),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// New / Edit form
// ---------------------------------------------------------------------------

class _ReservationFormDialog extends StatefulWidget {
  const _ReservationFormDialog(
      {required this.ops,
      required this.tables,
      required this.existing,
      required this.now});
  final DriftOperationsStore ops;
  final List<OpsTable> tables;
  final OpsReservation? existing;
  final DateTime now;

  @override
  State<_ReservationFormDialog> createState() => _ReservationFormDialogState();
}

class _ReservationFormDialogState extends State<_ReservationFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _guests;
  late final TextEditingController _notes;
  late DateTime _date;
  late TimeOfDay _time;
  String? _tableId;
  late ReservationStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.guestName ?? '');
    final digits = e == null ? '' : _phoneDigits(e.phone);
    _phone = TextEditingController(
        text: e == null ? '' : (digits.length == 10 ? digits : e.phone));
    _email = TextEditingController(text: e?.email ?? '');
    _guests = TextEditingController(text: '${e?.guests ?? 2}');
    _notes = TextEditingController(text: e?.notes ?? '');
    final at = e?.dateTime ??
        DateTime(widget.now.year, widget.now.month, widget.now.day,
                widget.now.hour + 1)
            .add(const Duration(hours: 1));
    _date = _day(at);
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
    _tableId = e?.tableId;
    _status = e?.status ?? ReservationStatus.confirmed;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _guests, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _guestCount => int.tryParse(_guests.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final id =
        widget.existing?.id ?? 'RSV-${DateTime.now().millisecondsSinceEpoch}';
    final r = OpsReservation(
      id: id,
      guestName: _name.text.trim(),
      phone: _formatPhone(_phoneDigits(_phone.text)),
      email: _email.text.trim(),
      guests: _guestCount,
      dateTime: DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute),
      status: _status,
      tableId: _tableId,
      notes: _notes.text.trim(),
    );
    final ok = await runMasterAction(
        context, () => widget.ops.upsertReservation(r),
        success: widget.existing == null
            ? 'Reservation created for ${r.guestName}'
            : 'Reservation updated');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, id);
  }

  InputDecoration _dec(String label, {String? hint, Widget? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefix: prefix,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final guests = _guestCount;
    final tableOptions = widget.tables
        .where((t) => t.seats >= guests || t.id == _tableId)
        .toList();
    // A booking whose table was deleted keeps it until another is picked;
    // it reads "Removed table", never the table's id.
    final removedTableId = _tableId != null &&
            !widget.tables.any((t) => t.id == _tableId)
        ? _tableId
        : null;
    final dateText =
        '${_dayLabel(_date, widget.now)} (${_shortDate(_date)} ${_date.year})';
    final timeText =
        formatClock(DateTime(2000, 1, 1, _time.hour, _time.minute));

    Widget pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 420
            ? Column(children: [a, const SizedBox(height: 14), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ]));

    return AlertDialog(
      title: Text(
          widget.existing == null ? 'New Reservation' : 'Edit Reservation'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                decoration: _dec('Guest name *'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the guest name' : null,
              ),
              const SizedBox(height: 14),
              pair(
                TextFormField(
                  controller: _phone,
                  decoration: _dec('Phone *',
                      hint: '98765 43210', prefix: const Text('+91 ')),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  validator: (v) => _phoneDigits(v ?? '').length != 10
                      ? 'Enter a 10-digit mobile number'
                      : null,
                ),
                TextFormField(
                  controller: _email,
                  decoration: _dec('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(s)
                        ? null
                        : 'Enter a valid email';
                  },
                ),
              ),
              const SizedBox(height: 14),
              pair(
                TextFormField(
                  controller: _guests,
                  decoration: _dec('Party size *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 30) {
                      return 'Party size must be 1–30';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<ReservationStatus>(
                  initialValue: _status,
                  decoration: _dec('Status'),
                  items: [
                    for (final s in ReservationStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) => setState(() => _status = s ?? _status),
                ),
              ),
              const SizedBox(height: 14),
              pair(
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate:
                          _day(widget.now).subtract(const Duration(days: 365)),
                      lastDate: _day(widget.now).add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: _dec('Date *').copyWith(
                        suffixIcon: const Icon(Icons.calendar_today_outlined,
                            size: 18)),
                    child: Text(dateText, style: const TextStyle(fontSize: 14)),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                  child: InputDecorator(
                    decoration: _dec('Time *').copyWith(
                        suffixIcon: const Icon(Icons.access_time, size: 18)),
                    child: Text(timeText, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: ValueKey('table-$guests'),
                initialValue: _tableId,
                isExpanded: true,
                decoration: _dec('Table (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Unassigned')),
                  if (removedTableId != null)
                    DropdownMenuItem<String?>(
                        value: removedTableId,
                        child: const Text(_removedTable)),
                  for (final t in tableOptions)
                    DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(
                            '${_tableName(t.label)} · ${t.floor} · ${t.seats} seats · ${t.status.label}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _tableId = v),
                validator: (v) {
                  if (v == null) return null;
                  final t = widget.tables.where((t) => t.id == v).firstOrNull;
                  if (t != null && guests > 0 && t.seats < guests) {
                    return '${_tableName(t.label)} seats only ${t.seats}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                decoration: _dec('Notes & requests',
                    hint: 'e.g. Birthday, window seat preferred'),
                maxLines: 3,
                minLines: 2,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ViniiColors.brandGreen,
              foregroundColor: Colors.black),
          onPressed: _saving ? null : _save,
          child: Text(
              widget.existing == null ? 'Create Reservation' : 'Save Changes'),
        ),
      ],
    );
  }
}
