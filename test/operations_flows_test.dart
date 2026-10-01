import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/data/operations_seeder.dart';
import 'package:proviyaa_pos/domain/operations.dart';
import 'package:proviyaa_pos/presentation/operations/ops_captain_orders_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_delivery_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_dine_in_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_kitchen_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_live_operations_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_pos_billing_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_qr_ordering_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_reservations_screen.dart';
import 'package:proviyaa_pos/presentation/vinii_theme.dart';

/// End-to-end journeys through the restaurant-admin Operations screens:
/// each test drives the real UI (taps / typing on the real labels) on a
/// seeded in-memory database and checks the result in the store — the
/// same tables the POS reads.
void main() {
  late AppDatabase db;
  late DriftOperationsStore ops;
  late DriftMasterStore master;

  /// [before] runs on the seeded database before the screen subscribes:
  /// a write while a screen's query is waiting on fake time would never
  /// finish.
  Future<void> open(WidgetTester tester, Widget Function() screen,
      {Future<void> Function()? before}) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Menu thumbnails are network images the test binding answers with
    // HTTP 400 — expected, not a flow problem.
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library == 'image resource service') return;
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    ops = DriftOperationsStore(db);
    master = DriftMasterStore(db);
    await tester.runAsync(() async {
      await MasterSeeder.seedIfNeeded(db);
      await OperationsSeeder.seedIfNeeded(db);
      await before?.call();
    });
    await tester.pumpWidget(
        MaterialApp(theme: viniiLightTheme(), home: Scaffold(body: screen())));
  }

  /// Lets real database work finish and streams deliver, while advancing
  /// fake time so dialogs / animations complete.
  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    // Let snackbars time out, then dispose the screen (and its periodic
    // timers) before closing the database.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  Future<T> read<T>(WidgetTester tester, Future<T> Function() op) async =>
      (await tester.runAsync(op)) as T;

  Future<void> tap(WidgetTester tester, Finder f) async {
    expect(f, findsWidgets);
    // A person waits for the last message to go; a test taps at once, so
    // clear it first — a wide snackbar can cover the next button.
    for (final m in find.byType(ScaffoldMessenger).evaluate()) {
      final state = (m as StatefulElement).state;
      if (state is ScaffoldMessengerState) state.removeCurrentSnackBar();
    }
    await tester.pump();
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first, warnIfMissed: false);
    await settle(tester);
  }

  /// [target] inside the nearest ancestor of [anchor] that contains one.
  Finder near(Finder anchor, Finder target) {
    expect(anchor, findsWidgets);
    final el = anchor.evaluate().first;
    Finder? result;
    el.visitAncestorElements((a) {
      final f = find.descendant(
          of: find.byElementPredicate((e) => identical(e, a)),
          matching: target);
      if (f.evaluate().isNotEmpty) {
        result = f;
        return false;
      }
      return true;
    });
    if (result == null) fail('No $target near $anchor');
    return result!;
  }

  Finder tooltipStarting(String prefix) => find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message ?? '').startsWith(prefix));

  // =====================================================================
  // 1. Captain Orders
  // =====================================================================
  testWidgets('Captain Orders: T9 + 2 dishes → Send to Kitchen',
      (tester) async {
    await open(tester, () => OpsCaptainOrdersScreen(ops: ops, master: master));
    await settle(tester);

    await tap(tester, find.text('T9'));
    expect(find.text('Order Ticket · T9'), findsOneWidget);

    final adds = tooltipStarting('Add ');
    expect(adds.evaluate().length, greaterThanOrEqualTo(2));
    final names = [
      for (final e in adds.evaluate().take(2))
        (e.widget as Tooltip).message!.substring(4)
    ];
    for (final n in names) {
      await tap(tester, find.byTooltip('Add $n'));
    }
    expect(find.text('2 items'), findsOneWidget);

    await tap(tester, find.text('Send to Kitchen (KOT)'));
    expect(find.text('KOT sent to kitchen'), findsOneWidget);
    await tap(tester, find.text('Done'));

    final t9 = (await read(tester, () => ops.getTable('T9')))!;
    expect(t9.status, OpsTableStatus.occupied);
    expect(t9.currentOrderId, isNotNull);
    final order = (await read(tester, () => ops.getOrder(t9.currentOrderId!)))!;
    expect(order.status, OpsOrderStatus.open);
    expect(order.tableLabel, 'T9');
    expect(order.source, 'Captain');
    expect(order.guests, 2);
    expect(order.lines.map((l) => l.name), unorderedEquals(names));
    expect(order.lines.every((l) => l.quantity == 1), isTrue);
    final kots = await read(tester, ops.getKots);
    final kot = kots.where((k) => k.order.id == order.id).single;
    expect(kot.status, OpsKotStatus.newTicket);
    await close(tester);
  });

  // =====================================================================
  // 2. KOT / Kitchen
  // =====================================================================
  group('KOT / Kitchen', () {
    Widget screen() => OpsKitchenScreen(ops: ops, master: master);

    /// The view is remembered across screen instances — start each
    /// test from the requested one.
    Future<void> showView(WidgetTester tester, String label) async {
      await tap(tester, find.text(label));
    }

    Future<OpsKot> kotOf(WidgetTester tester, String itemName) async =>
        (await read(tester, ops.getKots)).firstWhere((k) =>
            k.status == OpsKotStatus.newTicket &&
            k.order.lines.any((l) => l.name == itemName));

    testWidgets('KOT Cards: Start Cooking → Mark as Ready → Done / Clear',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await showView(tester, 'KOT Cards');
      final kot = await kotOf(tester, 'Margherita Pizza');
      final id = kot.ticketId;
      Future<OpsKotStatus> status() async => (await read(tester, ops.getKots))
          .firstWhere((k) => k.ticketId == id)
          .status;

      await tap(tester, near(find.text(id), find.text('Start Cooking')));
      expect(await status(), OpsKotStatus.preparing);
      await tap(tester, near(find.text(id), find.text('Mark as Ready')));
      expect(await status(), OpsKotStatus.ready);
      final lines =
          (await read(tester, () => ops.getOrder(kot.order.id)))!.lines;
      expect(lines.every((l) => l.done), isTrue,
          reason: 'ready ticks every item');
      await tap(tester, near(find.text(id), find.text('Done / Clear')));
      expect(await status(), OpsKotStatus.completed);
      await close(tester);
    });

    testWidgets('Kitchen Display: item switch, stations and sound settings',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await showView(tester, 'Kitchen Display');
      final kot = await kotOf(tester, 'Veg Biryani');
      expect(kot.order.lines.any((l) => l.done), isFalse);

      // Tick the first item on the ticket.
      final sw = near(find.text(kot.order.number), find.byType(Switch));
      await tap(tester, sw.first);
      final o = (await read(tester, () => ops.getOrder(kot.order.id)))!;
      expect(o.lines.where((l) => l.done).length, 1);
      final after = (await read(tester, ops.getKots))
          .firstWhere((k) => k.ticketId == kot.ticketId);
      expect(after.status, OpsKotStatus.preparing,
          reason: 'first ticked item starts the ticket');

      // Kitchen Stations: + Grill, Save changes.
      await tap(tester, find.byTooltip('Kitchen stations'));
      expect(find.text('Kitchen Stations'), findsOneWidget);
      await tap(tester, find.text('+ Grill'));
      await tap(tester, find.text('Save changes'));
      expect(find.text('Kitchen Stations'), findsNothing, reason: 'closed');
      final stations =
          await read(tester, () => ops.watchKitchenStations().first);
      expect(stations.map((s) => s.name), contains('Grill'));
      expect(stations.map((s) => s.name), contains('Tandoor'));

      // Sound & Alerts: sounds off, Done.
      await tap(tester, find.byTooltip('Sound & alert settings'));
      expect(find.text('Sound & Alerts'), findsOneWidget);
      await tap(tester, near(find.text('Sounds enabled'), find.byType(Switch)));
      await tap(tester, find.text('Done'));
      final alerts = await read(tester, () => ops.watchAlertSettings().first);
      expect(alerts.soundsEnabled, isFalse);
      expect(find.text('Alerts Off'), findsOneWidget);
      await close(tester);
    });
  });

  // =====================================================================
  // 3. Dine In
  // =====================================================================
  testWidgets('Dine In: Generate Bill, Transfer Table, Start Ordering',
      (tester) async {
    await open(tester, () => OpsDineInScreen(ops: ops, master: master));
    await settle(tester);
    final orderId =
        (await read(tester, () => ops.getTable('T2')))!.currentOrderId!;

    await tap(tester, find.text('T2'));
    expect(find.text('Table 2'), findsWidgets);
    await tap(tester, find.text('Generate Bill'));
    var order = (await read(tester, () => ops.getOrder(orderId)))!;
    expect(order.status, OpsOrderStatus.billed);
    expect(order.billNo, isNotNull);
    expect((await read(tester, () => ops.getTable('T2')))!.status,
        OpsTableStatus.billing);

    await tap(tester, find.text('Transfer Table'));
    await tap(tester, find.text('T11 · 4 seats'));
    await tap(tester, find.text('Transfer to T11'));
    final t11 = (await read(tester, () => ops.getTable('T11')))!;
    expect(t11.currentOrderId, orderId);
    expect(t11.status, OpsTableStatus.billing);
    final t2 = (await read(tester, () => ops.getTable('T2')))!;
    expect(t2.currentOrderId, isNull);
    expect(t2.status, OpsTableStatus.cleaning);
    order = (await read(tester, () => ops.getOrder(orderId)))!;
    expect(order.tableLabel, 'T11');

    await tap(tester, find.text('T8'));
    await tap(tester, find.text('Start Ordering'));
    expect(find.text('Seat guests · T8'), findsOneWidget);
    expect(near(find.text('Guests').last, find.text('2')), findsWidgets);
    await tap(tester, find.text('Seat & Take Order'));
    // The take-order dialog opens next — close it without ordering.
    await tap(tester, find.byIcon(Icons.close).last);
    final t8 = (await read(tester, () => ops.getTable('T8')))!;
    expect(t8.status, OpsTableStatus.occupied);
    expect(t8.guests, 2);
    expect(t8.currentOrderId, isNull);
    await close(tester);
  });

  // =====================================================================
  // 4. POS Billing
  // =====================================================================
  group('POS Billing', () {
    testWidgets('new Takeaway bill paid by UPI waits for verification',
        (tester) async {
      await open(tester, () => OpsPosBillingScreen(ops: ops, master: master));
      await settle(tester);
      final dishes = (await read(tester, master.getDishes))
          .where((d) => d.status == 'Active' && d.availability != 'Unavailable')
          .toList();
      final names = <String>[];
      for (final d in dishes) {
        if (names.length == 2) break;
        if (find.text(d.name).evaluate().length == 1) names.add(d.name);
      }
      expect(names, hasLength(2));
      final before = (await read(tester, ops.getOrders)).map((o) => o.id);

      await tap(tester, find.text('Takeaway'));
      for (final n in names) {
        await tap(tester,
            find.ancestor(of: find.text(n), matching: find.byType(InkWell)));
      }
      // Qty of the first item 1 → 2.
      await tap(tester, near(find.text(names.first).last, find.text('+')));
      // Cash is the default; UPI must be picked and is not "settled".
      expect(find.textContaining('Settle & Close'), findsOneWidget);
      await tap(tester, find.text('Card'));
      await tap(tester, find.text('UPI (Google Pay)'));
      await tap(tester, find.textContaining('Record Payment'));
      expect(find.textContaining('pending verification'), findsWidgets);
      expect(find.textContaining('settled'), findsNothing);

      final created = (await read(tester, ops.getOrders))
          .where((o) => !before.contains(o.id))
          .toList();
      expect(created, hasLength(1));
      final o = created.single;
      expect(o.channel, OpsChannel.takeaway);
      expect(o.status, OpsOrderStatus.billed);
      expect(o.paymentState, OrderPaymentState.pendingVerification);
      expect(o.paymentMethod, 'upi');
      expect(o.billNo, isNotNull);
      expect({for (final l in o.lines) l.name: l.quantity},
          {names[0]: 2, names[1]: 1});
      final pays = await read(tester, () => db.select(db.payments).get());
      final p = pays.singleWhere((p) => p.clientOrderId == o.id);
      expect(p.method, 'upi');
      expect(p.amountMinor, o.grandTotalMinor);
      await close(tester);
    });

    testWidgets('open order: 10% discount is saved', (tester) async {
      late String orderId;
      await open(tester, () => OpsPosBillingScreen(ops: ops, master: master));
      orderId = (await read(tester, () => ops.getTable('T2')))!.currentOrderId!;
      await tester.pumpWidget(MaterialApp(
          theme: viniiLightTheme(),
          home: Scaffold(
              body: OpsPosBillingScreen(
                  ops: ops, master: master, focusOrderId: orderId))));
      await settle(tester);
      expect(find.textContaining(orderId), findsWidgets);
      await tap(tester, find.textContaining('Discount ('));
      await tap(tester, find.text('10%'));
      // A discount needs a reason (kept in the order history).
      await tap(tester, find.text('Apply'));
      expect(find.textContaining('Enter a reason'), findsOneWidget);
      expect((await read(tester, () => ops.getOrder(orderId)))!.discountPct,
          isNot(10));
      await tester.enterText(
          find.widgetWithText(TextField, 'Reason'), 'Regular guest');
      await tap(tester, find.text('Apply'));
      final o = (await read(tester, () => ops.getOrder(orderId)))!;
      expect(o.discountPct, 10);
      expect(o.auditLog.last.text, endsWith('→ 10%: Regular guest'));
      expect(find.text('Discount (10% Applied)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Verify Payment is shown only to users who may verify',
        (tester) async {
      late String orderId;
      // Record the UPI payment before any screen watches the database.
      await open(tester, () => const SizedBox());
      await tester.runAsync(() async {
        orderId = (await ops.getTable('T2'))!.currentOrderId!;
        await ops.settleOrder(orderId, 'upi');
      });
      Future<void> show(bool canVerify) async {
        await tester.pumpWidget(MaterialApp(
            theme: viniiLightTheme(),
            home: Scaffold(
                body: OpsPosBillingScreen(
                    key: ValueKey(canVerify),
                    ops: ops,
                    master: master,
                    focusOrderId: orderId,
                    canVerifyPayments: canVerify))));
        await settle(tester);
      }

      await show(false);
      expect(find.textContaining('pending verification'), findsWidgets);
      expect(find.text('Verify Payment'), findsNothing);
      expect(find.textContaining('A manager must verify'), findsOneWidget);

      await show(true);
      await tap(tester, find.text('Verify Payment'));
      expect(find.text('Verify payment for $orderId?'), findsOneWidget);
      await tap(tester, find.text('Verify Payment').last);
      final o = (await read(tester, () => ops.getOrder(orderId)))!;
      expect(o.status, OpsOrderStatus.settled);
      expect(o.auditLog.last.text, startsWith('Payment verified: UPI'));
      await close(tester);
    });

    testWidgets('a role without money rights cannot settle a bill', (tester) async {
      late String orderId;
      await open(tester, () => const SizedBox());
      await tester.runAsync(() async {
        orderId = (await ops.getTable('T2'))!.currentOrderId!;
      });
      await tester.pumpWidget(MaterialApp(
          theme: viniiLightTheme(),
          home: Scaffold(
              body: OpsPosBillingScreen(
                  ops: ops,
                  master: master,
                  focusOrderId: orderId,
                  canVerifyPayments: true,
                  canTakePayments: false,
                  canPlaceOrders: false))));
      await settle(tester);
      expect(find.text('Payment is taken by the cashier'), findsOneWidget);
      expect(find.textContaining('Settle & Close'), findsNothing);
      await tap(tester, find.text('Payment is taken by the cashier'));
      final o = (await read(tester, () => ops.getOrder(orderId)))!;
      expect(o.payment, isNull, reason: 'nothing was recorded');
      await close(tester);
    });

  });

  // =====================================================================
  // 5. Reservations
  // =====================================================================
  testWidgets('Reservations: create, Seat Now, cancel another', (tester) async {
    await open(tester, () => OpsReservationsScreen(ops: ops));
    await settle(tester);
    final before =
        (await read(tester, ops.getReservations)).map((r) => r.id).toSet();

    await tap(tester, find.text('New Reservation').first);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Guest name *'), 'Riya Kapoor');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone *'), '9876512345');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Party size *'), '2');
    await settle(tester, 2);
    await tap(tester,
        find.byWidgetPredicate((w) => w is DropdownButtonFormField<String?>));
    await tap(
        tester, find.text('Table 8 · Ground Floor · 2 seats · Available').last);
    await tap(tester, find.text('Create Reservation'));
    expect(find.text('Create Reservation'), findsNothing, reason: 'closed');

    final created = (await read(tester, ops.getReservations))
        .where((r) => !before.contains(r.id))
        .single;
    expect(created.guestName, 'Riya Kapoor');
    expect(created.phone.replaceAll(RegExp(r'\D'), ''), endsWith('9876512345'));
    expect(created.guests, 2);
    expect(created.tableId, 'T8');
    expect(created.status, ReservationStatus.confirmed);

    // The default time is ~2h ahead — after 22:00 that is tomorrow.
    final now = DateTime.now();
    if (created.dateTime.day != now.day) {
      await tap(tester, find.text('Tomorrow').last);
    }
    await tap(tester, find.text('Seat Now').last);
    final seated = (await read(tester, ops.getReservations))
        .singleWhere((r) => r.id == created.id);
    expect(seated.status, ReservationStatus.seated);
    final t8 = (await read(tester, () => ops.getTable('T8')))!;
    expect(t8.status, OpsTableStatus.occupied);
    expect(t8.guests, 2);

    // Cancel Suresh Menon's pending booking (today). "Today" is also a
    // KPI tag above the list, so tap the date chip (the last match).
    await tap(tester, find.text('Today').last);
    await tap(
        tester, find.textContaining('Suresh Menon', findRichText: true).first);
    await tap(tester, find.text('Cancel Reservation').first);
    expect(find.text('Cancel reservation?'), findsOneWidget);
    await tap(tester, find.text('Cancel Reservation').last);
    final rsv = (await read(tester, ops.getReservations))
        .singleWhere((r) => r.id == 'RSV-102');
    expect(rsv.status, ReservationStatus.cancelled);
    await close(tester);
  });

  // =====================================================================
  // 6. Delivery
  // =====================================================================
  testWidgets('Delivery: New Delivery → Assign Rider → Delivered',
      (tester) async {
    // A delivery order taken at the counter, waiting for a rider.
    late String orderId;
    await open(tester, () => OpsDeliveryScreen(ops: ops),
        before: () async => orderId = await ops.placeOrder(
              channel: OpsChannel.delivery,
              customerName: 'Test Customer',
              lines: const [
                OpsOrderLine(
                    itemId: 'qa-biryani',
                    name: 'Veg Biryani',
                    unitMinor: 22000,
                    quantity: 1)
              ],
            ));
    await settle(tester);
    final order = (await read(tester, () => ops.getOrder(orderId)))!;
    final id = await read(tester, ops.nextDeliveryId);

    await tap(tester, find.text('New Delivery'));
    expect(find.text('New Delivery'), findsWidgets);
    Future<void> fill(String label, String text) async {
      await tester.enterText(
          near(find.text(label).last, find.byType(TextFormField)), text);
      await tester.pump();
    }

    // The order is picked from the open orders by its number — never
    // typed as a key — and its customer fills in.
    await fill('Order', order.number);
    await tap(
        tester,
        find.descendant(
            of: find.byType(ListTile), matching: find.text(order.number)));
    expect(find.text('Test Customer'), findsOneWidget);
    // The merchant is a list, not free text.
    await tap(tester, find.text('Restaurant (own delivery)'));
    await tap(tester, find.text('Swiggy').last);
    await fill('Delivery address', '12 MG Road, Latur');
    await fill('Distance', '3.2');
    await tap(tester, find.text('Create Delivery'));
    Future<OpsDelivery> get() async =>
        (await read(tester, ops.getDeliveries)).singleWhere((d) => d.id == id);
    var d = await get();
    expect(d.orderId, orderId);
    expect(d.merchant, 'Swiggy');
    expect(d.customerName, 'Test Customer');
    expect(d.distanceKm, 3.2);
    expect(d.status, DeliveryStatus.unassigned);
    expect(d.riderName, isNull);

    // The row shows the order's number, not the delivery's key.
    expect(find.text('#$id'), findsNothing);
    // Detail sheet → Assign Rider.
    await tap(tester, find.text(order.number).first);
    await tap(tester, find.text('Assign Rider'));
    await tester.enterText(
        near(find.text('Rider name'), find.byType(TextFormField)), 'Ravi M.');
    await tester.enterText(
        near(find.text('ETA (optional)'), find.byType(TextFormField)), '15');
    await tap(tester, find.text('Assign'));
    d = await get();
    expect(d.status, DeliveryStatus.assigned);
    expect(d.riderName, 'Ravi M.');
    expect(d.etaMinutes, 15);

    await tap(tester, find.text('Mark Picked Up'));
    expect((await get()).status, DeliveryStatus.pickedUp);
    await tap(tester, find.text('Mark In Transit'));
    expect((await get()).status, DeliveryStatus.inTransit);
    await tap(tester, find.text('Mark Delivered'));
    d = await get();
    expect(d.status, DeliveryStatus.delivered);
    expect(d.etaMinutes, isNull);
    await tap(tester, find.byTooltip('Close'));
    await close(tester);
  });

  // =====================================================================
  // 7. QR Ordering
  // =====================================================================
  testWidgets('QR Ordering: Close Session, toggle Status, Regenerate',
      (tester) async {
    await open(tester, () => OpsQrOrderingScreen(ops: ops));
    await settle(tester);

    await tap(tester, near(find.text('Table 8'), find.text('Close Session')));
    expect(find.text("Close Table 8's session?"), findsOneWidget);
    await tap(tester, find.text('Close Session').last);
    final s = (await read(tester, ops.getQrSessions))
        .singleWhere((s) => s.id == 'QRS-3');
    expect(s.status, QrSessionStatus.closed);
    expect(find.text('Table 8'), findsNothing, reason: 'row removed');

    Future<QrTableCode> code(String t) async =>
        (await read(tester, ops.getQrCodes)).singleWhere((c) => c.tableId == t);
    expect((await code('T1')).enabled, isTrue);
    await tap(tester, near(find.text('T1'), find.byType(Switch)));
    expect((await code('T1')).enabled, isFalse);
    expect((await code('T3')).enabled, isFalse);
    await tap(tester, near(find.text('T3'), find.byType(Switch)));
    expect((await code('T3')).enabled, isTrue);

    final before = {
      for (final c in await read(tester, ops.getQrCodes)) c.tableId: c.token
    };
    // Tokens embed the clock in microseconds — make sure it moves on.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tap(tester, find.text('Regenerate'));
    expect(find.text('Regenerate all QR codes?'), findsOneWidget);
    await tap(tester, find.text('Regenerate').last);
    final after = await read(tester, ops.getQrCodes);
    expect(after, hasLength(before.length));
    for (final c in after) {
      expect(c.token, isNot(before[c.tableId]), reason: c.tableId);
    }
    await close(tester);
  });

  // =====================================================================
  // 8. Live Operations
  // =====================================================================
  testWidgets('Live Operations: New Order → Mark Paid & Complete',
      (tester) async {
    await open(tester, () => OpsLiveOperationsScreen(ops: ops, master: master));
    await settle(tester);

    await tap(tester, find.text('New Order').first);
    await tap(tester, find.text('Takeaway').last);
    await tester.enterText(
        find.widgetWithText(TextField, 'Customer name (optional)'),
        'Ravi Kumar');
    await tap(tester, find.text('Add').first);
    expect(find.textContaining('1 item ·'), findsOneWidget);
    await tap(tester, find.text('Place Order'));
    expect(find.text('Place Order'), findsNothing, reason: 'dialog closed');

    final o = (await read(tester, ops.getOrders))
        .singleWhere((o) => o.customerName == 'Ravi Kumar');
    expect(o.channel, OpsChannel.takeaway);
    expect(o.status, OpsOrderStatus.open);
    expect(o.lines, hasLength(1));
    expect((await read(tester, ops.getKots)).where((k) => k.order.id == o.id),
        hasLength(1));

    await tap(tester, near(find.text(o.number), find.text('Update')));
    await tap(tester, find.text('Mark Paid & Complete'));
    expect(find.text('Mark ${o.number} paid'), findsOneWidget);
    await tap(tester, find.text('UPI'));
    await tap(tester, find.text('Mark Paid & Complete').last);
    // The food is handed over, but UPI stays pending verification.
    final paid = (await read(tester, () => ops.getOrder(o.id)))!;
    expect(paid.status, OpsOrderStatus.billed);
    expect(paid.paymentState, OrderPaymentState.pendingVerification);
    expect(paid.paymentMethod, 'upi');
    final kot = (await read(tester, ops.getKots))
        .singleWhere((k) => k.order.id == o.id);
    expect(kot.status, OpsKotStatus.completed);
    final pays = await read(tester, () => db.select(db.payments).get());
    expect(pays.singleWhere((p) => p.clientOrderId == o.id).method, 'upi');
    expect(find.textContaining('UPI · pending verification'), findsWidgets);
    // This screen was opened without verification rights.
    await tap(tester, near(find.text(o.number), find.text('Update')));
    expect(find.text('Verify Payment'), findsNothing);
    expect(find.text('Mark Paid & Complete'), findsNothing);
    await close(tester);
  });

  testWidgets('Live Operations: verify a UPI payment, cancel with a reason',
      (tester) async {
    // Record the UPI payment before any screen watches the database.
    await open(tester, () => const SizedBox());
    late String upiOrder;
    late String cancelOrder;
    await tester.runAsync(() async {
      final open = (await ops.getOrders(openOnly: true))
          .where((o) => o.status == OpsOrderStatus.open)
          .toList();
      upiOrder = open[0].id;
      cancelOrder = open[1].id;
      await ops.settleOrder(upiOrder, 'upi');
    });
    await tester.pumpWidget(MaterialApp(
        theme: viniiLightTheme(),
        home: Scaffold(
            body: OpsLiveOperationsScreen(
                ops: ops, master: master, canVerifyPayments: true))));
    await settle(tester);

    await tap(tester, near(find.text(upiOrder), find.text('Update')));
    await tap(tester, find.text('Verify Payment'));
    await tap(tester, find.text('Verify Payment').last);
    expect((await read(tester, () => ops.getOrder(upiOrder)))!.status,
        OpsOrderStatus.settled);

    await tap(tester, near(find.text(cancelOrder), find.text('Update')));
    await tap(tester, find.text('Cancel Order'));
    // A reason is required.
    await tap(tester, find.text('Cancel Order').last);
    expect(find.textContaining('A reason is required'), findsOneWidget);
    await tap(tester, find.text('Guest left'));
    await tap(tester, find.text('Cancel Order').last);
    final c = (await read(tester, () => ops.getOrder(cancelOrder)))!;
    expect(c.status, OpsOrderStatus.cancelled);
    expect(c.auditLog.single.text, 'Cancelled: Guest left');
    expect((await read(tester, ops.getKots)).where((k) => k.order.id == c.id),
        isEmpty);
    await close(tester);
  });
}
