import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api/api_client.dart';
import '../../data/csv.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

part 'finance_payments.dart';
part 'finance_settlements.dart';

/// Finance section of the vendor panel (v1/fianance/*.png): balances and
/// cash flow, POS + online payments, expenses against budget heads,
/// settlements and compliance documents. Every figure is read from
/// /v1/finance on the Proviyaa server; nothing is kept locally.
///
/// The Proviyaa payout wallet (finance-wallet.png) is not built here: the
/// server has no restaurant wallet yet.
enum FinanceTab { dashboard, payments, expenses, settlements, documents }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen(
      {super.key,
      required this.api,
      this.initialTab = FinanceTab.dashboard,
      this.canDelete = true,
      this.branches = const []});
  final ProviyaaApiClient api;
  final FinanceTab initialTab;

  /// The restaurant's branches: entries, settlements and documents are
  /// recorded for one of them (the picker shows when there are several).
  final List<BranchLocation> branches;

  /// Owners may delete finance records; a branch manager may not (the
  /// server enforces it too).
  final bool canDelete;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late FinanceTab _tab = widget.initialTab;

  static const _labels = [
    'Dashboard',
    'Payments',
    'Expenses',
    'Settlements',
    'Documents',
  ];

  @override
  void didUpdateWidget(covariant FinanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final branches = widget.branches;
    final Widget body = switch (_tab) {
      FinanceTab.dashboard => _DashboardTab(
          api: api, canDelete: widget.canDelete, branches: branches),
      FinanceTab.payments => _PaymentsTab(api: api),
      FinanceTab.expenses => _ExpensesTab(
          api: api, canDelete: widget.canDelete, branches: branches),
      FinanceTab.settlements => _SettlementsTab(
          api: api, canDelete: widget.canDelete, branches: branches),
      FinanceTab.documents => _DocumentsTab(
          api: api, canDelete: widget.canDelete, branches: branches),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTabBar(
        tabs: _labels,
        selected: _tab.index,
        keyPrefix: 'finance-tab',
        onSelect: (i) => setState(() => _tab = FinanceTab.values[i]),
      ),
      Expanded(child: body),
    ]);
  }
}

// ── shared labels & helpers ─────────────────────────────────────────────

const _kinds = <(String, String)>[
  ('cash_register', 'Cash register'),
  ('top_up', 'Top-up'),
  ('withdrawal', 'Withdrawal'),
  ('capital', 'Capital'),
  ('expense', 'Expense'),
  ('transfer', 'Transfer'),
  ('other', 'Other'),
];

const _accounts = <(String, String)>[
  ('cash', 'Cash'),
  ('bank', 'Bank'),
  ('upi', 'UPI'),
  ('wallet', 'Wallet'),
];

const _methods = <(String, String)>[
  ('cash', 'Cash'),
  ('upi', 'UPI'),
  ('card', 'Card'),
  ('wallet', 'Wallet'),
  ('online', 'Online'),
  ('cod', 'Cash on delivery'),
  ('bank_transfer', 'Bank transfer'),
];

const _periods = <(String, String)>[
  ('today', 'Today'),
  ('week', 'Last 7 days'),
  ('month', 'This month'),
];

const _capsLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w600,
    color: ViniiColors.textSecondaryLight);

const _chipTint = Color(0xFFF3F4F6);
const _outRed = Color(0xFFF43F5E);
const _orangeDot = Color(0xFFF59E0B);

/// The label of [v] in a (value, label) list, else [v] humanized.
String _labelOf(List<(String, String)> items, dynamic v) {
  final s = '${v ?? ''}';
  for (final (key, label) in items) {
    if (key == s) return label;
  }
  return humanize(s);
}

/// from / to (YYYY-MM-DD) for a period key.
Map<String, String> _periodQuery(String period) {
  final t = staffToday();
  final from = switch (period) {
    'week' => DateTime(t.year, t.month, t.day - 6),
    'month' => DateTime(t.year, t.month, 1),
    _ => t,
  };
  return {'from': isoDay(from), 'to': isoDay(t)};
}

/// "Aug '26" from "2026-08".
String _monthLabel(dynamic ym) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch('${ym ?? ''}');
  if (m == null) return textOf(ym);
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return textOf(ym);
  return "${staffMonthNames[month - 1].substring(0, 3)} '${m.group(1)!.substring(2)}";
}

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// "September 2026" from "2026-09".
String _monthName(String ym) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(ym);
  if (m == null) return ym;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return ym;
  return '${staffMonthNames[month - 1]} ${m.group(1)}';
}

/// Copies [rows] as CSV to the clipboard and says so.
Future<void> _copyCsv(BuildContext context, String what, List<String> headers,
    List<List<Object?>> rows) async {
  await Clipboard.setData(ClipboardData(text: Csv.encode(headers, rows)));
  if (!context.mounted) return;
  showStaffNotice(
      context, 'Copied ${rows.length} $what as CSV to the clipboard');
}

