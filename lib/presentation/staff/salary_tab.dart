import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

/// Salary tab (v1/staff managment/staff-salary.png): generate a month's
/// salaries from attendance, OT, incentives and advances; edit bonus /
/// penalty; record payments.
class SalaryTab extends StaffTabWidget {
  const SalaryTab({super.key, required super.repository, super.refreshToken});

  @override
  State<SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<SalaryTab> with StaffLoadState<SalaryTab> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  List<SalaryRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async => _rows = await repo.salaries(_year, _month);

  String get _period => '${staffMonthNames[_month - 1]} $_year';

  static String _statusLabel(String status) => switch (status) {
        'paid' => 'Paid',
        'partial' => 'Partial',
        _ => 'Pending',
      };

  void _setPeriod({int? year, int? month}) {
    setState(() {
      _year = year ?? _year;
      _month = month ?? _month;
      loaded = false;
    });
    reload();
  }

  Future<void> _generate() => act(() => repo.generateSalaries(_year, _month),
      success: 'Salaries generated for $_period');

  ReportTable get _table => ReportTable(
        kind: 'salaries',
        title: 'Salaries — $_period',
        columns: const [
          'Staff',
          'Basic',
          'OT',
          'Bonus',
          'Advance',
          'Penalty',
          'Net',
          'Paid',
          'Pending',
          'Status',
        ],
        rows: [
          for (final r in _rows)
            [
              r.staffName,
              staffNumText(r.basic),
              staffNumText(r.ot),
              staffNumText(r.bonus),
              staffNumText(r.advance),
              staffNumText(r.penalty),
              staffNumText(r.net),
              staffNumText(r.paid),
              staffNumText(r.pending),
              _statusLabel(r.status),
            ]
        ],
      );

  Future<void> _editAdjustments(SalaryRow r) async {
    final v = await showStaffPrompt(
      context,
      title: 'Bonus & penalty',
      subtitle: '${r.staffName} · $_period',
      sideBySide: true,
      confirmKey: const Key('salary-adjust-save'),
      fields: [
        StaffPromptField('bonus', 'Bonus',
            key: const Key('salary-bonus'),
            initial: staffNumText(r.bonus),
            number: true,
            prefix: '₹ '),
        StaffPromptField('penalty', 'Penalty',
            key: const Key('salary-penalty'),
            initial: staffNumText(r.penalty),
            number: true,
            prefix: '₹ '),
      ],
      note: Text(
          'Net = basic ${staffMoney(r.basic)} + OT ${staffMoney(r.ot)} + '
          'bonus − advance ${staffMoney(r.advance)} − penalty.',
          style: MasterStyle.muted),
      validate: (v) {
        final b = staffParseNum(v['bonus']!);
        final p = staffParseNum(v['penalty']!);
        if (b == null || p == null || b < 0 || p < 0) {
          return 'Enter bonus and penalty as amounts of zero or more.';
        }
        return null;
      },
    );
    if (v == null || !mounted) return;
    await act(
        () => repo.updateSalary(r.id,
            bonus: staffParseNum(v['bonus']!),
            penalty: staffParseNum(v['penalty']!)),
        success: 'Updated ${r.staffName}\'s salary');
  }

