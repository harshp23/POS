// POS → Delivery, from v1/POS-DELIVERY-V3.png: the live delivery queue on
// the real orders (channel delivery) and their delivery records
// (deliveries table — customer, address, rider name, status). Kitchen
// progress comes from the KOTs, payment state from the payment rows
// (cash on delivery is taken in the POS payment screen; card / UPI stay
// pending verification). The rider is a name on the delivery record,
// picked from the delivery-enabled staff when there is a staff list — there is no rider app / integration.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/drift_operations_store.dart';
import '../data/staff_repository.dart' show StaffRepository;
import '../domain/operations.dart';
import 'operations/ops_order_dialogs.dart';
import 'operations/ops_order_queue.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen(
      {super.key,
      this.ops,
      this.onNewDelivery,
      this.onOpenOrder,
      this.canTakePayments = true,
      this.staff});

  /// The shared order store. Without it the screen says it is not
  /// connected (nothing is invented).
  final DriftOperationsStore? ops;

  /// Opens the POS order screen for a new delivery order.
  final VoidCallback? onNewDelivery;

  /// Opens an order in the POS order screen (resume, add items, payment).
  final ValueChanged<String>? onOpenOrder;

  /// The signed-in role may collect money (cashier, owners, managers).
  /// Delivery staff and waiters take orders only: the payment actions are
  /// hidden and the server refuses them as well.
  final bool canTakePayments;

  /// The staff list: riders are picked from the active staff with
  /// delivery enabled. Without it (or when nobody has delivery enabled)
  /// the rider is typed, with the riders already used as suggestions.
  final StaffRepository? staff;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

enum _Tab { active, held, kitchen, awaitingRider, onTheWay, delivered, closed }

extension on _Tab {
  String get label => switch (this) {
        _Tab.active => 'Active',
        _Tab.held => 'Held',
        _Tab.kitchen => 'In Kitchen',
        _Tab.awaitingRider => 'Awaiting Rider',
        _Tab.onTheWay => 'Out for Delivery',
        _Tab.delivered => 'Delivered',
        _Tab.closed => 'Failed / Cancelled',
      };
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  _Tab _tab = _Tab.active;
  String _query = '';
  final _subs = <StreamSubscription<Object?>>[];
  List<OpsOrder>? _orders;
  Map<String, OpsDelivery> _deliveries = const {};

  /// Riders already used on any delivery (suggested when typing a rider).
  List<String> _riders = const [];
  Object? _error;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final ops = widget.ops;
    if (ops != null) {
      _subs
        ..add(ops.watchOrders().listen((o) {
          if (mounted) {
            setState(() => _orders = [
                  for (final x in o)
                    if (x.channel == OpsChannel.delivery) x
                ]);
          }
        }, onError: (Object e) => mounted ? setState(() => _error = e) : null))
        ..add(ops.watchDeliveries().listen((d) {
          if (!mounted) return;
          // Newest record per order (deliveries arrive newest first).
          final by = <String, OpsDelivery>{};
          for (final x in d) {
            by.putIfAbsent(x.orderId, () => x);
          }
          setState(() {
            _deliveries = by;
            _riders = distinctNames(d.map((x) => x.riderName));
          });
        }, onError: (Object e) => mounted ? setState(() => _error = e) : null));
    }
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

  bool _onTheWay(OpsDelivery? d) =>
      d != null &&
      (d.status == DeliveryStatus.pickedUp ||
          d.status == DeliveryStatus.inTransit);

  bool _inTab(OpsOrder o, _Tab t) {
    final d = _deliveries[o.id];
    final open = o.isActive || (d != null && d.isOpen);
    return switch (t) {
      _Tab.active => o.status != OpsOrderStatus.cancelled &&
          (o.isActive || _onTheWay(d)) &&
          d?.status != DeliveryStatus.failed,
      _Tab.held => o.isHeld,
      _Tab.kitchen => o.isActive &&
          (o.kitchenState == OpsKitchenState.queued ||
              o.kitchenState == OpsKitchenState.preparing),
      _Tab.awaitingRider => open &&
          o.status != OpsOrderStatus.cancelled &&
          o.sentToKitchen &&
          !_onTheWay(d) &&
          d?.status != DeliveryStatus.delivered &&
          d?.status != DeliveryStatus.failed &&
          (o.kitchenState == OpsKitchenState.ready ||
              o.kitchenState == OpsKitchenState.served),
      _Tab.onTheWay => _onTheWay(d),
      _Tab.delivered => d?.status == DeliveryStatus.delivered,
      _Tab.closed => o.status == OpsOrderStatus.cancelled ||
          d?.status == DeliveryStatus.failed,
    };
  }