Widget _kpis(List<Widget> cards, {int columns = 4}) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MasterGrid(columns: columns, minItemWidth: 170, children: cards),
    );

Widget _legend(Color color, String label) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      _Dot(color),
      const SizedBox(width: 6),
      Text(label, style: MasterStyle.muted),
    ]);

Widget _emptyCard(IconData icon, String title, String message) => MasterCard(
      child: Center(
          child: StaffEmptyState(icon: icon, title: title, message: message)),
    );

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// KPI tile like the finance designs: small caps label (with an optional
/// status dot), big value, caption.
class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      this.caption,
      this.dot,
      this.valueColor = ViniiColors.textPrimaryLight});
  final String label;
  final String value;
  final String? caption;
  final Color? dot;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _capsLabel),
            ),
            if (dot != null) ...[const SizedBox(width: 8), _Dot(dot!)],
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: valueColor)),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MasterStyle.muted),
          ],
        ]),
      );
}

/// "All (10) | Online (0) | POS (10)" filter pills.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs(
      {required this.labels,
      required this.selected,
      required this.onSelect,
      required this.keyPrefix});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: i == selected ? const Color(0xFFECECEA) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('$keyPrefix-$i'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == selected ? FontWeight.w700 : FontWeight.w500,
                          color: i == selected
                              ? ViniiColors.textPrimaryLight
                              : ViniiColors.textSecondaryLight)),
                ),
              ),
            ),
        ],
      );
}

/// Filter pills on the left, buttons on the right (wrapping when narrow).
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.left, required this.actions});
  final Widget left;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            left,
            Wrap(spacing: 10, runSpacing: 8, children: actions),
          ],
        ),
      );
}

/// Children side by side ([flex] each), stacked below 820 px.
class _Split extends StatelessWidget {
  const _Split({required this.children, this.flex = const [1, 1]});
  final List<Widget> children;
  final List<int> flex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 820) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
                flex: i < flex.length ? flex[i] : 1, child: children[i]),
          ],
        ]);
      });
}

/// "Period: Today ⌄".
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => MasterFilterButton(
        key: const Key('finance-period'),
        label: 'Period: ${_labelOf(_periods, value)}',
        options: [for (final (_, label) in _periods) label],
        onSelected: (picked) {
          for (final (key, label) in _periods) {
            if (label == picked) onChanged(key);
          }
        },
      );
}

/// A date box that may be empty (with a clear button).
class _OptionalDate extends StatelessWidget {
  const _OptionalDate(
      {super.key,
      required this.value,
      required this.onChanged,
      this.emptyLabel = 'Not set'});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(children: [
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: v ?? staffToday(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100, 12, 31),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kStaffBorder),
            ),
            child: Row(children: [
              Expanded(
                child: Text(v == null ? emptyLabel : staffSlashDate(v),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            v == null ? FontWeight.w400 : FontWeight.w600,
                        color: v == null
                            ? ViniiColors.textMutedLight
                            : ViniiColors.textPrimaryLight)),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 15, color: ViniiColors.textSecondaryLight),
            ]),
          ),
        ),
      ),
      if (v != null)
        StaffIconAction(
            icon: Icons.close,
            tooltip: 'Clear date',
            onPressed: () => onChanged(null)),
    ]);
  }
}

// ── dashboard ────────────────────────────────────────────────────────────

/// One ledger sub-tab: which entries it lists and the kind a new entry
/// starts as.
class _Ledger {
  const _Ledger(this.label, this.query, this.kind, this.subtitle);
  final String label;
  final Map<String, String> query;
  final String? kind;
  final String subtitle;
}

const _ledgers = [
  _Ledger('Cash register', {'account': 'cash'}, 'cash_register',
      'Every entry on the cash account: cash put into or taken out of the counter.'),
  _Ledger('Top-ups', {'kind': 'top_up'}, 'top_up',
      'Money partners or owners put into the business.'),
  _Ledger('Withdrawals', {'kind': 'withdrawal'}, 'withdrawal',
      'Money owners or partners took out of the business.'),
  _Ledger('Owners & capital', {'kind': 'capital'}, 'capital',
      'Capital introduced into or returned from the business.'),
  _Ledger('Approvals', {'status': 'pending'}, null,
      'Entries waiting for approval. They count in balances only once approved.'),
  _Ledger('Ledger', {}, null,
      'Every entry recorded in Finance, newest first (bills are under Payments).'),
];

class _DashboardTab extends StatefulWidget {
  const _DashboardTab(
      {required this.api, required this.canDelete, this.branches = const []});
  final ProviyaaApiClient api;
  final bool canDelete;
  final List<BranchLocation> branches;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _period = 'today';
  int _sub = 0;
  int _rev = 0;

  /// One request feeds both the KPI cards and the overview below the tabs.
  Future<Map<String, dynamic>>? _data;

