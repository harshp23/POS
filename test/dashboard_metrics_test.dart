import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/application/dashboard/dashboard_metrics.dart';
import 'package:proviyaa_pos/domain/inventory.dart';
import 'package:proviyaa_pos/domain/operations.dart';

/// 29 Sep 2026, 1 pm.
final now = DateTime(2026, 9, 29, 13);

OpsPaymentRecord payment(String method, int amountMinor, {DateTime? at}) =>
    OpsPaymentRecord(
      paymentId: 'PAY',
      method: method,
      amountMinor: amountMinor,
      receivedMinor: amountMinor,
      recordedAt: at ?? now,
    );

/// One line of [unitMinor]; no tax unless given, so grand total ==
/// [unitMinor].
OpsOrder order(
  String id, {
  required OpsOrderStatus status,
  int unitMinor = 10000,
  DateTime? createdAt,
  DateTime? settledAt,
  String? paymentMethod,
  OpsPaymentRecord? payment,
  double taxPct = 0,
  double discountPct = 0,
}) =>
    OpsOrder(
      id: id,
      channel: OpsChannel.takeaway,
      status: status,
      createdAt: createdAt ?? now.subtract(const Duration(hours: 1)),
      settledAt: settledAt,
      paymentMethod: paymentMethod ?? payment?.method,
      payment: payment,
      taxPct: taxPct,
      discountPct: discountPct,
      lines: [
        OpsOrderLine(
            itemId: 'i-$id', name: 'Item', unitMinor: unitMinor, quantity: 1),
      ],
    );

/// A settled order paid with [method] at [at] (default: now).
OpsOrder paid(String id, String method, int minor, {DateTime? at}) => order(id,
    status: OpsOrderStatus.settled,
    unitMinor: minor,
    settledAt: at ?? now,
    payment: payment(method, minor, at: at));

RawMaterial material(String name, double stock, double reorder) => RawMaterial(
      id: name,
      code: name,
      name: name,
      category: 'Dairy',
      unit: 'kg',
      stockQty: stock,
      reorderLevel: reorder,
      maxCapacity: 100,
      purchaseCostPerUnit: 100,
      preferredSupplierId: '',
      status: stockStatusFor(stock, reorder),
    );

DashboardMetrics compute(List<OpsOrder> orders,
        {List<OpsKot> kots = const [],
        List<RawMaterial> materials = const [],
        DashboardRange range = DashboardRange.today}) =>
    DashboardMetrics.compute(
        orders: orders,
        kots: kots,
        materials: materials,
        range: range,
        now: now);

