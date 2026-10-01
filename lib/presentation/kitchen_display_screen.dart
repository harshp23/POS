// Rebuilt from v1/POS-KOT-KITCHEN-DEFAULT.png and
// v1/POS-KOT-KITCHEN-V3.png (light/dark pair) — see Q02 in
// docs/DECISIONS-AND-QUESTIONS.txt.
//
// Live: the board watches the kitchen tickets, orders and lines in the
// local database (drift watch queries), so a KOT sent from any POS /
// Operations screen appears without a refresh, and elapsed times tick.
// Each card shows the order's type / table, its items, the KOT and order
// notes, and how long it has been waiting. Transitions are forward-only
// (Start Cooking → Mark Ready → Serve), validated by KitchenService.
// Tickets of orders cancelled after they reached the kitchen leave the
// queue and are listed under "Order cancelled" so the kitchen stops.
//
// "Delayed" is not a stored status — PAGE-RES-005 doesn't give an SLA
// number, and the PRD explicitly defers timeout/heartbeat values to
// owner review (§11). 20 minutes (OpsKot.delayedAfterMinutes) is a
// clearly-placeholder threshold for New/Preparing tickets, not a sourced
// value.

import 'dart:async';

import 'package:flutter/material.dart';

import '../application/kitchen_service.dart';
import '../data/drift_local_store.dart';
import '../data/drift_operations_store.dart';
import '../domain/operations.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

class KitchenDisplayScreen extends StatefulWidget {
  const KitchenDisplayScreen(
      {super.key,
      required this.kitchenService,
      required this.localStore,
      this.ops});

  /// Validates and applies the forward-only ticket transitions.
  final KitchenService kitchenService;
  final DriftLocalStore localStore;

  /// Live ticket / order data; built on [localStore]'s database when null.
  final DriftOperationsStore? ops;

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  late final DriftOperationsStore _ops =
      widget.ops ?? DriftOperationsStore(widget.localStore.db);
  final _subs = <StreamSubscription<Object?>>[];
  List<OpsKot>? _tickets;
  List<OpsKot> _cancelled = const [];
  Object? _error;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_ops.watchKots().listen((k) {
        if (mounted) {
          setState(() => _tickets = [
                for (final t in k)
                  if (t.status != OpsKotStatus.completed) t
              ]);
        }
      }, onError: (Object e) => mounted ? setState(() => _error = e) : null))
      ..add(_ops.watchCancelledKots().listen((k) {
        if (mounted) setState(() => _cancelled = k);
      }, onError: (_) {}));
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

  Future<void> _advance(String ticketId) async {
    if (_busy.contains(ticketId)) return;
    setState(() => _busy.add(ticketId));
    try {
      await widget.kitchenService.advance(ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: ViniiColors.redSolid,
            content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(ticketId));
    }
  }

  /// Cancelled in the last two hours.
  List<OpsKot> get _recentlyCancelled => [
        for (final k in _cancelled)
          if (_now.difference(k.cancelledAt ?? k.createdAt) <
              const Duration(hours: 2))
            k
      ];

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
          child: Text(
              'Could not load kitchen tickets: ${friendlyError(_error!)}'));
    }
    final tickets = _tickets;
    if (tickets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Oldest first — the kitchen works in arrival order.
    final all = [...tickets]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final delayed = all.where((t) => t.isDelayed(_now)).toList();
    final newT = all
        .where((t) => t.status == OpsKotStatus.newTicket && !t.isDelayed(_now))
        .toList();
    final preparing = all
        .where((t) => t.status == OpsKotStatus.preparing && !t.isDelayed(_now))
        .toList();
    final ready = all.where((t) => t.status == OpsKotStatus.ready).toList();
    final cancelled = _recentlyCancelled;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Kitchen Display System (KDS)',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Tooltip(
              message: 'Updates automatically as tickets change',
              child: _pill('LIVE', ViniiColors.greenSolid, filled: true)),
          const Spacer(),
          Text(
              'New ${all.where((t) => t.status == OpsKotStatus.newTicket).length}'
              '  ·  Preparing ${all.where((t) => t.status == OpsKotStatus.preparing).length}'
              '  ·  Ready ${ready.length}  ·  Delayed ${delayed.length}',
              style: const TextStyle(color: Colors.grey)),
        ]),
        if (cancelled.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: ViniiColors.redTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ViniiColors.redSolid.withValues(alpha: 0.3))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order cancelled — stop preparing',
                  style: TextStyle(
                      color: ViniiColors.redSolid,
                      fontWeight: FontWeight.bold)),
              for (final k in cancelled)
                Text(
                    '${k.label} · ${k.order.number}'
                    '${k.order.tableLabel != null ? ' · ${k.order.tableLabel}' : ''}'
                    ' — ${k.order.lines.map((l) => '${l.name} ×${l.quantity}').join(', ')}',
                    style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _KotColumn(
                    title: 'NEW',
                    color: ViniiColors.blueSolid,
                    tickets: newT,
                    now: _now,
                    busy: _busy,
                    onAdvance: _advance)),
            const SizedBox(width: 16),
            Expanded(
                child: _KotColumn(
                    title: 'PREPARING',
                    color: ViniiColors.amberSolid,
                    tickets: preparing,
                    now: _now,
                    busy: _busy,
                    onAdvance: _advance)),
            const SizedBox(width: 16),
            Expanded(
                child: _KotColumn(
                    title: 'READY',
                    color: ViniiColors.greenSolid,
                    tickets: ready,
                    now: _now,
                    busy: _busy,
                    onAdvance: _advance)),
            const SizedBox(width: 16),
            Expanded(
                child: _KotColumn(
                    title: 'DELAYED',
                    color: ViniiColors.redSolid,
                    tickets: delayed,
                    now: _now,
                    busy: _busy,
                    onAdvance: _advance)),
          ]),
        ),
      ]),
    );
  }
}

