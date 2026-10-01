import 'operations.dart';

/// Plain-text bill for an order, as shown in the on-screen bill preview
/// and copied to the clipboard. No receipt printer is connected, so this
/// text is never claimed to have been printed.
///
/// Money in integer paise throughout; tax is the order's stored GST %
/// applied to the discounted subtotal (see [OpsOrder.taxMinor]).
String receiptText(OpsOrder o, {String header = '', DateTime? now}) {
  String money(int minor) {
    final neg = minor < 0;
    final v = minor.abs();
    return '${neg ? '-' : ''}₹${v ~/ 100}.${(v % 100).toString().padLeft(2, '0')}';
  }

  String pct(double p) =>
      p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);

  String row(String left, String right, {int width = 40}) {
    final gap = width - left.length - right.length;
    return gap >= 1 ? '$left${' ' * gap}$right' : '$left $right';
  }

  final b = StringBuffer();
  if (header.trim().isNotEmpty) b.writeln(header.trim());
  b.writeln(
      o.billNo == null ? 'DRAFT BILL (no bill no. yet)' : 'Bill #${o.billNo}');
  b.writeln('Order ${o.number} · ${o.channel.label}'
      '${o.tableLabel != null ? ' · ${o.tableLabel}' : ''}');
  if (o.customerName.isNotEmpty) b.writeln('Customer: ${o.customerName}');
  final at = o.createdAt;
  b.writeln('Placed ${at.day.toString().padLeft(2, '0')}/'
      '${at.month.toString().padLeft(2, '0')}/${at.year} ${formatClock(at)}');
  b.writeln('-' * 40);
  for (final l in o.lines) {
    b.writeln(row('${l.quantity} x ${l.name}', money(l.totalMinor)));
  }
  b.writeln('-' * 40);
  b.writeln(row('Subtotal', money(o.subtotalMinor)));
  if (o.discountMinor != 0) {
    b.writeln(
        row('Discount (${pct(o.discountPct)}%)', money(-o.discountMinor)));
  }
  b.writeln(row('GST (${pct(o.taxPct)}%)', money(o.taxMinor)));
  b.writeln(row('TOTAL', money(o.grandTotalMinor)));
  b.writeln('-' * 40);
  b.writeln('Payment: ${o.paymentLabel}');
  final p = o.payment;
  if (p != null && p.receivedMinor > p.amountMinor) {
    b.writeln(row('Received', money(p.receivedMinor)));
    b.writeln(row('Change', money(p.receivedMinor - p.amountMinor)));
  }
  if (o.status == OpsOrderStatus.cancelled) b.writeln('ORDER CANCELLED');
  if (now != null) b.writeln('Preview generated ${formatClock(now)}');
  return b.toString().trimRight();
}
