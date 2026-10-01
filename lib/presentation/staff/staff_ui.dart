import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_repository.dart';
import '../../domain/inventory.dart' show formatInr;
import '../../domain/vendor_account.dart' show BranchLocation;
import '../dashboard/dashboard_widgets.dart' show friendlyErrorText;
import '../master/master_ui.dart';
import '../vinii_theme.dart';

/// Shared styling and helpers for the Staff Management tabs
/// (v1/staff managment/*.png).

const kStaffBorder = Color(0xFFE5E7EB);
const kStaffPageBg = Color(0xFFF8F9FB);
const kStaffDark = Color(0xFF1F2937);
const kStaffIconGreen = Color(0xFF5DC800);
const kStaffGreen = Color(0xFF16A34A);
const kStaffAmber = Color(0xFFD97706);
const kStaffRed = Color(0xFFDC2626);
const kStaffPurple = Color(0xFF7C3AED);

const staffMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// ₹24,000 · ₹1,250.50 (Indian grouping, paise only when present).
String staffMoney(num v) =>
    formatInr(v, decimals: (v * 100).round() % 100 == 0 ? 0 : 2);

/// 12 Oct 2023 from YYYY-MM-DD.
String staffDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  return staffDay(d);
}

String staffDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${staffMonthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// 12/09/2026, like the date fields in the designs.
String staffSlashDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String staffHm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String staffDateTime(DateTime? t) {
  if (t == null) return '—';
  final l = t.toLocal();
  return '${staffDay(l)}, ${staffHm(l)}';
}

/// 2h 05m → "2h 5m".
String staffDuration(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

DateTime staffToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The message to show for anything a repository call threw: the server's
/// (or demo data's) own sentence, else a plain one — never a Dart type
/// error, database error or record id.
String staffErrorText(Object e) => friendlyErrorText(e);

/// "Sep 2026" (or "September 2026" with [long]) from a month and year.
String staffMonthYear(int month, int year, {bool long = false}) {
  if (month < 1 || month > 12) return '$year';
  final name = staffMonthNames[month - 1];
  return '${long ? name : name.substring(0, 3)} $year';
}

/// "September 2026" from "2026-09" / "2026-09-30"; "—" when unreadable.
String staffMonthLabel(String? yyyyMm, {bool long = true}) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(yyyyMm?.trim() ?? '');
  if (m == null) return '—';
  return staffMonthYear(int.parse(m.group(2)!), int.parse(m.group(1)!),
      long: long);
}

/// "Half day" from "half_day" — for a code with no label of its own.
String staffHumanize(String? code) {
  final s = (code ?? '').trim().replaceAll(RegExp(r'[_\-]+'), ' ');
  if (s.isEmpty) return '—';
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// Labels of the status / type codes the Staff screens show.
const staffCodeLabels = <String, String>{
  // attendance
  'present': 'Present',
  'absent': 'Absent',
  'half_day': 'Half day',
  'leave': 'Leave',
  'week_off': 'Week off',
  // salary
  'pending': 'Pending',
  'partial': 'Partial',
  'paid': 'Paid',
  // employee / login
  'active': 'Active',
  'inactive': 'Inactive',
  'suspended': 'Suspended',
  // advances
  'open': 'Open',
  'deducted': 'Deducted',
  'cancelled': 'Cancelled',
  // approvals
  'approved': 'Approved',
  'declined': 'Declined',
  // salary type
  'monthly': 'Monthly',
  'daily': 'Daily',
  'hourly': 'Hourly',
  // advance mode
  'cash': 'Cash',
  'upi': 'UPI',
  'bank': 'Bank transfer',
};

/// The human label of a status / type code ("half_day" → "Half day").
String staffCodeLabel(String? code) =>
    staffCodeLabels[(code ?? '').trim().toLowerCase()] ?? staffHumanize(code);

/// "Pravin M · VIN-001" — how a staff member is picked from a list, so two
/// people with the same name can be told apart.
String staffPickLabel(String name, String? code) {
  final c = code?.trim() ?? '';
  return c.isEmpty ? name : '$name · $c';
}

/// The branch's name: the server's [serverName], else [id] looked up in
/// [branches]; [none] when the record belongs to no branch.
String staffBranchName(
    String? id, String? serverName, List<BranchLocation> branches,
    {String none = 'All branches'}) {
  final named = serverName?.trim() ?? '';
  if (named.isNotEmpty) return named;
  if (id == null || id.isEmpty) return none;
  for (final b in branches) {
    if (b.id == id) return b.name;
  }
  return 'Other branch';
}

/// A branch picker's items: [noneLabel] (value '' = no single branch, left
/// out when null) then each branch by name.
List<(String, String)> staffBranchItems(List<BranchLocation> branches,
        {String? noneLabel = 'All branches (no single branch)'}) =>
    [
      if (noneLabel != null) ('', noneLabel),
      for (final b in branches)
        (
          b.id,
          (b.code ?? '').trim().isEmpty || b.name.contains(b.code!.trim())
              ? b.name
              : '${b.name} (${b.code!.trim()})'
        ),
    ];

/// Built-in roles that work at one branch (Branch Manager, Cashier,
/// Captain, Kitchen): their login needs a home branch when the restaurant
/// has more than one.
const staffBranchBoundRoles = {'location_manager', 'biller', 'captain', 'kitchen'};

final _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}');
final _monthSlashYear = RegExp(r'^(\d{1,2})/(\d{4})$');
final _yearDashMonth = RegExp(r'^(\d{4})-(\d{1,2})$');
final _clock = RegExp(r'^(\d{1,2}):(\d{2})(:\d{2}(\.\d+)?)?$');
const _moneyColumns = {
  'basic',
  'ot',
  'bonus',
  'advance',
  'penalty',
  'net',
  'paid',
  'pending',
  'amount',
  'pay rate',
};
const _codeColumns = {'status', 'salary type', 'mode', 'type'};

/// One report cell as people read it, by its column: status / type / mode
/// codes as labels, months as "Sep 2026", times as HH:MM; with [forPrint]
/// also dates as "12 Oct 2023" and amounts as ₹24,000 (the CSV keeps ISO
/// dates and plain numbers for spreadsheets).
String staffReportCell(String column, String value, {bool forPrint = true}) {
  final col = column.trim().toLowerCase();
  final v = value.trim();
  if (v.isEmpty || v == 'null') return forPrint ? '—' : '';
  if (col == 'month' || col == 'deduct in' || col == 'deduct month') {
    final a = _monthSlashYear.firstMatch(v);
    if (a != null) {
      return staffMonthYear(int.parse(a.group(1)!), int.parse(a.group(2)!));
    }
    final b = _yearDashMonth.firstMatch(v);
    if (b != null) {
      return staffMonthYear(int.parse(b.group(2)!), int.parse(b.group(1)!));
    }
    return v;
  }
  if (_codeColumns.contains(col)) return staffCodeLabel(v);
  if (col == 'check-in' || col == 'check-out' || col.contains('time')) {
    final m = _clock.firstMatch(v);
    if (m != null) return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
    return v;
  }
  if (forPrint &&
      (col == 'date' || col == 'joined' || col.endsWith(' date')) &&
      _isoDay.hasMatch(v)) {
    return staffDate(v.substring(0, 10));
  }
  if (forPrint && _moneyColumns.contains(col)) {
    final n = double.tryParse(v.replaceAll(',', ''));
    if (n != null) return staffMoney(n);
  }
  return v;
}

/// [table] with every cell as people read it (see [staffReportCell]).
ReportTable staffReadableReport(ReportTable table, {bool forPrint = true}) =>
    ReportTable(
      kind: table.kind,
      title: table.title,
      columns: table.columns,
      rows: [
        for (final r in table.rows)
          [
            for (var i = 0; i < r.length; i++)
              i < table.columns.length
                  ? staffReportCell(table.columns[i], r[i], forPrint: forPrint)
                  : r[i],
          ],
      ],
    );

void showStaffNotice(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    width: 460,
    duration: const Duration(seconds: 3),
  ));
}

