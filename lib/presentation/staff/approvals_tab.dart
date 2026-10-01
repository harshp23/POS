import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'attendance_tab.dart' show attendanceStatusLabels;
import 'staff_ui.dart';

const approvalTypeLabels = {
  'leave': 'Leave',
  'salary_advance': 'Salary advance',
  'shift_change': 'Shift change',
  'attendance_correction': 'Attendance correction',
  'other': 'Other',
};

/// Approvals tab (v1/staff managment/staff-approvals-v3.png): leave and
/// salary-advance requests; approving a leave marks the days as leave,
/// approving an advance records it for salary deduction.
class ApprovalsTab extends StaffTabWidget {
  const ApprovalsTab(
      {super.key, required super.repository, super.refreshToken});

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab>
    with StaffLoadState<ApprovalsTab> {
  bool _history = false;
  ApprovalsOverview _o = const ApprovalsOverview();
  List<StaffMember> _staff = const [];
  String _query = '';
  String _type = '';
  String _staffId = '';
  bool _thisMonth = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final r = await Future.wait<Object>(
        [repo.approvals(history: _history), repo.employees()]);
    _o = r[0] as ApprovalsOverview;
    _staff = r[1] as List<StaffMember>;
  }

  void _setView(bool history) {
    if (history == _history) return;
    setState(() {
      _history = history;
      loaded = false;
    });
    reload();
  }

  static String details(StaffApproval a) {
    final d = a.details;
    String text(String key) => '${d[key] ?? ''}'.trim();
    final reason = text('reason');
    switch (a.type) {
      case 'leave':
        final from = staffDate(text('from'));
        final to = staffDate(text('to'));
        final range = from == to ? from : '$from – $to';
        return reason.isEmpty ? range : '$range · $reason';
      case 'salary_advance':
        final amount = staffParseNum(text('amount')) ?? 0;
        final m = int.tryParse(text('deduct_month'));
        final y = int.tryParse(text('deduct_year'));
        return [
          staffMoney(amount),
          if (m != null && y != null) 'deduct in ${staffMonthYear(m, y)}',
          if (reason.isNotEmpty) reason,
        ].join(' · ');
      case 'shift_change':
        final shift = text('shift');
        final start = text('start_time');
        final end = text('end_time');
        final parts = [
          if (text('date').isNotEmpty) staffDate(text('date')),
          if (shift.isNotEmpty)
            start.isEmpty || end.isEmpty
                ? 'Shift: $shift'
                : 'Shift: $shift ($start–$end)',
          if (reason.isNotEmpty) reason,
        ];
        return parts.isEmpty ? '—' : parts.join(' · ');
      case 'attendance_correction':
        final status = text('status');
        final parts = [
          if (text('date').isNotEmpty) staffDate(text('date')),
          if (status.isNotEmpty)
            attendanceStatusLabels[status] ?? staffCodeLabel(status),
          if (text('check_in').isNotEmpty) 'In ${text('check_in')}',
          if (text('check_out').isNotEmpty) 'Out ${text('check_out')}',
          if (reason.isNotEmpty) reason,
        ];
        return parts.isEmpty ? '—' : parts.join(' · ');
      default:
        return reason.isEmpty ? '—' : reason;
    }
  }

  List<StaffApproval> get _rows {
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();
    return [
      for (final a in _o.rows)
        if ((_type.isEmpty || a.type == _type) &&
            (_staffId.isEmpty || a.staffId == _staffId) &&
            (!_thisMonth ||
                (a.requestedAt.year == now.year &&
                    a.requestedAt.month == now.month)) &&
            (q.isEmpty ||
                a.staffName.toLowerCase().contains(q) ||
                (approvalTypeLabels[a.type] ?? a.type)
                    .toLowerCase()
                    .contains(q) ||
                details(a).toLowerCase().contains(q) ||
                (a.decidedByName ?? '').toLowerCase().contains(q)))
          a
    ];
  }

  Future<void> _decide(StaffApproval a, bool approve) async {
    final v = await showStaffPrompt(
      context,
      title: approve ? 'Approve request?' : 'Decline request?',
      subtitle: '${a.staffName} · ${approvalTypeLabels[a.type] ?? a.type}',
      confirmLabel: approve ? 'Approve' : 'Decline',
      confirmKey: const Key('approval-confirm'),
      danger: !approve,
      fields: const [
        StaffPromptField('note', 'Note (optional)',
            key: Key('approval-note'), maxLines: 2),
      ],
      note: Text(
          approve
              ? switch (a.type) {
                  'leave' => 'The days will be marked as Leave in attendance.',
                  'salary_advance' =>
                    'An advance will be recorded and deducted from salary.',
                  _ => details(a),
                }
              : details(a),
          style: MasterStyle.muted),
    );
    if (v == null || !mounted) return;
    await act(
        () => repo.decideApproval(a.id,
            approve: approve,
            note: (v['note'] ?? '').isEmpty ? null : v['note']),
        success: '${approve ? 'Approved' : 'Declined'} ${a.staffName}\'s '
            '${(approvalTypeLabels[a.type] ?? a.type).toLowerCase()} request');
  }

