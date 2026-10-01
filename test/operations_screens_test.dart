import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_operations_store.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/data/operations_seeder.dart';
import 'package:proviyaa_pos/main.dart';
import 'package:proviyaa_pos/presentation/operations/ops_captain_orders_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_delivery_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_dine_in_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_kitchen_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_live_operations_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_pos_billing_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_qr_ordering_screen.dart';
import 'package:proviyaa_pos/presentation/operations/ops_reservations_screen.dart';
import 'package:proviyaa_pos/presentation/vinii_theme.dart';

/// Every Operations screen, filled with the seeded data, must lay out
/// without errors at the shell's content width (1200) and a narrow
/// window (900); and the admin must reach each one from the sidebar.
/// Returns a description of every short child of a multi-child Wrap that
/// stretched to (almost) the whole Wrap width — the "chip rendered as a
/// full-width bar" bug (e.g. a Container with `alignment` inside a Wrap).
List<String> stretchedWrapChildren(WidgetTester tester) {
  final problems = <String>[];
  void visit(RenderObject o) {
    if (o is RenderWrap && o.hasSize && o.size.width > 300) {
      final kids = <RenderBox>[];
      var c = o.firstChild;
      while (c != null) {
        kids.add(c);
        c = (c.parentData! as WrapParentData).nextSibling;
      }
      if (kids.length > 1) {
        for (final k in kids) {
          if (k.hasSize &&
              k is! RenderWrap &&
              k is! RenderParagraph &&
              k.size.height <= 48 &&
              k.size.width >= o.size.width * 0.95) {
            problems.add('${k.runtimeType} ${k.size} in Wrap ${o.size}');
          }
        }
      }
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return problems;
}

void main() {
  AppDatabase newDb() => AppDatabase(DatabaseConnection(NativeDatabase.memory(),
      closeStreamsSynchronously: true));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  // Menu thumbnails are network images, which the test binding answers
  // with HTTP 400 — expected here, not a layout problem.
  void ignoreImageErrors() {
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library == 'image resource service') return;
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);
  }

  final screens =
      <String, Widget Function(DriftOperationsStore, DriftMasterStore, String)>{
    'live operations': (o, m, _) => OpsLiveOperationsScreen(ops: o, master: m),
    'captain orders': (o, m, _) => OpsCaptainOrdersScreen(ops: o, master: m),
    'kitchen (KOT / KDS)': (o, m, _) => OpsKitchenScreen(ops: o, master: m),
    'dine in': (o, m, _) => OpsDineInScreen(ops: o, master: m),
    'reservations': (o, m, _) => OpsReservationsScreen(ops: o),
    'pos billing (new bill)': (o, m, _) =>
        OpsPosBillingScreen(ops: o, master: m),
    'pos billing (open order)': (o, m, orderId) =>
        OpsPosBillingScreen(ops: o, master: m, focusOrderId: orderId),
    'delivery': (o, m, _) => OpsDeliveryScreen(ops: o),
    'qr ordering': (o, m, _) => OpsQrOrderingScreen(ops: o),
  };

  for (final width in [1200.0, 900.0]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} lays out at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        ignoreImageErrors();
        final db = newDb();
        final ops = DriftOperationsStore(db);
        final master = DriftMasterStore(db);
        late String openOrder;
        await tester.runAsync(() async {
          await MasterSeeder.seedIfNeeded(db);
          await OperationsSeeder.seedIfNeeded(db);
          openOrder = (await ops.getTable('T2'))!.currentOrderId!;
        });
        await tester.pumpWidget(MaterialApp(
            theme: viniiLightTheme(),
            home: Scaffold(body: e.value(ops, master, openOrder))));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(stretchedWrapChildren(tester), isEmpty,
            reason: 'chips/buttons stretched to full width');
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      });
    }
  }

  testWidgets('admin reaches every Operations page from the sidebar',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ignoreImageErrors();
    // Sidebar/dashboard overflow is outside this module and the test
    // font is wider than Inter; screens themselves are checked above.
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('RenderFlex overflowed')) return;
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);

    final db = newDb();
    await tester.runAsync(() async {
      await MasterSeeder.seedIfNeeded(db);
      await OperationsSeeder.seedIfNeeded(db);
    });
    await tester.pumpWidget(ProviyaaPosApp(
      database: db,
      config: const AppConfig(
          appEnv: 'local',
          dataMode: 'local_demo',
          apiBaseUrl: '',
          syncEnabled: false),
    ));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'admin@onelatur.com');
    await tester.tap(find.text('Sign In'));
    await settle(tester);
    // ("QR Ordering" also appears on the dashboard, so check a label that
    // only the sidebar group has.)
    if (find.text('Live Operations').evaluate().isEmpty) {
      await tester.tap(find.text('Operations').first);
      await settle(tester);
    }
    final pages = <String, Type>{
      'Live Operations': OpsLiveOperationsScreen,
      'Captain Orders': OpsCaptainOrdersScreen,
      'KOT / Kitchen': OpsKitchenScreen,
      'Dine In': OpsDineInScreen,
      'Reservations': OpsReservationsScreen,
      'POS Billing': OpsPosBillingScreen,
      'Delivery': OpsDeliveryScreen,
      'QR Ordering': OpsQrOrderingScreen,
    };
    for (final p in pages.entries) {
      final item = find.text(p.key).first;
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settle(tester);
      expect(find.byType(p.value), findsOneWidget,
          reason: '${p.key} did not open');
      expect(tester.takeException(), isNull, reason: '${p.key} threw');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