void showStaffError(BuildContext context, Object error) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(staffErrorText(error)),
    behavior: SnackBarBehavior.floating,
    width: 460,
    backgroundColor: ViniiColors.redSolid,
    duration: const Duration(seconds: 4),
  ));
}

/// Copies [table] as CSV to the clipboard (labels instead of codes; ISO
/// dates and plain numbers stay for spreadsheets).
Future<void> copyStaffCsv(BuildContext context, ReportTable table) async {
  final readable = staffReadableReport(table, forPrint: false);
  await Clipboard.setData(ClipboardData(text: readable.toCsv()));
  if (!context.mounted) return;
  showStaffNotice(context,
      'Copied ${table.title} CSV to the clipboard (${table.rows.length} rows)');
}

/// Printable preview of [raw] (there is no print/PDF plugin in the app,
/// so this is the page to print or screenshot, plus a CSV copy). Cells are
/// shown as people read them: labels, dates, months and ₹ amounts.
Future<void> showStaffTablePreview(BuildContext context, ReportTable raw) {
  final table = staffReadableReport(raw);
  return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.print_outlined,
                        size: 20, color: ViniiColors.textSecondaryLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(table.title,
                                style: MasterStyle.sectionTitle
                                    .copyWith(fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(
                                'Print preview · ${table.rows.length} rows · '
                                '${staffDateTime(DateTime.now())}',
                                style: MasterStyle.muted),
                          ]),
                    ),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 16),
                  Flexible(
                    child: table.rows.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: Text('No records to print.',
                                    style: MasterStyle.muted)),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 40,
                                dataRowMinHeight: 36,
                                dataRowMaxHeight: 44,
                                headingRowColor: const WidgetStatePropertyAll(
                                    MasterStyle.tableHeaderBg),
                                border: TableBorder.all(color: kStaffBorder),
                                columns: [
                                  for (final c in table.columns)
                                    DataColumn(
                                        label: Text(c,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700))),
                                ],
                                rows: [
                                  for (final r in table.rows)
                                    DataRow(cells: [
                                      for (var i = 0;
                                          i < table.columns.length;
                                          i++)
                                        DataCell(Text(i < r.length ? r[i] : '',
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    MasterButton(
                        label: 'Copy CSV',
                        icon: Icons.copy,
                        onPressed: () => copyStaffCsv(context, raw)),
                    const SizedBox(width: 10),
                    MasterButton(
                        label: 'Close',
                        kind: MasterButtonKind.primary,
                        onPressed: () => Navigator.pop(context)),
                  ]),
                ]),
          ),
        ),
      ),
    );
}

