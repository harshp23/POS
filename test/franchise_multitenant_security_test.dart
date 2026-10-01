import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/franchise_organization_store.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_command_center_screen.dart';

import 'support/franchise_fixtures.dart';

void main() {
  group('Multi-Tenant Franchise Organization Data Security & Isolation Tests',
      () {
    late MultiTenantFranchiseStore store;

    setUp(() {
      store = MultiTenantFranchiseStore();
    });

    test(
        '1. Single Restaurant ("Spicy Bistro") checks into Franchise, performs operations, and saves records securely',
        () async {
      // Step A: Restaurant check-in context
      const bistroContext = OrganizationContext.spicyBistro;
      expect(bistroContext.organizationId, equals('org_spicy_bistro_001'));
      expect(bistroContext.organizationName, equals('Spicy Bistro'));
      expect(bistroContext.locationId, equals('loc_delhi_cp'));

      // Step B: Save Lateral Stock Transfer Record
      final transferRecord = FranchiseOrganizationRecord(
        id: 'REC-TRANSFER-001',
        organizationId: bistroContext.organizationId,
        organizationName: bistroContext.organizationName,
        locationId: bistroContext.locationId,
        recordType: 'stock_transfer',
        details: {
          'item': 'Raw Chicken Breast',
          'quantity_kg': 15.0,
          'source_branch': 'Noida Sector 62',
          'target_branch': 'Delhi Connaught Place',
          'financial_impact': '₹45,000 revenue risk prevented',
        },
        createdAt: DateTime.now(),
        createdByStaff: bistroContext.staffName,
      );

      await store.saveRecord(
        callerOrgId: bistroContext.organizationId,
        record: transferRecord,
      );

      // Step C: Save Safety Stock Threshold Adjustment Record
      final stockAdjustmentRecord = FranchiseOrganizationRecord(
        id: 'REC-STOCK-002',
        organizationId: bistroContext.organizationId,
        organizationName: bistroContext.organizationName,
        locationId: bistroContext.locationId,
        recordType: 'safety_stock_adjustment',
        details: {
          'item': 'Fresh Cottage Cheese',
          'previous_threshold_kg': 10.0,
          'new_threshold_kg': 25.0,
        },
        createdAt: DateTime.now(),
        createdByStaff: bistroContext.staffName,
      );

      await store.saveRecord(
        callerOrgId: bistroContext.organizationId,
        record: stockAdjustmentRecord,
      );

      // Step D: Save Target Amendment Record
      final targetAmendmentRecord = FranchiseOrganizationRecord(
        id: 'REC-TARGET-003',
        organizationId: bistroContext.organizationId,
        organizationName: bistroContext.organizationName,
        locationId: bistroContext.locationId,
        recordType: 'target_amendment',
        details: {
          'target_name': 'Food Cost Target',
          'previous_value': '30.0%',
          'new_value': '28.5%',
        },
        createdAt: DateTime.now(),
        createdByStaff: bistroContext.staffName,
      );

      await store.saveRecord(
        callerOrgId: bistroContext.organizationId,
        record: targetAmendmentRecord,
      );

      // Step E: Save Compliance Audit Report Record
      final auditRecord = FranchiseOrganizationRecord(
        id: 'REC-AUDIT-004',
        organizationId: bistroContext.organizationId,
        organizationName: bistroContext.organizationName,
        locationId: bistroContext.locationId,
        recordType: 'audit_report',
        details: {
          'auditor_name': 'FSSAI Hygiene Inspector',
          'score': 95,
          'grade': 'A+',
          'status': 'Compliant',
        },
        createdAt: DateTime.now(),
        createdByStaff: bistroContext.staffName,
      );

      await store.saveRecord(
        callerOrgId: bistroContext.organizationId,
        record: auditRecord,
      );

      // Verify all 4 records were saved securely for Spicy Bistro
      final savedRecords = await store.getRecordsForOrganization(
        callerOrgId: bistroContext.organizationId,
      );
      expect(savedRecords.length, equals(4));
    });

    test(
        '2. ZERO DATA LEAKAGE TEST: Querying database as competing organization ("Burger Express") returns NO data of "Spicy Bistro"',
        () async {
      const spicyBistro = OrganizationContext.spicyBistro;
      const burgerExpress = OrganizationContext.burgerExpress;

      // Save a sensitive financial & inventory record for Spicy Bistro
      final spicyBistroData = FranchiseOrganizationRecord(
        id: 'SEC-CONFIDENTIAL-001',
        organizationId: spicyBistro.organizationId,
        organizationName: spicyBistro.organizationName,
        locationId: spicyBistro.locationId,
        recordType: 'financial_report',
        details: {
          'monthly_revenue_lakhs': 45.8,
          'profit_margin': '22.4%',
          'secret_recipe_cost': '₹1,20,000',
        },
        createdAt: DateTime.now(),
        createdByStaff: spicyBistro.staffName,
      );

      await store.saveRecord(
        callerOrgId: spicyBistro.organizationId,
        record: spicyBistroData,
      );

      // Query database under Burger Express org context
      final leakedData = await store.getRecordsForOrganization(
        callerOrgId: burgerExpress.organizationId,
      );

      // ASSERTION: ZERO DATA LEAKAGE!
      expect(leakedData, isEmpty,
          reason: 'Burger Express MUST NOT see Spicy Bistro data!');

      // Attempt direct ID access as Burger Express to Spicy Bistro's record ID
      expect(
        () async => await store.getRecordById(
          callerOrgId: burgerExpress.organizationId,
          recordId: 'SEC-CONFIDENTIAL-001',
        ),
        throwsA(isA<SecurityException>()),
        reason:
          'Direct cross-tenant access MUST throw a SecurityException to prevent data leaks!',
      );
    });

    test(
        '3. CROSS-TENANT MUTATION SECURITY TEST: Unauthorized organization cannot hijack or overwrite another organization data',
        () async {
      const spicyBistro = OrganizationContext.spicyBistro;
      const burgerExpress = OrganizationContext.burgerExpress;

      final maliciousRecord = FranchiseOrganizationRecord(
        id: 'REC-MALICIOUS-999',
        organizationId: spicyBistro.organizationId, // Target is Spicy Bistro
        organizationName: spicyBistro.organizationName,
        locationId: spicyBistro.locationId,
        recordType: 'target_amendment',
        details: {'malicious_change': 'Overwriting target'},
        createdAt: DateTime.now(),
        createdByStaff: burgerExpress.staffName,
      );

      // Attempting to save with Burger Express caller ID for Spicy Bistro org ID
      expect(
        () async => await store.saveRecord(
          callerOrgId: burgerExpress.organizationId,
          record: maliciousRecord,
        ),
        throwsA(isA<SecurityException>()),
        reason:
          'Saving records with callerOrgId mismatch MUST be blocked by Security Guard!',
      );

      // Attempting unauthorized deletion
      // First save legitimate record as Spicy Bistro
      final legitRecord = FranchiseOrganizationRecord(
        id: 'REC-LEGIT-100',
        organizationId: spicyBistro.organizationId,
        organizationName: spicyBistro.organizationName,
        locationId: spicyBistro.locationId,
        recordType: 'audit_report',
        details: {'valid': true},
        createdAt: DateTime.now(),
        createdByStaff: spicyBistro.staffName,
      );
      await store.saveRecord(
        callerOrgId: spicyBistro.organizationId,
        record: legitRecord,
      );

      // Burger Express tries to delete Spicy Bistro record
      expect(
        () async => await store.deleteRecord(
          callerOrgId: burgerExpress.organizationId,
          recordId: 'REC-LEGIT-100',
        ),
        throwsA(isA<SecurityException>()),
        reason:
          'Deleting another organization record MUST throw SecurityException!',
      );
    });

    testWidgets(
        '4. End-to-End Widget Test: "Spicy Bistro" franchise actions persist securely without leaking',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const bistroContext = OrganizationContext.spicyBistro;

      // Without chain data the screen invents nothing.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FranchiseCommandCenterScreen(
              onNavigateToInventory: () {},
              onSelectBranch: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No branch data yet'), findsOneWidget);
      expect(find.text('Transfer Stock'), findsNothing);

      // Pump Franchise Command Center Screen under Spicy Bistro context,
      // with the chain data the server returned.
      final transfers = <Object>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FranchiseCommandCenterScreen(
              data: sampleSnapshot(),
              onInitiateTransfer: (rec) async => transfers.add(rec),
              onNavigateToInventory: () {},
              onSelectBranch: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify UI renders Franchise Command Center
      expect(find.text('Real-Time System Overview'), findsOneWidget);

      // Perform a lateral stock transfer action in UI
      final transferButton = find.text('Transfer Stock');
      expect(transferButton, findsOneWidget);
      await tester.tap(transferButton);
      await tester.pumpAndSettle();
      expect(transfers, hasLength(1), reason: 'the transfer goes to the server');

      // Save the recorded action to the Multi-Tenant store under Spicy Bistro context
      final actionRecord = FranchiseOrganizationRecord(
        id: 'UI-ACTION-001',
        organizationId: bistroContext.organizationId,
        organizationName: bistroContext.organizationName,
        locationId: bistroContext.locationId,
        recordType: 'stock_transfer',
        details: {
          'action': 'Transfer 15kg Raw Chicken Breast',
          'source': 'Noida Sector 62',
          'destination': 'Delhi Connaught Place',
        },
        createdAt: DateTime.now(),
        createdByStaff: bistroContext.staffName,
      );

      await store.saveRecord(
        callerOrgId: bistroContext.organizationId,
        record: actionRecord,
      );

      // Verify record is securely stored for Spicy Bistro
      final bistroRecords = await store.getRecordsForOrganization(
        callerOrgId: bistroContext.organizationId,
      );
      expect(bistroRecords.length, equals(1));
      expect(bistroRecords.first.details['action'],
          equals('Transfer 15kg Raw Chicken Breast'));

      // Verify zero leakage to another organization
      final burgerRecords = await store.getRecordsForOrganization(
        callerOrgId: OrganizationContext.burgerExpress.organizationId,
      );
      expect(burgerRecords, isEmpty);

      // Clean up widget hierarchy
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
