import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/domain/restaurant_table.dart';
import 'package:proviyaa_pos/main.dart';

void main() {
  testWidgets('renders the local-demo shell', (WidgetTester tester) async {
    // A real on-disk database (drift_flutter's driftDatabase) schedules a
    // background timer that outlives a pumped test frame, which the test
    // binding flags as a leak — use an in-memory one here instead.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tableStore = DriftTableStore(db);
    await tableStore.insertTable(const RestaurantTable(
      id: 'T1',
      label: 'T1',
      seats: 4,
      zone: TableZone.indoor,
      status: TableStatus.available,
    ));

    await tester.pumpWidget(
      ProviyaaPosApp(
        database: db,
        config: const AppConfig(
          appEnv: 'local',
          dataMode: 'local_demo',
          apiBaseUrl: '',
          syncEnabled: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'cashier@onelatur.com');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // The app opens inside the persistent PosShell (sidebar + top
    // bar), defaulted to the Dine In board
    expect(find.text('VINII POS'), findsWidgets);
    expect(find.text('Dine In Orders'), findsOneWidget);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
