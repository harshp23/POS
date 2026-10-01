import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

part 'ops_kitchen_alerts.dart';
part 'ops_kitchen_kds.dart';

/// Operations → "KOT / Kitchen". One sidebar item, two views over the
/// same POS kitchen_tickets:
///  * KOT Cards  — v1/operations/OPS-KITCHEN-KOT-DEFAULT.png
///  * Kitchen Display (KDS board) — OPS-KITCHEN-DISPLAY-KDS-DEFAULT.png
/// The view switch sits top-right of each view's header.
class OpsKitchenScreen extends StatefulWidget {
  const OpsKitchenScreen(
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
  State<OpsKitchenScreen> createState() => _OpsKitchenScreenState();
}

enum _KitchenView { kot, kds }

enum _KotFilter { all, newTicket, preparing, ready }

enum _SummaryTab { category, item, overall }

/// Colours sampled from the two kitchen PNGs.
class _Kc {
  static const lime = Color(0xFF76EC00);
  static const pageBg = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const ink = ViniiColors.textPrimaryLight;
  static const sub = Color(0xFF6B7280);
  static const label = Color(0xFF374151);
  static const blue = Color(0xFF2563EB);
  static const amber = Color(0xFFD97706);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const qtyBg = Color(0xFFF3F4F6);
  static const notesBg = Color(0xFFFFFBEB);
  static const notesBorder = Color(0xFFFCEFC7);
  static const progressGreen = Color(0xFF01BC6B);
  static const textMuted = Color(0xFF9CA3AF);
}

/// Tint / border / foreground triple for pills, tiles and column heads.
class _Tone {
  const _Tone(this.bg, this.border, this.fg);
  final Color bg;
  final Color border;
  final Color fg;

  static const blue = _Tone(Color(0xFFEFF6FF), Color(0xFFBFDBFE), _Kc.blue);
  static const amber = _Tone(Color(0xFFFFFBEB), Color(0xFFFDE68A), _Kc.amber);
  static const green = _Tone(Color(0xFFF0FDF4), Color(0xFFBBF7D0), _Kc.green);
  static const mint = _Tone(Color(0xFFECFDF5), Color(0xFFA7F3D0), _Kc.green);
  static const red = _Tone(Color(0xFFFEF2F2), Color(0xFFFECACA), _Kc.red);
  static const gray = _Tone(Color(0xFFF4F4F5), Color(0xFFE4E4E7), _Kc.sub);
  static const purple =
      _Tone(Color(0xFFF5F3FF), Color(0xFFDDD6FE), Color(0xFF7C3AED));
  static const orange =
      _Tone(Color(0xFFFFF7ED), Color(0xFFFED7AA), Color(0xFFEA580C));
}

class _OpsKitchenScreenState extends State<OpsKitchenScreen> {
  // Remembered across rebuilds of the screen for the life of the app.
  static _KitchenView _savedView = _KitchenView.kot;

  _KitchenView _view = _savedView;
  _KotFilter _filter = _KotFilter.all;
  String? _station; // null = All Stations
  _SummaryTab _summaryTab = _SummaryTab.category;
  bool _summaryCollapsed = false;
  KdsAlertSettings _alerts = const KdsAlertSettings();
  List<KitchenStation> _stations = defaultKitchenStations;

  StreamSubscription<List<OpsKot>>? _sub;
  StreamSubscription<KdsAlertSettings>? _alertSub;
  StreamSubscription<List<KitchenStation>>? _stationSub;
  StreamSubscription<List<OpsKot>>? _cancelSub;
  List<OpsKot>? _kots;

