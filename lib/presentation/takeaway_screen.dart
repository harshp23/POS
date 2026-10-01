// POS → Takeaway, from v1/POS-TAKEAWAY-V3.png: the live takeaway / pickup
// queue built on the real orders (channel takeaway) — kitchen progress
// from their KOTs, payment state (incl. card / UPI pending verification)
// from their payment rows, and handover (the KOT served = picked up).

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/drift_operations_store.dart';
import '../domain/operations.dart';
import 'operations/ops_order_dialogs.dart';
import 'operations/ops_order_queue.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

class TakeawayScreen extends StatefulWidget {
  const TakeawayScreen(
      {super.key,
      this.ops,
      this.onNewTakeaway,
      this.onOpenOrder,
      this.canTakePayments = true});

  /// The shared order store. Without it the screen says it is not
  /// connected (nothing is invented).
  final DriftOperationsStore? ops;

  /// Opens the POS order screen for a new takeaway order.
  final VoidCallback? onNewTakeaway;

  /// Opens an order in the POS order screen (resume a held order, add
  /// items, take the payment).
  final ValueChanged<String>? onOpenOrder;

  /// The signed-in role may collect money (cashier, owners, managers).
  /// Captains and waiters take orders only: the payment actions are hidden
  /// and the server refuses them as well.
  final bool canTakePayments;

  @override
  State<TakeawayScreen> createState() => _TakeawayScreenState();
}

enum _Tab { active, held, kitchen, ready, payment, completed, cancelled }

extension on _Tab {
  String get label => switch (this) {
        _Tab.active => 'Active',
        _Tab.held => 'Held',
        _Tab.kitchen => 'In Kitchen',
        _Tab.ready => 'Ready for Pickup',
        _Tab.payment => 'Awaiting Payment',
        _Tab.completed => 'Completed',
        _Tab.cancelled => 'Cancelled',
      };
}

class _TakeawayScreenState extends State<TakeawayScreen> {
  _Tab _tab = _Tab.active;
  String _query = '';
  StreamSubscription<List<OpsOrder>>? _sub;
  List<OpsOrder>? _orders;
  Object? _error;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _sub = widget.ops?.watchOrders().listen((o) {
      if (mounted) {
        setState(() => _orders = [
              for (final x in o)
                if (x.channel == OpsChannel.takeaway) x
            ]);
      }
    }, onError: (Object e) => mounted ? setState(() => _error = e) : null);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  bool _inTab(OpsOrder o, _Tab t) => switch (t) {
        _Tab.active => o.isActive,
        _Tab.held => o.isHeld,
        _Tab.kitchen => o.isActive &&
            (o.kitchenState == OpsKitchenState.queued ||
                o.kitchenState == OpsKitchenState.preparing),
        _Tab.ready => o.isActive && o.kitchenState == OpsKitchenState.ready,
        _Tab.payment => o.isActive && o.paymentState != OrderPaymentState.paid,
        _Tab.completed => o.status == OpsOrderStatus.settled,
        _Tab.cancelled => o.status == OpsOrderStatus.cancelled,
      };

  /// The takeaway queue's own status for an order.
  (String, Color) _status(OpsOrder o) {
    if (o.status == OpsOrderStatus.cancelled) {
      return ('Cancelled', ViniiColors.redSolid);
    }
    if (o.isHeld) return ('Held', ViniiColors.graySolid);
    return switch (o.kitchenState) {
      OpsKitchenState.notSent => ('Held', ViniiColors.graySolid),
      OpsKitchenState.queued => ('New', ViniiColors.blueSolid),
      OpsKitchenState.preparing => ('Preparing', ViniiColors.amberSolid),
      OpsKitchenState.ready => ('Ready for pickup', ViniiColors.greenSolid),
      OpsKitchenState.served => o.status == OpsOrderStatus.settled
          ? ('Completed', ViniiColors.graySolid)
          : ('Picked up', ViniiColors.purpleSolid),
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

  /// Handover: every ready ticket of the order is marked served.
  Future<void> _handOver(OpsOrder o) => _run(() async {
        final ops = widget.ops!;
        for (final k in await ops.getKots()) {
          if (k.order.id == o.id && k.status == OpsKotStatus.ready) {
            await ops.advanceKot(k.ticketId);
          }
        }
      }, '${o.number} handed over');

  (String, VoidCallback?)? _primary(OpsOrder o) {
    final ops = widget.ops!;
    if (o.isHeld) {
      return (
        'Send KOT',
        () => _run(
            () => ops.sendKot(o.id), 'KOT for ${o.number} sent to kitchen')
      );
    }
    if (o.isActive && o.kitchenState == OpsKitchenState.ready) {
      return ('Hand Over', () => _handOver(o));
    }
    if (o.isActive &&
        o.paymentState == OrderPaymentState.unpaid &&
        widget.canTakePayments &&
        widget.onOpenOrder != null) {
      return ('Collect Payment', () => widget.onOpenOrder!(o.id));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.ops;
    if (ops == null) return const QueueNotConnected(title: 'Takeaway Orders');
    if (_error != null) {
      return Center(
          child: Text('Could not load orders: ${friendlyError(_error!)}'));
    }
    final all = _orders;
    final scoped = [
      for (final o in all ?? const <OpsOrder>[])
        if (inQueueScope(o, _now)) o
    ];
    final counts = {for (final t in _Tab.values) t: 0};
    for (final o in scoped) {
      for (final t in _Tab.values) {
        if (_inTab(o, t)) counts[t] = counts[t]! + 1;
      }
    }
    final shown = [
      for (final o in scoped.reversed)
        if (_inTab(o, _tab) && orderMatchesQuery(o, _query)) o
    ];
    final today = scoped.where((o) {
      final d = o.createdAt;
      return d.year == _now.year && d.month == _now.month && d.day == _now.day;
    }).length;

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
                        const Text('Takeaway Orders',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$today today · ${counts[_Tab.active]} active',
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
                            hint: 'Search order, customer, item',
                            onChanged: (v) => setState(() => _query = v)),
                        FilledButton.icon(
                            onPressed: widget.onNewTakeaway,
                            style: FilledButton.styleFrom(
                                backgroundColor: ViniiColors.brandGreen,
                                foregroundColor: Colors.black),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Takeaway',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                      ]),
                ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _Tab.values)
                ChoiceChip(
                    label: Text('${t.label}  ${counts[t]}'),
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
                                  ? 'No takeaway orders match "$_query".'
                                  : scoped.isEmpty
                                      ? 'No takeaway orders today. Tap "New Takeaway" to take one.'
                                      : 'No ${_tab.label.toLowerCase()} takeaway orders.',
                              style: const TextStyle(
                                  color: ViniiColors.textMutedLight)))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 340,
                                  mainAxisExtent: 250,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final o = shown[i];
                            final (label, color) = _status(o);
                            final primary = _primary(o);
                            return OrderQueueCard(
                                order: o,
                                now: _now,
                                statusLabel: label,
                                statusColor: color,
                                onView: () => showOrderDetailsDialog(context,
                                    ops: ops,
                                    orderId: o.id,
                                    onOpenOrder: widget.onOpenOrder),
                                primaryLabel: primary?.$1,
                                onPrimary: primary?.$2,
                                moreActions: [
                                  if (o.status == OpsOrderStatus.open &&
                                      widget.onOpenOrder != null)
                                    (
                                      'Open order',
                                      () => widget.onOpenOrder!(o.id)
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