Future<bool> staffConfirm(BuildContext context,
    {required String title,
    required String message,
    String confirmLabel = 'Delete',
    bool danger = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          key: const Key('staff-confirm'),
          style: FilledButton.styleFrom(
              backgroundColor:
                  danger ? ViniiColors.redSolid : ViniiColors.brandGreen,
              foregroundColor: danger ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Base widget for a tab: it reads from [repository] and reloads when
/// [refreshToken] changes (e.g. after an import from the page header).
abstract class StaffTabWidget extends StatefulWidget {
  const StaffTabWidget(
      {super.key,
      required this.repository,
      this.refreshToken = 0,
      this.branches = const [],
      this.defaultBranchId});
  final StaffRepository repository;
  final int refreshToken;

  /// The restaurant's branches, to show branch names and to pick one.
  /// Empty = not known (branch columns show the server's names only).
  final List<BranchLocation> branches;

  /// The branch new staff and logins start at (this device's branch).
  final String? defaultBranchId;
}

/// Loading / error / mutation plumbing shared by every tab.
mixin StaffLoadState<W extends StaffTabWidget> on State<W> {
  bool loaded = false;
  String? loadError;
  bool busy = false;

  StaffRepository get repo => widget.repository;

  /// Reads the tab's data into fields (no setState needed).
  Future<void> fetch();

  Future<void> reload() async {
    try {
      await fetch();
      if (!mounted) return;
      setState(() {
        loaded = true;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loaded = true;
        loadError = staffErrorText(e);
      });
    }
  }

  /// Runs a mutation; on success shows [success] and reloads, on failure
  /// shows the backend's message.
  Future<bool> act(Future<void> Function() action,
      {String? success, bool refresh = true}) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await action();
      if (refresh) await reload();
      if (mounted && success != null) showStaffNotice(context, success);
      return true;
    } catch (e) {
      if (mounted) showStaffError(context, e);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.repository != widget.repository) {
      reload();
    }
  }

  /// Spinner until the first load, the error with a retry, else [body].
  Widget guarded(Widget Function() body) {
    if (!loaded) return const StaffLoading();
    if (loadError != null) {
      return StaffErrorPanel(message: loadError!, onRetry: reload);
    }
    return body();
  }
}

/// Scrollable tab body.
class StaffTabPage extends StatelessWidget {
  const StaffTabPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class StaffLoading extends StatelessWidget {
  const StaffLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
}

class StaffErrorPanel extends StatelessWidget {
  const StaffErrorPanel(
      {super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: MasterBanner(
          tone: PillTone.red,
          title: "Couldn't load this page",
          message: message,
          trailing: MasterButton(label: 'Retry', onPressed: onRetry),
        ),
      );
}

/// Centered icon + title + message, with optional actions.
class StaffEmptyState extends StatelessWidget {
  const StaffEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.actions = const [],
      this.bigIcon = false});
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;
  final bool bigIcon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: bigIcon ? 88 : 56,
            height: bigIcon ? 88 : 56,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: Icon(icon,
                size: bigIcon ? 40 : 26, color: ViniiColors.textMutedLight),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: bigIcon ? 20 : 15,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
          if (message != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight)),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: actions),
          ],
        ]),
      );
}

