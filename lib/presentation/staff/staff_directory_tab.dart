import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_form_dialog.dart';
import 'staff_ui.dart';

/// Staff tab — Staff Directory (v1/staff managment/staff-directory.png).
class StaffDirectoryTab extends StaffTabWidget {
  const StaffDirectoryTab(
      {super.key,
      required super.repository,
      super.refreshToken,
      super.branches,
      super.defaultBranchId,
      this.department});

  /// Opens filtered to this department (from the dashboard).
  final String? department;

  @override
  State<StaffDirectoryTab> createState() => StaffDirectoryTabState();
}

class StaffDirectoryTabState extends State<StaffDirectoryTab>
    with StaffLoadState<StaffDirectoryTab> {
  List<StaffMember> _staff = const [];
  String _query = '';
  late String? _department = widget.department;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant StaffDirectoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.department != widget.department) {
      setState(() => _department = widget.department);
    }
  }

  @override
  Future<void> fetch() async => _staff = await repo.employees();

  /// "Add New Staff" in the page header.
  Future<void> addStaff() async {
    final created = await showStaffFormDialog(context, repo,
        branches: widget.branches, defaultBranchId: widget.defaultBranchId);
    if (created == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Added ${created.fullName}');
  }

  Future<void> _edit(StaffMember m) async {
    final saved = await showStaffFormDialog(context, repo,
        existing: m,
        branches: widget.branches,
        defaultBranchId: widget.defaultBranchId);
    if (saved == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Saved ${saved.fullName}');
  }

  Future<void> _delete(StaffMember m) async {
    final ok = await staffConfirm(context,
        title: 'Delete ${m.fullName}?',
        message: m.hasLogin
            ? 'This removes the staff record and deactivates their app '
                'login (${m.loginEmail ?? ''}). Attendance and salary '
                'history stay in the reports.'
            : 'This removes the staff record. Attendance and salary history '
                'stay in the reports.');
    if (!ok || !mounted) return;
    await act(() => repo.deleteEmployee(m.id),
        success: 'Deleted ${m.fullName}');
  }

  String _branch(StaffMember m) =>
      staffBranchName(m.locationId, m.locationName, widget.branches);

  List<StaffMember> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final m in _staff)
        if ((_department == null || m.department == _department) &&
            (_status == 'all' || m.status == _status) &&
            (q.isEmpty ||
                m.fullName.toLowerCase().contains(q) ||
                m.mobile.toLowerCase().contains(q) ||
                m.staffCode.toLowerCase().contains(q) ||
                m.designation.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q) ||
                (m.locationId != null &&
                    _branch(m).toLowerCase().contains(q))))
          m
    ];
  }

  String _salary(StaffMember m) => switch (m.salaryType) {
        'daily' => '${staffMoney(m.dailyWage)}/day',
        'hourly' => '${staffMoney(m.hourlyRate)}/hr',
        _ => staffMoney(m.monthlySalary),
      };

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        guarded(() {
          if (_staff.isEmpty) {
            return MasterCard(
              child: StaffEmptyState(
                icon: Icons.people_outline,
                title: 'No staff yet',
                message: 'Add your team to track attendance, salaries and '
                    'give them app logins.',
                actions: [
                  MasterButton(
                      label: 'Add New Staff',
                      icon: Icons.add,
                      kind: MasterButtonKind.primary,
                      onPressed: addStaff),
                ],
              ),
            );
          }
          final departments = {
            for (final m in _staff)
              if (m.department.isNotEmpty) m.department
          }.toList()
            ..sort();
          final rows = _visible;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MasterSearchField(
                          hint: 'Search name, mobile, code…',
                          width: 300,
                          onChanged: (v) => setState(() => _query = v)),
                      SizedBox(
                        width: 200,
                        child: StaffSelect<String>(
                          key: const Key('staff-dept-filter'),
                          dense: true,
                          value: _department ?? '',
                          items: [
                            ('', 'All departments'),
                            for (final d in departments) (d, d),
                            if (_department != null &&
                                !departments.contains(_department))
                              (_department!, _department!),
                          ],
                          onChanged: (v) => setState(() => _department =
                              (v == null || v.isEmpty) ? null : v),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: StaffSelect<String>(
                          dense: true,
                          value: _status,
                          items: const [
                            ('all', 'All statuses'),
                            ('active', 'Active'),
                            ('inactive', 'Inactive'),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'all'),
                        ),
                      ),
                      Text('${rows.length} of ${_staff.length} staff',
                          style: MasterStyle.muted),
                    ]),
                const SizedBox(height: 16),
                MasterTable(
                  minWidth: 1120,
                  columns: const [
                    MasterColumn('Photo', flex: 6),
                    MasterColumn('Name', flex: 16),
                    MasterColumn('Mobile', flex: 13),
                    MasterColumn('Role', flex: 11),
                    MasterColumn('Dept', flex: 11),
                    MasterColumn('Branch', flex: 12),
                    MasterColumn('Joined', flex: 11),
                    MasterColumn('Salary', flex: 11),
                    MasterColumn('Status', flex: 8),
                    MasterColumn('Actions', flex: 8, alignEnd: true),
                  ],
                  rows: [
                    for (final m in rows)
                      [
                        StaffAvatar(initials: m.initials, photoUrl: m.photoUrl),
                        MasterCellTitle(m.fullName,
                            subtitle: m.staffCode.isEmpty ? null : m.staffCode),
                        MasterCellText(m.mobile.isEmpty ? '—' : m.mobile),
                        MasterCellTitle(
                            m.designation.isEmpty ? '—' : m.designation,
                            subtitle: m.hasLogin
                                ? 'Login: ${m.roleName ?? 'no role'}'
                                : null),
                        MasterCellText(
                            m.department.isEmpty ? '—' : m.department),
                        MasterCellText(_branch(m)),
                        MasterCellText(staffDate(m.joiningDate)),
                        MasterCellText(_salary(m), bold: true),
                        MasterStatusPill(m.isActive ? 'Active' : 'Inactive'),
                        Wrap(children: [
                          StaffIconAction(
                              key: Key('staff-edit-${m.id}'),
                              tooltip: 'Edit',
                              icon: Icons.edit_note,
                              onPressed: () => _edit(m)),
                          StaffIconAction(
                              key: Key('staff-delete-${m.id}'),
                              tooltip: 'Delete',
                              icon: Icons.delete_outline,
                              color: ViniiColors.redSolid,
                              onPressed: busy ? null : () => _delete(m)),
                        ]),
                      ]
                  ],
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('No staff match these filters.',
                            style: MasterStyle.muted)),
                  ),
              ]);
        }),
      ]);
}