  /// Tickets whose order was cancelled while the kitchen still had them.
  List<OpsKot> _cancelled = const [];
  Object? _error;
  DateTime _now = DateTime.now();
  Timer? _tick;
  Timer? _blink;
  bool _blinkOn = true;
  bool _primed = false;
  final Map<String, (OpsKotStatus, bool)> _known = {};
  final Set<String> _delayAlerted = {};
  final Map<String, DateTime> _flashUntil = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _sub = widget.ops.watchKots().listen(_onKots, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
    _alertSub = widget.ops.watchAlertSettings().listen((a) {
      if (mounted) setState(() => _alerts = a);
    }, onError: (_) {});
    _cancelSub = widget.ops.watchCancelledKots().listen((c) {
      if (mounted) setState(() => _cancelled = c);
    }, onError: (_) {});
    _stationSub = widget.ops.watchKitchenStations().listen((st) {
      if (!mounted) return;
      setState(() {
        _stations = st;
        if (_station != null && !_activeStations.contains(_station)) {
          _station = null;
        }
      });
      _checkDelayed();
    }, onError: (_) {});
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _checkDelayed();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _alertSub?.cancel();
    _stationSub?.cancel();
    _cancelSub?.cancel();
    _tick?.cancel();
    _blink?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data + alerts
  // ---------------------------------------------------------------------

  void _onKots(List<OpsKot> list) {
    if (!mounted) return;
    final newIds = <String>[], priorityIds = <String>[], readyIds = <String>[];
    for (final k in list) {
      final prev = _known[k.ticketId];
      _known[k.ticketId] = (k.status, k.urgent);
      if (!_primed) continue;
      if (prev == null) {
        if (k.status == OpsKotStatus.newTicket) newIds.add(k.ticketId);
        if (k.urgent && k.status != OpsKotStatus.completed) {
          priorityIds.add(k.ticketId);
        }
        continue;
      }
      if (k.urgent && !prev.$2 && k.status != OpsKotStatus.completed) {
        priorityIds.add(k.ticketId);
      }
      if (k.status == OpsKotStatus.ready && prev.$1 != OpsKotStatus.ready) {
        readyIds.add(k.ticketId);
      }
    }
    setState(() {
      _kots = list;
      _error = null;
      _now = DateTime.now();
    });
    if (!_primed) {
      _primed = true;
      for (final k in list) {
        if (_isDelayed(k)) _delayAlerted.add(k.ticketId);
      }
      return;
    }
    _raise([
      if (_alerts.newOrder) ...newIds,
      if (_alerts.priority) ...priorityIds,
      if (_alerts.ready) ...readyIds,
    ]);
    _checkDelayed();
  }

  List<String> get _activeStations => [
        for (final s in _stations)
          if (s.active) s.name
      ];

  KitchenStation? _stationConfig(String name) {
    for (final s in _stations) {
      if (s.name.toLowerCase() == name.toLowerCase()) return s;
    }
    return null;
  }

  /// SLA of one station (its configured target, else the POS default).
  int _targetOf(String station) =>
      _stationConfig(station)?.targetMinutes ?? OpsKot.delayedAfterMinutes;

  /// A ticket is late once it passes the target of its slowest station
  /// (or of [station] when the KDS is filtered to one station).
  int _thresholdOf(OpsKot k, [String? station]) {
    if (station != null) return _targetOf(station);
    var t = 0;
    for (final l in k.order.lines) {
      final x = _targetOf(l.station);
      if (x > t) t = x;
    }
    return t == 0 ? OpsKot.delayedAfterMinutes : t;
  }

  bool _isDelayed(OpsKot k, [String? station]) =>
      (k.status == OpsKotStatus.newTicket ||
          k.status == OpsKotStatus.preparing) &&
      k.ageMinutes(_now) >= _thresholdOf(k, station);

  void _checkDelayed() {
    if (!_primed) return;
    final late = <String>[
      for (final k in _kots ?? const <OpsKot>[])
        if (_isDelayed(k) && _delayAlerted.add(k.ticketId)) k.ticketId
    ];
    if (_alerts.delayed) _raise(late);
  }

  /// Sounds the on-device tone (when sounds are on) and flashes the cards.
  void _raise(List<String> ids) {
    if (ids.isEmpty) return;
    _playTone(_alerts);
    final until = DateTime.now().add(const Duration(seconds: 8));
    setState(() {
      for (final id in ids) {
        _flashUntil[id] = until;
      }
    });
    _blink ??= Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _flashUntil.removeWhere((_, u) => now.isAfter(u));
        _blinkOn = !_blinkOn;
        if (_flashUntil.isEmpty) {
          _blinkOn = true;
          t.cancel();
          _blink = null;
        }
      });
    });
  }

  bool _flashing(String ticketId) =>
      _flashUntil.containsKey(ticketId) && _blinkOn;

  Future<void> _openAlertSettings() async {
    final s = await _showAlertSettings(context, _alerts);
    if (s == null || !mounted) return;
    setState(() => _alerts = s);
    await runMasterAction(context, () => widget.ops.saveAlertSettings(s),
        success: s.soundsEnabled
            ? 'Sound & alert settings saved'
            : 'Kitchen sounds turned off');
  }

  Future<void> _openStationSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StationsDialog(
        ops: widget.ops,
        stations: _stations,
        dishes: (widget.master ?? DriftMasterStore(widget.ops.db))
            .watchDishes(),
      ),
    );
    if (saved == true && mounted) {
      showMasterNotice(context, 'Kitchen stations saved');
    }
  }

  void _selectStation(String? station) => setState(() => _station = station);

  void _selectSummaryTab(_SummaryTab t) => setState(() => _summaryTab = t);

  void _toggleSummary() =>
      setState(() => _summaryCollapsed = !_summaryCollapsed);

  void _setView(_KitchenView v) {
    _savedView = v;
    setState(() => _view = v);
  }

  // ---------------------------------------------------------------------
  // Store actions
  // ---------------------------------------------------------------------

  Future<void> _advance(OpsKot k) async {
    if (!_busy.add(k.ticketId)) return;
    setState(() {});
    final msg = switch (k.status) {
      OpsKotStatus.newTicket => '${k.label} — cooking started',
      OpsKotStatus.preparing => '${k.label} marked ready',
      OpsKotStatus.ready => '${k.label} served & cleared',
      OpsKotStatus.completed => null,
    };
    await runMasterAction(context, () async {
      await widget.ops.advanceKot(k.ticketId);
    }, success: msg);
    if (mounted) setState(() => _busy.remove(k.ticketId));
  }

  /// KDS "Ready": confirms first when some items are still unticked.
  Future<void> _markReady(OpsKot k) async {
    final pending = k.order.lines.where((l) => !l.done).length;
    if (pending > 0) {
      final ok = await confirmMasterAction(context,
          title: 'Mark ${k.label} ready?',
          message: '$pending item${pending == 1 ? '' : 's'} not ticked done '
              'yet. Marking the ticket ready ticks every item as done.',
          confirmLabel: 'Mark Ready',
          destructive: false);
      if (!ok || !mounted) return;
    }
    await _advance(k);
  }

  Future<void> _setLineDone(OpsKot k, OpsOrderLine l, bool done) =>
      runMasterAction(context, () async {
        await widget.ops.setLineDone(k.order.id, l.itemId, done);
      });

  Future<void> _toggleUrgent(OpsKot k) => runMasterAction(context, () async {
        await widget.ops.setKotUrgent(k.ticketId, !k.urgent);
      },
          success: k.urgent
              ? '${k.label} no longer urgent'
              : '${k.label} marked urgent');

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _Kc.pageBg,
        child: _view == _KitchenView.kot ? _buildKot() : _buildKds(),
      );

  Widget _buildKds() => _KdsView(host: this);

  Widget _viewSwitch() => _ViewSwitch(value: _view, onChanged: _setView);

  Widget _statusBody() {
    if (_error != null) {
      return MasterBanner(
          message: 'Could not load kitchen tickets: ${friendlyError(_error!)}',
          tone: PillTone.red);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// Cancelled in the last two hours — long enough for the kitchen to see
  /// it and stop, without keeping the day's cancellations on screen.
  List<OpsKot> get _recentlyCancelled => [
        for (final k in _cancelled)
          if (_now.difference(k.cancelledAt ?? k.createdAt) <
              const Duration(hours: 2))
            k
      ];

  // ---- KOT Cards view ----------------------------------------------------

  Widget _buildKot() {
    final open = [
      for (final k in _kots ?? const <OpsKot>[])
        if (k.status != OpsKotStatus.completed) k
    ];
    int count(OpsKotStatus s) => open.where((k) => k.status == s).length;
    final shown = switch (_filter) {
      _KotFilter.all => open,
      _KotFilter.newTicket =>
        open.where((k) => k.status == OpsKotStatus.newTicket).toList(),
      _KotFilter.preparing =>
        open.where((k) => k.status == OpsKotStatus.preparing).toList(),
      _KotFilter.ready =>
        open.where((k) => k.status == OpsKotStatus.ready).toList(),
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _Kc.border))),
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
                    Text('Kitchen Orders (KOT)',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: _Kc.ink)),
                    SizedBox(height: 4),
                    Text('Live kitchen display & preparation tracking',
                        style: TextStyle(fontSize: 14, color: _Kc.sub)),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _viewSwitch(),
                    const _LivePill(),
                    _AlertsButton(
                        enabled: _alerts.soundsEnabled,
                        onTap: _openAlertSettings),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (f, label) in [
                    (_KotFilter.all, 'All (${open.length})'),
                    (
                      _KotFilter.newTicket,
                      'New (${count(OpsKotStatus.newTicket)})'
                    ),
                    (
                      _KotFilter.preparing,
                      'Preparing (${count(OpsKotStatus.preparing)})'
                    ),
                    (_KotFilter.ready, 'Ready (${count(OpsKotStatus.ready)})'),
                  ])
                    _PillTab(
                        label: label,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f)),
                ]),
                if (_recentlyCancelled.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _CancelledBanner(kots: _recentlyCancelled),
                ],
                const SizedBox(height: 24),
                if (_kots == null)
                  _statusBody()
                else if (shown.isEmpty)
                  _EmptyCard(
                      message: open.isEmpty
                          ? 'No open kitchen tickets — new orders sent to the '
                              'kitchen appear here.'
                          : 'No tickets in this state.')
                else
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 960
                        ? 3
                        : c.maxWidth >= 600
                            ? 2
                            : 1;
                    final w = (c.maxWidth - (cols - 1) * 20) / cols;
                    return Wrap(spacing: 20, runSpacing: 20, children: [
                      for (final k in shown)
                        SizedBox(width: w, child: _kotCard(k)),
                    ]);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotCard(OpsKot k) {
    final delayed = _isDelayed(k);
    final age = k.ageMinutes(_now);
    final (_Tone tone, String state) = delayed
        ? (_Tone.red, 'Delayed')
        : switch (k.status) {
            OpsKotStatus.newTicket => (_Tone.blue, 'New'),
            OpsKotStatus.preparing => (_Tone.amber, 'Preparing'),
            OpsKotStatus.ready => (_Tone.mint, 'Ready'),
            OpsKotStatus.completed => (_Tone.gray, 'Served'),
          };
    final o = k.order;
    final subtitle = [
      o.number,
      o.channel.label,
      if (o.channel == OpsChannel.dineIn && o.tableLabel != null)
        _tableText(o.tableLabel!),
    ].join(' • ');
    final notes = k.notes.trim().isNotEmpty ? k.notes.trim() : o.notes.trim();
    final (String action, Color bg, Color fg) = switch (k.status) {
      OpsKotStatus.newTicket => ('Start Cooking', _Kc.blue, Colors.white),
      OpsKotStatus.preparing => ('Mark as Ready', _Kc.amber, Colors.white),
      _ => ('Done / Clear', _Kc.lime, _Kc.ink),
    };
    final flash = _flashing(k.ticketId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: flash ? _Kc.lime : _Kc.border, width: flash ? 2.5 : 1),
        boxShadow: flash
            ? [
                BoxShadow(
                    color: _Kc.lime.withValues(alpha: 0.45), blurRadius: 14)
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
            decoration: BoxDecoration(
                color: tone.bg,
                border: const Border(bottom: BorderSide(color: _Kc.border))),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(k.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _Kc.ink)),
                      ),
                      if (k.urgent) ...[
                        const SizedBox(width: 6),
                        const _UrgentTag(),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _Kc.sub)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tone.fg)),
                child: Text('$state (${_ageText(age)})',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tone.fg)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(children: [
              for (final l in o.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(l.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _Kc.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: _Kc.qtyBg,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('x${l.quantity}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _Kc.ink)),
                    ),
                  ]),
                ),
            ]),
          ),
          if (notes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                  color: _Kc.notesBg,
                  border: Border.symmetric(
                      horizontal: BorderSide(color: _Kc.notesBorder))),
              child: Row(children: [
                const Icon(Icons.warning_rounded, size: 13, color: _Kc.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Notes: $notes',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _Kc.amber)),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: _SolidButton(
              label: action,
              bg: bg,
              fg: fg,
              height: 36,
              fontSize: 13,
              busy: _busy.contains(k.ticketId),
              onPressed: () => _advance(k),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Shared helpers & small widgets
// -------------------------------------------------------------------------

/// "T4" → "Table 4"; other labels unchanged.
String _tableText(String label) {
  final m = RegExp(r'^T(\d+)$').firstMatch(label.trim());
  return m == null ? label : 'Table ${m.group(1)}';
}

/// 12 → "12m", 75 → "1h 15m".
String _ageText(int minutes) {
  if (minutes < 0) return '0m';
  if (minutes < 60) return '${minutes}m';
  final m = minutes % 60;
  return m == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${m}m';
}

class _PillTab extends StatelessWidget {
  const _PillTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _Kc.lime : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: selected ? _Kc.lime : _Kc.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? _Kc.ink : _Kc.label)),
          ),
        ),
      );
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onPressed,
    this.height = 32,
    this.fontSize = 12,
    this.busy = false,
    this.radius = 8,
    this.padding = EdgeInsets.zero,
  });
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final bool busy;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: busy ? bg.withValues(alpha: 0.6) : bg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: busy ? null : onPressed,
          child: Container(
            height: height,
            padding: padding,
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: fg)),
          ),
        ),
      );
}

