import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/staff_repository.dart';
import 'package:proviyaa_pos/domain/inventory.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/presentation/franchise/restaurant_dashboard_screen.dart';

import 'support/franchise_fixtures.dart';

/// 29 Sep 2026, 1 pm — the dashboard's and the store's clock.
final now = DateTime(2026, 9, 29, 13);

/// Only [dashboard] is used by the dashboard.
class _FakeStaff implements StaffRepository {
  _FakeStaff({this.live = true, this.fail = false});

  @override
  final bool live;
  final bool fail;

  @override
  Future<StaffDashboard> dashboard() async {
    if (fail) throw Exception('staff service down');
    return const StaffDashboard(
        active: 9, presentToday: 6, absentToday: 2, onShift: 4);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RawMaterial _material(String id, String name, double stock, double reorder) =>
    RawMaterial(
      id: id,
      code: id,
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

void main() {
  late AppDatabase db;
  late DriftOperationsStore ops;
  late DriftInventoryStore inventory;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    ops = DriftOperationsStore(db, clock: () => now);
    inventory = DriftInventoryStore(db);
  });

  tearDown(() => db.close());

  void largeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpDashboard(WidgetTester tester,
      {StaffRepository? staff,
      bool withInventory = true,
      bool withFranchise = false,
      VoidCallback? onActionCenter}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestaurantDashboardScreen(
          ops: ops,
          inventory: withInventory ? inventory : null,
          staff: staff,
          franchise: withFranchise ? sampleSnapshot() : null,
          branchName: 'Latur Main',
          onNavigateToActionCenter: onActionCenter,
          clock: () => now,
        ),
      ),
    ));
  }

  /// Runs a store write while a screen watches the database. The write runs
  /// in the test's zone and is pumped to completion (inside runAsync it
  /// would wait forever on a query the fake-async zone holds).
  Future<void> write(
      WidgetTester tester, Future<void> Function() action) async {
    var done = false;
    Object? error;
    action().then((_) => done = true, onError: (Object e) {
      error = e;
      done = true;
    });
    for (var i = 0; i < 100 && !done; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (error != null) throw error!;
    expect(done, isTrue, reason: 'the write finished');
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  /// Four orders today: A settled in cash (₹420), B paid by UPI but not yet
  /// verified (₹105), C cancelled (₹52.50), D open (₹31.50).
  Future<void> seedOrders() async {
    const tax5 = [
      OpsOrderLine(
          itemId: 'thali', name: 'Veg Thali', unitMinor: 20000, quantity: 2),
    ];
    final a = await ops.placeOrder(channel: OpsChannel.takeaway, lines: tax5);
    await ops.settleOrder(a, 'cash');
    final b = await ops.placeOrder(channel: OpsChannel.takeaway, lines: const [
      OpsOrderLine(
          itemId: 'biryani', name: 'Biryani', unitMinor: 10000, quantity: 1),
    ]);
    // UPI is recorded but stays pending verification (order billed).
    await ops.settleOrder(b, 'upi');
    final c = await ops.placeOrder(channel: OpsChannel.takeaway, lines: const [
      OpsOrderLine(
          itemId: 'lassi', name: 'Lassi', unitMinor: 5000, quantity: 1),
    ]);
    await ops.cancelOrder(c, reason: 'Guest left');
    await ops.placeOrder(channel: OpsChannel.takeaway, lines: const [
      OpsOrderLine(itemId: 'chai', name: 'Chai', unitMinor: 3000, quantity: 1),
    ]);
  }

  Future<void> seedStock() async {
    await inventory.upsertMaterial(_material('RM-1', 'Paneer', 2, 5));
    await inventory.upsertMaterial(_material('RM-2', 'Basmati Rice', 50, 10));
    await inventory.upsertMaterial(_material('RM-3', 'Milk', 0, 5));
  }

  testWidgets('without a data source it says it is not connected',
      (tester) async {
    largeView(tester);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RestaurantDashboardScreen())));
    expect(find.text('Dashboard data is not connected'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('shows a loading state until the device data is read',
      (tester) async {
    largeView(tester);
    await pumpDashboard(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sales'.toUpperCase()), findsNothing);
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await close(tester);
  });

  testWidgets('an empty device shows zeros and honest empty states',
      (tester) async {
    largeView(tester);
    await pumpDashboard(tester);
    await settle(tester);

    expect(find.text('Restaurant Dashboard'), findsOneWidget);
    expect(find.textContaining('No orders in this period yet'), findsOneWidget);
    expect(find.text('SALES'), findsOneWidget);
    expect(find.text('₹0'), findsWidgets);
    expect(find.text('No payments recorded in this period.'), findsOneWidget);
    expect(find.textContaining('No raw materials set up yet'), findsOneWidget);
    expect(find.text('Attendance not available'), findsOneWidget);
    // Average order value has no data: "—" with a tooltip.
    expect(find.byTooltip('Not enough data — no settled orders in this period'),
        findsOneWidget);
    // Nothing from the old design reference.
    expect(find.textContaining('Vinii Cafe'), findsNothing);
    expect(find.text('Publish Offer'), findsNothing);
    expect(find.text('Launch AI Campaign'), findsNothing);
    await close(tester);
  });

  testWidgets('real orders, payments, kitchen, stock and attendance',
      (tester) async {
    largeView(tester);
    await tester.runAsync(() async {
      await seedOrders();
      await seedStock();
    });
    await pumpDashboard(tester, staff: _FakeStaff());
    await settle(tester);

    // KPIs: only A is a sale.
    expect(find.text('₹420'), findsNWidgets(3),
        reason: 'sales tile, AOV tile and the payment summary total');
    expect(find.text('3 placed · 1 cancelled (₹52.50)'), findsOneWidget);
    expect(find.text('₹105'), findsNWidgets(2),
        reason: 'pending-verification KPI and live "payments to verify"');
    expect(find.text('1 card/UPI payment not yet verified'), findsOneWidget);

    // Payment summary: cash settled, UPI pending verification.
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('₹420 · 1'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('₹105 · 1'), findsOneWidget);

    // Live: D open, B's payment to verify.
    expect(find.text('₹136.50'), findsOneWidget,
        reason: 'open bill value ₹105 + ₹31.50');

    // Kitchen: A, B and D still have new tickets; C's order was cancelled.
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Stock: Paneer low, Milk out, Rice fine.
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Basmati Rice'), findsNothing);
    expect(find.text('2 kg / reorder 5'), findsOneWidget);

    // Attendance from the staff repository.
    expect(find.text('PRESENT TODAY'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.text('1 not marked yet today'), findsOneWidget);
    expect(find.text('Demo data'), findsNothing);

    // Yesterday had nothing.
    await tester.tap(find.byKey(const ValueKey('dashboard-range-yesterday')));
    await tester.pump();
    expect(find.textContaining('No orders in this period yet'), findsOneWidget);
    expect(find.text('₹420'), findsNothing);
    expect(find.text('₹136.50'), findsOneWidget,
        reason: 'live figures ignore the date filter');

    // Last 7 days includes today.
    await tester.tap(find.byKey(const ValueKey('dashboard-range-last7Days')));
    await tester.pump();
    expect(find.text('₹420'), findsNWidgets(3));
    await close(tester);
  });

  testWidgets('a new settlement updates the dashboard live', (tester) async {
    largeView(tester);
    await pumpDashboard(tester);
    await settle(tester);
    expect(find.text('₹420'), findsNothing);
    await write(tester, () async {
      final a =
          await ops.placeOrder(channel: OpsChannel.takeaway, lines: const [
        OpsOrderLine(
            itemId: 'thali', name: 'Veg Thali', unitMinor: 20000, quantity: 2),
      ]);
      await ops.settleOrder(a, 'cash');
    });
    await settle(tester);
    expect(find.text('₹420'), findsNWidgets(3));
    expect(find.text('Cash'), findsOneWidget);
    await close(tester);
  });

  testWidgets('attendance errors and demo staff data are labelled',
      (tester) async {
    largeView(tester);
    await pumpDashboard(tester, staff: _FakeStaff(fail: true));
    await settle(tester);
    expect(find.text('Attendance could not load'), findsOneWidget);
    expect(find.textContaining('staff service down'), findsOneWidget);

    await pumpDashboard(tester, staff: _FakeStaff(live: false));
    await settle(tester);
    expect(find.text('Demo data'), findsOneWidget);
    await close(tester);
  });

  testWidgets('several branches: branch table and the exceptions link',
      (tester) async {
    largeView(tester);
    var opened = 0;
    await pumpDashboard(tester,
        withFranchise: true, onActionCenter: () => opened++);
    await settle(tester);

    expect(find.text('Branches'), findsOneWidget);
    expect(find.text('Latur Station Road'), findsOneWidget);
    expect(find.text('₹2,450'), findsOneWidget);
    await tester.tap(find.text('1 open exception needs action'));
    expect(opened, 1);
    await close(tester);
  });
}