/// Stat tile from the dashboard / approvals designs: tinted icon square,
/// small uppercase label, big value.
class StaffStatTile extends StatelessWidget {
  const StaffStatTile(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.color = ViniiColors.textPrimaryLight,
      this.labelColor,
      this.tint = const Color(0xFFF3F4F6)});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? labelColor;
  final Color tint;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w600,
                          color: labelColor ?? color)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ]),
          ),
        ]),
      );
}

/// "Total Staff  1" card with a round icon on the right.
class StaffValueCard extends StatelessWidget {
  const StaffValueCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.iconColor = kStaffGreen,
      this.iconTint = const Color(0xFFF0FDF4)});
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconTint;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: ViniiColors.textSecondaryLight)),
                  const SizedBox(height: 6),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                ]),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconTint, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ]),
      );
}

/// Two-state pill switcher ("Roster & attendance | Shift master").
class StaffPills extends StatelessWidget {
  const StaffPills(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelect,
      this.keyPrefix = 'pill'});
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < options.length; i++)
            Material(
              color: i == selected ? kStaffDark : Colors.white,
              shape: StadiumBorder(
                  side: BorderSide(
                      color: i == selected ? kStaffDark : kStaffBorder)),
              child: InkWell(
                key: Key('$keyPrefix-$i'),
                customBorder: const StadiumBorder(),
                onTap: () => onSelect(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(options[i],
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: i == selected
                              ? Colors.white
                              : ViniiColors.textPrimaryLight)),
                ),
              ),
            ),
        ],
      );
}

