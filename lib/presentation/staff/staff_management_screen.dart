import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../../domain/access.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'advances_tab.dart';
import 'approvals_tab.dart';
import 'attendance_tab.dart';
import 'audit_log_tab.dart';
import 'login_security_tab.dart';
import 'reports_tab.dart';
import 'roles_tab.dart';
import 'salary_tab.dart';
import 'shifts_tab.dart';
import 'staff_dashboard_tab.dart';
import 'staff_directory_tab.dart';
import 'staff_form_dialog.dart';
import 'staff_ui.dart';
import 'training_tab.dart';

/// The tabs of Staff Management, in the order the tab bar shows them.
enum StaffTab {
  dashboard,
  staff,
  attendance,
  salary,
  advances,
  roles,
  shifts,
  loginSecurity,
  approvals,
  auditLog,
  reports,
  training,
}

extension StaffTabScreen on StaffTab {
  /// The access screen id (lib/domain/access.dart) that unlocks this tab.
  String get screenId => switch (this) {
        StaffTab.dashboard => Screens.staffDashboard,
        StaffTab.staff => Screens.staffDirectory,
        StaffTab.attendance => Screens.staffAttendance,
        StaffTab.salary => Screens.staffSalary,
        StaffTab.advances => Screens.staffAdvances,
        StaffTab.roles => Screens.staffRoles,
        StaffTab.shifts => Screens.staffShifts,
        StaffTab.loginSecurity => Screens.staffLoginSecurity,
        StaffTab.approvals => Screens.staffApprovals,
        StaffTab.auditLog => Screens.staffAuditLog,
        StaffTab.reports => Screens.staffReports,
        StaffTab.training => Screens.staffTraining,
      };

  String get label => switch (this) {
        StaffTab.dashboard => 'Dashboard',
        StaffTab.staff => 'Staff',
        StaffTab.attendance => 'Attendance',
        StaffTab.salary => 'Salary',
        StaffTab.advances => 'Advances',
        StaffTab.roles => 'Roles & permissions',
        StaffTab.shifts => 'Shifts & roster',
        StaffTab.loginSecurity => 'Login security',
        StaffTab.approvals => 'Approvals',
        StaffTab.auditLog => 'Audit log',
        StaffTab.reports => 'Reports',
        StaffTab.training => 'Training',
      };
}