  Future<Map<String, dynamic>> _dashboard() {
    final cached = _data;
    if (cached != null) return cached;
    final f = widget.api
        .get('v1/finance/dashboard', query: _periodQuery(_period))
        .then(jsonMap);
    _data = f;
    // A failed load is not kept, so Retry asks the server again.
    f.then((_) {}, onError: (Object _) {
      if (identical(_data, f)) _data = null;
    });
    return f;
  }

  void _refresh() => setState(() {
        _data = null;
        _rev++;
      });

  Future<void> _record([String? kind]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EntryDialog(
          api: widget.api, initialKind: kind, branches: widget.branches),
    );
    if (saved != true || !mounted) return;
    showStaffNotice(context, 'Transaction recorded');
    _refresh();
  }

  String get _periodText => _labelOf(_periods, _period).toLowerCase();

  @override
  Widget build(BuildContext context) => BusinessPage(
        title: 'Finance',
        subtitle:
            "Balances, today's figures and cash flow. Flow figures cover: $_periodText.",
        actions: [
          _PeriodPicker(
            value: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _data = null;
              _rev++;
            }),
          ),
        ],
        children: [
          ApiLoader<Map<String, dynamic>>(
            key: ValueKey('finance-kpis-$_rev'),
            load: _dashboard,
            builder: (context, d, _) => _kpiCards(d),
          ),
          MasterTabStrip(
            tabs: ['Dashboard', for (final l in _ledgers) l.label],
            selected: _sub,
            onSelect: (i) => setState(() => _sub = i),
          ),
          const SizedBox(height: 18),
          if (_sub == 0)
            ApiLoader<Map<String, dynamic>>(
              key: ValueKey('finance-overview-$_rev'),
              load: _dashboard,
              builder: (context, d, _) => _overview(d),
            )
          else
            _EntriesPanel(
              key: ValueKey('finance-ledger-$_sub-$_rev'),
              api: widget.api,
              ledger: _ledgers[_sub - 1],
              canDelete: widget.canDelete,
              branches: widget.branches,
              onChanged: _refresh,
              onRecord: () => _record(_ledgers[_sub - 1].kind),
            ),
        ],
      );

  Widget _kpiCards(Map<String, dynamic> d) {
    final net = numOf(d['net_cash_flow']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpiGrid(cards: [
        _StatCard(
            label: 'Cash in hand',
            value: inr(d['cash_in_hand']),
            caption: 'Cash bills + cash entries in − cash entries out'),
        _StatCard(
            label: 'Bank balance',
            value: inr(d['bank_balance']),
            caption:
                'Card & other bills + bank entries + completed Zomato / Swiggy / online settlements'),
        _StatCard(
            label: 'UPI balance',
            value: inr(d['upi_balance']),
            caption: 'UPI bills + UPI entries in − out'),
        _StatCard(
            label: 'Wallet balance',
            value: inr(d['wallet_balance']),
            caption: 'Wallet bills + wallet entries in − out'),
        _StatCard(
            label: "Today's sales",
            value: inr(d['today_sales']),
            caption: 'Totals of bills paid today'),
        _StatCard(
            label: "Today's expense",
            value: inr(d['today_expense']),
            caption: 'Approved expense entries dated today'),
        _StatCard(
            label: "Today's collection",
            value: inr(d['today_collection']),
            caption: 'Payments received on paid bills today'),
        _StatCard(
            label: "Today's refund",
            value: inr(d['today_refund']),
            caption: 'Refunds are not recorded in Proviyaa yet'),
        _StatCard(
            label: 'Pending settlements',
            value: inr(d['pending_settlements']),
            caption: 'Settlements recorded as not yet received'),
        _StatCard(
            label: 'Supplier payables',
            value: inr(d['supplier_payables']),
            caption: 'Open purchase orders'),
        _StatCard(
            label: 'Customer receivables',
            value: inr(d['customer_receivables']),
            caption: 'Bills awaiting payment'),
        _StatCard(
            label: 'Net cash flow',
            value: inr(net),
            valueColor:
                net < 0 ? ViniiColors.redSolid : ViniiColors.textPrimaryLight,
            caption: 'Money in − money out, $_periodText'),
      ]),
      const InfoNote(
          'Balances are running totals of what Proviyaa records: paid POS bills by payment method plus approved '
          'Finance entries (and completed aggregator settlements into bank). They are not read from your bank or UPI app.'),
    ]);
  }

  // ── overview (the "Dashboard" sub-tab) ──

  Widget _overview(Map<String, dynamic> d) {
    final monthly = jsonList(d['monthly']);
    final net = numOf(d['net_cash_flow']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Split(flex: const [2, 3], children: [
        _totalBalance(d),
        MasterSection(
          title: 'Inflow vs outflow',
          subtitle:
              'Money in (bill payments + entries in) and money out (entries out), last six months',
          child: monthly.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                      'No money movement recorded in the last six months.',
                      style: MasterStyle.muted),
                )
              : _FlowBars(monthly: monthly),
        ),
      ]),
      const SizedBox(height: 16),
      _kpis([
        _StatCard(
            label: 'Money in',
            value: inr(d['money_in']),
            dot: ViniiColors.greenSolid,
            caption: 'Bill payments + approved entries in, $_periodText'),
        _StatCard(
            label: 'Money out',
            value: inr(d['money_out']),
            dot: ViniiColors.redSolid,
            caption: 'Approved entries out, $_periodText'),
        _StatCard(
            label: 'Net cash flow',
            value: inr(net),
            dot: ViniiColors.blueSolid,
            valueColor:
                net < 0 ? ViniiColors.redSolid : ViniiColors.textPrimaryLight,
            caption: 'Money in − money out'),
        _StatCard(
            label: 'Partner top-ups',
            value: inr(d['partner_top_ups']),
            dot: _orangeDot,
            caption: 'Approved top-up entries, $_periodText'),
      ]),
      _Split(children: [
        MasterSection(
          title: 'Collection mix',
          subtitle: 'Payments on paid bills by method, $_periodText',
          child: _shareList(jsonList(d['collection_mix']), 'method',
              ViniiColors.greenSolid,
              empty: 'No bill payments in this period.',
              labeler: (v) => _labelOf(_methods, v)),
        ),
        MasterSection(
          title: 'Expense breakdown',
          subtitle:
              'Approved money-out entries by category, $_periodText (top 8)',
          child: _shareList(jsonList(d['expense_breakdown']), 'category',
              ViniiColors.amberSolid,
              empty: 'No money-out entries in this period.',
              labeler: (v) => textOf(v, 'Uncategorised')),
        ),
      ]),
      const SizedBox(height: 16),
      MasterSection(
        title: 'Net cash trend',
        subtitle:
            'Money in − money out per month, last six months (paid bills + approved entries)',
        child: _netTrend(monthly),
      ),
    ]);
  }

  Widget _totalBalance(Map<String, dynamic> d) => MasterCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TOTAL BALANCE', style: _capsLabel),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(inr(d['total_balance']),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: ViniiColors.textPrimaryLight)),
          ),
          const SizedBox(height: 4),
          const Text('Cash + bank + UPI + wallet balances',
              style: MasterStyle.muted),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child:
                    MasterKeyValue('Pending top-ups', inr(d['pending_top_ups']))),
            const SizedBox(width: 12),
            Expanded(
                child: MasterKeyValue(
                    'Withdrawals due', inr(d['withdrawals_due']))),
          ]),
          const SizedBox(height: 4),
          const Text('Entries waiting for approval, not in the balance yet',
              style: MasterStyle.muted),
          const SizedBox(height: 18),
          MasterButton(
            key: const Key('finance-record-transaction'),
            label: '+ Record transaction',
            kind: MasterButtonKind.primary,
            onPressed: () => _record(),
          ),
        ]),
      );

  static Widget _shareList(
      List<Map<String, dynamic>> rows, String field, Color color,
      {required String empty, String Function(dynamic v)? labeler}) {
    if (rows.isEmpty) return Text(empty, style: MasterStyle.muted);
    num total = 0;
    for (final r in rows) {
      total += numOf(r['amount']);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in rows)
        ShareBar(
          label: labeler == null ? textOf(r[field]) : labeler(r[field]),
          value: total > 0
              ? '${inr(r['amount'])} · ${(numOf(r['amount']) * 100 / total).round()}%'
              : inr(r['amount']),
          share: total > 0 ? numOf(r['amount']) / total : 0.0,
          color: color,
        ),
    ]);
  }

  static Widget _netTrend(List<Map<String, dynamic>> monthly) {
    if (monthly.isEmpty) {
      return const Text('No months with money movement yet.',
          style: MasterStyle.muted);
    }
    num top = 0;
    for (final m in monthly) {
      top = math.max(top, numOf(m['net']).abs());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final m in monthly)
        ShareBar(
          label: _monthLabel(m['month']),
          value:
              '${numOf(m['net']) < 0 ? '−' : '+'}${inr(numOf(m['net']).abs())}',
          share: top > 0 ? numOf(m['net']).abs() / top : 0.0,
          color: numOf(m['net']) < 0
              ? ViniiColors.redSolid
              : ViniiColors.greenSolid,
        ),
    ]);
  }
}