/// Small coloured chip for flags / statuses.
class StaffChip extends StatelessWidget {
  const StaffChip(this.text, {super.key, required this.color, this.tint});
  final String text;
  final Color color;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tint ?? color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      );
}

/// Label above a form control.
class StaffField extends StatelessWidget {
  const StaffField(
      {super.key,
      required this.label,
      required this.child,
      this.required = false});
  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (required)
                    const TextSpan(
                        text: ' *',
                        style: TextStyle(color: ViniiColors.redSolid)),
                ]),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 6),
            child,
          ]);
}

InputDecoration staffInput({String? hint, Widget? suffix, String? prefix}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefix,
      suffixIcon: suffix,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kStaffBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kStaffBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ViniiColors.brandGreen)),
    );

/// Text style for dropdowns. A dropdown's `style` replaces the ambient text
/// style outright, so it's built from the theme to keep the app font.
TextStyle staffDropdownStyle(BuildContext context, double size) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
        .copyWith(fontSize: size, color: ViniiColors.textPrimaryLight);

/// A text field that offers values already in use (departments,
/// designations…): the arrow lists them all, typing narrows them down,
/// and a value that isn't there yet is simply typed in to add it.
class StaffSuggestField extends StatefulWidget {
  const StaffSuggestField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.fieldKey,
    this.hint,
    this.validator,
  });
  final TextEditingController controller;

  /// Offered in this order; blanks and repeats are dropped.
  final List<String> suggestions;

  /// Key of the text field itself (for tests).
  final Key? fieldKey;
  final String? hint;
  final String? Function(String?)? validator;

  @override
  State<StaffSuggestField> createState() => _StaffSuggestFieldState();
}

class _StaffSuggestFieldState extends State<StaffSuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Every suggestion once, in order.
  List<String> get _all {
    final seen = <String>{};
    return [
      for (final raw in widget.suggestions)
        if (raw.trim().isNotEmpty && seen.add(raw.trim().toLowerCase()))
          raw.trim(),
    ];
  }

  /// While typing: the suggestions containing the text (not the text
  /// itself). Nothing pops up for an empty field — the arrow lists all.
  Iterable<String> _options(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final s in _all)
        if (s.toLowerCase() != q && s.toLowerCase().contains(q)) s
    ];
  }

  void _pick(String value) {
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: _options,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          final all = _all;
          return TextFormField(
            key: widget.fieldKey,
            controller: controller,
            focusNode: focusNode,
            validator: widget.validator,
            style: const TextStyle(fontSize: 13.5),
            decoration: staffInput(
              hint: widget.hint,
              suffix: PopupMenuButton<String>(
                tooltip: 'Choose from the list',
                enabled: all.isNotEmpty,
                icon: const Icon(Icons.arrow_drop_down,
                    size: 20, color: ViniiColors.textMutedLight),
                onSelected: _pick,
                itemBuilder: (_) => [
                  for (final s in all)
                    PopupMenuItem<String>(
                        value: s,
                        child: Text(s,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
            onFieldSubmitted: (_) => onSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    InkWell(
                      onTap: () => onSelected(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Text(o,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: ViniiColors.textPrimaryLight)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Compact icon button for table row actions.
class StaffIconAction extends StatelessWidget {
  const StaffIconAction(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.color = ViniiColors.textSecondaryLight});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        icon: Icon(icon,
            size: 18,
            color: onPressed == null ? ViniiColors.textMutedLight : color),
      );
}

/// Small toggle like the designs' (white thumb, grey / green track).
class StaffSwitch extends StatelessWidget {
  const StaffSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 26,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: Colors.white,
            activeTrackColor: ViniiColors.brandGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      );
}

/// A bordered dropdown whose value the parent controls.
class StaffSelect<T> extends StatelessWidget {
  const StaffSelect(
      {super.key,
      required this.value,
      required this.items,
      required this.onChanged,
      this.hint,
      this.dense = false});
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
        height: dense ? 36 : 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: onChanged == null ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kStaffBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: items.any((i) => i.$1 == value) ? value : null,
            isExpanded: true,
            isDense: true,
            hint: hint == null
                ? null
                : Text(hint!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: ViniiColors.textMutedLight)),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: staffDropdownStyle(context, 13),
            items: [
              for (final (v, label) in items)
                DropdownMenuItem<T>(
                    value: v,
                    child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}

/// Tappable box showing a date; opens the date picker.
class StaffDateButton extends StatelessWidget {
  const StaffDateButton(
      {super.key,
      required this.value,
      required this.onChanged,
      this.label,
      this.firstDate,
      this.lastDate});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: firstDate ?? DateTime(2015),
            lastDate: lastDate ?? DateTime(DateTime.now().year + 3, 12, 31),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kStaffBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (label != null) ...[
              Text('$label: ',
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight)),
            ],
            Text(staffSlashDate(value),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: ViniiColors.textSecondaryLight),
          ]),
        ),
      );
}

/// Tappable box showing an HH:MM time; opens the time picker.
class StaffTimeButton extends StatelessWidget {
  const StaffTimeButton(
      {super.key,
      required this.value,
      required this.onChanged,
      this.placeholder = '--:--'});
  final String? value;
  final ValueChanged<String?> onChanged;
  final String placeholder;

  static TimeOfDay? _parse(String? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v ?? '');
    if (m == null) return null;
    return TimeOfDay(
        hour: int.parse(m.group(1)!) % 24, minute: int.parse(m.group(2)!) % 60);
  }

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final picked = await showTimePicker(
              context: context,
              initialTime:
                  _parse(value) ?? const TimeOfDay(hour: 9, minute: 0));
          if (picked == null) return;
          onChanged('${picked.hour.toString().padLeft(2, '0')}:'
              '${picked.minute.toString().padLeft(2, '0')}');
        },
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kStaffBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                  (value == null || value!.isEmpty) ? placeholder : value!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: (value == null || value!.isEmpty)
                          ? ViniiColors.textMutedLight
                          : ViniiColors.textPrimaryLight)),
            ),
            const Icon(Icons.schedule,
                size: 14, color: ViniiColors.textMutedLight),
          ]),
        ),
      );
}

