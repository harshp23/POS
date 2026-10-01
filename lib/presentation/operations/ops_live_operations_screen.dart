import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../data/staff_repository.dart' show StaffRepository;
import '../../domain/inventory.dart';
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_order_dialogs.dart';
import 'ops_pickers.dart';

/// Operations → Live Operations ("Live Orders"): every order on the
/// floor, in the kitchen and on the road, with its live state derived
/// from the POS tables (orders, kitchen_tickets, payments) and deliveries.
class OpsLiveOperationsScreen extends StatefulWidget {
  const OpsLiveOperationsScreen(
      {super.key,
      required this.ops,
      this.master,
      this.focusOrderId,
      this.onOpenBilling,
      this.canVerifyPayments = false,
      this.canTakePayments = true,
      this.staff});
  final DriftOperationsStore ops;
  final DriftMasterStore? master;
  final String? focusOrderId;
  final ValueChanged<String>? onOpenBilling;

  /// The signed-in role may verify card / UPI payments (owner, restaurant
  /// admin, branch manager). False hides "Verify Payment".
  final bool canVerifyPayments;

  /// The role may collect money; false hides "Mark Paid & Complete".
  final bool canTakePayments;

  /// The staff list: the rider for "Out for Delivery" is picked from the
  /// active staff with delivery enabled. Without it (or when nobody has
  /// delivery enabled) the rider is typed, with the riders already used
  /// as suggestions.
  final StaffRepository? staff;

  @override
  State<OpsLiveOperationsScreen> createState() =>
      _OpsLiveOperationsScreenState();
}

// ---------------------------------------------------------------------------
// Live state
// ---------------------------------------------------------------------------

enum _Live { newOrder, preparing, ready, outForDelivery, completed, cancelled }

extension on _Live {
  String get label => switch (this) {
        _Live.newOrder => 'New',
        _Live.preparing => 'Preparing',
        _Live.ready => 'Ready',
        _Live.outForDelivery => 'Out for Delivery',
        _Live.completed => 'Completed',
        _Live.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        _Live.newOrder => _C.blue,
        _Live.preparing => _C.orange,
        _Live.ready => _C.green,
        _Live.outForDelivery => _C.indigo,
        _Live.completed => _C.gray,
        _Live.cancelled => _C.red,
      };

  Color get tint => switch (this) {
        _Live.newOrder => const Color(0xFFEFF6FF),
        _Live.preparing => const Color(0xFFFFF7ED),
        _Live.ready => const Color(0xFFF0FDF4),
        _Live.outForDelivery => const Color(0xFFEEF2FF),
        _Live.completed => const Color(0xFFF3F4F6),
        _Live.cancelled => const Color(0xFFFEF2F2),
      };

  bool get isActive => this != _Live.completed && this != _Live.cancelled;
}

class _C {
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFEA7A0C);
  static const green = Color(0xFF16A34A);
  static const indigo = Color(0xFF4F46E5);
  static const gray = Color(0xFF6B7280);
  static const red = Color(0xFFDC2626);
  static const border = Color(0xFFE5E7EB);
  static const pageBg = Color(0xFFF9FAFB);
  static const text = ViniiColors.textPrimaryLight;
  static const muted = Color(0xFF6B7280);
}

/// One order plus everything needed to render and act on its card.
class _OrderView {
  _OrderView(this.order, this.kots, this.delivery);
  final OpsOrder order;

  /// This order's tickets, newest first.
  final List<OpsKot> kots;
  final OpsDelivery? delivery;

  OpsKot? get latestKot => kots.isEmpty ? null : kots.first;
  bool get isDelivery => order.channel == OpsChannel.delivery;
  bool get settled => order.status == OpsOrderStatus.settled;
  bool get isPaid => order.paymentState == OrderPaymentState.paid;
  bool get pendingVerification =>
      order.paymentState == OrderPaymentState.pendingVerification;

  /// Short payment text for the card: Paid / Unpaid / "UPI · pending
  /// verification".
  String get paymentText => isPaid
      ? 'Paid'
      : pendingVerification
          ? order.paymentLabel
          : 'Unpaid';

  Color get paymentColor => isPaid
      ? _C.green
      : pendingVerification
          ? _C.orange
          : _C.red;

  _Live get state {
    final o = order;
    if (o.status == OpsOrderStatus.cancelled) return _Live.cancelled;
    final d = delivery;
    if (isDelivery && d != null) {
      if (d.status == DeliveryStatus.pickedUp ||
          d.status == DeliveryStatus.inTransit) {
        return _Live.outForDelivery;
      }
      if (d.status == DeliveryStatus.delivered) {
        // Delivered but still unpaid (cash on delivery) stays on the board.
        return settled ? _Live.completed : _Live.outForDelivery;
      }
    }
    final k = latestKot;
    if (settled && (k == null || k.status == OpsKotStatus.completed)) {
      return _Live.completed;
    }
    if (k == null) return _Live.newOrder;
    return switch (k.status) {
      OpsKotStatus.newTicket => _Live.newOrder,
      OpsKotStatus.preparing => _Live.preparing,
      OpsKotStatus.ready => _Live.ready,
      OpsKotStatus.completed =>
        isDelivery ? _Live.ready : _Live.completed, // delivery: awaiting rider
    };
  }

