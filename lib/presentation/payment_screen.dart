// Rebuilt 1:1 from v1/POS-PAYMENT-DEFAULT.png and v1/POS-PAYMENT-V3.png
// (light/dark pair) — see Q02 in docs/DECISIONS-AND-QUESTIONS.txt. One
// real nuance the reference has that a naive theme flip would miss: the
// order-recap column on the left stays light in BOTH screens — only the
// payment-method column on the right goes dark in V3. Reproduced with
// an explicit light-styled Container on the left rather than inheriting
// the ambient theme.
//
// Only Cash is wired to actually complete — PRD §9: "A screenshot,
// manually entered UPI reference or offline 'paid' tap is not provider
// verification." Card/UPI/Split Pay are shown (matching the reference)
// but refuse to complete here, since accepting them would misrepresent
// an unverified tap as a confirmed digital payment. (Operations → POS
// Billing records them as "pending verification" for a manager to
// verify.)
//
// Completing a cash payment records the payment AND settles the order in
// one transaction through the Operations store (the same orders /
// payments / tables rows Operations uses): the order is closed, its
// table is released for cleaning and its All Orders row (linked by order
// id) shows Completed — so Operations cannot settle it a second time.
//
// Service Charge, coupons and Add Tip appear in the reference but there
// is no real service-charge/promotion/tip feature — those rows are left
// out rather than faked. Subtotal, the order's discount (if any), GST at
// the order's stored rate and the Total are shown.
//
// "Print Bill" opens the on-screen bill preview: no receipt printer is
// connected, and the screen says so instead of claiming a print.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/drift_operations_store.dart';
import '../domain/operations.dart';
import 'operations/ops_order_dialogs.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

enum _PaymentMethod { cash, card, upi, split }