Widget _pill(String label, Color color, {bool filled = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]));

String _actionFor(OpsKotStatus s) => switch (s) {
      OpsKotStatus.newTicket => 'Start Cooking',
      OpsKotStatus.preparing => 'Mark Ready',
      OpsKotStatus.ready => 'Serve',
      OpsKotStatus.completed => '',
    };

class _KotColumn extends StatelessWidget {
  const _KotColumn(
      {required this.title,
      required this.color,
      required this.tickets,
      required this.now,
      required this.busy,
      required this.onAdvance});
  final String title;
  final Color color;
  final List<OpsKot> tickets;
  final DateTime now;
  final Set<String> busy;
  final void Function(String ticketId) onAdvance;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 3))),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 6),
          CircleAvatar(
              radius: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text('${tickets.length}',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold))),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: ListView(children: [
          for (final t in tickets)
            _KotCard(
                kot: t,
                now: now,
                // Delayed cards keep the action of the status they are in.
                actionLabel: _actionFor(t.status),
                busy: busy.contains(t.ticketId),
                onAdvance: () => onAdvance(t.ticketId)),
        ]),
      ),
    ]);
  }
}

class _KotCard extends StatelessWidget {
  const _KotCard(
      {required this.kot,
      required this.now,
      required this.actionLabel,
      required this.busy,
      required this.onAdvance});
  final OpsKot kot;
  final DateTime now;
  final String actionLabel;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final order = kot.order;
    final elapsed = kot.ageMinutes(now);
    final delayed = kot.isDelayed(now);
    final warn = delayed || kot.urgent;
    final notes = [
      if (kot.notes.trim().isNotEmpty) kot.notes.trim(),
      if (order.notes.trim().isNotEmpty &&
          order.notes.trim() != kot.notes.trim())
        order.notes.trim(),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(
              color: warn
                  ? ViniiColors.redSolid.withValues(alpha: 0.5)
                  : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text('${kot.label} · ${order.number}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (warn) ...[
              Text(kot.urgent ? 'URGENT' : 'DELAYED',
                  style: const TextStyle(
                      color: ViniiColors.redSolid,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.access_time,
                size: 13, color: delayed ? ViniiColors.redSolid : Colors.grey),
            Text(' $elapsed min',
                style: TextStyle(
                    fontSize: 12,
                    color: delayed ? ViniiColors.redSolid : Colors.grey)),
          ]),
        ]),
        const SizedBox(height: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
                order.channel == OpsChannel.dineIn
                    ? 'Dine In · ${order.tableLabel ?? '—'}'
                    : '${order.channel.label}'
                        '${order.customerName.isEmpty ? '' : ' · ${order.customerName}'}',
                style: const TextStyle(fontSize: 11))),
        const SizedBox(height: 8),
        for (final line in order.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text('${line.name} ×${line.quantity}',
                style: TextStyle(
                    fontSize: 13,
                    color: line.done ? Colors.grey : null,
                    decoration: line.done ? TextDecoration.lineThrough : null)),
          ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: ViniiColors.amberTint,
                borderRadius: BorderRadius.circular(4)),
            child: Text(notes.join('\n'),
                style: const TextStyle(
                    fontSize: 12, color: ViniiColors.amberSolid)),
          ),
        ],
        const SizedBox(height: 10),
        if (actionLabel.isNotEmpty)
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: busy ? null : onAdvance,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: ViniiColors.greenSolid,
                      side: const BorderSide(color: ViniiColors.greenSolid)),
                  child: Text(actionLabel))),
      ]),
    );
  }
}