  /// "Table 4" for a "T4" label.
  static String tableName(String? label) {
    if (label == null || label.isEmpty) return 'Table';
    final m = RegExp(r'^T(\d+)$').firstMatch(label);
    return 'Table ${m == null ? label : m.group(1)}';
  }

  String get customer {
    final name = order.customerName.trim();
    if (name.isNotEmpty) return name;
    switch (order.channel) {
      case OpsChannel.dineIn:
        final g = order.guests;
        return g == null
            ? tableName(order.tableLabel)
            : '${tableName(order.tableLabel)} · $g guest${g == 1 ? '' : 's'}';
      case OpsChannel.delivery:
        final n = delivery?.customerName.trim() ?? '';
        return n.isEmpty ? 'Delivery Customer' : n;
      case OpsChannel.takeaway:
        return 'Walk-in';
    }
  }

  String get location => switch (order.channel) {
        OpsChannel.dineIn => tableName(order.tableLabel),
        OpsChannel.delivery => (delivery?.address.trim().isNotEmpty ?? false)
            ? delivery!.address.trim()
            : 'Address not set',
        OpsChannel.takeaway => 'Pickup Counter',
      };

  String get itemsLine {
    final n = order.lines.length;
    final names = order.lines.map((l) => l.name).join(', ');
    return '$n Item${n == 1 ? '' : 's'}${n == 0 ? '' : ' ($names)'}';
  }
}

String _ago(DateTime then, DateTime now) {
  final m = now.difference(then).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  if (m < 60 * 24) return '${m ~/ 60}h ago';
  return '${m ~/ (60 * 24)}d ago';
}

