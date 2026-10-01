import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_operations_store.dart';
import '../../domain/operations.dart';
import '../../domain/receipt.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

/// Dialogs shared by the POS and Operations order screens: the reason
/// prompt every correction needs, payment verification, and the on-screen
/// bill preview (no receipt printer is connected).

/// Read-only details of an order (items, totals, kitchen, payment,
/// delivery, history) with its safe actions: view the bill, cancel with a
/// reason (open orders without a payment), and [onOpenOrder] to continue
/// it in the order screen.
Future<void> showOrderDetailsDialog(BuildContext context,
        {required DriftOperationsStore ops,
        required String orderId,
        OpsDelivery? delivery,
        ValueChanged<String>? onOpenOrder}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _OrderDetails(
            ops: ops,
            orderId: orderId,
            delivery: delivery,
            onOpenOrder: onOpenOrder));

class _OrderDetails extends StatefulWidget {
  const _OrderDetails(
      {required this.ops,
      required this.orderId,
      this.delivery,
      this.onOpenOrder});
  final DriftOperationsStore ops;
  final String orderId;
  final OpsDelivery? delivery;
  final ValueChanged<String>? onOpenOrder;

  @override
  State<_OrderDetails> createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<_OrderDetails> {
  late final Stream<OpsOrder?> _order = widget.ops.watchOrder(widget.orderId);
  String? _error;

  Future<void> _cancel(OpsOrder o) async {
    final reason = await showReasonDialog(context,
        title: 'Cancel ${o.number}?',
        message: 'The order is cancelled'
            '${o.sentToKitchen ? ' and the kitchen sees it as "Order cancelled"' : ''}. '
            'This is recorded in the order history.',
        confirm: 'Cancel Order',
        suggestions: const ['Guest left', 'Duplicate order']);
    if (reason == null || !mounted) return;
    try {
      await widget.ops.cancelOrder(o.id, reason: reason);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<OpsOrder?>(
      stream: _order,
      builder: (context, snap) {
        final o = snap.data;
        Widget row(String l, String r, {bool bold = false, Color? color}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                    child: Text(l,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                bold ? FontWeight.w700 : FontWeight.w400))),
                Text(r,
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
              ]),
            );
        final d = widget.delivery;
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(o == null
              ? 'Order details'
              : '${o.number} · ${o.displayName}'),
          content: SizedBox(
            width: 460,
            child: o == null
                ? (snap.connectionState == ConnectionState.waiting
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()))
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('This order was not found on this device.')))
                : SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${o.channel.label} · ${o.source} · placed '
                              '${formatClock(o.createdAt)} · ${o.status.label}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ViniiColors.textSecondaryLight)),
                          if (d != null) ...[
                            const SizedBox(height: 4),
                            Text(
                                'Delivery · ${d.status.label}'
                                '${d.riderName != null ? ' · Rider ${d.riderName}' : ''}'
                                '${d.address.isNotEmpty ? ' · ${d.address}' : ''}',
                                style: const TextStyle(fontSize: 12.5)),
                          ],
                          const Divider(height: 20),
                          for (final l in o.lines)
                            row('${l.quantity} × ${l.name}',
                                _inr(l.totalMinor)),
                          if (o.lines.isEmpty) const Text('No items'),
                          const Divider(height: 16),
                          row('Subtotal', _inr(o.subtotalMinor)),
                          if (o.discountMinor > 0)
                            row('Discount (${o.discountPct.toStringAsFixed(o.discountPct == o.discountPct.roundToDouble() ? 0 : 1)}%)',
                                '-${_inr(o.discountMinor)}'),
                          row('GST (${o.taxPct.toStringAsFixed(o.taxPct == o.taxPct.roundToDouble() ? 0 : 1)}%)',
                              _inr(o.taxMinor)),
                          row('Total', _inr(o.grandTotalMinor), bold: true),
                          row('Payment', o.paymentLabel,
                              color: switch (o.paymentState) {
                                OrderPaymentState.paid =>
                                  ViniiColors.greenSolid,
                                OrderPaymentState.pendingVerification =>
                                  ViniiColors.amberSolid,
                                OrderPaymentState.unpaid =>
                                  ViniiColors.redSolid,
                              }),
                          row('Kitchen', o.kitchenState.label),
                          if (o.billNo != null) row('Bill no.', '${o.billNo}'),
                          if (o.notes.isNotEmpty) ...[
                            const Divider(height: 16),
                            Text('Notes: ${o.notes}'),
                          ],
                          if (o.auditLog.isNotEmpty) ...[
                            const Divider(height: 16),
                            const Text('History',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            for (final e in o.auditLog)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                    '${formatClock(e.at)}${e.actor.isEmpty ? '' : ' · ${e.actor}'} — ${e.text}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: ViniiColors.textSecondaryLight)),
                              ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    color: ViniiColors.redSolid,
                                    fontSize: 12.5)),
                          ],
                        ]),
                  ),
          ),
          actions: [
            if (o != null &&
                o.isActive &&
                o.payment == null &&
                o.status == OpsOrderStatus.open)
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: ViniiColors.redSolid),
                  onPressed: () => _cancel(o),
                  child: const Text('Cancel Order')),
            if (o != null)
              TextButton(
                  onPressed: () => showBillPreview(context,
                      ops: widget.ops,
                      orderId: o.id,
                      actorName: widget.ops.actorName),
                  child: const Text('View Bill')),
            if (o != null && o.isActive && widget.onOpenOrder != null)
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpenOrder!(o.id);
                  },
                  child: const Text('Open Order')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: ViniiColors.brandGreen,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      });
}

