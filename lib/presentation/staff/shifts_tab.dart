import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

/// Shifts & roster tab (v1/staff managment/staff-shifts-roster-v3.png):
/// the day's roster with clock in/out, and the shift master.
class ShiftsTab extends StaffTabWidget {
  const ShiftsTab({super.key, required super.repository, super.refreshToken});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> with StaffLoadState<ShiftsTab> {
  /// 0 = Roster & attendance, 1 = Shift master.
  int _view = 0;
  DateTime _day = staffToday();
  RosterDay? _roster;
  List<Shift> _shifts = const [];
  String? _staffId;
  String? _shiftId;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final r = await Future.wait<Object>([repo.roster(_day), repo.shifts()]);
    _roster = r[0] as RosterDay;
    _shifts = r[1] as List<Shift>;
    if (!_shifts.any((s) => s.id == _shiftId)) _shiftId = null;
    if (!(_roster?.rows.any((x) => x.staffId == _staffId) ?? false)) {
      _staffId = null;
    }
  }

  void _setDay(DateTime d) {
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      loaded = false;
    });
    reload();
  }

  Future<void> _assign() async {
    if (_staffId == null || _shiftId == null) {
      showStaffError(context, 'Select an employee and a shift first.');
      return;
    }
    final staff = _roster?.rows.firstWhere((r) => r.staffId == _staffId);
    final shift = _shifts.firstWhere((s) => s.id == _shiftId);
    final ok = await act(() => repo.assignShift(_day, _staffId!, _shiftId!),
        success:
            '${staff?.staffName} → ${shift.name} on ${staffSlashDate(_day)}');
    if (ok && mounted) setState(() => _staffId = null);
  }

  Future<void> _editShift([Shift? s]) async {
    final saved = await showDialog<Shift>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShiftDialog(repository: repo, existing: s),
    );
    if (saved == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Saved ${saved.name} shift');
  }

  Future<void> _deleteShift(Shift s) async {
    final ok = await staffConfirm(context,
        title: 'Delete ${s.name}?',
        message: 'Upcoming roster entries for this shift that nobody has '
            'clocked in to are removed too.');
    if (!ok || !mounted) return;
    await act(() => repo.deleteShift(s.id), success: 'Deleted ${s.name}');
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        StaffPills(
            keyPrefix: 'shifts-view',
            options: const ['Roster & attendance', 'Shift master'],
            selected: _view,
            onSelect: (i) => setState(() => _view = i)),
        const SizedBox(height: 18),
        guarded(() => _view == 0 ? _rosterView() : _masterView()),
      ]);

  static (Color, Color) _flagColors(String f) => switch (f) {
        'Absent' => (kStaffRed, ViniiColors.redTint),
        'Late' => (kStaffAmber, ViniiColors.amberTint),
        'On shift' => (kStaffGreen, const Color(0xFFF0FDF4)),
        'Overtime' => (kStaffPurple, ViniiColors.purpleTint),
        'Scheduled' => (ViniiColors.blueSolid, ViniiColors.blueTint),
        _ => (ViniiColors.graySolid, const Color(0xFFF3F4F6)),
      };

  Widget _rosterView() {
    final day = _roster!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StaffDateButton(
                key: const Key('roster-date'), value: _day, onChanged: _setDay),
            SizedBox(
              width: 210,
              child: StaffSelect<String>(
                key: const Key('roster-staff'),
                dense: true,
                value: _staffId,
                hint: 'Select employee',
                items: [
                  for (final r in day.rows)
                    (r.staffId, staffPickLabel(r.staffName, r.staffCode))
                ],
                onChanged: (v) => setState(() => _staffId = v),
              ),
            ),
            SizedBox(
              width: 230,
              child: StaffSelect<String>(
                key: const Key('roster-shift'),
                dense: true,
                value: _shiftId,
                hint: _shifts.isEmpty ? 'No shifts yet' : 'Select shift',
                items: [
                  for (final s in _shifts)
                    (s.id, '${s.name} (${s.startTime}–${s.endTime})')
                ],
                onChanged: (v) => setState(() => _shiftId = v),
              ),
            ),
            MasterButton(
                key: const Key('roster-assign'),
                label: 'Assign',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: busy ? null : _assign),
            if (_shifts.isEmpty)
              MasterButton(
                  label: 'Create a shift',
                  kind: MasterButtonKind.text,
                  onPressed: () => setState(() => _view = 1)),
          ]),
      const SizedBox(height: 18),
      MasterGrid(columns: 4, minItemWidth: 180, children: [
        StaffStatTile(
            label: 'Scheduled',
            value: '${day.scheduled}',
            icon: Icons.calendar_month_outlined),
        StaffStatTile(
            label: 'On shift',
            value: '${day.onShift}',
            icon: Icons.check,
            color: kStaffGreen,
            tint: const Color(0xFFF0FDF4)),
        StaffStatTile(
            label: 'Late entries',
            value: '${day.late}',
            icon: Icons.schedule,
            color: kStaffAmber,
            tint: ViniiColors.amberTint),
        StaffStatTile(
            label: 'Overtime',
            value: '${day.overtime}',
            icon: Icons.more_time,
            color: kStaffPurple,
            tint: ViniiColors.purpleTint),
      ]),
      const SizedBox(height: 18),
      MasterTable(
        minWidth: 1100,
        columns: const [
          MasterColumn('Employee', flex: 16),
          MasterColumn('Shift', flex: 14),
          MasterColumn('Clock In', flex: 8),
          MasterColumn('Clock Out', flex: 8),
          MasterColumn('Break', flex: 6),
          MasterColumn('Worked', flex: 8),
          MasterColumn('Overtime', flex: 8),
          MasterColumn('Flags', flex: 16),
          MasterColumn('Actions', flex: 10, alignEnd: true),
        ],
        rows: [
          for (final r in day.rows)
            [
              MasterCellTitle(r.staffName,
                  subtitle:
                      r.staffCode.isEmpty ? null : 'Staff code: ${r.staffCode}'),
              r.shiftName == null
                  ? const MasterCellText('--',
                      color: ViniiColors.textMutedLight)
                  : MasterCellTitle(r.shiftName!,
                      subtitle: '${r.startTime}–${r.endTime}'),
              MasterCellText(r.clockIn == null ? '--' : staffHm(r.clockIn!)),
              MasterCellText(r.clockOut == null ? '--' : staffHm(r.clockOut!)),
              MasterCellText('${r.breakMinutes}m'),
              MasterCellText(staffDuration(r.workedMinutes)),
              MasterCellText(r.overtimeMinutes > 0
                  ? staffDuration(r.overtimeMinutes)
                  : '--'),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final f in (r.flags.isEmpty && r.rosterId != null
                    ? const ['Scheduled']
                    : r.flags))
                  StaffChip(f,
                      color: _flagColors(f).$1, tint: _flagColors(f).$2),
              ]),
              if (r.rosterId == null)
                const SizedBox()
              else if (r.clockIn == null)
                MasterButton(
                    key: Key('roster-clock-in-${r.staffId}'),
                    label: 'Clock in',
                    icon: Icons.login,
                    onPressed: busy
                        ? null
                        : () => act(() => repo.clockIn(r.rosterId!),
                            success: '${r.staffName} clocked in'))
              else if (r.clockOut == null)
                MasterButton(
                    key: Key('roster-clock-out-${r.staffId}'),
                    label: 'Clock out',
                    icon: Icons.logout,
                    onPressed: busy
                        ? null
                        : () => act(() => repo.clockOut(r.rosterId!),
                            success: '${r.staffName} clocked out'))
              else
                const MasterCellText('Done', color: ViniiColors.textMutedLight),
            ]
        ],
        footer: day.rows.isEmpty
            ? const StaffEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No active staff',
                message: 'Add staff in the Staff tab to build a roster.',
              )
            : null,
      ),
    ]);
  }

  Widget _masterView() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          MasterButton(
              key: const Key('shift-add'),
              label: 'Add Shift',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: () => _editShift()),
        ]),
        const SizedBox(height: 16),
        MasterTable(
          minWidth: 800,
          columns: const [
            MasterColumn('Shift', flex: 16),
            MasterColumn('Start', flex: 8),
            MasterColumn('End', flex: 8),
            MasterColumn('Length', flex: 8),
            MasterColumn('Break', flex: 8),
            MasterColumn('Grace', flex: 8),
            MasterColumn('Actions', flex: 8, alignEnd: true),
          ],
          rows: [
            for (final s in _shifts)
              [
                MasterCellText(s.name, bold: true),
                MasterCellText(s.startTime),
                MasterCellText(s.endTime),
                MasterCellText(staffDuration(_span(s))),
                MasterCellText('${s.breakMinutes} min'),
                MasterCellText('${s.graceMinutes} min'),
                Wrap(children: [
                  StaffIconAction(
                      key: Key('shift-edit-${s.id}'),
                      tooltip: 'Edit',
                      icon: Icons.edit_note,
                      onPressed: () => _editShift(s)),
                  StaffIconAction(
                      key: Key('shift-delete-${s.id}'),
                      tooltip: 'Delete',
                      icon: Icons.delete_outline,
                      color: ViniiColors.redSolid,
                      onPressed: busy ? null : () => _deleteShift(s)),
                ]),
              ]
          ],
          footer: _shifts.isEmpty
              ? const StaffEmptyState(
                  icon: Icons.schedule,
                  title: 'No shifts yet',
                  message: 'Create shifts like Morning 09:00–17:00 to put '
                      'staff on the roster.',
                )
              : null,
        ),
      ]);

  static int _span(Shift s) {
    int m(String t) {
      final p = t.split(':');
      return (int.tryParse(p.first) ?? 0) * 60 +
          (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
    }

    var span = m(s.endTime) - m(s.startTime);
    if (span <= 0) span += 24 * 60;
    return span;
  }
}