/// Round initials avatar (or the photo, when a URL is set).
class StaffAvatar extends StatelessWidget {
  const StaffAvatar(
      {super.key, required this.initials, this.photoUrl, this.size = 32});
  final String initials;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFF3F4F6),
      foregroundImage: url.isEmpty ? null : NetworkImage(url),
      onForegroundImageError: url.isEmpty ? null : (_, __) {},
      child: Text(initials,
          style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: ViniiColors.textSecondaryLight)),
    );
  }
}

/// Standard dialog frame: title bar with close, scrollable body, footer.
class StaffDialog extends StatelessWidget {
  const StaffDialog(
      {super.key,
      required this.title,
      required this.body,
      required this.actions,
      this.width = 560,
      this.error,
      this.subtitle,
      this.onClose});
  final String title;
  final VoidCallback? onClose;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final double width;
  final String? error;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ViniiColors.textPrimaryLight)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: MasterStyle.muted),
                            ],
                          ]),
                    ),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: onClose ?? () => Navigator.pop(context),
                        icon: const Icon(Icons.highlight_off,
                            size: 20, color: ViniiColors.textSecondaryLight)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: body,
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: MasterBanner(tone: PillTone.red, message: error!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: actions),
                ),
              ]),
        ),
      );
}

/// Two controls side by side (one column on narrow dialogs).
class StaffFormRow extends StatelessWidget {
  const StaffFormRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 420 || children.length == 1) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    children[i],
                  ]
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ]
          ]);
        }),
      );
}

/// Parses a number field ("₹1,200.50" → 1200.5); empty → [fallback].
double? staffParseNum(String text, {double? fallback = 0}) {
  final raw = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (raw.isEmpty) return fallback;
  return double.tryParse(raw);
}