void main() {
  group('date ranges', () {
    test('today, yesterday, last 7 days and this month are local days', () {
      DateSpan span(DashboardRange r) => DateSpan.of(r, now);
      expect(span(DashboardRange.today).start, DateTime(2026, 9, 29));
      expect(span(DashboardRange.today).end, DateTime(2026, 9, 30));
      expect(span(DashboardRange.yesterday).start, DateTime(2026, 9, 28));
      expect(span(DashboardRange.yesterday).end, DateTime(2026, 9, 29));
      expect(span(DashboardRange.last7Days).start, DateTime(2026, 9, 23));
      expect(span(DashboardRange.last7Days).end, DateTime(2026, 9, 30));
      expect(span(DashboardRange.thisMonth).start, DateTime(2026, 9, 1));
      expect(span(DashboardRange.thisMonth).end, DateTime(2026, 9, 30));
    });

    test('spans cross month boundaries and exclude their end', () {
      final first = DateTime(2026, 10, 1, 9);
      expect(DateSpan.of(DashboardRange.yesterday, first).start,
          DateTime(2026, 9, 30));
      expect(DateSpan.of(DashboardRange.last7Days, first).start,
          DateTime(2026, 9, 25));
      expect(DateSpan.of(DashboardRange.thisMonth, first).start,
          DateTime(2026, 10, 1));
      final today = DateSpan.of(DashboardRange.today, now);
      expect(today.contains(DateTime(2026, 9, 29)), isTrue);
      expect(today.contains(DateTime(2026, 9, 29, 23, 59, 59)), isTrue);
      expect(today.contains(DateTime(2026, 9, 30)), isFalse);
      expect(today.contains(DateTime(2026, 9, 28, 23, 59)), isFalse);
    });

    test('an order settled yesterday is yesterday\'s sale, not today\'s', () {
      final orders = [
        paid('A', 'cash', 50000, at: DateTime(2026, 9, 28, 21)),
      ];
      expect(compute(orders).salesMinor, 0);
      expect(
          compute(orders, range: DashboardRange.yesterday).salesMinor, 50000);
      expect(
          compute(orders, range: DashboardRange.last7Days).salesMinor, 50000);
      expect(
          compute(orders, range: DashboardRange.thisMonth).salesMinor, 50000);
    });

    test('sales follow the settle time, not the order time', () {
      final orders = [
        order('A',
            status: OpsOrderStatus.settled,
            createdAt: DateTime(2026, 9, 28, 23, 50),
            settledAt: DateTime(2026, 9, 29, 0, 10),
            payment: payment('cash', 10000, at: DateTime(2026, 9, 29, 0, 10))),
      ];
      final today = compute(orders);
      expect(today.salesMinor, 10000);
      expect(today.placedCount, 0, reason: 'placed yesterday');
    });
  });

  group('sales, orders and AOV', () {
    test('only paid orders are sales; cancelled are reported apart', () {
      final m = compute([
        paid('S1', 'cash', 30000),
        paid('S2', 'upi', 20001),
        order('O1', status: OpsOrderStatus.open, unitMinor: 99900),
        order('B1', status: OpsOrderStatus.billed, unitMinor: 45000),
        order('C1', status: OpsOrderStatus.cancelled, unitMinor: 70000),
      ]);
      expect(m.salesMinor, 50001);
      expect(m.settledCount, 2);
      expect(m.aovMinor, 25001, reason: '50001 / 2 = 25000.5 rounds up');
      expect(m.placedCount, 4, reason: 'cancelled orders are not placed');
      expect(m.cancelledCount, 1);
      expect(m.cancelledMinor, 70000);
      expect(m.openCount, 1);
      expect(m.billedCount, 1);
      expect(m.openValueMinor, 99900 + 45000);
    });

    test('the grand total includes discount and tax as billed', () {
      final m = compute([
        order('S1',
            status: OpsOrderStatus.settled,
            unitMinor: 10000,
            discountPct: 10,
            taxPct: 5,
            settledAt: now,
            paymentMethod: 'card'),
      ]);
      // 10000 − 1000 discount + 450 tax; no payment row, so the bill total.
      expect(m.salesMinor, 9450);
    });

    test('no settled orders means no AOV', () {
      final m = compute([order('O1', status: OpsOrderStatus.open)]);
      expect(m.salesMinor, 0);
      expect(m.aovMinor, isNull);
      expect(m.hasPeriodActivity, isTrue);
      expect(compute(const []).hasPeriodActivity, isFalse);
    });

    test('a recorded cash payment is a sale even before the order settles', () {
      final m = compute([
        order('P1',
            status: OpsOrderStatus.open,
            unitMinor: 10500,
            payment: payment('cash', 10000)),
      ]);
      expect(m.salesMinor, 10000, reason: 'the amount actually recorded');
      expect(m.settledCount, 1);
      expect(m.openCount, 0);
    });
  });

  group('payment methods and pending verification', () {
    test('settled sales are split by method', () {
      final m = compute([
        paid('A', 'Cash', 10000),
        paid('B', 'upi', 20000),
        paid('C', 'card', 5000),
        paid('D', 'split: cash ₹30 + upi ₹40', 7000),
        order('E',
            status: OpsOrderStatus.settled, unitMinor: 100, settledAt: now),
      ]);
      final byKey = {for (final p in m.paymentMethods) p.key: p};
      expect(byKey['cash']!.settledMinor, 10000);
      expect(byKey['upi']!.settledMinor, 20000);
      expect(byKey['card']!.settledMinor, 5000);
      expect(byKey['split']!.settledMinor, 7000);
      expect(byKey['unrecorded']!.settledMinor, 100);
      expect(byKey['unrecorded']!.label, 'Not recorded');
      expect(m.paymentMethods.first.key, 'upi', reason: 'largest first');
      expect(m.pendingVerificationCount, 0);
    });

    test('a billed order with a card or UPI payment is pending verification',
        () {
      final m = compute([
        order('B1',
            status: OpsOrderStatus.billed,
            unitMinor: 40000,
            payment: payment('card', 40000)),
        order('B2',
            status: OpsOrderStatus.billed,
            unitMinor: 25000,
            payment: payment('upi', 25000)),
        order('B3', status: OpsOrderStatus.billed, unitMinor: 9000),
        order('B4',
            status: OpsOrderStatus.billed,
            unitMinor: 6000,
            payment: payment('split: cash ₹40 + card ₹20', 6000)),
      ]);
      expect(m.salesMinor, 0, reason: 'unverified payments are not sales');
      expect(m.pendingVerificationMinor, 71000);
      expect(m.pendingVerificationCount, 3);
      expect(m.livePendingVerificationCount, 3);
      final byKey = {for (final p in m.paymentMethods) p.key: p};
      expect(byKey['card']!.pendingMinor, 40000);
      expect(byKey['upi']!.pendingMinor, 25000);
      expect(byKey['split']!.pendingMinor, 6000);
      expect(byKey['card']!.settledMinor, 0);
      expect(m.billedCount, 1, reason: 'only B3 is awaiting any payment');
      expect(m.openValueMinor, 71000 + 9000);
    });

    test('a verified digital payment becomes a sale on its verify day', () {
      final m = compute([
        order('V1',
            status: OpsOrderStatus.settled,
            unitMinor: 30000,
            createdAt: DateTime(2026, 9, 28, 20),
            settledAt: now,
            payment: payment('upi', 30000, at: DateTime(2026, 9, 28, 21))),
      ]);
      expect(m.salesMinor, 30000);
      expect(m.pendingVerificationCount, 0);
    });

    test('pending verification in the period vs live', () {
      final m = compute([
        order('Old',
            status: OpsOrderStatus.billed,
            createdAt: DateTime(2026, 9, 27, 12),
            payment: payment('upi', 10000, at: DateTime(2026, 9, 27, 13))),
      ]);
      expect(m.pendingVerificationCount, 0, reason: 'recorded before today');
      expect(m.livePendingVerificationCount, 1);
      expect(m.livePendingVerificationMinor, 10000);
    });

    test('method keys', () {
      expect(DashboardMetrics.methodKey(null), 'unrecorded');
      expect(DashboardMetrics.methodKey('  '), 'unrecorded');
      expect(DashboardMetrics.methodKey('CASH'), 'cash');
      expect(DashboardMetrics.methodKey('UPI / QR'), 'upi');
      expect(DashboardMetrics.methodKey('Credit Card'), 'card');
      expect(DashboardMetrics.methodKey('split: cash ₹10 + card ₹5'), 'split');
    });
  });

  group('kitchen', () {
    OpsKot kot(String id, OpsKotStatus status,
            {int ageMinutes = 5,
            OpsOrderStatus orderStatus = OpsOrderStatus.open}) =>
        OpsKot(
          ticketId: id,
          order: order('O-$id', status: orderStatus),
          status: status,
          createdAt: now.subtract(Duration(minutes: ageMinutes)),
        );

    test('tickets by status, delayed after the limit', () {
      final m = compute(const [], kots: [
        kot('1', OpsKotStatus.newTicket),
        kot('2', OpsKotStatus.newTicket,
            ageMinutes: OpsKot.delayedAfterMinutes + 1),
        kot('3', OpsKotStatus.preparing),
        kot('4', OpsKotStatus.ready, ageMinutes: 90),
        kot('5', OpsKotStatus.completed),
        kot('6', OpsKotStatus.newTicket, orderStatus: OpsOrderStatus.cancelled),
      ]);
      expect(m.kitchen.newTickets, 2, reason: 'cancelled orders excluded');
      expect(m.kitchen.preparing, 1);
      expect(m.kitchen.ready, 1);
      expect(m.kitchen.delayed, 1, reason: 'ready tickets are not delayed');
      expect(m.kitchen.servedToday, 1);
      expect(m.kitchen.active, 4);
    });
  });

  group('low stock', () {
    test('at or below the reorder level, out of stock first', () {
      final m = compute(const [], materials: [
        material('Above', 10, 5),
        material('AtLevel', 5, 5),
        material('Below', 1, 5),
        material('Out', 0, 5),
        material('NoLevel', 3, 0),
        material('NoLevelOut', 0, 0),
      ]);
      // Out of stock first (by name), then lowest stock ÷ reorder level.
      expect(m.lowStock.map((x) => x.name),
          ['NoLevelOut', 'Out', 'Below', 'AtLevel']);
      expect(m.outOfStockCount, 2);
      expect(DashboardMetrics.isLowStock(material('AtLevel', 5, 5)), isTrue);
      expect(DashboardMetrics.isLowStock(material('Above', 5.01, 5)), isFalse);
    });
  });

  group('money formatting', () {
    test('₹ with Indian grouping from paise', () {
      expect(formatPaise(0), '₹0');
      expect(formatPaise(5), '₹0.05');
      expect(formatPaise(100), '₹1');
      expect(formatPaise(123456), '₹1,234.56');
      expect(formatPaise(12345678), '₹1,23,456.78');
      expect(formatPaise(1234567800), '₹1,23,45,678');
      expect(formatPaise(-250050), '-₹2,500.50');
      expect(formatPaise(100, alwaysShowPaise: true), '₹1.00');
      expect(groupIndian(100000), '1,00,000');
      expect(formatQty(12), '12');
      expect(formatQty(2.5), '2.5');
      expect(formatQty(0.25), '0.25');
    });
  });
}