  (String, Color) _status(OpsOrder o) {
    final d = _deliveries[o.id];
    if (o.status == OpsOrderStatus.cancelled) {
      return ('Cancelled', ViniiColors.redSolid);
    }
    if (d != null) {
      switch (d.status) {
        case DeliveryStatus.delivered:
          return ('Delivered', ViniiColors.greenSolid);
        case DeliveryStatus.failed:
          return ('Delivery failed', ViniiColors.redSolid);
        case DeliveryStatus.pickedUp:
        case DeliveryStatus.inTransit:
          return (d.status.label, ViniiColors.purpleSolid);
        case DeliveryStatus.unassigned:
        case DeliveryStatus.assigned:
          break;
      }
    }
    if (o.isHeld) return ('Held', ViniiColors.graySolid);
    return switch (o.kitchenState) {
      OpsKitchenState.notSent => ('Held', ViniiColors.graySolid),
      OpsKitchenState.queued => ('New', ViniiColors.blueSolid),
      OpsKitchenState.preparing => ('Preparing', ViniiColors.amberSolid),
      OpsKitchenState.ready || OpsKitchenState.served => d?.riderName == null
          ? ('Awaiting rider', ViniiColors.greenSolid)
          : ('Rider assigned', ViniiColors.greenSolid),
    };
  }

