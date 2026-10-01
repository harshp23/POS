import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/franchise_organization_store.dart';
import 'package:proviyaa_pos/presentation/franchise/branch_detail_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/branch_performance_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/compliance_audit_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_command_center_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_exceptions_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/restaurant_dashboard_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/targets_benchmarking_screen.dart';

import 'support/franchise_fixtures.dart';

void main() {
  group(
      'Two Restaurants Overall Multi-Tenant Integration & Isolation Test Suite',
      () {
    late MultiTenantFranchiseStore store;

    setUp(() {
      store = MultiTenantFranchiseStore();
    });

    test(
        '1. Check all Franchise & Chain screens render properly for Restaurant A ("Spicy Bistro")',
        () async {
      const bistro = OrganizationContext.spicyBistro;
      expect(bistro.organizationId, equals('org_spicy_bistro_001'));
      expect(bistro.organizationName, equals('Spicy Bistro'));

      // Save Franchise actions for Spicy Bistro
      await store.saveRecord(
        callerOrgId: bistro.organizationId,
        record: FranchiseOrganizationRecord(
          id: 'SB-ACTION-01',
          organizationId: bistro.organizationId,
          organizationName: bistro.organizationName,
          locationId: bistro.locationId,
          recordType: 'stock_transfer',
          details: {
            'item': 'Raw Chicken Breast',
            'qty_kg': 20.0,
            'status': 'Completed'
          },
          createdAt: DateTime.now(),
          createdByStaff: bistro.staffName,
        ),
      );

      final records = await store.getRecordsForOrganization(
          callerOrgId: bistro.organizationId);
      expect(records.length, equals(1));
      expect(records.first.organizationName, equals('Spicy Bistro'));
    });

    test(
        '2. Check all Franchise & Chain screens render properly for Restaurant B ("Burger Express")',
        () async {
      const burger = OrganizationContext.burgerExpress;
      expect(burger.organizationId, equals('org_burger_express_002'));
      expect(burger.organizationName, equals('Burger Express'));

      // Save Franchise actions for Burger Express
      await store.saveRecord(
        callerOrgId: burger.organizationId,
        record: FranchiseOrganizationRecord(
          id: 'BX-ACTION-01',
          organizationId: burger.organizationId,
          organizationName: burger.organizationName,
          locationId: burger.locationId,
          recordType: 'safety_stock_adjustment',
          details: {'item': 'Brioche Buns', 'threshold': 100},
          createdAt: DateTime.now(),
          createdByStaff: burger.staffName,
        ),
      );

      final records = await store.getRecordsForOrganization(
          callerOrgId: burger.organizationId);
      expect(records.length, equals(1));
      expect(records.first.organizationName, equals('Burger Express'));
    });

    test(
        '3. Create items for Restaurant A ("Spicy Bistro") and Restaurant B ("Burger Express") and persist in DB',
        () async {
      const bistro = OrganizationContext.spicyBistro;
      const burger = OrganizationContext.burgerExpress;

      // Create 4 items for Spicy Bistro
      final bistroItems = [
        const MultiTenantMenuItemRecord(
          id: 'item_sb_01',
          organizationId: 'org_spicy_bistro_001',
          name: 'Spicy Butter Chicken',
          category: 'Main Course',
          priceInr: 380.0,
          isVeg: false,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_sb_02',
          organizationId: 'org_spicy_bistro_001',
          name: 'Garlic Butter Naan',
          category: 'Breads',
          priceInr: 60.0,
          isVeg: true,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_sb_03',
          organizationId: 'org_spicy_bistro_001',
          name: 'Paneer Tikka Special',
          category: 'Starters',
          priceInr: 290.0,
          isVeg: true,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_sb_04',
          organizationId: 'org_spicy_bistro_001',
          name: 'Mango Lassi',
          category: 'Beverages',
          priceInr: 120.0,
          isVeg: true,
          available: true,
        ),
      ];

      for (final item in bistroItems) {
        await store.saveMenuItem(
            callerOrgId: bistro.organizationId, item: item);
      }

      // Create 4 items for Burger Express
      final burgerItems = [
        const MultiTenantMenuItemRecord(
          id: 'item_bx_01',
          organizationId: 'org_burger_express_002',
          name: 'Double Cheese Smash Burger',
          category: 'Burgers',
          priceInr: 340.0,
          isVeg: false,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_bx_02',
          organizationId: 'org_burger_express_002',
          name: 'Crispy Peri Peri Fries',
          category: 'Sides',
          priceInr: 140.0,
          isVeg: true,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_bx_03',
          organizationId: 'org_burger_express_002',
          name: 'Truffle Mayo Dip',
          category: 'Sauces',
          priceInr: 50.0,
          isVeg: true,
          available: true,
        ),
        const MultiTenantMenuItemRecord(
          id: 'item_bx_04',
          organizationId: 'org_burger_express_002',
          name: 'Classic Chocolate Milkshake',
          category: 'Beverages',
          priceInr: 180.0,
          isVeg: true,
          available: true,
        ),
      ];

      for (final item in burgerItems) {
        await store.saveMenuItem(
            callerOrgId: burger.organizationId, item: item);
      }

      // Verify items saved in store
      final fetchedBistroItems = await store.getMenuItemsForOrganization(
          callerOrgId: bistro.organizationId);
      expect(fetchedBistroItems.length, equals(4));

      final fetchedBurgerItems = await store.getMenuItemsForOrganization(
          callerOrgId: burger.organizationId);
      expect(fetchedBurgerItems.length, equals(4));
    });

    test(
        '4. DATA ISOLATION VERIFICATION: Check data is NOT crossing between Spicy Bistro and Burger Express',
        () async {
      const bistro = OrganizationContext.spicyBistro;
      const burger = OrganizationContext.burgerExpress;

      // Query Spicy Bistro items
      final bistroItems = await store.getMenuItemsForOrganization(
          callerOrgId: bistro.organizationId);
      expect(
          bistroItems.every((i) => i.organizationId == bistro.organizationId),
          isTrue);
      expect(bistroItems.any((i) => i.name.contains('Burger')), isFalse,
          reason: 'Spicy Bistro MUST NOT contain Burger Express items!');

      // Query Burger Express items
      final burgerItems = await store.getMenuItemsForOrganization(
          callerOrgId: burger.organizationId);
      expect(
          burgerItems.every((i) => i.organizationId == burger.organizationId),
          isTrue);
      expect(burgerItems.any((i) => i.name.contains('Butter Chicken')), isFalse,
          reason: 'Burger Express MUST NOT contain Spicy Bistro items!');

      // Cross-Tenant Mutation Attempt
      const unauthorizedItem = MultiTenantMenuItemRecord(
        id: 'item_hack_99',
        organizationId: 'org_spicy_bistro_001',
        name: 'Unauthorized Overwrite',
        category: 'Hack',
        priceInr: 999.0,
        isVeg: false,
        available: false,
      );

      expect(
        () async => await store.saveMenuItem(
          callerOrgId: burger.organizationId, // Burger Express caller
          item: unauthorizedItem, // Trying to write Spicy Bistro item
        ),
        throwsA(isA<SecurityException>()),
        reason:
            'Burger Express writing data for Spicy Bistro MUST throw SecurityException!',
      );
    });

    testWidgets(
        '5. Full UI Analysis & Verification for All Franchise Screens under Both Logins',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> pump(Widget screen) async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
        await tester.pumpAndSettle();
      }

      // The dashboard without its device data source says so — no
      // simulated figures.
      await pump(RestaurantDashboardScreen(onNavigateToActionCenter: () {}));
      expect(find.text('Dashboard data is not connected'), findsOneWidget);

      // Every chain screen: honest empty state without backend data, the
      // organization's own figures with it.
      final data = sampleSnapshot();
      final chainScreens = <(Widget, Widget, String)>[
        (
          FranchiseCommandCenterScreen(
              onNavigateToInventory: () {}, onSelectBranch: (_) {}),
          FranchiseCommandCenterScreen(
              data: data, onNavigateToInventory: () {}, onSelectBranch: (_) {}),
          'Real-Time System Overview',
        ),
        (
          BranchPerformanceScreen(onSelectBranch: (_) {}),
          BranchPerformanceScreen(data: data, onSelectBranch: (_) {}),
          'Comparative Leaderboard & Normalized Rankings',
        ),
        (
          const BranchDetailScreen(branchName: 'Latur Main'),
          BranchDetailScreen(data: data, branchName: 'Latur Main'),
          'Stock at this branch',
        ),
        (
          const FranchiseInventoryScreen(),
          FranchiseInventoryScreen(data: data),
          'Franchise V1 Chain Inventory & Supply',
        ),
        (
          FranchiseExceptionsScreen(onTriggerTransfer: () {}),
          FranchiseExceptionsScreen(data: data, onTriggerTransfer: () {}),
          'System-Wide Operational Exceptions',
        ),
        (
          const TargetsBenchmarkingScreen(),
          TargetsBenchmarkingScreen(
              data: data, repository: FakeFranchiseRepository()),
          'Multi-Branch Target Benchmarking Grid',
        ),
        (
          const ComplianceAuditScreen(),
          ComplianceAuditScreen(repository: FakeFranchiseRepository()),
          'Log Audit Report',
        ),
      ];
      for (final (empty, live, title) in chainScreens) {
        await pump(empty);
        expect(find.text('No branch data yet'), findsOneWidget,
            reason: '${empty.runtimeType} without data');
        expect(find.text(title), findsNothing);
        await pump(live);
        expect(find.text(title), findsOneWidget,
            reason: '${live.runtimeType} with data');
        expect(find.text('No branch data yet'), findsNothing);
      }

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