/// Paired in / out bars per month, drawn with plain containers.
class _FlowBars extends StatelessWidget {
  const _FlowBars({required this.monthly});
  final List<Map<String, dynamic>> monthly;

  static const _height = 140.0;

  @override
  Widget build(BuildContext context) {
    num top = 0;
    for (final m in monthly) {
      top = math.max(top,
          math.max(numOf(m['inflow']), numOf(m['outflow'])));
    }
    Widget bar(num v, Color color, String tip) => Tooltip(
          message: tip,
          child: Container(
            width: 18,
            height: top <= 0 || v <= 0
                ? 0.0
                : math.max(2, _height * v / top).toDouble(),
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Tallest bar: ${inr(top)}', style: MasterStyle.muted),
      const SizedBox(height: 10),
      SizedBox(
        height: _height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final m in monthly)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  bar(numOf(m['inflow']), ViniiColors.brandGreen,
                      '${_monthLabel(m['month'])} in: ${inr(m['inflow'])}'),
                  const SizedBox(width: 3),
                  bar(numOf(m['outflow']), _outRed,
                      '${_monthLabel(m['month'])} out: ${inr(m['outflow'])}'),
                ],
              ),
            ),
        ]),
      ),
      const Divider(height: 1, color: MasterStyle.cardBorder),
      const SizedBox(height: 6),
      Row(children: [
        for (final m in monthly)
          Expanded(
            child: Text(_monthLabel(m['month']),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: MasterStyle.muted),
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 16, children: [
        _legend(ViniiColors.brandGreen, 'In'),
        _legend(_outRed, 'Out'),
      ]),
    ]);
  }
}

