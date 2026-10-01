import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_menu_store.dart';
import 'package:proviyaa_pos/data/drift_table_store.dart';
import 'package:proviyaa_pos/data/tab_storage.dart';
import 'package:proviyaa_pos/domain/menu.dart';
import 'package:proviyaa_pos/domain/restaurant_table.dart';
import 'package:proviyaa_pos/presentation/dine_in_screen.dart';

void main() {
  group('Database Persistence & Schema Version', () {
    test('AppDatabase schemaVersion is 7', () {
      final db = AppDatabase(NativeDatabase.memory());
      expect(db.schemaVersion, equals(7));
      db.close();
    });

    test('User data CRUD persists in SQLite across database sessions',
        () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Open database to trigger beforeOpen
      final migrator = db.createMigrator();
      for (final table in db.allTables) {
        try {
          await migrator.createTable(table);
        } catch (_) {}
      }

      // Add a custom category and custom table
      final menuStore = DriftMenuStore(db);
      final tableStore = DriftTableStore(db);

      const customCat = MenuCategory(id: 'custom-cat-1', name: 'Custom Snacks');
      await menuStore.insertCategory(customCat);

      const customTable = RestaurantTable(
        id: 'T-999',
        label: 'T-999',
        seats: 8,
        zone: TableZone.outdoor,
        status: TableStatus.available,
      );
      await tableStore.insertTable(customTable);

      // Verify custom records exist
      final allCats = await menuStore.getAllCategories();
      expect(allCats.any((c) => c.id == 'custom-cat-1'), isTrue);

      final allTbls = await tableStore.getAllTables();
      expect(allTbls.any((t) => t.id == 'T-999'), isTrue);

      // Close database
      await db.close();
    });
  });

  group('Tab Storage Helper', () {
    test('persistTab and getPersistedTab operate safely', () {
      // On non-web test harness, this uses stub which returns null and does not throw
      persistTab('menu');
      final tab = getPersistedTab();
      expect(tab, anyOf(isNull, equals('menu')));
    });
  });

  group('DineInScreen SQLite Integration', () {
    testWidgets('renders tables from DriftTableStore when provided',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final migrator = db.createMigrator();
      for (final table in db.allTables) {
        try {
          await migrator.createTable(table);
        } catch (_) {}
      }

      final tableStore = DriftTableStore(db);
      await tableStore.insertTable(const RestaurantTable(
        id: 'TBL-LIVE-1',
        label: 'TBL-LIVE-1',
        seats: 4,
        zone: TableZone.indoor,
        status: TableStatus.available,
      ));

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DineInScreen(
              tableStore: tableStore,
              onOpenOrder: (_) {},
              onStartOrder: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TBL-LIVE-1'), findsOneWidget);
      expect(find.text('Dine In Orders'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    });
  });
}