String _inr(int minor) => formatInr(minor / 100, decimals: 0);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class _OpsLiveOperationsScreenState extends State<OpsLiveOperationsScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _ticker;
  DateTime _now = DateTime.now();

  List<OpsOrder>? _orders;
  List<OpsKot> _kots = const [];
  List<OpsDelivery> _deliveries = const [];
  Object? _error;

  /// Filter chip: null = All (active orders), otherwise a live state.
  _Live? _filter;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(widget.ops.watchOrders().listen((v) => setState(() => _orders = v),
          onError: (Object e) => setState(() => _error = e)))
      ..add(widget.ops.watchKots().listen((v) => setState(() => _kots = v),
          onError: (Object e) => setState(() => _error = e)))
      ..add(widget.ops.watchDeliveries().listen(
          (v) => setState(() => _deliveries = v),
          onError: (Object e) => setState(() => _error = e)));
    _ticker = Timer.periodic(const Duration(seconds: 30),
        (_) => mounted ? setState(() => _now = DateTime.now()) : null);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    super.dispose();
  }

  List<_OrderView> _views() {
    final kotsBy = <String, List<OpsKot>>{};
    for (final k in _kots) {
      kotsBy.putIfAbsent(k.order.id, () => []).add(k);
    }
    for (final l in kotsBy.values) {
      l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    // Deliveries arrive newest first; keep the newest per order.
    final delBy = <String, OpsDelivery>{};
    for (final d in _deliveries) {
      delBy.putIfAbsent(d.orderId, () => d);
    }
    return [
      for (final o in _orders ?? const <OpsOrder>[])
        _OrderView(o, kotsBy[o.id] ?? const [], delBy[o.id]),
    ];
  }

  /// Completed / cancelled only count for today; active orders always.
  bool _visible(_OrderView v, _Live s) {
    if (s.isActive) return true;
    final when = v.order.settledAt ?? v.order.createdAt;
    return _sameDay(when, _now) || _sameDay(v.order.createdAt, _now);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
          child: Text('Could not load orders. ${friendlyError(error)}',
              style: const TextStyle(color: _C.red)));
    }
    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final views = _views();
    final byState = <_Live, List<_OrderView>>{
      for (final s in _Live.values) s: [],
    };
    for (final v in views) {
      final s = v.state;
      if (_visible(v, s)) byState[s]!.add(v);
    }
    // "All" = active orders plus those whose card / UPI payment still
    // waits for verification.
    final shown = _filter == null
        ? [
            for (final v in views)
              if (v.state.isActive || v.pendingVerification) v
          ]
        : byState[_filter]!;

    return Container(
      color: _C.pageBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kpis(byState),
                  const SizedBox(height: 22),
                  _chips(byState),
                  const SizedBox(height: 22),
                  _grid(shown),
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 22),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _C.border))),
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
                  Text('Live Orders',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: _C.text)),
                  SizedBox(height: 4),
                  Text('Real-time order tracking',
                      style: TextStyle(fontSize: 14, color: _C.muted)),
                ]),
            MasterButton(
                label: 'New Order',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: _newOrder),
          ],
        ),
      );

  Widget _kpis(Map<_Live, List<_OrderView>> byState) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1050
          ? 6
          : c.maxWidth >= 640
              ? 3
              : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final s in _Live.values)
          SizedBox(
              width: w,
              child: _KpiCard(
                  label: s.label.toUpperCase(),
                  value: byState[s]!.length,
                  pill: s.color,
                  pillTint: s.tint)),
      ]);
    });
  }

  Widget _chips(Map<_Live, List<_OrderView>> byState) {
    Widget chip(String label, _Live? s) => _FilterChip(
        label: label,
        selected: _filter == s,
        onTap: () => setState(() => _filter = s));
    return Wrap(spacing: 10, runSpacing: 10, children: [
      chip('All', null),
      for (final s in _Live.values)
        chip('${s.label} (${byState[s]!.length})', s),
    ]);
  }

  Widget _grid(List<_OrderView> shown) {
    if (shown.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border)),
        child: Column(children: [
          const Icon(Icons.receipt_long_outlined, size: 36, color: _C.muted),
          const SizedBox(height: 10),
          Text(
              _filter == null
                  ? 'No live orders right now'
                  : 'No ${_filter!.label.toLowerCase()} orders',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _C.text)),
          const SizedBox(height: 4),
          const Text('Orders from POS, captains, QR and delivery appear here.',
              style: TextStyle(fontSize: 13, color: _C.muted)),
        ]),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 960
          ? 3
          : c.maxWidth >= 600
              ? 2
              : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final v in shown)
          SizedBox(
              width: w,
              child: _OrderCard(
                  view: v,
                  now: _now,
                  onView: () => _showDetails(v),
                  actions: _actionsFor(v))),
      ]);
    });
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  List<(String, IconData, bool, VoidCallback)> _actionsFor(_OrderView v) {
    final s = v.state;
    final k = v.latestKot;
    final out = <(String, IconData, bool, VoidCallback)>[];
    if (k != null && s != _Live.cancelled) {
      switch (k.status) {
        case OpsKotStatus.newTicket:
          out.add((
            'Start Preparing',
            Icons.local_fire_department_outlined,
            false,
            () => _advanceKot(k, 'moved to Preparing')
          ));
        case OpsKotStatus.preparing:
          out.add((
            'Mark Ready',
            Icons.check_circle_outline,
            false,
            () => _advanceKot(k, 'marked Ready')
          ));
        case OpsKotStatus.ready:
          if (!v.isDelivery) {
            out.add((
              'Mark Served',
              Icons.room_service_outlined,
              false,
              () => _advanceKot(k, 'marked Served')
            ));
          }
        case OpsKotStatus.completed:
          break;
      }
    }
    if (v.isDelivery && s == _Live.ready) {
      out.add((
        'Out for Delivery',
        Icons.delivery_dining_outlined,
        false,
        () => _outForDelivery(v)
      ));
    }
    final d = v.delivery;
    if (v.isDelivery &&
        d != null &&
        (d.status == DeliveryStatus.pickedUp ||
            d.status == DeliveryStatus.inTransit)) {
      out
        ..add((
          'Mark Delivered',
          Icons.where_to_vote_outlined,
          false,
          () => _setDelivery(v, DeliveryStatus.delivered)
        ))
        ..add((
          'Delivery Failed',
          Icons.report_gmailerrorred_outlined,
          true,
          () => _setDelivery(v, DeliveryStatus.failed)
        ));
    }
    final open = !v.settled && v.order.status != OpsOrderStatus.cancelled;
    if (open && v.order.payment == null) {
      if (widget.canTakePayments) {
        out.add((
          'Mark Paid & Complete',
          Icons.payments_outlined,
          false,
          () => _markPaid(v)
        ));
      }
      out.add(('Cancel Order', Icons.cancel_outlined, true, () => _cancel(v)));
    }
    if (open && v.pendingVerification && widget.canVerifyPayments) {
      out.add(
          ('Verify Payment', Icons.verified_outlined, false, () => _verify(v)));
    }
    return out;
  }

  Future<void> _verify(_OrderView v) async {
    final note = await showVerifyPaymentDialog(context, v.order);
    if (note == null || !mounted) return;
    await runMasterAction(
        context,
        () => widget.ops.verifyPayment(v.order.id, note: note),
        success: '${v.order.number} payment verified and settled');
  }

  Future<void> _advanceKot(OpsKot k, String what) =>
      runMasterAction(context, () => widget.ops.advanceKot(k.ticketId),
          success: '${k.order.number} $what');

  Future<void> _outForDelivery(_OrderView v) async {
    final existing = v.delivery;
    final reuse = existing != null && existing.isOpen;
    String? rider = reuse ? existing.riderName : null;
    if (rider == null) {
      rider = await _promptText(
          title: 'Out for Delivery',
          message: 'Who is taking ${v.order.number}?',
          label: 'Rider name',
          confirm: 'Dispatch',
          person: true,
          // Created once per dialog: the delivery-enabled staff, if any.
          namesFuture: loadStaffNames(widget.staff, deliveryOnly: true),
          suggestions: distinctNames(_deliveries.map((d) => d.riderName)));
      if (rider == null || !mounted) return;
    }
    final ops = widget.ops;
    await runMasterAction(context, () async {
      var id = reuse ? existing.id : null;
      if (id == null) {
        id = await ops.nextDeliveryId();
        final now = DateTime.now();
        await ops.upsertDelivery(OpsDelivery(
            id: id,
            orderId: v.order.id,
            merchant: 'Restaurant',
            status: DeliveryStatus.unassigned,
            createdAt: now,
            updatedAt: now,
            customerName: existing?.customerName ?? '',
            address: existing?.address ?? ''));
      }
      if (!reuse || existing.riderName == null) {
        await ops.assignRider(id, rider!);
      }
      final k = v.latestKot;
      if (k != null && k.status == OpsKotStatus.ready) {
        await ops.advanceKot(k.ticketId);
      }
      await ops.setDeliveryStatus(id, DeliveryStatus.pickedUp);
    }, success: '${v.order.number} is out for delivery with $rider');
  }

  Future<void> _setDelivery(_OrderView v, DeliveryStatus to) async {
    final d = v.delivery!;
    if (to == DeliveryStatus.failed) {
      final ok = await confirmMasterAction(context,
          title: 'Mark delivery failed?',
          message:
              'The delivery of ${v.order.number} will be closed as failed. The '
              'order returns to Ready so it can be dispatched again.',
          confirmLabel: 'Mark Failed');
      if (!ok || !mounted) return;
    }
    await runMasterAction(context, () => widget.ops.setDeliveryStatus(d.id, to),
        success: '${v.order.number} ${to.label.toLowerCase()}');
  }

  Future<void> _markPaid(_OrderView v) async {
    final method = await showDialog<String>(
        context: context,
        builder: (ctx) => _MethodPicker(
            orderNumber: v.order.number, total: v.order.grandTotalMinor));
    if (method == null || !mounted) return;
    final ops = widget.ops;
    var state = OrderPaymentState.unpaid;
    await runMasterAction(context, () async {
      state = await ops.settleOrder(v.order.id, method);
      // Complete: serve every open ticket and close the delivery run. The
      // food is handed over either way; a card / UPI payment stays
      // pending verification until an authorised user verifies it.
      for (final k in v.kots) {
        var s = k.status;
        while (s != OpsKotStatus.completed) {
          s = await ops.advanceKot(k.ticketId);
        }
      }
      final d = v.delivery;
      if (d != null &&
          (d.status == DeliveryStatus.pickedUp ||
              d.status == DeliveryStatus.inTransit)) {
        await ops.setDeliveryStatus(d.id, DeliveryStatus.delivered);
      }
    });
    if (!mounted) return;
    if (state == OrderPaymentState.paid) {
      showMasterNotice(context,
          '${v.order.number} paid by ${paymentMethodLabel(method)} and completed');
    } else if (state == OrderPaymentState.pendingVerification) {
      showMasterNotice(
          context,
          '${v.order.number} completed — ${paymentMethodLabel(method)} payment '
          'recorded, pending verification');
    }
  }

  Future<void> _cancel(_OrderView v) async {
    final reason = await showReasonDialog(context,
        title: 'Cancel ${v.order.number}?',
        message: 'The order is cancelled and its kitchen tickets are shown '
            'to the kitchen as "Order cancelled"'
            '${v.order.tableLabel != null ? '; ${_OrderView.tableName(v.order.tableLabel)} is released for cleaning' : ''}. '
            'This cannot be undone and is recorded in the order history.',
        confirm: 'Cancel Order',
        suggestions: const [
          'Guest left',
          'Duplicate order',
          'Kitchen could not prepare'
        ]);
    if (reason == null || !mounted) return;
    await runMasterAction(
        context, () => widget.ops.cancelOrder(v.order.id, reason: reason),
        success: '${v.order.number} cancelled');
  }

  /// A one-field prompt. With [person] the field picks a person: a
  /// drop-down of [namesFuture] (+ "Other…"), or a text field suggesting
  /// [suggestions] when there are no names.
  Future<String?> _promptText(
      {required String title,
      required String message,
      required String label,
      required String confirm,
      bool person = false,
      Future<List<String>>? namesFuture,
      List<String> suggestions = const []}) {
    return showDialog<String>(
        context: context,
        builder: (ctx) => _PromptDialog(
            title: title,
            message: message,
            label: label,
            confirm: confirm,
            person: person,
            namesFuture: namesFuture,
            suggestions: suggestions));
  }

  void _showDetails(_OrderView v) {
    showDialog<void>(
        context: context,
        builder: (ctx) => _OrderDetailsDialog(
              view: v,
              now: _now,
              ops: widget.ops,
              onOpenBill: () {
                Navigator.pop(ctx);
                final open = widget.onOpenBilling;
                if (open == null) {
                  showMasterNotice(
                      context, 'POS Billing is not available from here.');
                } else {
                  open(v.order.id);
                }
              },
            ));
  }

  Future<void> _newOrder() async {
    final master = widget.master;
    if (master == null) {
      showMasterNotice(context,
          'The menu catalogue is not connected — New Order needs the Master menu.');
      return;
    }
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NewOrderDialog(ops: widget.ops, master: master));
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.pill,
      required this.pillTint});
  final String label;
  final int value;
  final Color pill;
  final Color pillTint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: _C.muted)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: _C.text)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: pillTint, borderRadius: BorderRadius.circular(6)),
              child: Text('Live',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: pill)),
            ),
          ]),
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? ViniiColors.brandGreen : _C.border)),
            // widthFactor 1: size to the label. (Container.alignment would
            // stretch the chip to the full Wrap width.)
            child: Align(
              widthFactor: 1,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.black : _C.text)),
            ),
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
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: primary ? ViniiColors.brandGreen : _C.border)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: primary ? Colors.black : _C.text)),
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(
      {required this.view,
      required this.now,
      required this.onView,
      required this.actions});
  final _OrderView view;
  final DateTime now;
  final VoidCallback onView;
  final List<(String, IconData, bool, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final o = view.order;
    final s = view.state;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: s.color, width: 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(o.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _C.text)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4)),
            child: Text(o.channel.label,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: s.tint, borderRadius: BorderRadius.circular(999)),
                child: Text('${s.label} • ${_ago(o.createdAt, now)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: s.color)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(view.customer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _C.text)),
        const SizedBox(height: 3),
        Text(view.itemsLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563))),
        const SizedBox(height: 3),
        Row(children: [
          Flexible(
            child: Text(view.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _C.muted)),
          ),
          const Text('  •  ', style: TextStyle(fontSize: 12, color: _C.muted)),
          Flexible(
            child: Text(view.paymentText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: view.paymentColor)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text(_inr(o.grandTotalMinor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: _C.text)),
          ),
          _SmallButton(label: 'View', onTap: onView),
          const SizedBox(width: 8),
          MenuAnchor(
            alignmentOffset: const Offset(0, 4),
            style: const MenuStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.white)),
            menuChildren: [
              for (final (label, icon, danger, run) in actions)
                MenuItemButton(
                  leadingIcon:
                      Icon(icon, size: 18, color: danger ? _C.red : _C.text),
                  onPressed: run,
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13, color: danger ? _C.red : _C.text)),
                ),
            ],
            builder: (context, controller, _) => _SmallButton(
              label: 'Update',
              primary: true,
              onTap: () {
                if (actions.isEmpty) {
                  showMasterNotice(context,
                      '${o.number} is ${s.label.toLowerCase()} — no further updates.');
                } else if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _OrderDetailsDialog extends StatefulWidget {
  const _OrderDetailsDialog(
      {required this.view,
      required this.now,
      required this.ops,
      required this.onOpenBill});
  final _OrderView view;
  final DateTime now;
  final DriftOperationsStore ops;
  final VoidCallback onOpenBill;

  @override
  State<_OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<_OrderDetailsDialog> {
  /// Customer name after an edit made in this dialog.
  String? _customer;

  _OrderView get view => widget.view;
  DateTime get now => widget.now;
  VoidCallback get onOpenBill => widget.onOpenBill;

  Future<void> _editName() async {
    final o = view.order;
    final name = await showDialog<String>(
        context: context,
        builder: (ctx) => _PromptDialog(
            title: 'Customer name',
            message: 'Name shown on ${o.number}.',
            label: 'Customer name',
            confirm: 'Save',
            initialValue: _customer ?? o.customerName));
    if (name == null || !mounted) return;
    final ok = await runMasterAction(
        context, () => widget.ops.setCustomerName(o.id, name),
        success: 'Customer name updated');
    if (ok && mounted) setState(() => _customer = name);
  }

  @override
  Widget build(BuildContext context) {
    final o = view.order;
    final s = view.state;
    Widget row(String l, String r, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        color: bold ? _C.text : _C.muted))),
            Text(r,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color ?? _C.text)),
          ]),
        );
    final d = view.delivery;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(children: [
        Expanded(child: Text(o.number)),
        MasterStatusPill(s.label,
            tone: switch (s) {
              _Live.newOrder => PillTone.blue,
              _Live.preparing => PillTone.amber,
              _Live.ready => PillTone.green,
              _Live.outForDelivery => PillTone.purple,
              _Live.completed => PillTone.gray,
              _Live.cancelled => PillTone.red,
            }),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${o.channel.label} · ${o.source} · placed ${formatClock(o.createdAt)} (${_ago(o.createdAt, now)})',
                    style: MasterStyle.muted),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(
                    child: Text(
                        '${_customer ?? view.customer} — ${view.location}',
                        style: MasterStyle.body),
                  ),
                  IconButton(
                      tooltip: 'Edit customer name',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      onPressed: _editName,
                      icon: const Icon(Icons.edit_outlined, color: _C.muted)),
                ]),
                if (o.serverName.isNotEmpty)
                  Text('Server: ${o.serverName}', style: MasterStyle.muted),
                if (d != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      'Delivery · ${d.status.label}'
                      '${d.riderName != null ? ' · Rider ${d.riderName}' : ''}',
                      style: MasterStyle.muted),
                ],
                const Divider(height: 24),
                const Text('Items', style: MasterStyle.sectionTitle),
                const SizedBox(height: 6),
                for (final l in o.lines)
                  row('${l.quantity} × ${l.name}', _inr(l.totalMinor)),
                if (o.lines.isEmpty)
                  const Text('No items', style: MasterStyle.muted),
                const Divider(height: 20),
                row('Subtotal', _inr(o.subtotalMinor)),
                if (o.discountMinor > 0)
                  row('Discount (${o.discountPct.toStringAsFixed(0)}%)',
                      '−${_inr(o.discountMinor)}'),
                row('Tax (${o.taxPct.toStringAsFixed(0)}%)', _inr(o.taxMinor)),
                row('Total', _inr(o.grandTotalMinor), bold: true),
                row('Payment', o.paymentLabel, color: view.paymentColor),
                if (o.billNo != null) row('Bill no.', '${o.billNo}'),
                const Divider(height: 20),
                const Text('Kitchen (KOT)', style: MasterStyle.sectionTitle),
                const SizedBox(height: 6),
                if (view.kots.isEmpty)
                  const Text('No kitchen ticket for this order today.',
                      style: MasterStyle.muted),
                for (final k in view.kots)
                  row(
                      '${k.label} · ${formatClock(k.createdAt)}'
                          '${k.urgent ? ' · Urgent' : ''}',
                      '${k.status.label} (${k.doneCount}/${k.order.lines.length} done)'),
                if (o.notes.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text('Notes: ${o.notes}', style: MasterStyle.body),
                ],
                if (o.auditLog.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text('History', style: MasterStyle.sectionTitle),
                  const SizedBox(height: 6),
                  for (final e in o.auditLog)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                          '${formatClock(e.at)}${e.actor.isEmpty ? '' : ' · ${e.actor}'} — ${e.text}',
                          style: MasterStyle.muted),
                    ),
                ],
              ]),
        ),
      ),
      actions: [
        MasterButton(label: 'Close', onPressed: () => Navigator.pop(context)),
        MasterButton(
            label: 'View Bill',
            icon: Icons.receipt_outlined,
            onPressed: () =>
                showBillPreview(context, ops: widget.ops, orderId: o.id)),
        MasterButton(
            label: 'Open Bill',
            icon: Icons.receipt_long_outlined,
            kind: MasterButtonKind.primary,
            onPressed: onOpenBill),
      ],
    );
  }
}