// ── entries (cash register, top-ups, withdrawals, capital, approvals) ──

/// Approve / reject / delete one finance entry; true when it changed.
Future<bool> _entryAction(BuildContext context, ProviyaaApiClient api,
    Map<String, dynamic> e, String action) async {
  final id = '${e['id']}';
  final amount = inr(e['amount']);
  if (action == 'Approve' || action == 'Reject') {
    final approve = action == 'Approve';
    final ok = await runAction(context, () async {
      await api.post(
          'v1/finance/entries/$id/${approve ? 'approve' : 'reject'}');
      return true;
    }, success: approve ? 'Entry of $amount approved' : 'Entry of $amount rejected');
    return ok ?? false;
  }
  if (action == 'Delete') {
    final sure = await staffConfirm(context,
        title: 'Delete this entry?',
        message:
            'The $amount ${_labelOf(_kinds, e['kind']).toLowerCase()} entry dated '
            '${fmtDate(e['entry_date'])} will be removed from the ledger and the balances.');
    if (!sure || !context.mounted) return false;
    final ok = await runAction(context, () async {
      await api.delete('v1/finance/entries/$id');
      return true;
    }, success: 'Entry deleted');
    return ok ?? false;
  }
  return false;
}

Future<void> _copyEntriesCsv(BuildContext context, String what,
    List<Map<String, dynamic>> rows,
    {List<BranchLocation> branches = const []}) {
  final withBranch = hasManyBranches(branches);
  return _copyCsv(context, what, [
    'Date',
    'Direction',
    'Kind',
    'Account',
    'Category',
    'Party',
    'Reference',
    'Amount',
    'Status',
    if (withBranch) 'Branch',
    'Note',
  ], [
    for (final e in rows)
      [
        e['entry_date'] == null ? '' : fmtDate(e['entry_date']),
        e['direction'] == 'in' ? 'In' : 'Out',
        _labelOf(_kinds, e['kind']),
        _labelOf(_accounts, e['account']),
        textOf(e['category'], ''),
        textOf(e['party'], ''),
        textOf(e['reference'], ''),
        numOf(e['amount']),
        _entryStatusLabel(e['status']),
        if (withBranch) branchLabel(branches, e['location_id']),
        textOf(e['note'], ''),
      ],
  ]);
}

/// An entry's approval status as a label.
String _entryStatusLabel(dynamic status) => switch ('${status ?? ''}') {
      'pending' => 'Pending approval',
      'approved' || '' => 'Approved',
      'rejected' => 'Rejected',
      final other => humanize(other),
    };

class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel(
      {super.key,
      required this.api,
      required this.ledger,
      required this.canDelete,
      required this.onChanged,
      required this.onRecord,
      this.branches = const []});
  final ProviyaaApiClient api;
  final _Ledger ledger;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onRecord;
  final List<BranchLocation> branches;

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        load: () async => jsonList(await api.get('v1/finance/entries',
            query: {...ledger.query, 'limit': '300'})),
        builder: (context, rows, _) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ToolRow(
            left: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${ledger.label} (${rows.length})',
                        style: MasterStyle.sectionTitle),
                    const SizedBox(height: 4),
                    Text(ledger.subtitle, style: MasterStyle.muted),
                  ]),
            ),
            actions: [
              MasterButton(
                label: 'Export CSV',
                icon: Icons.description_outlined,
                onPressed: () => _copyEntriesCsv(
                    context, '${ledger.label.toLowerCase()} entries', rows,
                    branches: branches),
              ),
              MasterButton(
                key: const Key('finance-record-transaction'),
                label: '+ Record transaction',
                kind: MasterButtonKind.primary,
                onPressed: onRecord,
              ),
            ],
          ),
          _EntriesTable(
            rows: rows,
            canDelete: canDelete,
            branches: branches,
            emptyTitle: 'Nothing here yet',
            emptyMessage: ledger.query['status'] == 'pending'
                ? 'No entry is waiting for approval.'
                : 'Record a transaction and it will be listed here.',
            onAction: (e, a) async {
              if (await _entryAction(context, api, e, a)) onChanged();
            },
          ),
          if (rows.length >= 300)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Showing the latest 300 entries.',
                  style: MasterStyle.muted),
            ),
        ]),
      );
}

