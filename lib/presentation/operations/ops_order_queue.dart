import 'package:flutter/material.dart';

import '../../domain/operations.dart';
import '../vinii_theme.dart';

/// Pieces shared by the POS Takeaway and Delivery queues: scope, search,
/// status pills and the order card. Every value shown comes from the real
/// order (orders / order_lines / kitchen_tickets / payments / deliveries).

/// Today's orders, plus anything still open (or with a payment waiting for
/// verification) from earlier.
bool inQueueScope(OpsOrder o, DateTime now) {
  bool today(DateTime d) =>
      d.year == now.year && d.month == now.month && d.day == now.day;
  return o.isActive || today(o.createdAt) || today(o.settledAt ?? o.createdAt);
}

/// Order number (or key), customer, table, item names, rider / address.
bool orderMatchesQuery(OpsOrder o, String query, {OpsDelivery? delivery}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [
    o.number,
    o.id,
    o.customerName,
    o.displayName,
    o.tableLabel ?? '',
    o.source,
    for (final l in o.lines) l.name,
    if (o.billNo != null) '${o.billNo}',
    if (delivery != null) ...[
      delivery.customerName,
      delivery.address,
      delivery.riderName ?? '',
      delivery.id,
    ],
  ].join(' ').toLowerCase();
  return hay.contains(q);
}

Color kitchenColor(OpsKitchenState s) => switch (s) {
      OpsKitchenState.notSent => ViniiColors.graySolid,
      OpsKitchenState.queued => ViniiColors.blueSolid,
      OpsKitchenState.preparing => ViniiColors.amberSolid,
      OpsKitchenState.ready => ViniiColors.greenSolid,
      OpsKitchenState.served => ViniiColors.graySolid,
    };

Color paymentColor(OrderPaymentState s) => switch (s) {
      OrderPaymentState.paid => ViniiColors.greenSolid,
      OrderPaymentState.pendingVerification => ViniiColors.amberSolid,
      OrderPaymentState.unpaid => ViniiColors.redSolid,
    };

String queueRupees(int minor) =>
    '₹${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';

class QueuePill extends StatelessWidget {
  const QueuePill(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

/// One order in a queue.
class OrderQueueCard extends StatelessWidget {
  const OrderQueueCard({
    super.key,
    required this.order,
    required this.now,
    required this.statusLabel,
    required this.statusColor,
    required this.onView,
    this.delivery,
    this.primaryLabel,
    this.onPrimary,
    this.moreActions = const [],
  });
  final OpsOrder order;
  final DateTime now;

  /// The queue's own status for this order (e.g. "Ready for pickup").
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onView;
  final OpsDelivery? delivery;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Less common actions, in a "more" menu.
  final List<(String, VoidCallback)> moreActions;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final d = delivery;
    final items = o.lines.map((l) => '${l.quantity}x ${l.name}').join(', ');
    return Container(
        decoration: BoxDecoration(
            color: ViniiColors.lightBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: ViniiColors.lightBorder),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(o.number,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(formatClock(o.createdAt),
                style: const TextStyle(
                    fontSize: 12, color: ViniiColors.textMutedLight)),
            const Spacer(),
            Flexible(child: QueuePill(statusLabel.toUpperCase(), statusColor)),
          ]),
          const SizedBox(height: 6),
          Text(o.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(items.isEmpty ? 'No items' : items,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, color: ViniiColors.textSecondaryLight)),
          if (d != null) ...[
            const SizedBox(height: 2),
            Text(
                [
                  if (d.address.isNotEmpty) d.address,
                  d.riderName == null ? 'No rider' : 'Rider ${d.riderName}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: ViniiColors.textMutedLight)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            QueuePill(o.kitchenState.label, kitchenColor(o.kitchenState)),
            QueuePill(o.paymentLabel, paymentColor(o.paymentState)),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontSize: 10, color: ViniiColors.textMutedLight)),
                    Text(queueRupees(o.grandTotalMinor),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.greenSolid)),
                  ]),
            ),
            Text(formatAgo(o.createdAt, now),
                style: const TextStyle(
                    fontSize: 11, color: ViniiColors.textMutedLight)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: onView, child: const Text('View'))),
            if (primaryLabel != null) ...[
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 6)),
                      child: Text(primaryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)))),
            ],
            if (moreActions.isNotEmpty)
              PopupMenuButton<int>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (i) => moreActions[i].$2(),
                itemBuilder: (_) => [
                  for (var i = 0; i < moreActions.length; i++)
                    PopupMenuItem(value: i, child: Text(moreActions[i].$1)),
                ],
              ),
          ]),
        ]));
  }
}

/// Search box used on the queues.
class QueueSearchField extends StatelessWidget {
  const QueueSearchField(
      {super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        height: 38,
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
      );
}

/// "Not connected" state when a POS queue was built without the order
/// store.
class QueueNotConnected extends StatelessWidget {
  const QueueNotConnected({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
      color: ViniiColors.lightPageBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.link_off, size: 40, color: ViniiColors.textMutedLight),
        const SizedBox(height: 12),
        Text('$title — no order store is connected to this screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: ViniiColors.textMutedLight, fontSize: 14)),
      ]));
}