class _MethodPicker extends StatefulWidget {
  const _MethodPicker({required this.orderNumber, required this.total});

  /// The order's number as people read it ("ORD-248").
  final String orderNumber;
  final int total;

  @override
  State<_MethodPicker> createState() => _MethodPickerState();
}

class _MethodPickerState extends State<_MethodPicker> {
  static const _methods = [
    ('Cash', Icons.payments_outlined),
    ('Card', Icons.credit_card),
    ('UPI', Icons.qr_code_2),
  ];
  String _method = 'Cash';

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Mark ${widget.orderNumber} paid'),
        content: SizedBox(
          width: 380,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: ${_inr(widget.total)}',
                    style: MasterStyle.sectionTitle),
                const SizedBox(height: 4),
                const Text(
                    'Records the payment and serves any open kitchen tickets. '
                    'Cash closes the order; card / UPI stay pending '
                    'verification until a manager verifies them.',
                    style: MasterStyle.muted),
                const SizedBox(height: 14),
                Wrap(spacing: 10, children: [
                  for (final (m, icon) in _methods)
                    ChoiceChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(m),
                      selected: _method == m,
                      selectedColor: ViniiColors.brandGreen,
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ]),
              ]),
        ),
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              label: 'Mark Paid & Complete',
              kind: MasterButtonKind.primary,
              // Same lowercase keys the POS writes ('cash', 'card',
              // 'upi') so payments group consistently in reports.
              onPressed: () => Navigator.pop(context, _method.toLowerCase())),
        ],
      );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog(
      {required this.title,
      required this.message,
      required this.label,
      required this.confirm,
      this.initialValue = '',
      this.person = false,
      this.namesFuture,
      this.suggestions = const []});
  final String title, message, label, confirm, initialValue;

  /// The field names a person (a rider): picked with [PersonPickerField].
  final bool person;

  /// Names to pick from (e.g. delivery-enabled staff); see [person].
  final Future<List<String>>? namesFuture;

  /// Names suggested while typing when there are none to pick from.
  final List<String> suggestions;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _ctrl = TextEditingController(text: widget.initialValue);
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _err = widget.person
          ? 'Pick or enter the ${widget.label.toLowerCase()}.'
          : 'Enter the ${widget.label.toLowerCase()}.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(widget.title),
        content: SizedBox(
          width: 360,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.message, style: MasterStyle.body),
                const SizedBox(height: 12),
                if (widget.person)
                  PersonPickerField(
                    controller: _ctrl,
                    namesFuture: widget.namesFuture,
                    suggestions: widget.suggestions,
                    autofocus: true,
                    onChanged: (_) {
                      if (_err != null) setState(() => _err = null);
                    },
                    decoration: _inputDecoration(widget.label, error: _err),
                  )
                else
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    decoration: _inputDecoration(widget.label, error: _err),
                  ),
              ]),
        ),
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              label: widget.confirm,
              kind: MasterButtonKind.primary,
              onPressed: _submit),
        ],
      );
}

