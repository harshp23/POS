import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

/// How an advance was handed over.
const advanceModeLabels = {
  'cash': 'Cash',
  'upi': 'UPI',
  'bank': 'Bank transfer',
};

/// Advances tab (v1/staff managment/staff-advances.png). Open advances are
/// deducted from the salary of the month they're set to.
class AdvancesTab extends StaffTabWidget {
  const AdvancesTab({super.key, required super.repository, super.refreshToken});

  @override
  State<AdvancesTab> createState() => _AdvancesTabState();
}

class _AdvancesTabState extends State<AdvancesTab>
    with StaffLoadState<AdvancesTab> {
  List<StaffAdvance> _rows = const [];
  List<StaffMember> _staff = const [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final r = await Future.wait<Object>([repo.advances(), repo.employees()]);
    _rows = r[0] as List<StaffAdvance>;
    _staff = r[1] as List<StaffMember>;
  }

  Future<void> _new() async {
    final active = [
      for (final s in _staff)
        if (s.isActive) s
    ];
    if (active.isEmpty) {
      showStaffError(context, 'Add an active staff member first.');
      return;
    }
    final created = await showDialog<StaffAdvance>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdvanceDialog(repository: repo, staff: active),
    );
    if (created == null || !mounted) return;
    await reload();
    if (mounted) {
      showStaffNotice(context,
          'Advance of ${staffMoney(created.amount)} for ${created.staffName} saved');
    }
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        Row(children: [
          MasterButton(
              key: const Key('advance-new'),
              label: 'New Advance',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: loaded ? _new : null),
          const Spacer(),
          if (_rows.isNotEmpty)
            Text(
                'Open: ${staffMoney(_rows.where((a) => a.status == 'open').fold(0.0, (t, a) => t + a.amount))}',
                style: MasterStyle.muted),
        ]),
        const SizedBox(height: 20),
        guarded(() => MasterTable(
              minWidth: 900,
              columns: const [
                MasterColumn('Date', flex: 10),
                MasterColumn('Staff', flex: 18),
                MasterColumn('Amount', flex: 10),
                MasterColumn('Deduct in', flex: 10),
                MasterColumn('Reason', flex: 20),
                MasterColumn('Mode', flex: 8),
                MasterColumn('Status', flex: 9),
              ],
              rows: [
                for (final a in _rows)
                  [
                    MasterCellText(staffDate(a.date)),
                    MasterCellText(a.staffName, bold: true),
                    MasterCellText(staffMoney(a.amount), bold: true),
                    MasterCellText(
                        staffMonthYear(a.deductMonth, a.deductYear)),
                    MasterCellText(a.reason.isEmpty ? '—' : a.reason),
                    MasterCellText(advanceModeLabels[a.mode] ??
                        staffCodeLabel(a.mode)),
                    MasterStatusPill(
                        switch (a.status) {
                          'deducted' => 'Deducted',
                          'cancelled' => 'Cancelled',
                          _ => 'Open',
                        },
                        tone: switch (a.status) {
                          'deducted' => PillTone.green,
                          'cancelled' => PillTone.gray,
                          _ => PillTone.amber,
                        }),
                  ]
              ],
              footer: _rows.isEmpty
                  ? const StaffEmptyState(
                      icon: Icons.payments_outlined,
                      title: 'No advances yet',
                      message: 'Advances you give are deducted from the '
                          'salary of the month you choose.',
                    )
                  : null,
            )),
      ]);
}

class _AdvanceDialog extends StatefulWidget {
  const _AdvanceDialog({required this.repository, required this.staff});
  final StaffRepository repository;
  final List<StaffMember> staff;

  @override
  State<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDialogState extends State<_AdvanceDialog> {
  String? _staffId;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  DateTime _date = staffToday();
  late int _month = _date.month;
  late int _year = _date.year;
  String _mode = 'cash';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = staffParseNum(_amount.text, fallback: null);
    if (_staffId == null) {
      setState(() => _error = 'Pick the staff member.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount more than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final a = await widget.repository.createAdvance(
        staffId: _staffId!,
        amount: amount,
        date: _date,
        deductMonth: _month,
        deductYear: _year,
        reason: _reason.text.trim(),
        mode: _mode,
      );
      if (mounted) Navigator.pop(context, a);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = _date.year - 1; y <= _date.year + 2; y++) y];
    if (!years.contains(_year)) years.add(_year);
    return StaffDialog(
      title: 'New Advance',
      subtitle: 'Money given ahead of salary',
      width: 520,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('advance-save'),
            label: _saving ? 'Saving…' : 'Save',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          StaffField(
            label: 'Staff',
            required: true,
            child: StaffSelect<String>(
              key: const Key('advance-staff'),
              value: _staffId,
              hint: 'Select staff',
              items: [
                for (final s in widget.staff)
                  (
                    s.id,
                    s.staffCode.isEmpty
                        ? s.fullName
                        : '${s.fullName} · ${s.staffCode}'
                  )
              ],
              onChanged: (v) => setState(() => _staffId = v),
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Amount',
            required: true,
            child: TextField(
                key: const Key('advance-amount'),
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(prefix: '₹ ')),
          ),
          StaffField(
            label: 'Date',
            child: StaffDateButton(
                value: _date, onChanged: (d) => setState(() => _date = d)),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Deduct in month',
            child: StaffSelect<int>(
              key: const Key('advance-month'),
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
              key: const Key('advance-year'),
              value: _year,
              items: [for (final y in years) (y, '$y')],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Reason',
            child: TextField(
                key: const Key('advance-reason'),
                controller: _reason,
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(hint: 'Travel, medical, festival…')),
          ),
        ]),
        StaffField(
          label: 'Mode',
          child: Wrap(spacing: 8, children: [
            for (final m in advanceModeLabels.entries)
              ChoiceChip(
                key: Key('advance-mode-${m.key}'),
                label: Text(m.value),
                selected: _mode == m.key,
                selectedColor: ViniiColors.lightGreenTint,
                onSelected: (_) => setState(() => _mode = m.key),
              ),
          ]),
        ),
      ]),
    );
  }
}
