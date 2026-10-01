import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

/// Operations → QR Ordering (v1/operations/OPS-QR-ORDERING-DEFAULT.png).
/// Live KPIs over QR sessions, the active-session table and per-table QR
/// code configuration.
class OpsQrOrderingScreen extends StatefulWidget {
  const OpsQrOrderingScreen(
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
  State<OpsQrOrderingScreen> createState() => _OpsQrOrderingScreenState();
}

/// Public ordering link a table's printed code points to.
String _qrUrl(String token) => 'https://order.onelatur.com/t/$token';

class _OpsQrOrderingScreenState extends State<OpsQrOrderingScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _ticker;
  DateTime _now = DateTime.now();

  List<QrTableCode>? _codes;
  List<QrSession> _sessions = const [];
  List<OpsOrder> _orders = const [];

  @override
  void initState() {
    super.initState();
    final ops = widget.ops;
    _subs
      ..add(ops.watchQrCodes().listen((v) => setState(() => _codes = v)))
      ..add(ops
          .watchQrSessions(activeOnly: false)
          .listen((v) => setState(() => _sessions = v)))
      ..add(ops.watchOrders().listen((v) => setState(() => _orders = v)));
    _ticker = Timer.periodic(const Duration(seconds: 30),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _idNum(String id) =>
      int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  // ---- actions -----------------------------------------------------------

  Future<void> _generate() async {
    var created = 0;
    final ok = await runMasterAction(
        context, () async => created = await widget.ops.generateQrCodes());
    if (!ok || !mounted) return;
    showMasterNotice(
        context,
        created == 0
            ? 'All tables already have QR codes'
            : 'Created $created QR code${created == 1 ? '' : 's'}');
  }

  Future<void> _download(List<QrTableCode> codes) async {
    if (codes.isEmpty) {
      showMasterNotice(
          context, 'No QR codes yet — click Generate QR Codes first.');
      return;
    }
    // The table's name and its ordering link — the raw token is not a
    // column; it only lives inside the link.
    await exportCsv(context, fileName: 'qr_codes.csv', headers: const [
      'table',
      'url'
    ], rows: [
      for (final c in codes) [c.tableLabel, _qrUrl(c.token)]
    ]);
    if (!mounted) return;
    showMasterNotice(
        context,
        'The CSV lists each table\'s ordering link. Printable QR images '
        'need a QR-code package, which is not bundled yet.');
  }

  Future<void> _regenerate(List<QrTableCode> codes) async {
    if (codes.isEmpty) {
      showMasterNotice(
          context, 'No QR codes yet — click Generate QR Codes first.');
      return;
    }
    final ok = await confirmMasterAction(context,
        title: 'Regenerate all QR codes?',
        message: 'Every table gets a new link. Codes already printed and '
            'placed on tables will stop working until you replace them.',
        confirmLabel: 'Regenerate');
    if (!ok || !mounted) return;
    await runMasterAction(context, widget.ops.regenerateQrCodes,
        success: 'Regenerated ${codes.length} QR codes — reprint table cards');
  }

  Future<void> _toggle(QrTableCode c, bool enabled) => runMasterAction(
      context, () => widget.ops.setQrEnabled(c.tableId, enabled),
      success:
          'QR ordering ${enabled ? 'enabled' : 'disabled'} for ${c.tableLabel}');

  Future<void> _close(QrSession s) async {
    final ok = await confirmMasterAction(context,
        title: 'Close ${s.tableLabel}\'s session?',
        message: 'Guests at ${s.tableLabel} will no longer be able to add '
            'items from this QR session.',
        confirmLabel: 'Close Session');
    if (!ok || !mounted) return;
    await runMasterAction(context, () => widget.ops.closeQrSession(s.id),
        success: '${s.tableLabel} session closed');
  }

  void _viewCart(QrSession s) => showDialog<void>(
      context: context,
      builder: (_) => _CartDialog(
          ops: widget.ops, session: s, onOpenBilling: widget.onOpenBilling));

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final codes = _codes ?? const <QrTableCode>[];
    final today = _sessions.where((s) => _sameDay(s.startedAt, _now)).toList();
    final yesterdayDate = _now.subtract(const Duration(days: 1));
    final yesterday =
        _sessions.where((s) => _sameDay(s.startedAt, yesterdayDate)).length;
    final revenue = today.fold<int>(0, (a, s) => a + s.totalMinor);
    final withOrders = today.where((s) => s.totalMinor > 0).length;
    final avg = withOrders == 0 ? 0 : revenue ~/ withOrders;
    final dineIn = _orders
        .where((o) =>
            o.channel == OpsChannel.dineIn &&
            o.source != 'QR' &&
            _sameDay(o.createdAt, _now))
        .length;
    final adoption = today.isEmpty
        ? 0
        : (today.length * 100 / (today.length + dineIn)).round();
    final (String trend, Color trendFg, Color trendBg) = yesterday == 0
        ? (
            today.isEmpty ? 'No data' : 'New',
            ViniiColors.greenSolid,
            ViniiColors.greenTint
          )
        : () {
            final pct = ((today.length - yesterday) * 100 / yesterday).round();
            return pct >= 0
                ? ('+$pct%', ViniiColors.greenSolid, ViniiColors.greenTint)
                : ('$pct%', ViniiColors.redSolid, ViniiColors.redTint);
          }();

    final active = _sessions
        .where((s) => s.status != QrSessionStatus.closed)
        .toList()
      ..sort((a, b) => _idNum(a.id).compareTo(_idNum(b.id)));

    return MasterPage(children: [
      MasterPageHeader(
        title: 'QR Ordering',
        subtitle: 'Self-service menu and ordering',
        actions: [
          MasterButton(
              label: 'Generate QR Codes',
              icon: Icons.qr_code_2,
              kind: MasterButtonKind.primary,
              onPressed: _generate),
        ],
      ),
      const SizedBox(height: 4),
      MasterGrid(columns: 5, spacing: 12, minItemWidth: 160, children: [
        _Kpi(
            label: 'ACTIVE QR TABLES',
            value: '${codes.where((c) => c.enabled).length}',
            pill: 'Live',
            pillFg: ViniiColors.blueSolid,
            pillBg: ViniiColors.blueTint),
        _Kpi(
            label: 'ORDERS VIA QR TODAY',
            value: '${today.length}',
            pill: trend,
            pillFg: trendFg,
            pillBg: trendBg),
        _Kpi(
            label: 'REVENUE VIA QR',
            value: formatInr(revenue / 100, decimals: 0),
            pill: 'Today',
            pillFg: ViniiColors.greenSolid,
            pillBg: ViniiColors.greenTint),
        _Kpi(
            label: 'AVG ORDER VALUE',
            value: formatInr(avg / 100, decimals: 0),
            pill: 'Average',
            pillFg: ViniiColors.textSecondaryLight,
            pillBg: ViniiColors.grayTint),
        _Kpi(
            label: 'QR ADOPTION RATE',
            value: '$adoption%',
            pill: 'Target 50%',
            pillFg: ViniiColors.amberSolid,
            pillBg: ViniiColors.amberTint),
      ]),
      const SizedBox(height: 32),
      MasterCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Active QR Sessions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 16),
          _SessionTable(
              sessions: active, onViewCart: _viewCart, onClose: _close),
        ]),
      ),
      const SizedBox(height: 24),
      MasterCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('QR Code Configuration',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.textPrimaryLight)),
                    SizedBox(height: 4),
                    Text('Manage and download QR codes for physical tables',
                        style: TextStyle(
                            fontSize: 13,
                            color: ViniiColors.textSecondaryLight)),
                  ]),
              Wrap(spacing: 10, runSpacing: 8, children: [
                MasterButton(
                    label: 'Download All QR Codes',
                    onPressed: () => _download(codes)),
                _GreyButton(
                    label: 'Regenerate', onTap: () => _regenerate(codes)),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          if (_codes == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (codes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Text(
                  'No QR codes yet — click Generate QR Codes to create one per table.',
                  style: MasterStyle.muted),
            )
          else
            MasterGrid(columns: 3, spacing: 16, minItemWidth: 270, children: [
              for (final c in codes)
                _CodeTile(
                    code: c,
                    scanned: _scannedLabel(c.lastScannedAt),
                    onToggle: (v) => _toggle(c, v)),
            ]),
        ]),
      ),
    ]);
  }

  String _scannedLabel(DateTime? at) {
    if (at == null || !_sameDay(at, _now)) return 'Never scanned today';
    final m = _now.difference(at).inMinutes;
    if (m < 1) return 'Scanned just now';
    if (m < 60) return 'Scanned ${m}m ago';
    return 'Scanned ${m ~/ 60}h ago';
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _Kpi extends StatelessWidget {
  const _Kpi(
      {required this.label,
      required this.value,
      required this.pill,
      required this.pillFg,
      required this.pillBg});
  final String label;
  final String value;
  final String pill;
  final Color pillFg;
  final Color pillBg;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: ViniiColors.textPrimaryLight)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: pillBg, borderRadius: BorderRadius.circular(3)),
              child: Text(pill,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pillFg)),
            ),
          ]),
        ]),
      );
}

