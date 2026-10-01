import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

const attendanceStatusLabels = {
  'present': 'Present',
  'absent': 'Absent',
  'half_day': 'Half day',
  'leave': 'Leave',
  'week_off': 'Week off',
};

/// Attendance tab (v1/staff managment/staff-attendance.png): one row per
/// active employee for the chosen day, edited in place and saved together.
class AttendanceTab extends StaffTabWidget {
  const AttendanceTab(
      {super.key, required super.repository, super.refreshToken});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab>
    with StaffLoadState<AttendanceTab> {
  DateTime _day = staffToday();
  List<AttendanceEntry> _rows = const [];
  bool _dirty = false;

  /// Bumped on every load so the inline text fields pick up new values.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    _rows = await repo.attendance(_day);
    _dirty = false;
    _version++;
  }

  Future<void> _pickDay(DateTime d) async {
    if (_dirty) {
      final ok = await staffConfirm(context,
          title: 'Discard changes?',
          message: 'You have unsaved attendance for ${staffSlashDate(_day)}.',
          confirmLabel: 'Discard');
      if (!ok) return;
    }
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      loaded = false;
    });
    await reload();
  }

  void _edit(int i, AttendanceEntry next) => setState(() {
        _rows = [..._rows]..[i] = next;
        _dirty = true;
      });

  Future<void> _save() => act(() => repo.saveAttendance(_day, _rows),
      success: 'Attendance saved for ${staffSlashDate(_day)}');

  Future<void> _markAll() => act(() => repo.markAllPresent(_day),
      success: 'Everyone marked present for ${staffSlashDate(_day)}');

  Future<void> _export() => copyStaffCsv(
        context,
        ReportTable(
          kind: 'attendance',
          title: 'Attendance ${staffDay(_day)}',
          columns: const [
            'Date',
            'Staff',
            'Staff code',
            'Status',
            'Check-in',
            'Check-out',
            'OT (hr)',
            'Notes',
          ],
          rows: [
            for (final r in _rows)
              [
                r.date,
                r.staffName,
                r.staffCode,
                attendanceStatusLabels[r.status] ?? '',
                r.checkIn ?? '',
                r.checkOut ?? '',
                staffNumText(r.otHours),
                r.notes,
              ]
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in _rows) {
      counts[r.status ?? ''] = (counts[r.status ?? ''] ?? 0) + 1;
    }
    return StaffTabPage(children: [
      Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StaffDateButton(
                key: const Key('attendance-date'),
                label: 'Date',
                value: _day,
                onChanged: _pickDay),
            MasterButton(
                key: const Key('attendance-mark-all'),
                label: 'Mark all Present',
                kind: MasterButtonKind.primary,
                onPressed: busy || _rows.isEmpty ? null : _markAll),
            MasterButton(
                key: const Key('attendance-export'),
                label: 'Export',
                icon: Icons.download_outlined,
                onPressed: _rows.isEmpty ? null : _export),
            MasterButton(
                key: const Key('attendance-save'),
                label: busy ? 'Saving…' : 'Save',
                icon: Icons.save_outlined,
                kind: _dirty
                    ? MasterButtonKind.primary
                    : MasterButtonKind.outline,
                onPressed: busy || _rows.isEmpty ? null : _save),
            if (_dirty)
              const Text('Unsaved changes',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kStaffAmber)),
          ]),
      const SizedBox(height: 16),
      guarded(() {
        if (_rows.isEmpty) {
          return const MasterCard(
            child: StaffEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No active staff',
              message: 'Add staff (or set them Active) in the Staff tab to '
                  'mark attendance.',
            ),
          );
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in attendanceStatusLabels.entries)
                  if ((counts[e.key] ?? 0) > 0)
                    StaffChip('${e.value}: ${counts[e.key]}',
                        color: _statusColor(e.key)),
                if ((counts[''] ?? 0) > 0)
                  StaffChip('Not marked: ${counts['']}',
                      color: ViniiColors.graySolid),
              ]),
              const SizedBox(height: 12),
              MasterTable(
                minWidth: 1050,
                columns: const [
                  MasterColumn('Staff', flex: 18),
                  MasterColumn('Status', flex: 14),
                  MasterColumn('Check-in', flex: 11),
                  MasterColumn('Check-out', flex: 11),
                  MasterColumn('OT (hr)', flex: 8),
                  MasterColumn('Notes', flex: 20),
                ],
                rows: [
                  for (var i = 0; i < _rows.length; i++) _row(i, _rows[i]),
                ],
              ),
            ]);
      }),
    ]);
  }

  static Color _statusColor(String s) => switch (s) {
        'present' => kStaffGreen,
        'absent' => kStaffRed,
        'half_day' => kStaffAmber,
        'leave' => kStaffPurple,
        _ => ViniiColors.graySolid,
      };

  List<Widget> _row(int i, AttendanceEntry r) => [
        MasterCellTitle(r.staffName,
            subtitle: r.staffCode.isEmpty ? null : r.staffCode),
        StaffSelect<String>(
          key: Key('attendance-status-${r.staffId}'),
          dense: true,
          value: r.status,
          hint: 'Mark…',
          items: [
            for (final e in attendanceStatusLabels.entries) (e.key, e.value)
          ],
          onChanged: (v) => _edit(i, _rows[i].copyWith(status: v)),
        ),
        StaffTimeButton(
            value: r.checkIn,
            onChanged: (v) => _edit(i, _rows[i].copyWith(checkIn: v))),
        StaffTimeButton(
            value: r.checkOut,
            onChanged: (v) => _edit(i, _rows[i].copyWith(checkOut: v))),
        SizedBox(
          height: 34,
          child: TextFormField(
            key: ValueKey('ot-${r.staffId}-$_version'),
            initialValue: staffNumText(r.otHours),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            decoration: staffInput().copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onChanged: (v) {
              final n = staffParseNum(v);
              if (n != null && n >= 0) _edit(i, _rows[i].copyWith(otHours: n));
            },
          ),
        ),
        SizedBox(
          height: 34,
          child: TextFormField(
            key: ValueKey('notes-${r.staffId}-$_version'),
            initialValue: r.notes,
            style: const TextStyle(fontSize: 13),
            decoration: staffInput(hint: 'Notes here…').copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onChanged: (v) => _edit(i, _rows[i].copyWith(notes: v)),
          ),
        ),
      ];
}
