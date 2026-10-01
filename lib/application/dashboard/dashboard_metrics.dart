/// Restaurant dashboard figures, computed only from records this device
/// holds (orders with their payment rows, kitchen tickets, raw materials) —
/// the same rows the POS and Operations screens write.
///
/// Every rule the dashboard shows is defined here, in one place. Payment
/// states are never re-invented: they come from [OpsOrder.paymentState]
/// (`derivePaymentState` in domain/payment.dart).
///
/// * **Period** — a [DashboardRange] is a half-open local-time span
///   `[start, end)`: Today = midnight → next midnight; Yesterday = the day
///   before; Last 7 days = today and the 6 days before it; This month = the
///   1st of this month → next midnight.
/// * **Paid order** — a non-cancelled order whose payment state is `paid`:
///   settled (cash, or a card/UPI payment an authorised user verified), or
///   a recorded cash payment. Its paid time is the settle time, else the
///   payment's recorded time, else the order's created time.
/// * **Sales** = Σ amount of orders **paid in the period** (by paid time).
///   The amount is the recorded payment amount when a payment row exists,
///   otherwise the bill's grand total (lines − discount + tax, exactly as
///   the bill shows it). Open, unpaid, pending-verification and cancelled
///   orders are never sales.
/// * **Settled orders** = count of those paid orders.
///   **AOV** = Sales ÷ settled orders, rounded to the nearest paisa; with no
///   settled orders there is no AOV (the screen shows "—").
/// * **Orders placed** = orders created in the period that are not
///   cancelled. **Cancelled** = orders created in the period and cancelled;
///   their bill value is reported separately and never counted as sales.
/// * **Payment split** = the period's sales grouped by the recorded payment
///   method (cash, UPI, card, split, other; "Not recorded" when none).
/// * **Pending verification** = non-cancelled orders whose payment state is
///   `pendingVerification`: a card / UPI / split payment was recorded but
///   not yet verified, so the order is not settled. Never counted as sales.
///   Shown per method for payments recorded in the period (created time
///   when there is no payment row), and as a live total for all of them.
/// * **Live now** (ignores the period): open orders (not billed, unpaid),
///   billed orders awaiting payment (no payment recorded), payments to
///   verify, and the combined bill value of all of these.
/// * **Kitchen** (live) = kitchen tickets by status. Delayed = New or
///   Preparing tickets older than [OpsKot.delayedAfterMinutes] minutes.
///   Served = tickets completed today, excluding cancelled orders.
/// * **Low stock** = active raw materials whose stock is at or below their
///   reorder level (reorder level > 0), plus anything with stock ≤ 0
///   (out of stock).
///
/// Money is always integer paise; [formatPaise] renders it with ₹ and
/// Indian digit grouping.
library;

import '../../domain/inventory.dart';
import '../../domain/operations.dart';

/// Date ranges offered on the dashboard.
enum DashboardRange { today, yesterday, last7Days, thisMonth }

extension DashboardRangeLabel on DashboardRange {
  String get label => switch (this) {
        DashboardRange.today => 'Today',
        DashboardRange.yesterday => 'Yesterday',
        DashboardRange.last7Days => 'Last 7 days',
        DashboardRange.thisMonth => 'This month',
      };
}

/// A half-open local-time span `[start, end)`.
class DateSpan {
  const DateSpan(this.start, this.end);

  /// Inclusive.
  final DateTime start;

  /// Exclusive.
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// The span [range] covers on the local calendar of [now].
  static DateSpan of(DashboardRange range, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (range) {
      DashboardRange.today => DateSpan(today, tomorrow),
      DashboardRange.yesterday =>
        DateSpan(DateTime(now.year, now.month, now.day - 1), today),
      DashboardRange.last7Days =>
        DateSpan(DateTime(now.year, now.month, now.day - 6), tomorrow),
      DashboardRange.thisMonth =>
        DateSpan(DateTime(now.year, now.month, 1), tomorrow),
    };
  }
}

/// Sales and pending-verification amounts of one payment method.
class PaymentMethodTotal {
  PaymentMethodTotal(this.key);

  /// Normalised method key — see [DashboardMetrics.methodKey].
  final String key;
  int settledMinor = 0;
  int settledCount = 0;
  int pendingMinor = 0;
  int pendingCount = 0;