/// Asks for the reason of a correction (cancel, void, discount). Returns
/// the trimmed reason, or null when the user backed out.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String label = 'Reason',
  String confirm = 'Confirm',
  bool destructive = true,
  List<String> suggestions = const [],
}) =>
    showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(
            title: title,
            message: message,
            label: label,
            confirm: confirm,
            destructive: destructive,
            suggestions: suggestions));

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(
      {required this.title,
      required this.message,
      required this.label,
      required this.confirm,
      required this.destructive,
      required this.suggestions});
  final String title, message, label, confirm;
  final bool destructive;
  final List<String> suggestions;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'A reason is required — it is kept in the '
          'order history.');
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
          width: 380,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.message),
                const SizedBox(height: 12),
                TextField(
                  controller: _c,
                  autofocus: true,
                  maxLines: 2,
                  minLines: 1,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                      labelText: widget.label,
                      errorText: _error,
                      errorMaxLines: 2,
                      border: const OutlineInputBorder()),
                ),
                if (widget.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in widget.suggestions)
                      ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() {
                                _c.text = s;
                                _error = null;
                              })),
                  ]),
                ],
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: widget.destructive
                      ? ViniiColors.redSolid
                      : ViniiColors.greenSolid),
              onPressed: _submit,
              child: Text(widget.confirm)),
        ],
      );
}

/// Confirms verification of a card / UPI / split payment. Returns the
/// (possibly empty) note, or null when cancelled.
Future<String?> showVerifyPaymentDialog(BuildContext context, OpsOrder o) =>
    showDialog<String>(
        context: context, builder: (_) => _VerifyDialog(order: o));

class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog({required this.order});
  final OpsOrder order;

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final p = o.payment;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text('Verify payment for ${o.number}?'),
      content: SizedBox(
        width: 400,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p == null
                  ? 'No payment is recorded.'
                  : '${paymentMethodLabel(p.method)} · '
                      '${_inr(p.amountMinor)} recorded ${formatClock(p.recordedAt)}.'),
              const SizedBox(height: 8),
              const Text(
                  'Only verify after you have seen the money arrive (bank / '
                  'UPI app or card settlement). Verifying settles the order '
                  'and is recorded in its history with your name.',
                  style: TextStyle(
                      fontSize: 12.5, color: ViniiColors.textSecondaryLight)),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                    labelText: 'Reference / note (optional)',
                    hintText: 'e.g. UPI ref 4829…',
                    border: OutlineInputBorder()),
              ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: ViniiColors.greenSolid),
            onPressed: () => Navigator.pop(context, _note.text.trim()),
            child: const Text('Verify Payment')),
      ],
    );
  }
}

String _inr(int minor) {
  final v = minor.abs();
  final paise = v % 100;
  return '${minor < 0 ? '-' : ''}₹${v ~/ 100}'
      '${paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}'}';
}

/// On-screen bill preview for [orderId] (lines, discount, tax, total and
/// payment state). Physical printing is not connected: the dialog says so
/// and never reports a print as done. "Reprint" records a reprint entry in
/// the order's audit trail; "Copy text" puts the bill on the clipboard.
Future<void> showBillPreview(BuildContext context,
        {required DriftOperationsStore ops,
        required String orderId,
        String? actorName}) =>
    showDialog<void>(
        context: context,
        builder: (_) =>
            _BillPreview(ops: ops, orderId: orderId, actorName: actorName));

class _BillPreview extends StatefulWidget {
  const _BillPreview(
      {required this.ops, required this.orderId, this.actorName});
  final DriftOperationsStore ops;
  final String orderId;
  final String? actorName;

  @override
  State<_BillPreview> createState() => _BillPreviewState();
}

class _BillPreviewState extends State<_BillPreview> {
  late final Stream<OpsOrder?> _order = widget.ops.watchOrder(widget.orderId);
  String? _message;
  bool _busy = false;

  Future<void> _reprint() async {
    setState(() => _busy = true);
    try {
      await widget.ops.recordReprint(widget.orderId, by: widget.actorName);
      if (mounted) {
        setState(() => _message = 'Reprint recorded in the order history. '
            'Printing is not connected — nothing was printed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Could not record: ${friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<OpsOrder?>(
      stream: _order,
      builder: (context, snap) {
        final o = snap.data;
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(o == null
              ? 'Bill preview'
              : (o.billNo == null
                  ? 'Draft bill · ${o.number}'
                  : 'Bill #${o.billNo} · ${o.number}')),
          content: SizedBox(
            width: 420,
            child: o == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: ViniiColors.amberTint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: ViniiColors.amberSolid
                                        .withValues(alpha: 0.4))),
                            child: const Text(
                                'On-screen preview only — no receipt printer '
                                'is connected, so nothing is printed.',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: ViniiColors.amberSolid,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: ViniiColors.lightBorder)),
                            child: SelectableText(receiptText(o),
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    height: 1.35)),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 10),
                            Text(_message!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: ViniiColors.greenSolid)),
                          ],
                        ]),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: o == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                            ClipboardData(text: receiptText(o)));
                        if (mounted) {
                          setState(() =>
                              _message = 'Bill text copied to clipboard.');
                        }
                      },
                child: const Text('Copy text')),
            TextButton(
                onPressed: o == null || _busy ? null : _reprint,
                child: const Text('Reprint')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: ViniiColors.brandGreen,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      });
}
