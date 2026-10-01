import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/staff_repository.dart';
import 'package:proviyaa_pos/data/staff_repository_memory.dart';
import 'package:proviyaa_pos/domain/access.dart';
import 'package:proviyaa_pos/presentation/staff/staff_management_screen.dart';

/// Drives Staff Management (lib/presentation/staff) against the on-device
/// [InMemoryStaffRepository], the way a restaurant owner uses it.
void main() {
  late InMemoryStaffRepository repo;

  setUp(() => repo = InMemoryStaffRepository());

  Future<void> pumpScreen(WidgetTester t,
      {StaffTab tab = StaffTab.dashboard, Set<String>? allowed}) async {
    t.view.physicalSize = const Size(1600, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StaffManagementScreen(
            repository: repo, initialTab: tab, allowedScreens: allowed),
      ),
    ));
    await t.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    expect(f, findsOneWidget, reason: 'no widget with key $key');
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester t, StaffTab tab) =>
      tapKey(t, 'staff-tab-${tab.name}');

  Future<void> enter(WidgetTester t, String key, String text) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await t.enterText(f, text);
    await t.pump();
  }

  testWidgets('every tab renders from the demo data', (t) async {
    await pumpScreen(t);
    expect(find.text('Staff Management'), findsOneWidget);
    expect(find.byKey(const Key('staff-demo-chip')), findsOneWidget);
    const expected = {
      StaffTab.dashboard: 'QUICK ACTIONS',
      StaffTab.staff: 'Pravin M',
      StaffTab.attendance: 'Mark all Present',
      StaffTab.salary: 'No salaries generated for this month yet',
      StaffTab.advances: 'No advances yet',
      StaffTab.roles: 'No roles yet',
      StaffTab.shifts: 'Roster & attendance',
      StaffTab.loginSecurity: 'Sessions & access',
      StaffTab.approvals: 'No pending approvals',
      StaffTab.auditLog: 'No activity recorded yet.',
      StaffTab.reports: 'Staff List',
      StaffTab.training: 'No training modules yet',
    };
    final opened = <StaffTab>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StaffManagementScreen(repository: repo, onTabChanged: opened.add),
      ),
    ));
    await t.pumpAndSettle();
    for (final e in expected.entries) {
      await openTab(t, e.key);
      expect(find.text(e.value), findsWidgets, reason: '${e.key.label} tab');
      expect(t.takeException(), isNull, reason: '${e.key.label} threw');
    }
    expect(opened, expected.keys.toList());

    // Shift master, login history and the roster's seeded shifts.
    await openTab(t, StaffTab.shifts);
    expect(find.text('Scheduled'.toUpperCase()), findsOneWidget);
    await tapKey(t, 'shifts-view-1');
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    await openTab(t, StaffTab.loginSecurity);
    expect(find.text('Owner'), findsOneWidget);
    await tapKey(t, 'security-view-1');
    expect(find.text('Success'), findsOneWidget);
  });

  testWidgets('adding staff with an app login lists them with that role',
      (t) async {
    await pumpScreen(t, tab: StaffTab.staff);
    expect(find.text('Staff Directory'), findsOneWidget);
    expect(find.text('Ramesh Singh'), findsOneWidget);

    await tapKey(t, 'staff-add-button');
    expect(find.text('Add Staff'), findsOneWidget);
    await enter(t, 'staff-name', 'Asha Patil');
    await enter(t, 'staff-mobile', '+91 9000011111');
    await enter(t, 'staff-email', 'asha@example.com');
    await enter(t, 'staff-designation', 'Cashier');
    await tapKey(t, 'staff-login-switch');
    // No roles yet: the dialog offers to seed the defaults.
    expect(find.text('No staff roles yet'), findsOneWidget);
    await tapKey(t, 'staff-seed-roles');
    await tapKey(t, 'staff-login-role');
    await tapText(t, 'Cashier');
    await enter(t, 'staff-login-password', 'secret123');
    await tapKey(t, 'staff-create');

    expect(find.text('Add Staff'), findsNothing, reason: 'dialog closed');
    expect(find.text('Asha Patil'), findsOneWidget);
    expect(find.text('Login: Cashier'), findsOneWidget);

    final login =
        (await repo.logins()).firstWhere((l) => l.email == 'asha@example.com');
    expect(login.roleName, 'Cashier');
    expect(login.posRole, 'biller');
    expect(login.staffName, 'Asha Patil');
    expect(login.forcePasswordChange, isTrue);

    await openTab(t, StaffTab.roles);
    expect(find.text('Staff & Access Management'), findsOneWidget);
    await tapKey(t, 'roles-view-0');
    expect(find.text('asha@example.com'), findsOneWidget);
    final roleDropdown = t.widget<DropdownButton<String>>(find.descendant(
        of: find.byKey(Key('access-role-${login.userId}')),
        matching: find.byType(DropdownButton<String>)));
    expect(roleDropdown.value, login.roleId);
    final linkDropdown = t.widget<DropdownButton<String>>(find.descendant(
        of: find.byKey(Key('access-link-${login.userId}')),
        matching: find.byType(DropdownButton<String>)));
    expect(linkDropdown.value, login.staffId);

    // The role filter chips come from the roles in use.
    await tapKey(t, 'access-filter-Cashier');
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('owner@demo.proviyaa.in'), findsNothing);

    // The eye icon lists the POS screens a Cashier opens.
    await tapKey(t, 'access-view-${login.userId}');
    expect(find.text(Screens.byId[Screens.posBilling]!.label), findsOneWidget);
    expect(find.text(Screens.byId[Screens.posKitchen]!.label), findsNothing);
  });

  testWidgets('duplicate login email is refused with the server message',
      (t) async {
    await repo.seedDefaultRoles();
    await pumpScreen(t, tab: StaffTab.staff);
    await tapKey(t, 'staff-add-button');
    await enter(t, 'staff-name', 'Second Owner');
    await enter(t, 'staff-email', 'owner@demo.proviyaa.in');
    await tapKey(t, 'staff-login-switch');
    await tapKey(t, 'staff-login-role');
    await tapText(t, 'Branch Manager');
    await enter(t, 'staff-login-password', 'secret123');
    await tapKey(t, 'staff-create');
    expect(find.text('An account with this email already exists.'),
        findsOneWidget);
    expect((await repo.employees()).length, 3);
  });

  testWidgets('Mark all Present marks every active employee', (t) async {
    await pumpScreen(t, tab: StaffTab.attendance);
    expect(find.text('Mark…'), findsNWidgets(3));
    await tapKey(t, 'attendance-mark-all');
    final rows = await repo.attendance(DateTime.now());
    expect(rows, hasLength(3));
    expect(rows.every((r) => r.status == 'present' && r.checkIn == '09:00'),
        isTrue);
    expect(find.text('Present: 3'), findsOneWidget);
    expect(find.text('Mark…'), findsNothing);
  });

  testWidgets('Generate Salaries shows the net for Pravin M', (t) async {
    await pumpScreen(t, tab: StaffTab.salary);
    expect(
        find.text('No salaries generated for this month yet'), findsOneWidget);
    await tapKey(t, 'salary-generate');
    expect(find.text('Pravin M'), findsOneWidget);
    final now = DateTime.now();
    final pravin = (await repo.salaries(now.year, now.month))
        .firstWhere((r) => r.staffName == 'Pravin M');
    expect(pravin.net, 24000);
    expect(find.text('₹24,000'), findsWidgets);
    expect(find.text('₹35,000'), findsWidgets);
  });

  testWidgets('a new advance is deducted when salaries are regenerated',
      (t) async {
    await pumpScreen(t, tab: StaffTab.advances);
    await tapKey(t, 'advance-new');
    await tapKey(t, 'advance-staff');
    await tapText(t, 'Pravin M · VIN-001');
    await enter(t, 'advance-amount', '5000');
    await enter(t, 'advance-reason', 'Travel');
    await tapKey(t, 'advance-save');
    expect(find.text('₹5,000'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);

    await openTab(t, StaffTab.salary);
    await tapKey(t, 'salary-generate');
    expect(find.text('₹19,000'), findsWidgets);
    final now = DateTime.now();
    final pravin = (await repo.salaries(now.year, now.month))
        .firstWhere((r) => r.staffName == 'Pravin M');
    expect(pravin.advance, 5000);
    expect(pravin.net, 19000);

    // Paying in full marks the advance deducted.
    await tapKey(t, 'salary-menu-${pravin.staffId}');
    await tapText(t, 'Pay');
    await tapKey(t, 'salary-pay-confirm');
    expect((await repo.advances()).single.status, 'deducted');
    expect(find.text('Paid'), findsWidgets);
  });

  testWidgets('approving a leave request moves it to history', (t) async {
    await pumpScreen(t, tab: StaffTab.approvals);
    await tapKey(t, 'approval-new');
    await tapKey(t, 'approval-staff');
    await tapText(t, 'Suresh Kumar · VIN-002');
    await enter(t, 'approval-reason', 'Family function');
    await tapKey(t, 'approval-submit');
    expect(find.textContaining('Family function'), findsOneWidget);

    final id = (await repo.approvals()).rows.single.id;
    await tapKey(t, 'approval-approve-$id');
    await enter(t, 'approval-note', 'Enjoy');
    await tapKey(t, 'approval-confirm');
    expect(find.text('No pending approvals'), findsOneWidget);

    await tapKey(t, 'approvals-view-1');
    expect(find.textContaining('Family function'), findsOneWidget);
    expect(find.text('Approved by You'), findsOneWidget);

    final today = (await repo.attendance(DateTime.now()))
        .firstWhere((a) => a.staffName == 'Suresh Kumar');
    expect(today.status, 'leave');
    final stats = await repo.approvals(history: true);
    expect(stats.approved, 1);
    expect(stats.leaveRequests, 1);
  });

  testWidgets('a custom role keeps only the ticked screens', (t) async {
    await pumpScreen(t, tab: StaffTab.roles);
    expect(find.text('No roles yet'), findsOneWidget);
    expect(find.text('Seed default roles'), findsOneWidget);
    await tapKey(t, 'roles-create');
    await enter(t, 'role-name', 'Night Manager');
    await tapKey(t, 'role-screen-${Screens.masterRecipes}');
    await tapKey(t, 'role-screen-${Screens.staffTraining}');
    await tapKey(t, 'role-save');

    expect(find.text('Night Manager'), findsOneWidget);
    final role = (await repo.roles()).roles.single;
    expect(role.baseRole, 'location_manager');
    expect(
        role.screens,
        PosRoles.defaultScreens('location_manager')
            .difference({Screens.masterRecipes, Screens.staffTraining}));
    expect(find.text('${role.screens.length} screens'), findsOneWidget);
    expect(find.text('Vendor panel'), findsOneWidget);

    // Seeding afterwards adds the five defaults next to it.
    await tapText(t, 'Seed default roles');
    expect((await repo.roles()).roles, hasLength(6));
    expect(find.text('Kitchen (KOT)'), findsWidgets);
  });

  testWidgets('a published training module can be taken and passed', (t) async {
    await pumpScreen(t, tab: StaffTab.training);
    await tapKey(t, 'training-create');
    expect(find.text('Module Creator & Test Builder'), findsOneWidget);
    await enter(t, 'training-title', 'Food Safety');
    await tapKey(t, 'training-add-video');
    await enter(t, 'training-video-0-title', 'Personal hygiene');
    await enter(t, 'training-video-0-duration', '12:00');
    await tapKey(t, 'training-add-question');
    await enter(t, 'training-q-0', 'Where is raw meat stored?');
    const options = ['Top shelf', 'Below 5°C', 'Room temperature', 'Stove'];
    for (var j = 0; j < 4; j++) {
      await enter(t, 'training-q-0-opt-$j', options[j]);
    }
    await tapKey(t, 'training-q-0-correct-1');
    await tapKey(t, 'training-publish');

    expect(find.text('Food Safety'), findsOneWidget);
    expect(find.text('Completion: 0/3 staff passed'), findsOneWidget);
    await tapText(t, 'Start Module');
    expect(find.text('Chapter 1: Personal hygiene'), findsOneWidget);
    expect(find.text('Assessment Test'), findsOneWidget);

    await tapKey(t, 'training-taker');
    await tapText(t, 'Pravin M · VIN-001');
    await tapKey(t, 'training-option-1');
    await tapKey(t, 'training-submit');
    expect(find.text('Passed'), findsOneWidget);
    expect(find.textContaining('scored 100%'), findsOneWidget);
    expect(find.text('Passed 100%'), findsOneWidget);

    final o = await repo.training();
    expect(o.modules.single.passedCount, 1);
    expect(o.completionsPassed, 1);

    await tapKey(t, 'training-back');
    expect(find.text('Completion: 1/3 staff passed'), findsOneWidget);
  });

  testWidgets('allowedScreens hides the other tabs', (t) async {
    await pumpScreen(t, allowed: {Screens.staffAttendance});
    expect(find.byKey(const Key('staff-tab-attendance')), findsOneWidget);
    for (final tab in StaffTab.values) {
      if (tab == StaffTab.attendance) continue;
      expect(find.byKey(Key('staff-tab-${tab.name}')), findsNothing,
          reason: '${tab.label} should be hidden');
    }
    expect(find.text('Mark all Present'), findsOneWidget);
    expect(find.text('QUICK ACTIONS'), findsNothing);
  });

  group('InMemoryStaffRepository', () {
    test('salary maths: absences, half days, OT, incentives, advances',
        () async {
      final r = InMemoryStaffRepository(seedDemo: false);
      final m = await r.createEmployee(const StaffMember(
        fullName: 'Test Cook',
        monthlySalary: 30000,
        workingHours: 8,
        compensationModel: 'salary_incentive',
        incentiveType: 'fixed_amount',
        incentiveValue: 1000,
      ));
      final day = DateTime(2026, 9, 1); // September has 30 days
      await r.saveAttendance(day, [
        AttendanceEntry(
            staffId: m.id, staffName: '', date: '', status: 'absent'),
      ]);
      await r.saveAttendance(DateTime(2026, 9, 2), [
        AttendanceEntry(
            staffId: m.id,
            staffName: '',
            date: '',
            status: 'present',
            otHours: 2),
      ]);
      await r.saveAttendance(DateTime(2026, 9, 3), [
        AttendanceEntry(
            staffId: m.id, staffName: '', date: '', status: 'half_day'),
      ]);
      await r.createAdvance(
          staffId: m.id,
          amount: 2000,
          date: day,
          deductMonth: 9,
          deductYear: 2026);
      final row = (await r.generateSalaries(2026, 9)).single;
      // 30000 − 1000 (absent) − 500 (half day)
      expect(row.basic, 28500);
      // 2 h × 30000 / (30 × 8)
      expect(row.ot, 250);
      expect(row.bonus, 1000);
      expect(row.advance, 2000);
      expect(row.net, 27750);

      final updated = await r.updateSalary(row.id, penalty: 750);
      expect(updated.net, 27000);
      final partial = await r.paySalary(row.id, amount: 7000);
      expect(partial.status, 'partial');
      expect((await r.advances()).single.status, 'open');
      final paid = await r.paySalary(row.id);
      expect(paid.status, 'paid');
      expect(paid.pending, 0);
      expect((await r.advances()).single.status, 'deducted');
      // Paid rows are not regenerated.
      expect((await r.generateSalaries(2026, 9)).single.net, 27000);
      expect((await r.reportCounts())['salary_paid'], 1);
    });

    test('roles: grantable screens, defaults and deletion rules', () async {
      final r = InMemoryStaffRepository();
      expect(
          () => r.createRole(
              name: 'Bad', baseRole: 'biller', screens: {Screens.opsLive}),
          throwsArgumentError);
      final roles = await r.seedDefaultRoles();
      expect(roles.map((x) => x.name), [
        'Restaurant Admin',
        'Branch Manager',
        'Cashier',
        'Captain',
        'Kitchen (KOT)',
      ]);
      final cashier = roles.firstWhere((x) => x.name == 'Cashier');
      expect(cashier.panel, 'pos');
      expect((await r.seedDefaultRoles()), hasLength(5));

      final chef = roles.firstWhere((x) => x.name == 'Kitchen (KOT)');
      final login = await r.createLogin(StaffLoginDraft(
          email: 'chef@example.com', password: 'longenough', roleId: chef.id));
      expect(login.posRole, 'kitchen');
      expect(() => r.deleteRole(chef.id), throwsStateError);
      expect(
          () => r.createLogin(StaffLoginDraft(
              email: 'CHEF@example.com',
              password: 'longenough',
              roleId: chef.id)),
          throwsStateError);
      final captain = roles.firstWhere((x) => x.name == 'Captain');
      final moved = await r.updateLogin(login.userId, {'role_id': captain.id});
      expect(moved.posRole, 'captain');
      await r.deleteRole(chef.id);
      expect((await r.roles()).roles, hasLength(4));

      final overview = await r.roles();
      final biller = overview.baseRoles.firstWhere((b) => b.key == 'biller');
      expect(biller.grantable.every((s) => s.startsWith('pos.')), isTrue);
      final admin = overview.baseRoles.firstWhere((b) => b.key == 'org_admin');
      expect(admin.grantable.any((s) => s.startsWith('pos.')), isFalse);
    });

    test('roster flags and clocking in marks attendance', () async {
      var now = DateTime(2026, 9, 15, 9, 30);
      final r = InMemoryStaffRepository(clock: () => now);
      final staff = await r.employees();
      final morning = (await r.shifts()).firstWhere((s) => s.name == 'Morning');
      final day = DateTime(2026, 9, 15);
      await r.assignShift(day, staff[0].id, morning.id);
      await r.assignShift(day, staff[1].id, morning.id);
      var roster = await r.roster(day);
      expect(roster.scheduled, 2);
      expect(roster.rows[0].flags, ['Absent']);
      expect(roster.rows[2].flags, ['Not scheduled']);

      await r.clockIn(roster.rows[0].rosterId!); // 09:30 > 09:10 grace
      roster = await r.roster(day);
      expect(roster.rows[0].flags, containsAll(['Late', 'On shift']));
      expect(roster.onShift, 1);
      expect(roster.late, 1);
      expect((await r.attendance(day)).first.status, 'present');
      expect((await r.dashboard()).onShift, 1);

      now = DateTime(2026, 9, 15, 19, 0);
      await r.clockOut(roster.rows[0].rosterId!);
      roster = await r.roster(day);
      // 9h30m − 30m break = 9h worked vs a 7h30m shift.
      expect(roster.rows[0].workedMinutes, 540);
      expect(roster.rows[0].overtimeMinutes, 90);
      expect(roster.rows[0].flags, contains('Overtime'));
      expect((await r.attendance(day)).first.otHours, 1.5);
    });

    test('training progress follows role names and designations', () async {
      final r = InMemoryStaffRepository();
      final m = await r.saveTrainingModule(const TrainingModule(
        title: 'Knife skills',
        roles: ['Chef'],
        passScore: 50,
        status: 'published',
        questions: [
          TrainingQuestion(question: 'Q1', options: ['a', 'b'], answerIndex: 0),
          TrainingQuestion(question: 'Q2', options: ['a', 'b'], answerIndex: 1),
        ],
      ));
      expect(m.assignedCount, 1);
      final ramesh = m.progress.single;
      expect(ramesh.staffName, 'Ramesh Singh');
      final fail = await r.submitTrainingAttempt(m.id, ramesh.staffId, [1, 0]);
      expect(fail.passed, isFalse);
      var o = await r.training();
      expect(o.modules.single.progress.single.status, 'failed');
      expect(o.failedAttempts, 1);
      final pass = await r.submitTrainingAttempt(m.id, ramesh.staffId, [0, 1]);
      expect(pass.score, 100);
      o = await r.training();
      expect(o.modules.single.progress.single.status, 'passed');
      expect(o.completionsPassed, 1);
      expect((await r.auditLog(query: 'training')).length, greaterThan(1));
    });
  });
}