InputDecoration _inputDecoration(String label, {String? error, String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _C.border)),
    );

// ---------------------------------------------------------------------------
// New Order dialog
// ---------------------------------------------------------------------------

class _NewOrderDialog extends StatefulWidget {
  const _NewOrderDialog({required this.ops, required this.master});
  final DriftOperationsStore ops;
  final DriftMasterStore master;

  @override
  State<_NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<_NewOrderDialog> {
  OpsChannel _channel = OpsChannel.dineIn;
  String? _tableId;
  final _guests = TextEditingController(text: '2');
  final _customer = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _search = '';
  final _qty = <String, int>{};
  final _dishes = <String, MasterDishItem>{};
  bool _busy = false;

  String? _tableErr, _guestsErr, _customerErr, _addressErr, _itemsErr;

  late final Stream<List<OpsTable>> _tables$ = widget.ops.watchTables();
  late final Stream<List<MasterDishItem>> _dishes$ =
      widget.master.watchDishes();

  @override
  void dispose() {
    _guests.dispose();
    _customer.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _totalMinor => _qty.entries.fold(0, (s, e) {
        final d = _dishes[e.key];
        return d == null ? s : s + (d.sellingPrice * 100).round() * e.value;
      });

  int get _count => _qty.values.fold(0, (s, q) => s + q);

  Future<void> _submit(List<OpsTable> tables) async {
    final table = tables.where((t) => t.id == _tableId).firstOrNull;
    final guests = int.tryParse(_guests.text.trim());
    setState(() {
      _tableErr = _channel == OpsChannel.dineIn && table == null
          ? 'Pick a table.'
          : null;
      _guestsErr = _channel == OpsChannel.dineIn &&
              table?.currentOrderId == null &&
              (guests == null || guests < 1)
          ? 'Enter at least 1 guest.'
          : (table != null &&
                  table.currentOrderId == null &&
                  guests != null &&
                  guests > table.seats
              ? '${table.label} seats ${table.seats}.'
              : null);
      _customerErr =
          _channel == OpsChannel.delivery && _customer.text.trim().isEmpty
              ? 'Enter the customer name.'
              : null;
      _addressErr =
          _channel == OpsChannel.delivery && _address.text.trim().isEmpty
              ? 'Enter the delivery address.'
              : null;
      _itemsErr = _count == 0 ? 'Add at least one item.' : null;
    });
    if ([_tableErr, _guestsErr, _customerErr, _addressErr, _itemsErr]
        .any((e) => e != null)) {
      return;
    }
    final lines = [
      for (final e in _qty.entries)
        if (_dishes[e.key] != null)
          OpsOrderLine(
              itemId: e.key,
              name: _dishes[e.key]!.name,
              unitMinor: (_dishes[e.key]!.sellingPrice * 100).round(),
              quantity: e.value,
              station: stationForDish(
                  _dishes[e.key]!.category, _dishes[e.key]!.kitchenStation),
              isVeg: _dishes[e.key]!.isVeg),
    ];
    final notes = _notes.text.trim();
    final customer = _customer.text.trim();
    final ops = widget.ops;
    final nav = Navigator.of(context);
    String? placed;
    // The placed order's number as people read it (the id is only a key).
    String? placedNumber;
    setState(() => _busy = true);
    final ok = await runMasterAction(context, () async {
      placed = await ops.placeOrder(
          channel: _channel,
          lines: lines,
          tableId: _channel == OpsChannel.dineIn ? table!.id : null,
          guests: _channel == OpsChannel.dineIn ? guests : null,
          source: 'POS',
          customerName: customer,
          notes: notes);
      if (_channel == OpsChannel.delivery) {
        final now = DateTime.now();
        await ops.upsertDelivery(OpsDelivery(
            id: await ops.nextDeliveryId(),
            orderId: placed!,
            merchant: 'Restaurant',
            status: DeliveryStatus.unassigned,
            createdAt: now,
            updatedAt: now,
            customerName: customer,
            address: _address.text.trim()));
      }
      try {
        placedNumber = (await ops.getOrder(placed!))?.number;
      } catch (_) {
        // The order is placed; only its number could not be read back.
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      nav.pop();
      showMasterNotice(
          context,
          placedNumber == null
              ? 'Order placed and sent to kitchen'
              : '$placedNumber placed and sent to kitchen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(720.0, MediaQuery.sizeOf(context).width - 48);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: width,
        child: StreamBuilder<List<OpsTable>>(
          stream: _tables$,
          builder: (context, tSnap) {
            final tables = tSnap.data ?? const <OpsTable>[];
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(children: [
                  const Expanded(
                      child: Text('New Order',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _C.text))),
                  IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _channelPicker(),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _customer,
                            decoration: _inputDecoration(
                                _channel == OpsChannel.delivery
                                    ? 'Customer name'
                                    : 'Customer name (optional)',
                                hint: _channel == OpsChannel.takeaway
                                    ? 'Walk-in'
                                    : null,
                                error: _channel == OpsChannel.delivery
                                    ? _customerErr
                                    : null)),
                        const SizedBox(height: 12),
                        ..._channelFields(tables),
                        const SizedBox(height: 18),
                        _itemsPicker(),
                        const SizedBox(height: 14),
                        TextField(
                            controller: _notes,
                            maxLines: 2,
                            decoration: _inputDecoration('Notes (optional)',
                                hint: 'e.g. less spicy, extra sauces')),
                      ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _C.border))),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '$_count item${_count == 1 ? '' : 's'} · ${_inr(_totalMinor)} + tax',
                        style: MasterStyle.value),
                  ),
                  MasterButton(
                      label: 'Cancel',
                      onPressed: _busy ? null : () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  MasterButton(
                      label: _busy ? 'Placing…' : 'Place Order',
                      kind: MasterButtonKind.primary,
                      onPressed: _busy ? () {} : () => _submit(tables)),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _channelPicker() => Wrap(spacing: 10, runSpacing: 8, children: [
        for (final (c, icon) in [
          (OpsChannel.dineIn, Icons.table_restaurant_outlined),
          (OpsChannel.takeaway, Icons.shopping_bag_outlined),
          (OpsChannel.delivery, Icons.delivery_dining_outlined),
        ])
          ChoiceChip(
            avatar: Icon(icon, size: 16),
            label: Text(c.label),
            selected: _channel == c,
            selectedColor: ViniiColors.brandGreen,
            backgroundColor: Colors.white,
            onSelected: (_) => setState(() => _channel = c),
          ),
      ]);

  List<Widget> _channelFields(List<OpsTable> tables) {
    switch (_channel) {
      case OpsChannel.dineIn:
        final usable = tables
            .where((t) =>
                t.status == OpsTableStatus.available ||
                t.status == OpsTableStatus.occupied)
            .toList();
        final sel = usable.where((t) => t.id == _tableId).firstOrNull;
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                key: ValueKey('table-${sel?.id}'),
                initialValue: sel?.id,
                isExpanded: true,
                decoration: _inputDecoration('Table', error: _tableErr),
                items: [
                  for (final t in usable)
                    DropdownMenuItem(
                        value: t.id,
                        child: Text(
                            t.status == OpsTableStatus.available
                                ? '${t.label} · Available · ${t.seats} seats · ${t.floor}'
                                : '${t.label} · Occupied · adds to open order',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _tableId = v),
              ),
            ),
            if (sel == null || sel.currentOrderId == null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: _guests,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Guests', error: _guestsErr)),
              ),
            ],
          ]),
          if (usable.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No available or occupied tables.',
                  style: TextStyle(fontSize: 12, color: _C.red)),
            ),
        ];
      case OpsChannel.takeaway:
        return const [];
      case OpsChannel.delivery:
        return [
          TextField(
              controller: _address,
              maxLines: 2,
              decoration:
                  _inputDecoration('Delivery address', error: _addressErr)),
        ];
    }
  }