  Future<void> _pay(SalaryRow r) async {
    final v = await showStaffPrompt(
      context,
      title: 'Pay salary',
      subtitle: '${r.staffName} · $_period',
      confirmLabel: 'Pay',
      confirmKey: const Key('salary-pay-confirm'),
      fields: [
        StaffPromptField('amount', 'Amount',
            key: const Key('salary-pay-amount'),
            initial: staffNumText(r.pending),
            number: true,
            prefix: '₹ '),
      ],
      note: Text(
          'Net ${staffMoney(r.net)} · paid ${staffMoney(r.paid)} · pending '
          '${staffMoney(r.pending)}. Paying in full also marks this month\'s '
          'advances as deducted.',
          style: MasterStyle.muted),
      validate: (v) {
        final a = staffParseNum(v['amount']!, fallback: null);
        if (a == null || a <= 0) return 'Enter an amount more than zero.';
        if (a > r.pending + 0.005) {
          return 'That is more than the pending ${staffMoney(r.pending)}.';
        }
        return null;
      },
    );
    if (v == null || !mounted) return;
    final amount = staffParseNum(v['amount']!, fallback: null)!;
    await act(() => repo.paySalary(r.id, amount: amount),
        success: 'Paid ${staffMoney(amount)} to ${r.staffName}');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (var y = now.year - 3; y <= now.year + 1; y++) y];
    if (!years.contains(_year)) years.add(_year);
    return StaffTabPage(children: [
      Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 190,
              child: StaffSelect<int>(
                key: const Key('salary-month'),
                dense: true,
                value: _month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    (m, 'Month  ${staffMonthNames[m - 1]}')
                ],
                onChanged: (v) => _setPeriod(month: v),
              ),
            ),
            SizedBox(
              width: 130,
              child: StaffSelect<int>(
                key: const Key('salary-year'),
                dense: true,
                value: _year,
                items: [for (final y in years) (y, 'Year  $y')],
                onChanged: (v) => _setPeriod(year: v),
              ),
            ),
            MasterButton(
                key: const Key('salary-generate'),
                label: busy ? 'Working…' : 'Generate Salaries',
                kind: MasterButtonKind.primary,
                onPressed: busy ? null : _generate),
            MasterButton(
                key: const Key('salary-excel'),
                label: 'Excel',
                icon: Icons.download_outlined,
                onPressed: () => copyStaffCsv(context, _table)),
            MasterButton(
                key: const Key('salary-pdf'),
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () => showStaffTablePreview(context, _table)),
          ]),
      const SizedBox(height: 16),
      guarded(() {
        final totalNet = _rows.fold(0.0, (t, r) => t + r.net);
        final totalPaid = _rows.fold(0.0, (t, r) => t + r.paid);
        final totalPending = _rows.fold(0.0, (t, r) => t + r.pending);
        return MasterTable(
          minWidth: 1100,
          columns: const [
            MasterColumn('Staff', flex: 16),
            MasterColumn('Basic', flex: 10),
            MasterColumn('OT', flex: 9),
            MasterColumn('Bonus', flex: 9),
            MasterColumn('Advance', flex: 9),
            MasterColumn('Penalty', flex: 9),
            MasterColumn('Net', flex: 10),
            MasterColumn('Paid', flex: 10),
            MasterColumn('Pending', flex: 10),
            MasterColumn('Status', flex: 9),
            MasterColumn('', flex: 4, alignEnd: true),
          ],
          rows: [
            for (final r in _rows)
              [
                MasterCellText(r.staffName, bold: true),
                MasterCellText(staffMoney(r.basic)),
                MasterCellText(staffMoney(r.ot)),
                MasterCellText(staffMoney(r.bonus)),
                MasterCellText(staffMoney(r.advance),
                    color: r.advance > 0 ? kStaffRed : null),
                MasterCellText(staffMoney(r.penalty),
                    color: r.penalty > 0 ? kStaffRed : null),
                MasterCellText(staffMoney(r.net), bold: true),
                MasterCellText(staffMoney(r.paid)),
                MasterCellText(staffMoney(r.pending)),
                MasterStatusPill(_statusLabel(r.status)),
                PopupMenuButton<String>(
                  key: Key('salary-menu-${r.staffId}'),
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: ViniiColors.textSecondaryLight),
                  onSelected: (v) => v == 'pay' ? _pay(r) : _editAdjustments(r),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'adjust',
                        enabled: r.status != 'paid',
                        child: const Text('Edit bonus / penalty')),
                    PopupMenuItem(
                        value: 'pay',
                        enabled: r.status != 'paid',
                        child: const Text('Pay')),
                  ],
                ),
              ]
          ],
          footer: _rows.isEmpty
              ? const StaffEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No salaries generated for this month yet',
                  message: 'Pick the month and press Generate Salaries. '
                      'Attendance, overtime, incentives and advances for the '
                      'month are applied automatically.',
                )
              : Wrap(spacing: 24, runSpacing: 6, children: [
                  Text('${_rows.length} staff',
                      style: MasterStyle.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('Net ${staffMoney(totalNet)}', style: MasterStyle.body),
                  Text('Paid ${staffMoney(totalPaid)}',
                      style: MasterStyle.body.copyWith(color: kStaffGreen)),
                  Text('Pending ${staffMoney(totalPending)}',
                      style: MasterStyle.body.copyWith(color: kStaffAmber)),
                ]),
        );
      }),
    ]);
  }
}