/// Finance entries as a table. [expenseView] drops the direction and kind
/// columns (every row is an expense).
class _EntriesTable extends StatelessWidget {
  const _EntriesTable(
      {required this.rows,
      required this.canDelete,
      required this.onAction,
      this.expenseView = false,
      this.branches = const [],
      this.emptyTitle = 'No entries yet',
      this.emptyMessage = 'Record a transaction and it will be listed here.'});
  final List<Map<String, dynamic>> rows;
  final bool canDelete;
  final void Function(Map<String, dynamic> entry, String action) onAction;
  final bool expenseView;
  final List<BranchLocation> branches;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _emptyCard(
          Icons.account_balance_wallet_outlined, emptyTitle, emptyMessage);
    }
    final withBranch = hasManyBranches(branches);
    return MasterTable(
      minWidth: (expenseView ? 860.0 : 1040.0) + (withBranch ? 140.0 : 0.0),
      columns: [
        const MasterColumn('Date', flex: 2),
        if (!expenseView) const MasterColumn('Direction', flex: 2),
        if (!expenseView) const MasterColumn('Kind', flex: 2),
        const MasterColumn('Account', flex: 2),
        MasterColumn(expenseView ? 'Expense head' : 'Category', flex: 2),
        MasterColumn(expenseView ? 'Paid to' : 'Party', flex: 2),
        if (withBranch) const MasterColumn('Branch', flex: 2),
        const MasterColumn('Amount', flex: 2, alignEnd: true),
        const MasterColumn('Status', flex: 2),
        const MasterColumn('Actions', flex: 3),
      ],
      rows: [for (final e in rows) _cells(e)],
    );
  }

  List<Widget> _cells(Map<String, dynamic> e) {
    final isIn = e['direction'] == 'in';
    final reference = textOf(e['reference'], '');
    final actions = <String>[
      if (e['status'] == 'pending') ...['Approve', 'Reject'],
      if (canDelete) 'Delete',
    ];
    return [
      MasterCellTitle(fmtDate(e['entry_date']),
          subtitle: reference.isEmpty ? null : 'Ref $reference'),
      if (!expenseView)
        MasterStatusPill(isIn ? 'In' : 'Out',
            tone: isIn ? PillTone.green : PillTone.red),
      if (!expenseView) MasterCellText(_labelOf(_kinds, e['kind'])),
      MasterCellText(_labelOf(_accounts, e['account'])),
      MasterCellText(textOf(e['category'])),
      MasterCellText(textOf(e['party'])),
      if (hasManyBranches(branches))
        MasterCellText(branchLabel(branches, e['location_id'])),
      MasterCellText('${isIn ? '+' : '−'}${inr(e['amount'])}',
          bold: true,
          color: isIn ? ViniiColors.greenSolid : ViniiColors.redSolid),
      StatusPill(textOf(e['status'], 'approved'),
          label: _entryStatusLabel(e['status'])),
      actions.isEmpty
          ? const MasterCellText('—', color: ViniiColors.textMutedLight)
          : MasterRowActions(actions, onTap: (a) => onAction(e, a)),
    ];
  }
}

/// Value of the "+ Add head" item in the expense-head dropdown.
const _addHeadItem = '\u0000add-head';

/// "Record transaction" / "Add expense": POST /v1/finance/entries.
class _EntryDialog extends StatefulWidget {
  const _EntryDialog(
      {required this.api,
      this.initialKind,
      this.expense = false,
      this.heads = const [],
      this.branches = const []});
  final ProviyaaApiClient api;
  final String? initialKind;

  /// Expense mode: money out of kind "expense", counted against an expense
  /// head. [heads] are the active head names already loaded (the dialog
  /// reads them again).
  final bool expense;
  final List<String> heads;

  /// The restaurant's branches (the picker shows when there are several).
  final List<BranchLocation> branches;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late String _kind =
      widget.expense ? 'expense' : (widget.initialKind ?? 'cash_register');
  late String _direction = _directionFor(_kind);
  String _account = 'cash';
  DateTime _date = staffToday();
  bool _needsApproval = false;
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _party = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late String? _branch = defaultBranchId(widget.branches);
  String? _error;
  bool _saving = false;

