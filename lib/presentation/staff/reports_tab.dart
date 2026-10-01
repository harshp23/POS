import 'package:flutter/material.dart';

import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

const staffReportKinds = [
  ('staff_list', 'Staff List'),
  ('attendance', 'Attendance'),
  ('salaries', 'Salaries'),
  ('salary_paid', 'Salary Paid'),
  ('salary_pending', 'Salary Pending'),
  ('advances', 'Advances'),
];

/// Reports tab (v1/staff managment/staff-reports-v3.png): each report can
/// be copied as CSV or opened as a printable table.
class StaffReportsTab extends StaffTabWidget {
  const StaffReportsTab(
      {super.key, required super.repository, super.refreshToken});

  @override
  State<StaffReportsTab> createState() => _StaffReportsTabState();
}

class _StaffReportsTabState extends State<StaffReportsTab>
    with StaffLoadState<StaffReportsTab> {
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async => _counts = await repo.reportCounts();

  Future<void> _csv(String kind) async {
    try {
      final t = await repo.report(kind);
      if (mounted) await copyStaffCsv(context, t);
    } catch (e) {
      if (mounted) showStaffError(context, e);
    }
  }

  Future<void> _print(String kind) async {
    try {
      final t = await repo.report(kind);
      if (mounted) await showStaffTablePreview(context, t);
    } catch (e) {
      if (mounted) showStaffError(context, e);
    }
  }

  Widget _iconButton(Key key, IconData icon, String tip, VoidCallback onTap) =>
      Tooltip(
        message: tip,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kStaffBorder),
              ),
              child: Icon(icon, size: 17, color: ViniiColors.textPrimaryLight),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        guarded(() => MasterGrid(
              columns: 3,
              minItemWidth: 260,
              spacing: 20,
              children: [
                for (final (kind, title) in staffReportKinds)
                  MasterCard(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: ViniiColors.textPrimaryLight)),
                              const SizedBox(height: 4),
                              Text('${_counts[kind] ?? 0} records',
                                  key: Key('report-count-$kind'),
                                  style:
                                      MasterStyle.muted.copyWith(fontSize: 13)),
                            ]),
                      ),
                      _iconButton(
                          Key('report-csv-$kind'),
                          Icons.download_outlined,
                          'Copy CSV',
                          () => _csv(kind)),
                      const SizedBox(width: 8),
                      _iconButton(Key('report-print-$kind'),
                          Icons.print_outlined, 'Print', () => _print(kind)),
                    ]),
                  ),
              ],
            )),
      ]);
}
