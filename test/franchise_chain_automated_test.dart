import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/domain/access.dart';
import 'package:proviyaa_pos/domain/vendor_account.dart';
import 'package:proviyaa_pos/presentation/coming_soon_screen.dart';
import 'package:proviyaa_pos/presentation/dashboard/dashboard_widgets.dart';
import 'package:proviyaa_pos/presentation/franchise/branch_detail_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/branch_performance_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/compliance_audit_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_command_center_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_exceptions_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_vendor_shell.dart';
import 'package:proviyaa_pos/presentation/franchise/targets_benchmarking_screen.dart';

import 'support/franchise_fixtures.dart';

/// Figures and names from the old hard-coded design reference data. None
/// of them may appear on any screen any more.
const _referenceStrings = [
  'VINII Bengaluru - Indiranagar',
  'Bengaluru Indiranagar',
  'Delhi Connaught Place',
  'Noida Sector 62',
  'Abhishek Gupta',
  'Health Index: 5.2 (Poor)',
  '₹1,32,400',
  '₹18.45L',
  'Revenue Saved: ₹45,000',
  'Nandini Dairy',
  '3 chain-level exceptions require action',
  'Kitchen Turnaround Time (Avg 12m)',
];

void main() {
  void setLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
    await tester.pumpAndSettle();
  }

  void expectNoReferenceData() {
    for (final s in _referenceStrings) {
      expect(find.textContaining(s), findsNothing, reason: s);
    }
  }

  /// Taps [finder] after scrolling it into view.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool isEnabled(WidgetTester tester, Finder button) {
    final w = tester.widget(button);
    return switch (w) {
      ButtonStyleButton b => b.onPressed != null,
      _ => throw ArgumentError('not a button: $w'),
    };
  }

  group('without chain data every screen shows an honest empty state', () {
    testWidgets('command center, performance, detail, inventory, exceptions',
        (tester) async {
      setLargeSurface(tester);
      final screens = <Widget>[
        FranchiseCommandCenterScreen(
            onNavigateToInventory: () {}, onSelectBranch: (_) {}),
        BranchPerformanceScreen(onSelectBranch: (_) {}),
        const BranchDetailScreen(branchName: 'Delhi - Connaught Place'),
        const FranchiseInventoryScreen(),
        FranchiseExceptionsScreen(onTriggerTransfer: () {}),
      ];
      for (final screen in screens) {
        await pumpScreen(tester, screen);
        expect(find.text('No branch data yet'), findsOneWidget,
            reason: '${screen.runtimeType}');
        expect(find.textContaining(kConnectForBranchData), findsOneWidget);
        expect(find.text('Transfer Stock'), findsNothing);
        expect(find.text('Approve Transfer'), findsNothing);
        expect(find.text('Adjust Safety Stock'), findsNothing);
        expectNoReferenceData();
      }
    });

    testWidgets('targets and compliance need the server', (tester) async {
      setLargeSurface(tester);
      for (final screen in const <Widget>[
        TargetsBenchmarkingScreen(),
        ComplianceAuditScreen(),
      ]) {
        await pumpScreen(tester, screen);
        expect(find.text('No branch data yet'), findsOneWidget);
        expect(find.text('Change Target'), findsNothing);
        expect(find.text('Log Audit Report'), findsNothing);
        expect(find.textContaining('FSSAI hygiene certificate expires'),
            findsNothing);
      }
    });
  });

  group('Command Center', () {
    testWidgets('figures come from the snapshot; "—" when unknown',
        (tester) async {
      setLargeSurface(tester);
      String? selected;
      await pumpScreen(
          tester,
          FranchiseCommandCenterScreen(
            data: sampleSnapshot(),
            onNavigateToInventory: () {},
            onSelectBranch: (b) => selected = b,
          ));
      expect(find.text('Real-Time System Overview'), findsOneWidget);
      expect(find.text('₹2,450'), findsWidgets);
      expect(find.text('₹350'), findsOneWidget, reason: 'chain AOV');
      expect(find.text('31.2%'), findsOneWidget);
      expect(
          find.text('1 chain-level exception requires action'), findsOneWidget);
      // Operating profit and rating have no data.
      expect(
          find.byTooltip('Not enough data — needs labour cost in branch '
              'targets'),
          findsOneWidget);
      expect(find.byTooltip('Not enough data — no reviews connected'),
          findsOneWidget);
      expect(find.text('Branches not scored (no target or food-cost data)'),
          findsOneWidget);
      expectNoReferenceData();

      await tapVisible(tester, find.text('Latur Main').first);
      expect(selected, 'Latur Main');
    });

    testWidgets('Transfer Stock is disabled without a transfer action',
        (tester) async {
      setLargeSurface(tester);
      await pumpScreen(
          tester,
          FranchiseCommandCenterScreen(
            data: sampleSnapshot(),
            onNavigateToInventory: () {},
            onSelectBranch: (_) {},
          ));
      final button = find.widgetWithText(ElevatedButton, 'Transfer Stock');
      expect(isEnabled(tester, button), isFalse);
    });

    testWidgets('a failed transfer shows the error and keeps the suggestion',
        (tester) async {
      setLargeSurface(tester);
      var navigated = false;
      await pumpScreen(
          tester,
          FranchiseCommandCenterScreen(
            data: sampleSnapshot(),
            onNavigateToInventory: () => navigated = true,
            onSelectBranch: (_) {},
            onInitiateTransfer: (_) async =>
                throw FakeFranchiseRepository.failure,
          ));
      await tapVisible(tester, find.text('Transfer Stock'));
      expect(find.text('Transfer failed: Server unavailable'), findsOneWidget);
      expect(find.textContaining('Transfer recorded'), findsNothing);
      expect(find.text('Transfer Stock'), findsOneWidget);
      expect(navigated, isFalse);
    });

    testWidgets('a saved transfer is confirmed, then opens Inventory',
        (tester) async {
      setLargeSurface(tester);
      var navigated = false;
      final transferred = <String>[];
      await pumpScreen(
          tester,
          FranchiseCommandCenterScreen(
            data: sampleSnapshot(),
            onNavigateToInventory: () => navigated = true,
            onSelectBranch: (_) {},
            onInitiateTransfer: (rec) async => transferred.add(rec.id),
          ));
      await tapVisible(tester, find.text('Transfer Stock'));
      expect(transferred, ['TRF-1']);
      expect(
          find.text('Transfer recorded: 4 Paneer from Latur Main to Latur '
              'Station Road.'),
          findsOneWidget);
      expect(find.text('Transfer Stock'), findsNothing);
      expect(navigated, isTrue);
    });
  });

  group('Branch Performance', () {
    testWidgets('lists the snapshot branches with "—" for missing KPIs',
        (tester) async {
      setLargeSurface(tester);
      String? selected;
      await pumpScreen(
          tester,
          BranchPerformanceScreen(
              data: sampleSnapshot(), onSelectBranch: (b) => selected = b));
      expect(find.text('Latur Main'), findsOneWidget);
      expect(find.text('Latur Station Road'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('Not scored'), findsOneWidget);
      expect(find.byTooltip('Not enough data — no sales target set'),
          findsNWidgets(2));
      expect(find.text('Pin Selected (0)'), findsNothing);
      expect(find.text('Compare Branches'), findsNothing);

      await tester.enterText(find.byType(TextField), 'station');
      await tester.pumpAndSettle();
      expect(find.text('Latur Main'), findsNothing);
      await tester.tap(find.text('Latur Station Road'));
      expect(selected, 'Latur Station Road');
    });
  });

  group('Branch Detail', () {
    testWidgets('built from the branch\'s own row, stock and exceptions',
        (tester) async {
      setLargeSurface(tester);
      await pumpScreen(
          tester,
          BranchDetailScreen(
              data: sampleSnapshot(), branchName: 'Latur Station Road'));
      expect(find.text('Latur Station Road'), findsWidgets);
      expect(find.text('Not scored'), findsOneWidget);
      expect(find.text('Paneer'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(
          find.text('Low stock — Paneer (2 kg, reorder at 5)'), findsOneWidget);
      expect(find.text('Suggested transfers into this branch'), findsOneWidget);
      expect(find.byTooltip('Not enough data — no paid orders today'),
          findsOneWidget);
      expect(find.text('Adjust Safety Stock'), findsNothing);
      expect(find.text('Open Outlet'), findsNothing);
      expectNoReferenceData();
    });

    testWidgets('an unknown branch asks which branch to open', (tester) async {
      setLargeSurface(tester);
      String? selected;
      await pumpScreen(
          tester,
          BranchDetailScreen(
            data: sampleSnapshot(),
            branchName: 'Delhi - Connaught Place',
            onSelectBranch: (b) => selected = b,
          ));
      expect(find.text('Choose a branch'), findsOneWidget);
      await tester.tap(find.text('Latur Main'));
      await tester.pumpAndSettle();
      expect(selected, 'Latur Main');
      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('₹350'), findsOneWidget);
      expect(find.text('31.2%'), findsOneWidget);
    });
  });

  group('Exceptions', () {
    testWidgets('resolve buttons are disabled without a repository',
        (tester) async {
      setLargeSurface(tester);
      await pumpScreen(
          tester,
          FranchiseExceptionsScreen(
              data: sampleSnapshot(), onTriggerTransfer: () {}));
      expect(
          find.text('Low stock — Paneer (2 kg, reorder at 5)'), findsOneWidget);
      expect(
          isEnabled(
              tester, find.widgetWithText(ElevatedButton, 'Mark resolved')),
          isFalse);
      expect(
          isEnabled(
              tester, find.widgetWithText(ElevatedButton, 'Bulk Resolve All')),
          isFalse);
      expect(find.text('Initiated lateral stock transfer for Delhi CP!'),
          findsNothing);
    });

    testWidgets('a failed resolve shows the error and keeps the exception',
        (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository(fail: true);
      await pumpScreen(
          tester,
          FranchiseExceptionsScreen(
              data: sampleSnapshot(),
              repository: repo,
              onTriggerTransfer: () {}));
      await tapVisible(tester, find.text('Mark resolved'));
      expect(repo.calls, ['resolve:exc-1']);
      expect(find.text('Could not resolve the exception: Server unavailable'),
          findsOneWidget);
      expect(find.text('Exception marked resolved.'), findsNothing);
      expect(
          find.text('Low stock — Paneer (2 kg, reorder at 5)'), findsOneWidget);
    });

    testWidgets('a saved resolve removes it and asks for a reload',
        (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository();
      var reloads = 0;
      var transfers = 0;
      await pumpScreen(
          tester,
          FranchiseExceptionsScreen(
            data: sampleSnapshot(),
            repository: repo,
            onTriggerTransfer: () => transfers++,
            onChanged: () async => reloads++,
          ));
      await tapVisible(tester, find.text('Open transfer'));
      expect(transfers, 1, reason: 'navigation only');
      expect(repo.calls, isEmpty);

      await tapVisible(tester, find.text('Mark resolved'));
      expect(repo.calls, ['resolve:exc-1']);
      expect(find.text('Exception marked resolved.'), findsOneWidget);
      expect(find.text('No open exceptions'), findsWidgets);
      expect(reloads, 1);
    });
  });

  group('Inventory & Supply', () {
    testWidgets('approving a transfer saves it first', (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository();
      var reloads = 0;
      await pumpScreen(
          tester,
          FranchiseInventoryScreen(
            data: sampleSnapshot(),
            repository: repo,
            onChanged: () async => reloads++,
          ));
      // The purchase order has no price quote: prices are unknown, not ₹0.
      expect(
          find.byTooltip('No supplier price quote on file'), findsNWidgets(3));
      expect(find.text('Change Supplier'), findsNothing);
      expect(find.text('Adjust Par Level'), findsNothing);

      await tapVisible(tester, find.text('Approve Transfer'));
      expect(repo.calls, ['transfer:TRF-1']);
      expect(find.text('Transfer Approved'), findsOneWidget);
      expect(reloads, 1);
    });

    testWidgets('a failed approval is reported, not confirmed', (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository(fail: true);
      await pumpScreen(tester,
          FranchiseInventoryScreen(data: sampleSnapshot(), repository: repo));
      await tapVisible(tester, find.text('Approve Purchase'));
      expect(repo.calls, ['purchase:po-1:approve']);
      expect(find.text('Could not save: Server unavailable'), findsOneWidget);
      expect(find.textContaining('Approved the purchase order'), findsNothing);
    });

    testWidgets('without a repository the actions are disabled',
        (tester) async {
      setLargeSurface(tester);
      await pumpScreen(
          tester, FranchiseInventoryScreen(data: sampleSnapshot()));
      for (final label in ['Approve Transfer']) {
        expect(isEnabled(tester, find.widgetWithText(ElevatedButton, label)),
            isFalse,
            reason: label);
      }
      for (final label in ['Approve Purchase', 'Reject Purchase']) {
        expect(isEnabled(tester, find.widgetWithText(ElevatedButton, label)),
            isFalse,
            reason: label);
      }
      expect(
          isEnabled(
              tester, find.widgetWithText(OutlinedButton, 'Escalate Shortage')),
          isFalse);
    });
  });

  group('Targets & Benchmarking', () {
    testWidgets('targets start "Not set" and are saved as records',
        (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository();
      await pumpScreen(tester,
          TargetsBenchmarkingScreen(repository: repo, data: sampleSnapshot()));
      expect(
          find.text('Multi-Branch Target Benchmarking Grid'), findsOneWidget);
      expect(find.text('Not set'), findsNWidgets(5));
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.textContaining('Bengaluru Indiranagar has beaten'),
          findsNothing);

      await tapVisible(tester, find.text('Set Target').first);
      expect(find.text('Confirm Target Amendment'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('target-value')), '28');
      await tester.tap(find.text('Apply Target'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['log:target_amendment']);
      expect(repo.saved.single.details['value'], 28.0);
      expect(repo.saved.single.details['kpi'], 'Food Cost Ratio %');
      expect(find.text('Confirm Target Amendment'), findsNothing);
      expect(find.text('Food Cost Ratio % target saved: 28%.'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);
      // Chain food cost is 31.2% against a 28% target.
      expect(find.text('Above target by 3.2 pts'), findsOneWidget);
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('a failed save keeps the dialog open with the error',
        (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository(fail: true);
      await pumpScreen(tester, TargetsBenchmarkingScreen(repository: repo));
      await tapVisible(tester, find.text('Set Target').first);
      await tester.enterText(find.byKey(const Key('target-value')), '30');
      await tester.tap(find.text('Apply Target'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Target Amendment'), findsOneWidget);
      expect(find.text('Could not save the target: Server unavailable'),
          findsOneWidget);
      expect(find.textContaining('target saved'), findsNothing);
    });

    testWidgets('without a repository targets cannot be changed',
        (tester) async {
      setLargeSurface(tester);
      await pumpScreen(
          tester, TargetsBenchmarkingScreen(data: sampleSnapshot()));
      expect(
          isEnabled(
              tester, find.widgetWithText(OutlinedButton, 'Set Target').first),
          isFalse);
      expect(find.text(kNeedsServerToSave), findsOneWidget);
    });
  });

  group('Compliance & Audit', () {
    const locations = [
      BranchLocation(id: 'loc-main', name: 'Latur Main'),
      BranchLocation(id: 'loc-station', name: 'Latur Station Road'),
    ];

    testWidgets('raising a task saves it for the chosen branch',
        (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository();
      await pumpScreen(tester,
          ComplianceAuditScreen(repository: repo, locations: locations));
      expect(find.text('No compliance tasks yet. Use Raise Task to add one.'),
          findsOneWidget);
      expect(find.text('No audits logged yet'), findsOneWidget);

      await tester.tap(find.text('Raise Task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('task-observation')),
          'Replace the torn fly screen');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Raise Task'));
      await tester.pumpAndSettle();

      final task = repo.saved.single;
      expect(task.type, 'compliance_task');
      expect(task.locationId, 'loc-main');
      expect(task.details['observation'], 'Replace the torn fly screen');
      expect(find.text('Task raised for Latur Main.'), findsOneWidget);
      expect(find.text('Replace the torn fly screen'), findsOneWidget);

      await tapVisible(tester, find.text('Mark done'));
      expect(repo.calls.last, 'status:${task.id}:completed');
      expect(find.text('Task marked done.'), findsOneWidget);
      expect(find.text('No open compliance tasks.'), findsOneWidget);
    });

    testWidgets('logging an audit that fails shows the error', (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository(fail: true);
      await pumpScreen(tester,
          ComplianceAuditScreen(repository: repo, locations: locations));
      await tester.tap(find.text('Log Audit Report'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('audit-score')), '92');
      await tester.tap(find.text('Save Audit Report'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['log:audit_report']);
      expect(find.text('Could not save: Server unavailable'), findsOneWidget);
      expect(find.text('Log New Internal Compliance Audit'), findsOneWidget,
          reason: 'the dialog stays open');
      expect(find.textContaining('Audit logged'), findsNothing);
    });

    testWidgets('audit scores come from saved reports', (tester) async {
      setLargeSurface(tester);
      final repo = FakeFranchiseRepository();
      await repo.logRecord(
          'audit_report',
          'Internal audit: Latur Main — 90/100 (A)',
          {'branch': 'Latur Main', 'score': 90, 'grade': 'A'},
          status: 'completed',
          locationId: 'loc-main');
      await repo.logRecord(
          'audit_report',
          'Internal audit: Latur Station Road — 70/100 (C)',
          {'branch': 'Latur Station Road', 'score': 70, 'grade': 'C'},
          status: 'completed',
          locationId: 'loc-station');
      await pumpScreen(tester,
          ComplianceAuditScreen(repository: repo, locations: locations));
      expect(find.text('80 / 100'), findsOneWidget);
      expect(find.text('Grade B · 2 audits'), findsOneWidget);
      expect(find.text('92 / 100'), findsNothing);
      expect(find.text('Upload Docs'), findsNothing);
    });
  });

  group('Vendor shell', () {
    testWidgets('shows the signed-in user and only real controls',
        (tester) async {
      setLargeSurface(tester);
      final opened = <FranchiseTab>[];
      await tester.pumpWidget(MaterialApp(
        home: FranchiseVendorShell(
          activeTab: FranchiseTab.dashboard,
          onTabChanged: opened.add,
          content: const SizedBox(),
          organizationName: 'Latur Tiffin House',
          userEmail: 'asha@tiffin.test',
          userName: 'Asha Patil',
          roleName: 'Manager',
          allowedScreens: const {Screens.dashboard, Screens.opsBilling},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Asha Patil'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
      for (final gone in [
        'Rahul Khanna',
        'Principal Director',
        'Help',
        'Filter',
        'Q3 Summary',
        'NCR & Bengaluru Region',
        'Open / Accepting Online',
        'Reports',
        'Finance',
        'Action Center',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.byType(TextField), findsNothing,
          reason: 'no search box without search');

      await tester.tap(find.text('Quick Actions'));
      await tester.pumpAndSettle();
      expect(find.text('New order (POS Billing)'), findsOneWidget);
      expect(find.text('Staff & users'), findsNothing,
          reason: 'this role cannot open Staff');
      await tester.tap(find.text('New order (POS Billing)'));
      await tester.pumpAndSettle();
      expect(opened, [FranchiseTab.opsPosBilling]);
    });

    testWidgets(
        'the business sections follow the role; undesigned ones are tagged Soon',
        (tester) async {
      setLargeSurface(tester);
      const branch = ['Customers & CRM', 'Finance', 'Reports'];
      const ownersOnly = [
        'Task Manager',
        'Marketing',
        'Integrations',
        'Settings',
        'Page Builder',
        'Support',
      ];
      final opened = <FranchiseTab>[];
      Future<void> pumpFor(String role) async {
        await tester.pumpWidget(MaterialApp(
          home: FranchiseVendorShell(
            activeTab: FranchiseTab.dashboard,
            onTabChanged: opened.add,
            content: const SizedBox(),
            allowedScreens: PosRoles.defaultScreens(role),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpFor('org_owner');
      for (final s in [...branch, ...ownersOnly]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // Only Reports, Page Builder and Support are placeholders now.
      expect(find.text('Soon'), findsNWidgets(3));
      await tester.tap(find.text('Task Manager'));
      await tester.pumpAndSettle();
      expect(opened, [FranchiseTab.taskManager]);
      // A section group opens to its pages, as in the design.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      for (final page in [
        'Restaurant Settings',
        'POS Settings',
        'Order Settings',
        'Notification Settings',
        'Account Settings',
        'System Updates',
      ]) {
        expect(find.text(page), findsOneWidget, reason: page);
      }
      await tester.tap(find.text('Account Settings'));
      await tester.pumpAndSettle();
      expect(opened.last, FranchiseTab.settingsAccount);

      await pumpFor('location_manager');
      for (final s in branch) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      for (final s in ownersOnly) {
        expect(find.text(s), findsNothing, reason: s);
      }
      expect(find.text('Soon'), findsNWidgets(1));
    });

    testWidgets('a section still to be built says so and holds no data',
        (tester) async {
      setLargeSurface(tester);
      expect(comingSoonSections.keys.toSet(), {
        for (final s in Screens.all)
          if (s.group == 'Coming soon') s.id
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ComingSoonScreen(
              section: comingSoonSections[Screens.pageBuilder]!),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Page Builder'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('This section is not built yet'), findsOneWidget);
      for (final page in ['App Overview', 'App Builder', 'Publish']) {
        expect(find.text(page), findsOneWidget, reason: page);
      }
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('without a name the profile shows the email', (tester) async {
      setLargeSurface(tester);
      await tester.pumpWidget(const MaterialApp(
        home: FranchiseVendorShell(
          activeTab: FranchiseTab.dashboard,
          onTabChanged: _ignore,
          content: SizedBox(),
          userEmail: 'owner@tiffin.test',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('owner@tiffin.test'), findsOneWidget);
      expect(find.text('Action Center'), findsOneWidget);
    });
  });
}

void _ignore(FranchiseTab _) {}