/// Number with trailing zeros dropped (8.0 → "8").
String staffNumText(num v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// One text input in [showStaffPrompt].
class StaffPromptField {
  const StaffPromptField(this.id, this.label,
      {this.initial = '',
      this.key,
      this.number = false,
      this.prefix,
      this.obscure = false,
      this.maxLines = 1,
      this.hint});
  final String id;
  final String label;
  final String initial;
  final Key? key;
  final bool number;
  final String? prefix;
  final bool obscure;
  final int maxLines;
  final String? hint;
}

/// One checkbox in [showStaffPrompt]; returned as "true" / "false".
class StaffPromptCheck {
  const StaffPromptCheck(this.id, this.label, {this.initial = false, this.key});
  final String id;
  final String label;
  final bool initial;
  final Key? key;
}

/// Small form dialog: returns the entered values by id, or null when
/// cancelled. [validate] returns an error to show, or null when fine.
Future<Map<String, String>?> showStaffPrompt(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<StaffPromptField> fields = const [],
  List<StaffPromptCheck> checks = const [],
  Widget? note,
  String confirmLabel = 'Save',
  Key? confirmKey,
  bool danger = false,
  bool sideBySide = false,
  double width = 440,
  String? Function(Map<String, String> values)? validate,
}) =>
    showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _StaffPrompt(
        title: title,
        subtitle: subtitle,
        fields: fields,
        checks: checks,
        note: note,
        confirmLabel: confirmLabel,
        confirmKey: confirmKey,
        danger: danger,
        sideBySide: sideBySide,
        width: width,
        validate: validate,
      ),
    );

class _StaffPrompt extends StatefulWidget {
  const _StaffPrompt({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.checks,
    required this.note,
    required this.confirmLabel,
    required this.confirmKey,
    required this.danger,
    required this.sideBySide,
    required this.width,
    required this.validate,
  });
  final String title;
  final String? subtitle;
  final List<StaffPromptField> fields;
  final List<StaffPromptCheck> checks;
  final Widget? note;
  final String confirmLabel;
  final Key? confirmKey;
  final bool danger;
  final bool sideBySide;
  final double width;
  final String? Function(Map<String, String>)? validate;

  @override
  State<_StaffPrompt> createState() => _StaffPromptState();
}

class _StaffPromptState extends State<_StaffPrompt> {
  late final _controllers = {
    for (final f in widget.fields) f.id: TextEditingController(text: f.initial)
  };
  late final _checks = {for (final c in widget.checks) c.id: c.initial};
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = {
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
      for (final e in _checks.entries) e.key: '${e.value}',
    };
    final error = widget.validate?.call(values);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, values);
  }

  Widget _field(StaffPromptField f) => StaffField(
        label: f.label,
        child: TextField(
          key: f.key,
          controller: _controllers[f.id],
          obscureText: f.obscure,
          maxLines: f.obscure ? 1 : f.maxLines,
          keyboardType: f.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(prefix: f.prefix, hint: f.hint),
        ),
      );

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: widget.title,
        subtitle: widget.subtitle,
        width: widget.width,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
            key: widget.confirmKey,
            label: widget.confirmLabel,
            kind: widget.danger
                ? MasterButtonKind.danger
                : MasterButtonKind.primary,
            onPressed: _submit,
          ),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.sideBySide)
            StaffFormRow(children: [for (final f in widget.fields) _field(f)])
          else
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _field(f),
              ),
          for (final c in widget.checks)
            Row(children: [
              Checkbox(
                key: c.key,
                value: _checks[c.id],
                activeColor: ViniiColors.greenSolid,
                onChanged: (v) => setState(() => _checks[c.id] = v ?? false),
              ),
              Flexible(child: Text(c.label, style: MasterStyle.body)),
            ]),
          if (widget.note != null) widget.note!,
        ]),
      );
}