class _UrgentTag extends StatelessWidget {
  const _UrgentTag();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: _Kc.red, borderRadius: BorderRadius.circular(4)),
        child: const Text('URGENT',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white)),
      );
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: _Tone.red.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _Tone.red.border)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text('LIVE',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _Kc.red)),
        ]),
      );
}

/// "Kitchen Orders (KOT)" / "Kitchen Display" segmented switch.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.value, required this.onChanged});
  final _KitchenView value;
  final ValueChanged<_KitchenView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Kc.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (v, icon, label) in [
            (_KitchenView.kot, Icons.view_agenda_outlined, 'KOT Cards'),
            (_KitchenView.kds, Icons.view_kanban_outlined, 'Kitchen Display'),
          ])
            Material(
              color: value == v ? _Kc.qtyBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: value == v ? null : () => onChanged(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 14, color: value == v ? _Kc.ink : _Kc.sub),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                value == v ? FontWeight.w600 : FontWeight.w500,
                            color: value == v ? _Kc.ink : _Kc.sub)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

/// "Order cancelled" notice for tickets the kitchen may still be working on.
class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.kots});
  final List<OpsKot> kots;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.block, size: 16, color: _Kc.red),
            SizedBox(width: 6),
            Text('Order cancelled — stop preparing',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _Kc.red)),
          ]),
          const SizedBox(height: 6),
          for (final k in kots)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '${k.label} · ${k.order.number}'
                  '${k.order.tableLabel != null ? ' · ${_tableText(k.order.tableLabel!)}' : ''}'
                  ' — ${k.order.lines.map((l) => '${l.quantity}× ${l.name}').join(', ')}',
                  style: const TextStyle(fontSize: 12.5, color: _Kc.label)),
            ),
        ]),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _Kc.border)),
        child: Column(children: [
          const Icon(Icons.soup_kitchen_outlined, size: 32, color: _Kc.sub),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _Kc.sub)),
        ]),
      );
}