  String get label => DashboardMetrics.methodLabel(key);
}

/// Kitchen tickets by status (live).
class KitchenSummary {
  const KitchenSummary({
    this.newTickets = 0,
    this.preparing = 0,
    this.ready = 0,
    this.delayed = 0,
    this.servedToday = 0,
  });
  final int newTickets;
  final int preparing;
  final int ready;
  final int delayed;
  final int servedToday;

  /// Tickets the kitchen still has to finish or hand over.
  int get active => newTickets + preparing + ready;
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.range,
    required this.span,
    required this.salesMinor,
    required this.settledCount,
    required this.placedCount,
    required this.cancelledCount,
    required this.cancelledMinor,
    required this.paymentMethods,
    required this.pendingVerificationMinor,
    required this.pendingVerificationCount,
    required this.openCount,
    required this.billedCount,
    required this.openValueMinor,
    required this.livePendingVerificationMinor,
    required this.livePendingVerificationCount,
    required this.kitchen,
    required this.lowStock,
    required this.outOfStockCount,
  });

  final DashboardRange range;
  final DateSpan span;

  // ── the period ──
  final int salesMinor;
  final int settledCount;
  final int placedCount;
  final int cancelledCount;
  final int cancelledMinor;

  /// Sales per payment method, largest first; methods that only have
  /// pending-verification amounts are included too.
  final List<PaymentMethodTotal> paymentMethods;

  /// Card / UPI / split payments recorded in the period, not yet verified.
  final int pendingVerificationMinor;
  final int pendingVerificationCount;

  /// Sales ÷ settled orders, rounded to the nearest paisa; null without
  /// settled orders.
  int? get aovMinor =>
      settledCount == 0 ? null : (salesMinor / settledCount).round();

  // ── live now ──
  /// Unpaid orders not billed yet.
  final int openCount;

  /// Billed orders with no payment recorded.
  final int billedCount;

  /// Bill value of every order not yet paid (open, billed, pending).
  final int openValueMinor;
  final int livePendingVerificationMinor;
  final int livePendingVerificationCount;
  final KitchenSummary kitchen;

  /// Materials at or below their reorder level (or out of stock), the most
  /// urgent first.
  final List<RawMaterial> lowStock;
  final int outOfStockCount;

  /// Anything happened in the period (orders placed, paid or cancelled).
  bool get hasPeriodActivity =>
      settledCount > 0 || placedCount > 0 || cancelledCount > 0;

  /// Normalised payment-method key: `cash`, `upi`, `card`, `split`,
  /// `unrecorded` (no method), or the method itself in lower case.
  static String methodKey(String? method) {
    final m = method?.trim().toLowerCase() ?? '';
    if (m.isEmpty) return 'unrecorded';
    if (m.startsWith('split')) return 'split';
    if (m == 'cash') return 'cash';
    if (m.contains('upi')) return 'upi';
    if (m.contains('card')) return 'card';
    return m;
  }

  static String methodLabel(String key) => switch (key) {
        'cash' => 'Cash',
        'upi' => 'UPI',
        'card' => 'Card',
        'split' => 'Split',
        'unrecorded' => 'Not recorded',
        _ => key.isEmpty ? key : key[0].toUpperCase() + key.substring(1),
      };

  /// At or below the reorder level (reorder level > 0), or out of stock.
  static bool isLowStock(RawMaterial m) =>
      m.stockQty <= 0 || (m.reorderLevel > 0 && m.stockQty <= m.reorderLevel);

  static DashboardMetrics compute({
    required List<OpsOrder> orders,
    List<OpsKot> kots = const [],
    List<RawMaterial> materials = const [],
    required DashboardRange range,
    required DateTime now,
  }) {
    final span = DateSpan.of(range, now);
    final methods = <String, PaymentMethodTotal>{};
    PaymentMethodTotal bucket(String key) =>
        methods.putIfAbsent(key, () => PaymentMethodTotal(key));

    var sales = 0, settled = 0, placed = 0, cancelled = 0, cancelledValue = 0;
    var pending = 0, pendingCount = 0;
    var open = 0, billed = 0, openValue = 0;
    var livePending = 0, livePendingCount = 0;

    for (final o in orders) {
      final pay = o.payment;
      final method = pay?.method ?? o.paymentMethod;
      final key = methodKey(method);
      final amount = pay?.amountMinor ?? o.grandTotalMinor;

      if (o.status == OpsOrderStatus.cancelled) {
        if (span.contains(o.createdAt)) {
          cancelled++;
          cancelledValue += o.grandTotalMinor;
        }
        continue;
      }
      if (span.contains(o.createdAt)) placed++;

      switch (o.paymentState) {
        case OrderPaymentState.paid:
          final paidAt = o.settledAt ?? pay?.recordedAt ?? o.createdAt;
          if (span.contains(paidAt)) {
            sales += amount;
            settled++;
            bucket(key)
              ..settledMinor += amount
              ..settledCount += 1;
          }
        case OrderPaymentState.pendingVerification:
          openValue += amount;
          livePending += amount;
          livePendingCount++;
          if (span.contains(pay?.recordedAt ?? o.createdAt)) {
            pending += amount;
            pendingCount++;
            bucket(key)
              ..pendingMinor += amount
              ..pendingCount += 1;
          }
        case OrderPaymentState.unpaid:
          openValue += o.grandTotalMinor;
          if (o.status == OpsOrderStatus.billed) {
            billed++;
          } else {
            open++;
          }
      }
    }

    final methodList = methods.values.toList()
      ..sort((a, b) {
        final bySales = b.settledMinor.compareTo(a.settledMinor);
        return bySales != 0
            ? bySales
            : b.pendingMinor.compareTo(a.pendingMinor);
      });

    var newT = 0, prep = 0, ready = 0, delayed = 0, served = 0;
    for (final k in kots) {
      if (k.order.status == OpsOrderStatus.cancelled) continue;
      switch (k.status) {
        case OpsKotStatus.newTicket:
          newT++;
        case OpsKotStatus.preparing:
          prep++;
        case OpsKotStatus.ready:
          ready++;
        case OpsKotStatus.completed:
          served++;
      }
      if (k.isDelayed(now)) delayed++;
    }

    final low = materials.where(isLowStock).toList()
      ..sort((a, b) {
        final aOut = a.stockQty <= 0, bOut = b.stockQty <= 0;
        if (aOut != bOut) return aOut ? -1 : 1;
        double ratio(RawMaterial m) =>
            m.reorderLevel > 0 ? m.stockQty / m.reorderLevel : 0;
        final byRatio = ratio(a).compareTo(ratio(b));
        return byRatio != 0 ? byRatio : a.name.compareTo(b.name);
      });

    return DashboardMetrics(
      range: range,
      span: span,
      salesMinor: sales,
      settledCount: settled,
      placedCount: placed,
      cancelledCount: cancelled,
      cancelledMinor: cancelledValue,
      paymentMethods: methodList,
      pendingVerificationMinor: pending,
      pendingVerificationCount: pendingCount,
      openCount: open,
      billedCount: billed,
      openValueMinor: openValue,
      livePendingVerificationMinor: livePending,
      livePendingVerificationCount: livePendingCount,
      kitchen: KitchenSummary(
        newTickets: newT,
        preparing: prep,
        ready: ready,
        delayed: delayed,
        servedToday: served,
      ),
      lowStock: low,
      outOfStockCount: low.where((m) => m.stockQty <= 0).length,
    );
  }
}

/// "1,23,45,678" — Indian digit grouping (last three digits, then pairs).
String groupIndian(int n) {
  final s = n.abs().toString();
  final sign = n < 0 ? '-' : '';
  if (s.length <= 3) return '$sign$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '$sign${groups.join(',')},$last3';
}

/// "₹1,23,456.78" from paise; the paise are left out when they are zero
/// unless [alwaysShowPaise].
String formatPaise(int minor, {bool alwaysShowPaise = false}) {
  final negative = minor < 0;
  final abs = minor.abs();
  final paise = abs % 100;
  final fraction = paise != 0 || alwaysShowPaise
      ? '.${paise.toString().padLeft(2, '0')}'
      : '';
  return '${negative ? '-' : ''}₹${groupIndian(abs ~/ 100)}$fraction';
}

/// "12", "12.5", "0.25" — a stock quantity without trailing zeros.
String formatQty(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}