  Future<void> _run(Future<void> Function() op, String done) async {
    try {
      await op();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: ViniiColors.redSolid,
          content: Text(friendlyError(e))));
    }
  }

  /// The order's delivery record, created from the order if it has none.
  Future<String> _ensureDelivery(OpsOrder o) async {
    final ops = widget.ops!;
    final d = _deliveries[o.id];
    if (d != null && d.isOpen) return d.id;
    final id = await ops.nextDeliveryId();
    final now = DateTime.now();
    await ops.upsertDelivery(OpsDelivery(
        id: id,
        orderId: o.id,
        merchant: d?.merchant ?? 'Restaurant',
        status: DeliveryStatus.unassigned,
        createdAt: now,
        updatedAt: now,
        customerName: d?.customerName ?? o.customerName,
        address: d?.address ?? ''));
    return id;
  }

  Future<void> _assignRider(OpsOrder o) async {
    // Created once per dialog: the delivery-enabled staff, if any.
    final names = loadStaffNames(widget.staff, deliveryOnly: true);
    final rider = await showDialog<String>(
        context: context,
        builder: (_) => _RiderDialog(
            orderNumber: o.number,
            current: _deliveries[o.id]?.riderName,
            namesFuture: names,
            suggestions: _riders));
    if (rider == null || !mounted) return;
    await _run(() async {
      final id = await _ensureDelivery(o);
      await widget.ops!.assignRider(id, rider);
    }, '$rider assigned to ${o.number}');
  }

  /// Rider leaves with the food: ready tickets are served and the
  /// delivery moves to Picked Up.
  Future<void> _dispatch(OpsOrder o) => _run(() async {
        final ops = widget.ops!;
        for (final k in await ops.getKots()) {
          if (k.order.id == o.id && k.status == OpsKotStatus.ready) {
            await ops.advanceKot(k.ticketId);
          }
        }
        await ops.setDeliveryStatus(
            _deliveries[o.id]!.id, DeliveryStatus.pickedUp);
      }, '${o.number} is out for delivery');

  Future<void> _setStatus(OpsOrder o, DeliveryStatus to) => _run(
      () => widget.ops!.setDeliveryStatus(_deliveries[o.id]!.id, to),
      '${o.number}: ${to.label.toLowerCase()}');

  (String, VoidCallback?)? _primary(OpsOrder o) {
    final ops = widget.ops!;
    final d = _deliveries[o.id];
    if (o.status == OpsOrderStatus.cancelled) return null;
    if (o.isHeld) {
      return (
        'Send KOT',
        () => _run(() => ops.sendKot(o.id), 'KOT for ${o.number} sent to kitchen')
      );
    }
    if (_onTheWay(d)) {
      return ('Mark Delivered', () => _setStatus(o, DeliveryStatus.delivered));
    }
    if (d?.status == DeliveryStatus.delivered ||
        d?.status == DeliveryStatus.failed) {
      if (o.isActive &&
          o.paymentState == OrderPaymentState.unpaid &&
          widget.canTakePayments &&
          widget.onOpenOrder != null) {
        return ('Collect Payment', () => widget.onOpenOrder!(o.id));
      }
      return null;
    }
    if (d?.riderName == null) return ('Assign Rider', () => _assignRider(o));
    if (o.kitchenState == OpsKitchenState.ready ||
        o.kitchenState == OpsKitchenState.served) {
      return ('Dispatch', () => _dispatch(o));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.ops;
    if (ops == null) return const QueueNotConnected(title: 'Delivery Orders');
    final error = _error;
    if (error != null) {
      return Center(
          child: Text('Could not load orders. ${friendlyError(error)}'));
    }
    final all = _orders;
    final scoped = [
      for (final o in all ?? const <OpsOrder>[])
        if (inQueueScope(o, _now) || (_deliveries[o.id]?.isOpen ?? false)) o
    ];
    final counts = {for (final t in _Tab.values) t: 0};
    for (final o in scoped) {
      for (final t in _Tab.values) {
        if (_inTab(o, t)) counts[t] = counts[t]! + 1;
      }
    }
    final shown = [
      for (final o in scoped.reversed)
        if (_inTab(o, _tab) &&
            orderMatchesQuery(o, _query, delivery: _deliveries[o.id]))
          o
    ];

    return Container(
        color: ViniiColors.lightPageBg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Delivery Orders',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            '${scoped.length} in view · ${counts[_Tab.active]} active',
                            style: const TextStyle(
                                color: ViniiColors.textMutedLight,
                                fontSize: 13)),
                      ]),
                  Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        QueueSearchField(
                            hint: 'Search order, customer, rider',
                            onChanged: (v) => setState(() => _query = v)),
                        FilledButton.icon(
                            onPressed: widget.onNewDelivery,
                            style: FilledButton.styleFrom(
                                backgroundColor: ViniiColors.brandGreen,
                                foregroundColor: Colors.black),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Delivery',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                      ]),
                ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _Tab.values)
                ChoiceChip(
                    label: Text('${t.label} (${counts[t]})'),
                    selected: _tab == t,
                    selectedColor: ViniiColors.brandGreen,
                    labelStyle: TextStyle(
                        color: _tab == t ? Colors.black : null,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _tab = t)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: all == null
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                      ? Center(
                          child: Text(
                              _query.isNotEmpty
                                  ? 'No delivery orders match "$_query".'
                                  : scoped.isEmpty
                                      ? 'No delivery orders today. Tap "New Delivery" to take one.'
                                      : 'No ${_tab.label.toLowerCase()} delivery orders.',
                              style: const TextStyle(
                                  color: ViniiColors.textMutedLight)))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 380,
                                  mainAxisExtent: 268,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final o = shown[i];
                            final d = _deliveries[o.id];
                            final (label, color) = _status(o);
                            final primary = _primary(o);
                            return OrderQueueCard(
                                order: o,
                                now: _now,
                                delivery: d,
                                statusLabel: label,
                                statusColor: color,
                                onView: () => showOrderDetailsDialog(context,
                                    ops: ops,
                                    orderId: o.id,
                                    delivery: d,
                                    onOpenOrder: widget.onOpenOrder),
                                primaryLabel: primary?.$1,
                                onPrimary: primary?.$2,
                                moreActions: [
                                  if (o.isActive &&
                                      d?.riderName != null &&
                                      !_onTheWay(d))
                                    ('Change rider', () => _assignRider(o)),
                                  if (d?.status == DeliveryStatus.pickedUp)
                                    (
                                      'Mark In Transit',
                                      () => _setStatus(
                                          o, DeliveryStatus.inTransit)
                                    ),
                                  if (_onTheWay(d))
                                    (
                                      'Delivery failed',
                                      () => _setStatus(o, DeliveryStatus.failed)
                                    ),
                                  if (o.isActive &&
                                      o.paymentState ==
                                          OrderPaymentState.unpaid &&
                                      widget.onOpenOrder != null &&
                                      widget.canTakePayments &&
                                      primary?.$1 != 'Collect Payment')
                                    (
                                      'Collect payment',
                                      () => widget.onOpenOrder!(o.id)
                                    ),
                                ]);
                          }),
            ),
          ]),
        ));
  }
}

class _RiderDialog extends StatefulWidget {
  const _RiderDialog(
      {required this.orderNumber,
      this.current,
      this.namesFuture,
      this.suggestions = const []});

  /// The order's number as people read it ("ORD-248").
  final String orderNumber;

  /// The rider already on the delivery, if any.
  final String? current;

  /// Delivery-enabled staff ([loadStaffNames]): picked from a list. When
  /// it is empty the rider is typed.
  final Future<List<String>>? namesFuture;

  /// Riders already used on deliveries, suggested while typing.
  final List<String> suggestions;

  @override
  State<_RiderDialog> createState() => _RiderDialogState();
}

class _RiderDialogState extends State<_RiderDialog> {
  late final _c = TextEditingController(text: widget.current ?? '');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Pick or enter the rider name.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Rider for ${widget.orderNumber}'),
        content: SizedBox(
          width: 340,
          child: PersonPickerField(
            controller: _c,
            namesFuture: widget.namesFuture,
            suggestions: widget.suggestions,
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
                labelText: 'Rider name',
                errorText: _error,
                border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Assign')),
        ],
      );
}