String _rupees(int minor, {int decimals = 2}) =>
    '₹${(minor / 100).toStringAsFixed(decimals)}';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.ops, required this.orderId});

  /// The Operations store — orders, payments and tables are shared with
  /// Operations, so a bill paid here is closed everywhere.
  final DriftOperationsStore ops;

  /// The order to pay (its id, for the lookup). People see the order's
  /// number ([OpsOrder.number]), never this id.
  final String orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Stream<OpsOrder?> _order$ = widget.ops.watchOrder(widget.orderId);
  _PaymentMethod _method = _PaymentMethod.cash;
  bool _completing = false;

  // Rupees (what the cashier types), not paise; filled once the order
  // total is known.
  final _amountController = TextEditingController();
  bool _amountPrefilled = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _amountReceivedMinor {
    final rupees = double.tryParse(_amountController.text.trim());
    return rupees == null ? null : (rupees * 100).round();
  }

  void _selectMethod(_PaymentMethod m) {
    if (m != _PaymentMethod.cash) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_methodLabel(m)} needs provider verification, '
              'which isn\'t connected — take cash here, or record it in '
              'Operations → POS Billing, where it stays pending '
              'verification until a manager verifies it.')));
      return;
    }
    setState(() => _method = m);
  }

  Future<void> _completePayment(OpsOrder order) async {
    final received = _amountReceivedMinor;
    final total = order.grandTotalMinor;
    if (received == null || received < total) return;
    setState(() => _completing = true);
    try {
      // One transaction: payment row + order settled + table released +
      // All Orders row. Bounded, like the order save: a local write
      // should never take long.
      await widget.ops
          .settleOrder(order.id, 'cash', receivedMinor: received)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
          content: Text('${order.number} paid in cash — ${_rupees(total)}, '
              'change ${_rupees(received - total)}. Order closed.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is TimeoutException
                ? 'Saving is taking too long — the local database may be unavailable. Please try again.'
                : 'Could not record the payment: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  static String _methodLabel(_PaymentMethod m) => switch (m) {
        _PaymentMethod.cash => 'Cash',
        _PaymentMethod.card => 'Card',
        _PaymentMethod.upi => 'UPI / QR',
        _PaymentMethod.split => 'Split Pay',
      };

  @override
  Widget build(BuildContext context) => StreamBuilder<OpsOrder?>(
      stream: _order$,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text('Payment')),
              body: Center(
                  child: Text(
                      'Could not load the order: ${friendlyError(snap.error!)}')));
        }
        final order = snap.data;
        if (order == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Payment')),
              body: Center(
                  child: snap.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : const Text('This order was not found.')));
        }
        if (!_amountPrefilled) {
          _amountPrefilled = true;
          _amountController.text =
              (order.grandTotalMinor / 100).toStringAsFixed(0);
          if (_amountReceivedMinor != null &&
              _amountReceivedMinor! < order.grandTotalMinor) {
            _amountController.text =
                (order.grandTotalMinor / 100).ceil().toString();
          }
        }
        return _buildFor(order);
      });

  Widget _buildFor(OpsOrder order) {
    final total = order.grandTotalMinor;
    final received = _amountReceivedMinor;
    final change = received == null ? null : received - total;
    final closed = order.payment != null ||
        order.status == OpsOrderStatus.settled ||
        order.status == OpsOrderStatus.cancelled;
    final canComplete = !closed &&
        order.lines.isNotEmpty &&
        change != null &&
        change >= 0 &&
        _method == _PaymentMethod.cash;

    return Scaffold(
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 3, child: _OrderRecap(order: order)),
        SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 4),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('PAYMENT SCREEN',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey, letterSpacing: 1)),
                  Text('Select Method',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              ]),
              const SizedBox(height: 16),
              if (closed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: ViniiColors.amberTint,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      order.status == OpsOrderStatus.cancelled
                          ? 'This order was cancelled — it takes no payment.'
                          : 'Payment already recorded: ${order.paymentLabel}. '
                              'A payment is never recorded twice.',
                      style: const TextStyle(
                          color: ViniiColors.amberSolid,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
              ],
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  for (final (m, icon) in const [
                    (_PaymentMethod.cash, Icons.payments_outlined),
                    (_PaymentMethod.card, Icons.credit_card),
                    (_PaymentMethod.upi, Icons.qr_code),
                    (_PaymentMethod.split, Icons.call_split),
                  ])
                    _MethodTile(
                        icon: icon,
                        label: _methodLabel(m),
                        selected: _method == m,
                        onTap: () => _selectMethod(m)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('AMOUNT RECEIVED',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                enabled: !closed,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                    prefixText: '₹', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const Text('Quick Amounts',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (label, minor) in [
                  ('${_rupees(total, decimals: 0)} (Exact)', total),
                  ('₹${(total / 100 + 100).toStringAsFixed(0)}', total + 10000),
                  ('₹${(total / 100 + 300).toStringAsFixed(0)}', total + 30000),
                ])
                  _QuickAmountChip(
                      label: label,
                      minor: minor,
                      controller: _amountController,
                      onPicked: closed ? null : () => setState(() {})),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Change Due',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(change == null ? '—' : _rupees(change),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: change != null && change < 0
                            ? ViniiColors.redSolid
                            : ViniiColors.greenSolid)),
              ]),
              const Spacer(),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: canComplete && !_completing
                          ? () => _completePayment(order)
                          : null,
                      style: FilledButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          padding: const EdgeInsets.all(16)),
                      child: Text('Complete Cash Payment ${_rupees(total)}',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)))),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => showBillPreview(context,
                          ops: widget.ops,
                          orderId: order.id,
                          actorName: widget.ops.actorName),
                      child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Print Bill (preview)')))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OrderRecap extends StatelessWidget {
  const _OrderRecap({required this.order});
  final OpsOrder order;

  String _pct(double p) =>
      p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    // Deliberately light regardless of app theme — matches both
    // reference screens, where this column never goes dark.
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black87),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(
                  'Order ${order.number}${order.tableLabel != null ? ' — ${order.tableLabel}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: ViniiColors.greenTint,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(order.channel.label,
                    style: const TextStyle(
                        color: ViniiColors.brandGreen, fontSize: 12))),
          ]),
          if (order.billNo != null) ...[
            const SizedBox(height: 4),
            Text('Bill #${order.billNo}',
                style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE3E5EB)),
                borderRadius: BorderRadius.circular(10)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ORDER ITEMS',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 10),
              for (final line in order.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text('${line.quantity}× ',
                        style: const TextStyle(
                            color: ViniiColors.greenSolid,
                            fontWeight: FontWeight.bold)),
                    Expanded(child: Text(line.name)),
                    Text(_rupees(line.totalMinor,
                        decimals: line.totalMinor % 100 == 0 ? 0 : 2)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE3E5EB)),
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              _totalsRow('Subtotal', order.subtotalMinor),
              if (order.discountMinor > 0)
                _totalsRow('Discount (${_pct(order.discountPct)}%)',
                    -order.discountMinor),
              _totalsRow('GST (${_pct(order.taxPct)}%)', order.taxMinor),
              const Divider(),
              _totalsRow('Total Amount', order.grandTotalMinor, bold: true),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _totalsRow(String label, int minor, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(
              minor < 0
                  ? '-${_rupees(-minor)}'
                  : _rupees(minor, decimals: bold && minor % 100 == 0 ? 0 : 2),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 20 : 14)),
        ]),
      );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(
                color: selected
                    ? ViniiColors.brandGreen
                    : Theme.of(context).dividerColor,
                width: selected ? 2 : 1),
            color:
                selected ? ViniiColors.greenTint.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? ViniiColors.brandGreen : Colors.grey),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? ViniiColors.brandGreen : null)),
        ]),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip(
      {required this.label,
      required this.minor,
      required this.controller,
      required this.onPicked});
  final String label;
  final int minor;
  final TextEditingController controller;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final isSelected =
        controller.text.trim() == (minor / 100).toStringAsFixed(0) ||
            controller.text.trim() == (minor / 100).toString();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: ViniiColors.brandGreen,
      labelStyle: TextStyle(color: isSelected ? Colors.black : null),
      onSelected: onPicked == null
          ? null
          : (_) {
              controller.text = (minor / 100).toStringAsFixed(0);
              onPicked!();
            },
    );
  }
}