  Widget _itemsPicker() => StreamBuilder<List<MasterDishItem>>(
        stream: _dishes$,
        builder: (context, snap) {
          final error = snap.error;
          if (error != null) {
            return Text('Could not load the menu. ${friendlyError(error)}',
                style: const TextStyle(color: _C.red));
          }
          if (!snap.hasData) {
            return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()));
          }
          final all = snap.data!
              .where((d) =>
                  d.status == 'Active' && d.availability != 'Unavailable')
              .toList();
          for (final d in all) {
            _dishes[d.id] = d;
          }
          final q = _search.toLowerCase();
          final list = q.isEmpty
              ? all
              : all
                  .where((d) =>
                      d.name.toLowerCase().contains(q) ||
                      d.category.toLowerCase().contains(q))
                  .toList();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Text('Items', style: MasterStyle.sectionTitle),
                  const Spacer(),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: _inputDecoration('Search menu').copyWith(
                          prefixIcon: const Icon(Icons.search, size: 18)),
                    ),
                  ),
                ]),
                if (_itemsErr != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_itemsErr!,
                        style: const TextStyle(fontSize: 12, color: _C.red)),
                  ),
                const SizedBox(height: 10),
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                      border: Border.all(color: _C.border),
                      borderRadius: BorderRadius.circular(8)),
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                              all.isEmpty
                                  ? 'No active dishes in the Master menu.'
                                  : 'No dishes match "$_search".',
                              style: MasterStyle.muted))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: _C.border),
                          itemBuilder: (context, i) => _dishRow(list[i]),
                        ),
                ),
              ]);
        },
      );

  Widget _dishRow(MasterDishItem d) {
    final q = _qty[d.id] ?? 0;
    final vegColor = d.isVeg ? _C.green : _C.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              border: Border.all(color: vegColor),
              borderRadius: BorderRadius.circular(2)),
          alignment: Alignment.center,
          child: Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: vegColor, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _C.text)),
            Text(d.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MasterStyle.muted),
          ]),
        ),
        Text(formatInr(d.sellingPrice, decimals: 0),
            style: const TextStyle(fontSize: 13, color: _C.text)),
        const SizedBox(width: 12),
        if (q == 0)
          _SmallButton(
              label: 'Add',
              onTap: () => setState(() {
                    _qty[d.id] = 1;
                    _itemsErr = null;
                  }))
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => setState(() {
                      if (q <= 1) {
                        _qty.remove(d.id);
                      } else {
                        _qty[d.id] = q - 1;
                      }
                    })),
            SizedBox(
                width: 22,
                child: Text('$q',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => setState(() => _qty[d.id] = q + 1)),
          ]),
      ]),
    );
  }
}