class _GreyButton extends StatelessWidget {
  const _GreyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
                widthFactor: 1,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: ViniiColors.textPrimaryLight))),
          ),
        ),
      );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(
      {required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Material(
        color: primary ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: primary
                        ? ViniiColors.brandGreen
                        : MasterStyle.cardBorder)),
            child: Align(
                widthFactor: 1,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                        color: primary
                            ? const Color(0xFF14532D)
                            : ViniiColors.textPrimaryLight))),
          ),
        ),
      );
}

class _SessionPill extends StatelessWidget {
  const _SessionPill(this.status);
  final QrSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      QrSessionStatus.ordering => (
          ViniiColors.amberSolid,
          ViniiColors.amberTint
        ),
      QrSessionStatus.paymentPending => (
          const Color(0xFF9333EA),
          const Color(0xFFF3E8FF)
        ),
      QrSessionStatus.browsing => (ViniiColors.blueSolid, ViniiColors.blueTint),
      QrSessionStatus.completed => (
          ViniiColors.greenSolid,
          ViniiColors.greenTint
        ),
      QrSessionStatus.closed => (ViniiColors.graySolid, ViniiColors.grayTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(status.label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SessionTable extends StatelessWidget {
  const _SessionTable(
      {required this.sessions,
      required this.onViewCart,
      required this.onClose});
  final List<QrSession> sessions;
  final ValueChanged<QrSession> onViewCart;
  final ValueChanged<QrSession> onClose;

  static const _flex = [8, 7, 11, 11, 11, 15, 25];
  static const _headers = [
    'Table',
    'Guests',
    'Session Start',
    'Items Ordered',
    'Current Total',
    'Status',
    'Actions'
  ];
  static const _minWidth = 900.0;

  Widget _line(List<Widget> cells) => Row(children: [
        for (var i = 0; i < _flex.length; i++)
          Expanded(
            flex: _flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                  alignment: i == _flex.length - 1
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: cells[i]),
            ),
          ),
      ]);

  Widget _text(String s, {bool bold = false}) => Text(s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: bold
              ? ViniiColors.textPrimaryLight
              : ViniiColors.textSecondaryLight));