/// Staff Management (vendor panel → Staff & Users): the content area with
/// the page header, the tab bar and the open tab. The vendor shell provides
/// the sidebar and top bar.
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    required this.repository,
    this.initialTab = StaffTab.dashboard,
    this.allowedScreens,
    this.onTabChanged,
    this.branches = const [],
    this.defaultBranchId,
  });

  final StaffRepository repository;
  final StaffTab initialTab;

  /// The restaurant's branches (VendorAccount.locations): names for the
  /// Branch columns and the Branch pickers of staff and logins. Empty hides
  /// the pickers.
  final List<BranchLocation> branches;

  /// Where new staff and logins start (the signed-in device's branch,
  /// VendorAccount.location?.id); the only branch is used when there is one.
  final String? defaultBranchId;

  /// Screen ids this account may open; null = every tab. Tabs whose
  /// [StaffTabScreen.screenId] isn't in the set are hidden.
  final Set<String>? allowedScreens;
  final ValueChanged<StaffTab>? onTabChanged;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late StaffTab _tab = _pick(widget.initialTab);

  /// Department the Staff tab opens filtered to (from the dashboard).
  String? _department;

  /// Bumped after header actions (imports) so the open tab reloads.
  int _refresh = 0;

  final _directoryKey = GlobalKey<StaffDirectoryTabState>();
  final _rolesKey = GlobalKey<RolesTabState>();
  final _trainingKey = GlobalKey<TrainingTabState>();

  bool _allowed(StaffTab t) =>
      widget.allowedScreens == null ||
      widget.allowedScreens!.contains(t.screenId);

  List<StaffTab> get _visible => [
        for (final t in StaffTab.values)
          if (_allowed(t)) t
      ];

  StaffTab _pick(StaffTab wanted) {
    if (_allowed(wanted)) return wanted;
    final v = _visible;
    return v.isEmpty ? wanted : v.first;
  }

  @override
  void didUpdateWidget(covariant StaffManagementScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) {
      _tab = _pick(widget.initialTab);
      _department = null;
    } else if (!_allowed(_tab)) {
      _tab = _pick(_tab);
    }
  }

  void _open(StaffTab t, {String? department}) {
    if (!_allowed(t)) return;
    setState(() {
      _tab = t;
      _department = department;
    });
    widget.onTabChanged?.call(t);
  }

  // ── header ─────────────────────────────────────────────────────────────

  (String, String, IconData) get _heading => switch (_tab) {
        StaffTab.staff => (
            'Staff Directory',
            'View contact info, joined date, department and direct billing '
                'codes.',
            Icons.people_outline
          ),
        StaffTab.attendance => (
            'Staff Management',
            'Attendance daily tracking logs and check-in/out stamps.',
            Icons.people_outline
          ),
        StaffTab.salary => (
            'Staff Management',
            'Monthly salaries from attendance, overtime, incentives and '
                'advances.',
            Icons.people_outline
          ),
        StaffTab.roles => (
            'Staff & Access Management',
            'Manage staff logins, the branch each works at, and the '
                'screens each role opens.',
            Icons.people_outline
          ),
        StaffTab.loginSecurity => (
            'Staff & Access Management',
            'Sessions, password resets and sign-in history for staff '
                'logins.',
            Icons.people_outline
          ),
        StaffTab.auditLog => (
            'Audit Log',
            'Audit trail of actions performed in this panel',
            Icons.history
          ),
        StaffTab.training => (
            'Staff Training Modules',
            'Manage training modules, track completion, and monitor staff '
                'certifications.',
            Icons.people_outline
          ),
        _ => (
            'Staff Management',
            'Staff details, attendance, salaries & reports',
            Icons.people_outline
          ),
      };

  List<Widget> get _actions => switch (_tab) {
        StaffTab.staff => [
            _importExport(),
            MasterButton(
                key: const Key('staff-add-button'),
                label: 'Add New Staff',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: () => _directoryKey.currentState?.addStaff()),
          ],
        StaffTab.roles => [
            _importExport(),
            MasterButton(
                key: const Key('staff-access-add'),
                label: 'Add New Staff',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: () => _rolesKey.currentState?.addLogin()),
          ],
        StaffTab.training => [
            MasterButton(
                key: const Key('training-create'),
                label: 'Create Module',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: () => _trainingKey.currentState?.createModule()),
          ],
        _ => [_importExport()],
      };

  /// "Import / Export": import staff from pasted CSV, export reports as
  /// CSV (copied to the clipboard).
  Widget _importExport() {
    final canImport = _allowed(StaffTab.staff);
    final exports = [
      if (_allowed(StaffTab.staff) || _allowed(StaffTab.reports))
        ('staff_list', 'Export staff list'),
      if (_allowed(StaffTab.attendance) || _allowed(StaffTab.reports))
        ('attendance', 'Export attendance'),
      if (_allowed(StaffTab.salary) || _allowed(StaffTab.reports))
        ('salaries', 'Export salaries'),
      if (_allowed(StaffTab.advances) || _allowed(StaffTab.reports))
        ('advances', 'Export advances'),
    ];
    if (!canImport && exports.isEmpty) return const SizedBox();
    return PopupMenuButton<String>(
      key: const Key('staff-import-export'),
      tooltip: 'Import / Export',
      position: PopupMenuPosition.under,
      onSelected: _onImportExport,
      itemBuilder: (_) => [
        if (canImport)
          const PopupMenuItem(
            value: 'import',
            child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.upload_outlined, size: 18),
                title: Text('Import staff (CSV)')),
          ),
        if (canImport && exports.isNotEmpty) const PopupMenuDivider(),
        for (final (kind, label) in exports)
          PopupMenuItem(
            value: kind,
            child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined, size: 18),
                title: Text(label)),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kStaffBorder),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_outlined,
              size: 16, color: ViniiColors.textPrimaryLight),
          SizedBox(width: 6),
          Text('Import / Export',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
        ]),
      ),
    );
  }

  Future<void> _onImportExport(String v) async {
    if (v == 'import') {
      final n = await showStaffImportDialog(context, widget.repository);
      if (n == null || !mounted) return;
      setState(() => _refresh++);
      showStaffNotice(context, 'Imported $n staff');
      return;
    }
    try {
      final table = await widget.repository.report(v);
      if (mounted) await copyStaffCsv(context, table);
    } catch (e) {
      if (mounted) showStaffError(context, e);
    }
  }

  Widget _header() {
    final (title, subtitle, icon) = _heading;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: kStaffIconGreen),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(title,
                          key: const Key('staff-page-title'),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: ViniiColors.textPrimaryLight)),
                    ),
                    if (!widget.repository.live) ...[
                      const SizedBox(width: 10),
                      const Tooltip(
                        message: 'Not connected to the Proviyaa backend — '
                            'changes stay on this device.',
                        child: StaffChip('Demo data',
                            key: Key('staff-demo-chip'),
                            color: Color(0xFFB45309),
                            tint: Color(0xFFFEF3C7)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(subtitle, style: MasterStyle.subtitle),
                ]),
          ),
        ]),
        Wrap(spacing: 10, runSpacing: 8, children: _actions),
      ],
    );
  }

  Widget _tabBar() => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kStaffBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final t in _visible)
              InkWell(
                key: Key('staff-tab-${t.name}'),
                onTap: () => _open(t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            width: 2,
                            color:
                                t == _tab ? kStaffDark : Colors.transparent)),
                  ),
                  child: Text(t.label,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              t == _tab ? FontWeight.w700 : FontWeight.w500,
                          color: t == _tab
                              ? ViniiColors.textPrimaryLight
                              : ViniiColors.textSecondaryLight)),
                ),
              ),
          ]),
        ),
      );

  Widget _body() {
    final repo = widget.repository;
    return switch (_tab) {
      StaffTab.dashboard => StaffDashboardTab(
          repository: repo,
          refreshToken: _refresh,
          branches: widget.branches,
          defaultBranchId: widget.defaultBranchId,
          canManageStaff: _allowed(StaffTab.staff),
          onAssignRoles:
              _allowed(StaffTab.roles) ? () => _open(StaffTab.roles) : null,
          onOpenDepartment: _allowed(StaffTab.staff)
              ? (d) => _open(StaffTab.staff, department: d)
              : null,
        ),
      StaffTab.staff => StaffDirectoryTab(
          key: _directoryKey,
          repository: repo,
          refreshToken: _refresh,
          branches: widget.branches,
          defaultBranchId: widget.defaultBranchId,
          department: _department,
        ),
      StaffTab.attendance =>
        AttendanceTab(repository: repo, refreshToken: _refresh),
      StaffTab.salary => SalaryTab(repository: repo, refreshToken: _refresh),
      StaffTab.advances =>
        AdvancesTab(repository: repo, refreshToken: _refresh),
      StaffTab.roles => RolesTab(
          key: _rolesKey,
          repository: repo,
          refreshToken: _refresh,
          branches: widget.branches,
          defaultBranchId: widget.defaultBranchId),
      StaffTab.shifts => ShiftsTab(repository: repo, refreshToken: _refresh),
      StaffTab.loginSecurity =>
        LoginSecurityTab(repository: repo, refreshToken: _refresh),
      StaffTab.approvals =>
        ApprovalsTab(repository: repo, refreshToken: _refresh),
      StaffTab.auditLog =>
        AuditLogTab(repository: repo, refreshToken: _refresh),
      StaffTab.reports =>
        StaffReportsTab(repository: repo, refreshToken: _refresh),
      StaffTab.training => TrainingTab(
          key: _trainingKey, repository: repo, refreshToken: _refresh),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) {
      return const ColoredBox(
        color: kStaffPageBg,
        child: StaffEmptyState(
          icon: Icons.lock_outline,
          title: 'No access',
          message: "Your role doesn't include any Staff Management screens. "
              'Ask the owner or an administrator for access.',
        ),
      );
    }
    return ColoredBox(
      color: kStaffPageBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: _header(),
        ),
        _tabBar(),
        Expanded(
          child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
        ),
      ]),
    );
  }
}