  Future<void> _newRequest() async {
    final active = [
      for (final s in _staff)
        if (s.isActive) s
    ];
    if (active.isEmpty) {
      showStaffError(context, 'Add an active staff member first.');
      return;
    }
    final created = await showDialog<StaffApproval>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RequestDialog(repository: repo, staff: active),
    );
    if (created == null || !mounted) return;
    if (_history) {
      _setView(false);
    } else {
      await reload();
    }
    if (mounted) {
      showStaffNotice(context, 'Request raised for ${created.staffName}');
    }
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        MasterGrid(columns: 6, minItemWidth: 160, spacing: 12, children: [
          StaffStatTile(
              label: 'Total',
              value: '${_o.total}',
              icon: Icons.assignment_outlined),
          StaffStatTile(
              label: 'Pending',
              value: '${_o.pending}',
              icon: Icons.schedule,
              color: kStaffAmber,
              tint: ViniiColors.amberTint),
          StaffStatTile(
              label: 'Approved',
              value: '${_o.approved}',
              icon: Icons.check_circle_outline,
              color: kStaffGreen,
              tint: const Color(0xFFF0FDF4)),
          StaffStatTile(
              label: 'Declined',
              value: '${_o.declined}',
              icon: Icons.highlight_off,
              color: kStaffRed,
              tint: ViniiColors.redTint),
          StaffStatTile(
              label: 'Leave requests',
              value: '${_o.leaveRequests}',
              icon: Icons.event_outlined,
              color: kStaffPurple,
              tint: ViniiColors.purpleTint),
          StaffStatTile(
              label: 'Salary advances',
              value: '${_o.salaryAdvances}',
              icon: Icons.payments_outlined,
              color: kStaffAmber,
              tint: ViniiColors.amberTint),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: StaffPills(
                keyPrefix: 'approvals-view',
                options: const ['Pending approvals', 'Approval history'],
                selected: _history ? 1 : 0,
                onSelect: (i) => _setView(i == 1)),
          ),
          MasterButton(
              key: const Key('approval-new'),
              label: 'New request',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: loaded ? _newRequest : null),
        ]),
        const SizedBox(height: 14),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MasterSearchField(
                  hint: 'Search actions, users, entities...',
                  width: 300,
                  onChanged: (v) => setState(() => _query = v)),
              SizedBox(
                width: 190,
                child: StaffSelect<String>(
                  key: const Key('approval-type-filter'),
                  dense: true,
                  value: _type,
                  items: [
                    ('', 'All Types'),
                    for (final e in approvalTypeLabels.entries) (e.key, e.value)
                  ],
                  onChanged: (v) => setState(() => _type = v ?? ''),
                ),
              ),
              SizedBox(
                width: 150,
                child: StaffSelect<bool>(
                  dense: true,
                  value: _thisMonth,
                  items: const [(false, 'All time'), (true, 'This Month')],
                  onChanged: (v) => setState(() => _thisMonth = v ?? false),
                ),
              ),
              SizedBox(
                width: 190,
                child: StaffSelect<String>(
                  key: const Key('approval-staff-filter'),
                  dense: true,
                  value: _staffId,
                  items: [
                    ('', 'All Staff'),
                    for (final s in _staff)
                      (s.id, staffPickLabel(s.fullName, s.staffCode))
                  ],
                  onChanged: (v) => setState(() => _staffId = v ?? ''),
                ),
              ),
            ]),
        const SizedBox(height: 16),
        guarded(() {
          final rows = _rows;
          return MasterTable(
            minWidth: 1000,
            columns: [
              const MasterColumn('Requesting Staff', flex: 14),
              const MasterColumn('Type', flex: 11),
              const MasterColumn('Details', flex: 26),
              const MasterColumn('Date Requested', flex: 13),
              if (_history)
                const MasterColumn('Decision', flex: 16)
              else
                const MasterColumn('Actions', flex: 16, alignEnd: true),
            ],
            rows: [
              for (final a in rows)
                [
                  MasterCellText(a.staffName, bold: true),
                  StaffChip(approvalTypeLabels[a.type] ?? a.type,
                      color: a.type == 'leave'
                          ? kStaffPurple
                          : a.type == 'salary_advance'
                              ? kStaffAmber
                              : ViniiColors.graySolid),
                  MasterCellText(details(a)),
                  MasterCellText(staffDateTime(a.requestedAt)),
                  if (_history)
                    MasterCellTitle(
                        '${a.status == 'approved' ? 'Approved' : 'Declined'}'
                        '${a.decidedByName == null ? '' : ' by ${a.decidedByName}'}',
                        subtitle: [
                          staffDateTime(a.decidedAt),
                          if ((a.decisionNote ?? '').isNotEmpty)
                            a.decisionNote!,
                        ].join(' · '))
                  else
                    Wrap(spacing: 8, children: [
                      MasterButton(
                          key: Key('approval-approve-${a.id}'),
                          label: 'Approve',
                          kind: MasterButtonKind.primary,
                          onPressed: busy ? null : () => _decide(a, true)),
                      MasterButton(
                          key: Key('approval-decline-${a.id}'),
                          label: 'Decline',
                          kind: MasterButtonKind.dangerOutline,
                          onPressed: busy ? null : () => _decide(a, false)),
                    ]),
                ]
            ],
            footer: rows.isEmpty
                ? StaffEmptyState(
                    icon: Icons.inbox_outlined,
                    title: _history
                        ? 'No approval history yet'
                        : 'No pending approvals',
                    message: _history
                        ? 'Approved and declined requests show up here.'
                        : 'All caught up! There are no approval requests '
                            'waiting for your action.',
                  )
                : null,
          );
        }),
      ]);
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.repository, required this.staff});
  final StaffRepository repository;
  final List<StaffMember> staff;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  String? _staffId;
  String _type = 'leave';
  DateTime _from = staffToday();
  DateTime _to = staffToday();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late int _month = DateTime(_from.year, _from.month + 1).month;
  late int _year = DateTime(_from.year, _from.month + 1).year;
  bool _saving = false;
  String? _error;

  /// Shift change / attendance correction: the day it is about.
  DateTime _day = staffToday();

  /// Shift change: the shift wanted (from the shift master).
  String? _shiftId;
  List<Shift>? _shifts;
  String? _shiftsError;

  /// Attendance correction: what the day should say.
  String? _status;
  String? _checkIn;
  String? _checkOut;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await widget.repository.shifts();
      if (mounted) {
        setState(() => _shifts = [
              for (final s in shifts)
                if (s.active) s
            ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shifts = const [];
          _shiftsError = staffErrorText(e);
        });
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_staffId == null) {
      setState(() => _error = 'Pick who the request is for.');
      return;
    }
    final reason = _reason.text.trim();
    Map<String, Object?> details;
    switch (_type) {
      case 'leave':
        if (_to.isBefore(_from)) {
          setState(() => _error = 'The leave ends before it starts.');
          return;
        }
        details = {
          'from': isoDate(_from),
          'to': isoDate(_to),
          'reason': reason
        };
      case 'salary_advance':
        final amount = staffParseNum(_amount.text, fallback: null);
        if (amount == null || amount <= 0) {
          setState(() => _error = 'Enter the advance amount.');
          return;
        }
        details = {
          'amount': amount,
          'reason': reason,
          'deduct_month': _month,
          'deduct_year': _year,
        };
      case 'shift_change':
        final shift =
            (_shifts ?? const <Shift>[]).where((s) => s.id == _shiftId);
        if (shift.isEmpty) {
          setState(() => _error = 'Pick the shift they should work.');
          return;
        }
        details = {
          'date': isoDate(_day),
          'shift_id': shift.first.id,
          'shift': shift.first.name,
          'start_time': shift.first.startTime,
          'end_time': shift.first.endTime,
          'reason': reason,
        };
      case 'attendance_correction':
        if (_status == null) {
          setState(() => _error = 'Pick what the attendance should say.');
          return;
        }
        details = {
          'date': isoDate(_day),
          'status': _status,
          if ((_checkIn ?? '').isNotEmpty) 'check_in': _checkIn,
          if ((_checkOut ?? '').isNotEmpty) 'check_out': _checkOut,
          'reason': reason,
        };
      default:
        if (reason.isEmpty) {
          setState(() => _error = 'Describe the request.');
          return;
        }
        details = {'reason': reason};
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final a = await widget.repository
          .createApproval(staffId: _staffId!, type: _type, details: details);
      if (mounted) Navigator.pop(context, a);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = _from.year - 1; y <= _from.year + 2; y++) y];
    return StaffDialog(
      title: 'New request',
      subtitle: 'Raise a request on behalf of a staff member',
      width: 540,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('approval-submit'),
            label: _saving ? 'Saving…' : 'Submit request',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          StaffField(
            label: 'Staff',
            required: true,
            child: StaffSelect<String>(
              key: const Key('approval-staff'),
              value: _staffId,
              hint: 'Select staff',
              items: [
                for (final s in widget.staff)
                  (s.id, staffPickLabel(s.fullName, s.staffCode))
              ],
              onChanged: (v) => setState(() => _staffId = v),
            ),
          ),
          StaffField(
            label: 'Type',
            child: StaffSelect<String>(
              key: const Key('approval-type'),
              value: _type,
              items: [
                for (final e in approvalTypeLabels.entries) (e.key, e.value)
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ),
        ]),
        if (_type == 'leave')
          StaffFormRow(children: [
            StaffField(
              label: 'From',
              child: StaffDateButton(
                  key: const Key('approval-from'),
                  value: _from,
                  onChanged: (d) => setState(() {
                        _from = d;
                        if (_to.isBefore(d)) _to = d;
                      })),
            ),
            StaffField(
              label: 'To',
              child: StaffDateButton(
                  key: const Key('approval-to'),
                  value: _to,
                  onChanged: (d) => setState(() => _to = d)),
            ),
          ]),
        if (_type == 'salary_advance') ...[
          StaffFormRow(children: [
            StaffField(
              label: 'Amount',
              required: true,
              child: TextField(
                  key: const Key('approval-amount'),
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput(prefix: '₹ ')),
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Deduct in month',
              child: StaffSelect<int>(
                value: _month,
                items: [
                  for (var m = 1; m <= 12; m++) (m, staffMonthNames[m - 1])
                ],
                onChanged: (v) => setState(() => _month = v ?? _month),
              ),
            ),
            StaffField(
              label: 'Year',
              child: StaffSelect<int>(
                value: _year,
                items: [for (final y in years) (y, '$y')],
                onChanged: (v) => setState(() => _year = v ?? _year),
              ),
            ),
          ]),
        ],
        if (_type == 'shift_change' || _type == 'attendance_correction')
          StaffFormRow(children: [
            StaffField(
              label: 'Date',
              required: true,
              child: StaffDateButton(
                  key: const Key('approval-day'),
                  value: _day,
                  onChanged: (d) => setState(() => _day = d)),
            ),
            if (_type == 'shift_change')
              StaffField(
                label: 'Shift',
                required: true,
                child: StaffSelect<String>(
                  key: const Key('approval-shift'),
                  value: _shiftId,
                  hint: _shifts == null
                      ? 'Loading shifts…'
                      : _shifts!.isEmpty
                          ? (_shiftsError ?? 'No shifts yet')
                          : 'Select shift',
                  items: [
                    for (final s in _shifts ?? const <Shift>[])
                      (s.id, '${s.name} (${s.startTime}–${s.endTime})')
                  ],
                  onChanged: (_shifts ?? const <Shift>[]).isEmpty
                      ? null
                      : (v) => setState(() => _shiftId = v),
                ),
              )
            else
              StaffField(
                label: 'Should be',
                required: true,
                child: StaffSelect<String>(
                  key: const Key('approval-attendance-status'),
                  value: _status,
                  hint: 'Select status',
                  items: [
                    for (final e in attendanceStatusLabels.entries)
                      (e.key, e.value)
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
          ]),
        if (_type == 'shift_change' &&
            _shifts != null &&
            _shifts!.isEmpty &&
            _shiftsError == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
                'Create shifts in Shifts & roster → Shift master to pick one '
                'here.',
                style: MasterStyle.muted),
          ),
        if (_type == 'attendance_correction')
          StaffFormRow(children: [
            StaffField(
              label: 'Check-in (optional)',
              child: StaffTimeButton(
                  key: const Key('approval-check-in'),
                  value: _checkIn,
                  onChanged: (v) => setState(() => _checkIn = v)),
            ),
            StaffField(
              label: 'Check-out (optional)',
              child: StaffTimeButton(
                  key: const Key('approval-check-out'),
                  value: _checkOut,
                  onChanged: (v) => setState(() => _checkOut = v)),
            ),
          ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Reason',
            required: _type == 'other',
            child: TextField(
                key: const Key('approval-reason'),
                controller: _reason,
                maxLines: 2,
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput()),
          ),
        ]),
      ]),
    );
  }
}