  @override
  Widget build(BuildContext context) {
    final table =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: _line([
          for (final h in _headers)
            Text(h,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
        ]),
      ),
      if (sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
              child: Text('No active QR sessions right now.',
                  style: MasterStyle.muted)),
        ),
      for (final s in sessions)
        Container(
          height: 51,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
          child: _line([
            _text(s.tableLabel, bold: true),
            _text('${s.guests}'),
            _text(formatClock(s.startedAt)),
            _text('${s.itemCount} item${s.itemCount == 1 ? '' : 's'}'),
            _text(formatInr(s.totalMinor / 100, decimals: 0), bold: true),
            _SessionPill(s.status),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _SmallButton(label: 'View Cart', onTap: () => onViewCart(s)),
                const SizedBox(width: 8),
                _SmallButton(
                    label: 'Close Session',
                    primary: true,
                    onTap: () => onClose(s)),
              ]),
            ),
          ]),
        ),
    ]);
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= _minWidth
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: _minWidth, child: table)),
    );
  }
}

class _CodeTile extends StatelessWidget {
  const _CodeTile(
      {required this.code, required this.scanned, required this.onToggle});
  final QrTableCode code;
  final String scanned;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Tooltip(
            message: _qrUrl(code.token),
            child: Container(
              width: 112,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MasterStyle.cardBorder),
              ),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: MasterStyle.cardBorder)),
                padding: const EdgeInsets.all(12),
                child: Opacity(
                  opacity: code.enabled ? 1 : 0.35,
                  child: CustomPaint(painter: _QrPainter(code.token)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(code.tableLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ViniiColors.textPrimaryLight)),
                    const SizedBox(height: 2),
                    Text(scanned,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: ViniiColors.textMutedLight)),
                    const Spacer(),
                    Row(children: [
                      const Text('Status',
                          style: TextStyle(
                              fontSize: 12,
                              color: ViniiColors.textSecondaryLight)),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 24,
                        child: FittedBox(
                          child: Switch(
                            value: code.enabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: ViniiColors.greenSolid,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFD1D5DB),
                            trackOutlineColor: const WidgetStatePropertyAll(
                                Colors.transparent),
                            onChanged: onToggle,
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      );
}

/// QR-like placeholder: the design's five-block mark (corners + centre)
/// with the remaining cells filled from a hash of the table's token, so
/// each code — and each regeneration — looks different.
class _QrPainter extends CustomPainter {
  _QrPainter(this.token) : _hash = _fnv(token);
  final String token;
  final int _hash;

  static int _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111827);
    final side = size.shortestSide;
    final cell = side / 3;
    final block = cell * 0.62;
    final inset = (cell - block) / 2;
    // Fixed blocks: four corners + centre.
    for (final (cx, cy) in const [(0, 0), (2, 0), (0, 2), (2, 2), (1, 1)]) {
      canvas.drawRect(
          Rect.fromLTWH(cx * cell + inset, cy * cell + inset, block, block),
          paint);
    }
    // Edge-midpoint cells: 2×2 dots each, driven by 16 hash bits.
    final dot = block / 2;
    var bit = 0;
    for (final (cx, cy) in const [(1, 0), (0, 1), (2, 1), (1, 2)]) {
      for (var i = 0; i < 4; i++) {
        if ((_hash >> bit++) & 1 == 1) {
          canvas.drawRect(
              Rect.fromLTWH(cx * cell + inset + (i % 2) * dot,
                  cy * cell + inset + (i ~/ 2) * dot, dot, dot),
              paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.token != token;
}

class _CartDialog extends StatelessWidget {
  const _CartDialog(
      {required this.ops, required this.session, this.onOpenBilling});
  final DriftOperationsStore ops;
  final QrSession session;
  final ValueChanged<String>? onOpenBilling;

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _money(String k, int minor, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(formatInr(minor / 100, decimals: 0),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = session;
    return AlertDialog(
      title: Row(children: [
        Expanded(child: Text('${s.tableLabel} · Cart')),
        _SessionPill(s.status),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _kv('Table', s.tableLabel),
                _kv('Guests', '${s.guests}'),
                _kv('Started', formatClock(s.startedAt)),
                _kv('Items ordered', '${s.itemCount}'),
                _kv('Current total',
                    formatInr(s.totalMinor / 100, decimals: 0)),
                const Divider(height: 24),
                if (s.orderId == null)
                  const MasterBanner(
                      tone: PillTone.blue,
                      message: 'No POS order is linked to this session yet — '
                          'the guest is still building the cart on their '
                          'phone. Line items appear here once it is sent '
                          'to the kitchen.')
                else
                  FutureBuilder<OpsOrder?>(
                    future: ops.getOrder(s.orderId!),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return MasterBanner(
                            tone: PillTone.red,
                            message: 'Could not load the linked order: '
                                '${friendlyError(snap.error!)}');
                      }
                      final o = snap.data;
                      if (o == null) {
                        return const MasterBanner(
                            tone: PillTone.amber,
                            message: 'The linked order is not on this device.');
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(o.number,
                                style: MasterStyle.sectionTitle),
                            const SizedBox(height: 8),
                            for (final l in o.lines)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Icon(Icons.circle,
                                      size: 8,
                                      color: l.isVeg
                                          ? ViniiColors.greenSolid
                                          : ViniiColors.redSolid),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text('${l.name} × ${l.quantity}',
                                          style: MasterStyle.body)),
                                  Text(
                                      formatInr(l.totalMinor / 100,
                                          decimals: 0),
                                      style: MasterStyle.body),
                                ]),
                              ),
                            const Divider(height: 20),
                            _money('Subtotal', o.subtotalMinor),
                            if (o.discountMinor > 0)
                              _money('Discount', -o.discountMinor),
                            _money('Tax', o.taxMinor),
                            _money('Grand total', o.grandTotalMinor,
                                bold: true),
                          ]);
                    },
                  ),
              ]),
        ),
      ),
      actions: [
        if (s.orderId != null && onOpenBilling != null)
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                onOpenBilling!(s.orderId!);
              },
              child: const Text('Open in POS Billing')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}