class _ShiftDialog extends StatefulWidget {
  const _ShiftDialog({required this.repository, this.existing});
  final StaffRepository repository;
  final Shift? existing;

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late String _start = widget.existing?.startTime ?? '09:00';
  late String _end = widget.existing?.endTime ?? '17:00';
  late final _break =
      TextEditingController(text: '${widget.existing?.breakMinutes ?? 30}');
  late final _grace =
      TextEditingController(text: '${widget.existing?.graceMinutes ?? 10}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _break.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final brk = int.tryParse(_break.text.trim());
    final grace = int.tryParse(_grace.text.trim());
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the shift a name.');
      return;
    }
    if (brk == null || brk < 0 || grace == null || grace < 0) {
      setState(() => _error = 'Break and grace are whole minutes (0 or more).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveShift(Shift(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        startTime: _start,
        endTime: _end,
        breakMinutes: brk,
        graceMinutes: grace,
        active: widget.existing?.active ?? true,
      ));
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: widget.existing == null ? 'Add Shift' : 'Edit Shift',
        width: 480,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.pop(context)),
          MasterButton(
              key: const Key('shift-save'),
              label: _saving ? 'Saving…' : 'Save',
              kind: MasterButtonKind.primary,
              onPressed: _saving ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            StaffField(
              label: 'Shift name',
              required: true,
              child: TextField(
                  key: const Key('shift-name'),
                  controller: _name,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput(hint: 'Morning')),
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Start',
              child: StaffTimeButton(
                  value: _start,
                  onChanged: (v) => setState(() => _start = v ?? _start)),
            ),
            StaffField(
              label: 'End',
              child: StaffTimeButton(
                  value: _end,
                  onChanged: (v) => setState(() => _end = v ?? _end)),
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Break (minutes)',
              child: TextField(
                  key: const Key('shift-break'),
                  controller: _break,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput()),
            ),
            StaffField(
              label: 'Grace for late (minutes)',
              child: TextField(
                  key: const Key('shift-grace'),
                  controller: _grace,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput()),
            ),
          ]),
          const Text(
              'An end time before the start (e.g. 16:00–00:00) runs past '
              'midnight.',
              style: MasterStyle.muted),
        ]),
      );
}
