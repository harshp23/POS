import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_form_dialog.dart';
import 'staff_ui.dart';

/// Dashboard tab (v1/staff managment/staff-dashboard.png).
class StaffDashboardTab extends StaffTabWidget {
  const StaffDashboardTab({
    super.key,
    required super.repository,
    super.refreshToken,
    super.branches,
    super.defaultBranchId,
    this.canManageStaff = true,
    this.onAssignRoles,
    this.onOpenDepartment,
  });

  /// Add employee / Import staff need the Staff tab.
  final bool canManageStaff;

  /// Opens the Roles & permissions tab (null hides the button).
  final VoidCallback? onAssignRoles;

  /// Opens the Staff tab filtered to a department (null hides the button).
  final ValueChanged<String?>? onOpenDepartment;

  @override
  State<StaffDashboardTab> createState() => _StaffDashboardTabState();
}

class _StaffDashboardTabState extends State<StaffDashboardTab>
    with StaffLoadState<StaffDashboardTab> {
  StaffDashboard _d = const StaffDashboard();
  List<StaffMember> _staff = const [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final results = await Future.wait<Object>([
      repo.dashboard(),
      if (widget.onOpenDepartment != null) repo.employees(),
    ]);
    _d = results[0] as StaffDashboard;
    if (results.length > 1) _staff = results[1] as List<StaffMember>;
  }

  Future<void> _addEmployee() async {
    final created = await showStaffFormDialog(context, repo,
        branches: widget.branches, defaultBranchId: widget.defaultBranchId);
    if (created == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Added ${created.fullName}');
  }

  Future<void> _import() async {
    final n = await showStaffImportDialog(context, repo);
    if (n == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Imported $n staff');
  }

  Future<void> _departments() async {
    final counts = <String, int>{};
    for (final m in _staff) {
      final d = m.department.trim().isEmpty ? '' : m.department.trim();
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final names = counts.keys.toList()..sort();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => StaffDialog(
        title: 'Departments',
        subtitle: 'Departments come from each employee\'s Department field. '
            'Pick one to see its staff.',
        width: 440,
        actions: [
          MasterButton(label: 'Close', onPressed: () => Navigator.pop(context)),
        ],
        body: names.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No staff yet.', style: MasterStyle.muted),
              )
            : Column(children: [
                for (final n in names)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined, size: 20),
                    title: Text(n.isEmpty ? 'No department' : n),
                    trailing:
                        Text('${counts[n]} staff', style: MasterStyle.muted),
                    onTap: () => Navigator.pop(context, n),
                  ),
              ]),
      ),
    );
    if (picked == null || !mounted) return;
    widget.onOpenDepartment?.call(picked);
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        guarded(() {
          final d = _d;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MasterGrid(
                    columns: 7,
                    minItemWidth: 150,
                    spacing: 12,
                    children: [
                      StaffStatTile(
                          label: 'Total employees',
                          value: '${d.total}',
                          icon: Icons.person_outline),
                      StaffStatTile(
                          label: 'Active',
                          value: '${d.active}',
                          icon: Icons.how_to_reg_outlined,
                          color: kStaffGreen,
                          tint: const Color(0xFFF0FDF4)),
                      StaffStatTile(
                          label: 'Inactive',
                          value: '${d.inactive}',
                          icon: Icons.person_off_outlined,
                          color: ViniiColors.textMutedLight,
                          labelColor: ViniiColors.textSecondaryLight),
                      StaffStatTile(
                          label: 'Online now',
                          value: '${d.onlineNow}',
                          icon: Icons.language,
                          color: kStaffGreen,
                          tint: const Color(0xFFF0FDF4)),
                      StaffStatTile(
                          label: 'On shift',
                          value: '${d.onShift}',
                          icon: Icons.schedule,
                          color: kStaffGreen,
                          tint: const Color(0xFFF0FDF4)),
                      StaffStatTile(
                          label: 'Off shift',
                          value: '${d.offShift}',
                          icon: Icons.schedule,
                          color: kStaffAmber,
                          tint: ViniiColors.amberTint),
                      StaffStatTile(
                          label: 'Pending',
                          value: '${d.pendingApprovals}',
                          icon: Icons.pending_actions_outlined,
                          color: kStaffRed,
                          tint: ViniiColors.redTint),
                    ]),
                const SizedBox(height: 24),
                MasterCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QUICK ACTIONS',
                            style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w700,
                                color: ViniiColors.textSecondaryLight)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 12, runSpacing: 10, children: [
                          if (widget.canManageStaff) ...[
                            MasterButton(
                                key: const Key('dashboard-add-employee'),
                                label: 'Add employee',
                                icon: Icons.add,
                                kind: MasterButtonKind.primary,
                                onPressed: _addEmployee),
                            MasterButton(
                                key: const Key('dashboard-import-staff'),
                                label: 'Import staff',
                                icon: Icons.upload_outlined,
                                onPressed: _import),
                          ],
                          if (widget.onAssignRoles != null)
                            MasterButton(
                                key: const Key('dashboard-assign-roles'),
                                label: 'Assign roles',
                                icon: Icons.shield_outlined,
                                onPressed: widget.onAssignRoles),
                          if (widget.onOpenDepartment != null)
                            MasterButton(
                                key: const Key('dashboard-departments'),
                                label: 'Departments',
                                icon: Icons.folder_outlined,
                                onPressed: _departments),
                        ]),
                      ]),
                ),
                const SizedBox(height: 24),
                MasterGrid(columns: 4, minItemWidth: 200, children: [
                  StaffValueCard(
                      label: 'Total Staff',
                      value: '${d.total}',
                      icon: Icons.groups_outlined),
                  StaffValueCard(
                      label: 'Active',
                      value: '${d.active}',
                      icon: Icons.how_to_reg_outlined),
                  StaffValueCard(
                      label: d.month.trim().isEmpty
                          ? 'Payable this month'
                          : 'Payable (${staffMonthLabel(d.month)})',
                      value: staffMoney(d.payableMonth),
                      icon: Icons.credit_card,
                      iconColor: ViniiColors.textPrimaryLight,
                      iconTint: const Color(0xFFF3F4F6)),
                  StaffValueCard(
                      label: 'Paid this month',
                      value: staffMoney(d.paidMonth),
                      icon: Icons.check),
                ]),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final present = StaffValueCard(
                      label: 'Present Today',
                      value: '${d.presentToday}',
                      icon: Icons.check_circle_outline);
                  final absent = StaffValueCard(
                      label: 'Absent Today',
                      value: '${d.absentToday}',
                      icon: Icons.highlight_off,
                      iconColor: kStaffRed,
                      iconTint: ViniiColors.redTint);
                  final pending = StaffValueCard(
                      label: 'Pending this month',
                      value: staffMoney(d.pendingMonth),
                      icon: Icons.schedule,
                      iconColor: kStaffAmber,
                      iconTint: ViniiColors.amberTint);
                  if (c.maxWidth < 700) {
                    return MasterGrid(
                        columns: 2,
                        minItemWidth: 200,
                        children: [present, absent, pending]);
                  }
                  return Row(children: [
                    Expanded(child: present),
                    const SizedBox(width: 16),
                    Expanded(child: absent),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: pending),
                  ]);
                }),
              ]);
        }),
      ]);
}