  /// Active expense heads; null while loading.
  List<String>? _heads;

  /// The heads could not be read: an expense takes a typed category.
  bool _headsFailed = false;
  bool _addingHead = false;

  /// The expense head picked for an expense.
  String? _head;

  /// Earlier entries, suppliers and owner / admin logins, for suggestions.
  List<Map<String, dynamic>> _entries = const [];
  List<String> _suppliers = const [];
  List<String> _owners = const [];

  static String _directionFor(String kind) => switch (kind) {
        'withdrawal' || 'expense' => 'out',
        _ => 'in',
      };

  bool get _isExpense => _kind == 'expense';

  /// An expense picks its head from the dropdown (unless heads could not
  /// be read); every other kind types a category.
  bool get _usesHeads => _isExpense && !_headsFailed;

  @override
  void initState() {
    super.initState();
    if (widget.heads.isNotEmpty) _heads = List.of(widget.heads);
    _loadHeads();
    _loadEntries();
    _loadSuppliers();
    _loadOwners();
  }

  @override
  void dispose() {
    for (final c in [_category, _amount, _party, _reference, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHeads() async {
    try {
      final rows = jsonList(await widget.api
          .get('v1/finance/expense-heads', query: const {'limit': '500'}));
      if (!mounted) return;
      setState(() {
        _heads = distinctText([
          for (final h in rows)
            if (h['active'] != false) h['name'],
        ]);
        _headsFailed = false;
      });
    } catch (_) {
      if (mounted && _heads == null) setState(() => _headsFailed = true);
    }
  }

  Future<void> _loadEntries() async {
    try {
      final rows = jsonList(await widget.api
          .get('v1/finance/entries', query: const {'limit': '500'}));
      if (mounted) setState(() => _entries = rows);
    } catch (_) {
      // Categories and parties can still be typed.
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final rows = jsonList(await widget.api
          .get('v1/master/suppliers', query: const {'limit': '500'}));
      if (mounted) {
        setState(() => _suppliers = distinctText([
              for (final r in rows)
                if (r['deleted_at'] == null) r['name'],
            ]));
      }
    } catch (_) {
      // "Paid to" can still be typed.
    }
  }

  Future<void> _loadOwners() async {
    try {
      final rows = jsonList(await widget.api.get('v1/staff/logins'));
      if (mounted) {
        setState(() => _owners = distinctText([
              for (final r in rows)
                if (const ['org_owner', 'org_admin'].contains(r['pos_role']) &&
                    textOf(r['status'], 'Active').toLowerCase() == 'active')
                  textOf(r['full_name'], textOf(r['email'], '')),
            ]));
      }
    } catch (_) {
      // Not every role may list logins; the party can still be typed.
    }
  }

  /// Categories used before: this kind's first, then the other kinds'.
  List<String> get _categorySuggestions => distinctText([
        for (final e in _entries)
          if (e['kind'] == _kind) e['category'],
        for (final e in _entries)
          if (e['kind'] != 'expense') e['category'],
      ]);

  /// Suppliers for an expense, the owners and admins for money they put in
  /// or took out, then parties used before with this kind.
  List<String> get _partySuggestions => distinctText([
        if (_isExpense) ..._suppliers,
        if (const ['top_up', 'withdrawal', 'capital'].contains(_kind))
          ..._owners,
        for (final e in _entries)
          if (e['kind'] == _kind) e['party'],
      ]);

  static String? _validateHead(Map<String, String> v) {
    if ((v['name'] ?? '').trim().isEmpty) return 'Give the head a name.';
    final budget = staffParseNum(v['budget'] ?? '');
    if (budget == null || budget < 0) {
      return 'The monthly budget must be zero or more.';
    }
    return null;
  }

  /// "+ Add head": creates an expense head and picks it.
  Future<void> _addHead() async {
    final v = await showStaffPrompt(
      context,
      title: 'Add expense head',
      subtitle: 'A category of spending, with an optional monthly budget.',
      fields: const [
        StaffPromptField('name', 'Name',
            key: Key('expense-head-name'), hint: 'e.g. Gas & fuel'),
        StaffPromptField('budget', 'Monthly budget (optional)',
            key: Key('expense-head-budget'), number: true, prefix: '₹ '),
      ],
      confirmLabel: 'Add head',
      confirmKey: const Key('expense-head-save'),
      validate: _validateHead,
    );
    if (v == null || !mounted) return;
    final name = (v['name'] ?? '').trim();
    final existing = (_heads ?? const <String>[])
        .where((h) => h.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      setState(() => _head = existing);
      return;
    }
    setState(() {
      _addingHead = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/finance/expense-heads', {
        'name': name,
        'monthly_budget': staffParseNum(v['budget'] ?? '') ?? 0,
      });
      if (!mounted) return;
      setState(() {
        _addingHead = false;
        _heads = distinctText([...?_heads, name]);
        _head = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addingHead = false;
        _error = apiErrorText(e);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = staffParseNum(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter the amount as a number, e.g. 1500.');
      return;
    }
    final head = _head;
    if (_usesHeads && head == null) {
      setState(() => _error = (_heads ?? const <String>[]).isEmpty
          ? 'Add an expense head for this expense (+ Add head).'
          : 'Pick the expense head.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/finance/entries', {
        'entry_date': isoDay(_date),
        'direction': _isExpense ? 'out' : _direction,
        'kind': _kind,
        'account': _account,
        'category': _usesHeads ? (head ?? '') : _category.text.trim(),
        'amount': amount,
        'party': _party.text.trim(),
        'reference': _reference.text.trim(),
        'note': _note.text.trim(),
        'status': _needsApproval ? 'pending' : 'approved',
        if (widget.branches.isNotEmpty) 'location_id': _branch,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorText(e);
      });
    }
  }

  Widget _headField() {
    final heads = _heads;
    return StaffField(
      label: 'Expense head',
      required: true,
      child: StaffSelect<String>(
        key: const Key('entry-head'),
        value: _head,
        hint: heads == null
            ? 'Loading heads…'
            : (heads.isEmpty ? 'No heads yet — add one' : 'Pick a head'),
        items: [
          for (final h in heads ?? const <String>[]) (h, h),
          if (heads != null) (_addHeadItem, '+ Add head'),
        ],
        onChanged: heads == null || _addingHead
            ? null
            : (v) {
                if (v == _addHeadItem) {
                  _addHead();
                } else {
                  setState(() => _head = v);
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    return StaffDialog(
      title: expense ? 'Add expense' : 'Record transaction',
      subtitle: expense
          ? 'Money out, counted against its expense head\'s monthly budget'
          : 'Money in or out outside POS bills: cash register, top-ups, withdrawals, capital, expenses',
      width: 640,
      error: _error,
      actions: [
        MasterButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        MasterButton(
          key: const Key('entry-save'),
          label: _saving ? 'Saving…' : 'Save',
          kind: MasterButtonKind.primary,
          onPressed: _saving ? null : _save,
        ),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!expense)
          StaffFormRow(children: [
            StaffField(
              label: 'Direction',
              child: StaffSelect<String>(
                key: const Key('entry-direction'),
                value: _isExpense ? 'out' : _direction,
                items: const [('in', 'Money in'), ('out', 'Money out')],
                onChanged: _isExpense
                    ? null
                    : (v) => setState(() => _direction = v ?? _direction),
              ),
            ),
            StaffField(
              label: 'Kind',
              child: StaffSelect<String>(
                key: const Key('entry-kind'),
                value: _kind,
                items: _kinds,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _kind = v;
                    _direction = _directionFor(v);
                  });
                },
              ),
            ),
          ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Account',
            child: StaffSelect<String>(
              key: const Key('entry-account'),
              value: _account,
              items: _accounts,
              onChanged: (v) => setState(() => _account = v ?? _account),
            ),
          ),
          StaffField(
            label: 'Date',
            child: StaffDateButton(
                value: _date, onChanged: (d) => setState(() => _date = d)),
          ),
        ]),
        StaffFormRow(children: [
          if (_usesHeads)
            _headField()
          else
            BizComboField(
              key: const Key('entry-category'),
              label: 'Category',
              controller: _category,
              suggestions: _categorySuggestions,
              hint: _isExpense
                  ? 'e.g. Gas & fuel'
                  : 'e.g. Petty cash, Owner top-up',
            ),
          BizTextField(
            key: const Key('entry-amount'),
            label: 'Amount',
            controller: _amount,
            number: true,
            prefix: '₹ ',
            required: true,
          ),
        ]),
        StaffFormRow(children: [
          BizComboField(
            key: const Key('entry-party'),
            label: _isExpense ? 'Paid to (vendor)' : 'Party',
            controller: _party,
            suggestions: _partySuggestions,
            hint: _isExpense
                ? 'Supplier or person paid'
                : 'Who paid or was paid',
          ),
          BizTextField(
            label: 'Reference',
            controller: _reference,
            hint: 'Bill no., UTR, cheque no.',
          ),
        ]),
        if (hasManyBranches(widget.branches))
          StaffFormRow(children: [
            BizBranchSelect(
              selectKey: const Key('entry-branch'),
              branches: widget.branches,
              value: _branch,
              onChanged: (v) => setState(() => _branch = v),
            ),
            const SizedBox.shrink(),
          ]),
        BizTextField(label: 'Note', controller: _note, maxLines: 2),
        const SizedBox(height: 14),
        BizToggle(
          key: const Key('entry-needs-approval'),
          label: 'Needs approval (kept out of balances until approved)',
          value: _needsApproval,
          onChanged: (v) => setState(() => _needsApproval = v),
        ),
      ]),
    );
  }
}
