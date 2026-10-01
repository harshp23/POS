part of 'finance_screen.dart';

// ── payments ─────────────────────────────────────────────────────────────

/// POS bills and online (app) orders in one list
/// (v1/fianance/finance-payments.png).
class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _period = 'today';
  String _source = 'all';

  static const _sources = ['all', 'online', 'pos'];

  Future<Map<String, dynamic>> _load() =>
      widget.api.getEnvelope('v1/finance/payments', query: {
        'source': _source,
        'limit': '500',
        ..._periodQuery(_period),
      });

  Future<void> _export(List<Map<String, dynamic>> rows) => _copyCsv(
        context,
        'payments',
        const [
          'Date',
          'Source',
          'Reference',
          'Customer',
          'Method',
          'Amount',
          'Status',
        ],
        [
          for (final r in rows)
            [
              fmtDateTime(r['created_at']),
              r['source'] == 'online' ? 'Online' : 'POS',
              _paymentRef(r),
              _paymentCustomer(r),
              _labelOf(_methods, r['method']),
              numOf(r['amount']),
              _paymentStatusLabel(r['status']),
            ],
        ],
      );

  /// The bill or order number ("#12" for a POS bill, "OL-1A2B3C4D" for an
  /// online order) — never a database id.
  static String _paymentRef(Map<String, dynamic> r) {
    final ref = textOf(r['reference'], '');
    if (ref.isEmpty || isUuidLike(ref)) return '—';
    if (r['source'] != 'online' && RegExp(r'^\d+$').hasMatch(ref)) {
      return '#$ref';
    }
    return ref;
  }

  /// The customer's name; a POS bill without one was a walk-in, an online
  /// order without one a guest.
  static String _paymentCustomer(Map<String, dynamic> r) {
    final name = textOf(r['customer_name'], '');
    if (name.isNotEmpty && !isUuidLike(name)) return name;
    return r['source'] == 'online' ? 'Guest' : 'Walk-in';
  }

  static String _paymentStatusLabel(dynamic status) =>
      switch ('${status ?? ''}') {
        'completed' => 'Completed',
        'pending_verification' => 'Pending verification',
        'pending' => 'Pending',
        'open' || '' => 'Open',
        'cancelled' => 'Cancelled',
        final other => humanize(other),
      };

  @override
  Widget build(BuildContext context) => BusinessPage(
        title: 'Payments',
        subtitle:
            'Combined view of online (app) payments and offline POS bills',
        actions: [
          _PeriodPicker(
              value: _period, onChanged: (p) => setState(() => _period = p)),
        ],
        children: [
          ApiLoader<Map<String, dynamic>>(
            key: ValueKey('finance-payments-$_period-$_source'),
            load: _load,
            builder: (context, env, _) => _body(
                jsonList(env['data']), jsonMap(env['summary'])),
          ),
        ],
      );

  Widget _body(List<Map<String, dynamic>> rows, Map<String, dynamic> s) {
    final counts = jsonMap(s['counts']);
    int count(String k) => numOf(counts[k]).toInt();
    final period = _labelOf(_periods, _period).toLowerCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _kpis(columns: 5, <Widget>[
        _StatCard(
            label: 'Gross revenue',
            value: inr(s['gross']),
            caption: 'Completed POS payments + online orders, $period'),
        _StatCard(
            label: 'Online (app)',
            value: inr(s['online']),
            caption: 'Completed online orders'),
        _StatCard(
            label: 'Offline (POS)',
            value: inr(s['pos']),
            caption: 'Payments on paid POS bills'),
        _StatCard(
            label: 'Cash',
            value: inr(s['cash']),
            caption: 'Completed cash payments'),
        _StatCard(
            label: 'Pending',
            value: inr(s['pending']),
            dot: _orangeDot,
            caption: 'Bills awaiting payment + unpaid online orders'),
      ]),
      _ToolRow(
        left: _FilterTabs(
          keyPrefix: 'payments-source',
          labels: [
            'All (${count('all')})',
            'Online (${count('online')})',
            'POS (${count('pos')})',
          ],
          selected: math.max(0, _sources.indexOf(_source)),
          onSelect: (i) => setState(() => _source = _sources[i]),
        ),
        actions: [
          MasterButton(
            key: const Key('finance-payments-export'),
            label: 'Export CSV',
            icon: Icons.description_outlined,
            onPressed: () => _export(rows),
          ),
        ],
      ),
      if (rows.isEmpty)
        _emptyCard(
            Icons.receipt_long_outlined,
            'No payments in this period',
            'Payments on POS bills and online (app) orders appear here.')
      else
        MasterTable(
          minWidth: 900,
          columns: const [
            MasterColumn('Date', flex: 2),
            MasterColumn('Source'),
            MasterColumn('Reference', flex: 2),
            MasterColumn('Customer', flex: 2),
            MasterColumn('Method'),
            MasterColumn('Amount', flex: 2, alignEnd: true),
            MasterColumn('Status', flex: 2),
          ],
          rows: [
            for (final r in rows)
              [
                MasterCellText(fmtDateTime(r['created_at'])),
                r['source'] == 'online'
                    ? const StaffChip('Online',
                        color: ViniiColors.blueSolid, tint: ViniiColors.blueTint)
                    : const StaffChip('POS',
                        color: ViniiColors.textPrimaryLight, tint: _chipTint),
                MasterCellText(_paymentRef(r), bold: true),
                MasterCellText(_paymentCustomer(r)),
                MasterCellText(_labelOf(_methods, r['method'])),
                MasterCellText(inr(r['amount']), bold: true),
                StatusPill(textOf(r['status'], 'open'),
                    label: _paymentStatusLabel(r['status'])),
              ],
          ],
        ),
      const SizedBox(height: 10),
      Text(
          '${rows.length >= 500 ? 'Showing the latest 500. ' : ''}'
          'Online orders belong to the whole restaurant, so a branch login sees the POS bills of its branch only.',
          style: MasterStyle.muted),
    ]);
  }
}

// ── expenses ─────────────────────────────────────────────────────────────

typedef _ExpenseData = ({
  Map<String, dynamic> summary,
  List<Map<String, dynamic>> entries,
  List<Map<String, dynamic>> heads,
});

/// Expenses by head for a month, the expense entries, and the expense
/// master (heads with monthly budgets).
class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab(
      {required this.api, required this.canDelete, this.branches = const []});
  final ProviyaaApiClient api;
  final bool canDelete;
  final List<BranchLocation> branches;

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  String _month = _monthKey(DateTime.now());
  int _rev = 0;

  /// Active head names from the last load, for the "Add expense" dialog.
  List<String> _headNames = const [];

  static List<(String, String)> _monthOptions() {
    final now = DateTime.now();
    final out = <(String, String)>[];
    for (var i = 0; i < 12; i++) {
      final key = _monthKey(DateTime(now.year, now.month - i, 1));
      out.add((key, _monthName(key)));
    }
    return out;
  }

  Future<_ExpenseData> _load() async {
    final r = await Future.wait<dynamic>([
      widget.api.get('v1/finance/expenses/summary', query: {'month': _month}),
      widget.api.get('v1/finance/entries',
          query: {'kind': 'expense', 'limit': '500'}),
      widget.api.get('v1/finance/expense-heads', query: {'limit': '500'}),
    ]);
    final heads = jsonList(r[2]);
    _headNames = [
      for (final h in heads)
        if (h['active'] != false && textOf(h['name'], '').isNotEmpty)
          textOf(h['name'], ''),
    ];
    return (summary: jsonMap(r[0]), entries: jsonList(r[1]), heads: heads);
  }

  void _refresh() => setState(() => _rev++);

  Future<void> _write(Future<dynamic> Function() call, String success) async {
    final ok = await runAction(context, () async {
      await call();
      return true;
    }, success: success);
    if (ok == true && mounted) _refresh();
  }

  Future<void> _addExpense() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EntryDialog(
          api: widget.api,
          expense: true,
          heads: _headNames,
          branches: widget.branches),
    );
    if (saved != true || !mounted) return;
    showStaffNotice(context, 'Expense recorded');
    _refresh();
  }

  Future<void> _onEntry(Map<String, dynamic> e, String action) async {
    final changed = await _entryAction(context, widget.api, e, action);
    if (changed && mounted) _refresh();
  }

  static String? _validateHead(Map<String, String> v) {
    if ((v['name'] ?? '').isEmpty) return 'Give the head a name.';
    final budget = staffParseNum(v['budget'] ?? '');
    if (budget == null || budget < 0) {
      return 'The monthly budget must be zero or more.';
    }
    return null;
  }

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
    final name = v['name'] ?? '';
    await _write(
        () => widget.api.post('v1/finance/expense-heads', {
              'name': name,
              'monthly_budget': staffParseNum(v['budget'] ?? '') ?? 0,
            }),
        'Added $name');
  }

  Future<void> _headAction(Map<String, dynamic> h, String action) async {
    final id = '${h['id']}';
    final name = textOf(h['name']);
    if (action == 'Edit') {
      final v = await showStaffPrompt(
        context,
        title: 'Edit $name',
        subtitle:
            'Renaming does not change the category of expenses already recorded.',
        fields: [
          StaffPromptField('name', 'Name', initial: textOf(h['name'], '')),
          StaffPromptField('budget', 'Monthly budget',
              initial: staffNumText(numOf(h['monthly_budget'])),
              number: true,
              prefix: '₹ '),
        ],
        validate: _validateHead,
      );
      if (v == null || !mounted) return;
      await _write(
          () => widget.api.patch('v1/finance/expense-heads/$id', {
                'name': v['name'] ?? name,
                'monthly_budget': staffParseNum(v['budget'] ?? '') ?? 0,
              }),
          'Saved ${v['name'] ?? name}');
    } else if (action == 'Activate' || action == 'Deactivate') {
      final active = action == 'Activate';
      await _write(
          () => widget.api
              .patch('v1/finance/expense-heads/$id', {'active': active}),
          active ? '$name is active' : '$name deactivated');
    } else if (action == 'Delete') {
      final ok = await staffConfirm(context,
          title: 'Delete $name?',
          message:
              'The head and its budget are removed. Expenses already recorded keep their category.');
      if (!ok || !mounted) return;
      await _write(() => widget.api.delete('v1/finance/expense-heads/$id'),
          '$name deleted');
    }
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
        title: 'Expenses',
        subtitle:
            'Money out recorded as expenses, grouped by expense head against its monthly budget',
        actions: [
          SizedBox(
            width: 200,
            child: StaffSelect<String>(
              key: const Key('finance-expense-month'),
              value: _month,
              dense: true,
              items: _monthOptions(),
              onChanged: (m) {
                if (m != null) setState(() => _month = m);
              },
            ),
          ),
          MasterButton(
            key: const Key('finance-add-expense'),
            label: '+ Add expense',
            kind: MasterButtonKind.primary,
            onPressed: _addExpense,
          ),
        ],
        children: [
          ApiLoader<_ExpenseData>(
            key: ValueKey('finance-expenses-$_month-$_rev'),
            load: _load,
            builder: (context, d, _) => _body(d),
          ),
        ],
      );

  Widget _body(_ExpenseData d) {
    final s = d.summary;
    final byHead = jsonList(s['by_head']);
    final monthName = _monthName(_month);
    final entries = [
      for (final e in d.entries)
        if ('${e['entry_date'] ?? ''}'.startsWith(_month)) e,
    ];
    num pending = 0;
    for (final e in entries) {
      if (e['status'] == 'pending') pending += numOf(e['amount']);
    }
    num budget = 0;
    for (final h in d.heads) {
      if (h['active'] != false) budget += numOf(h['monthly_budget']);
    }
    final over = byHead
        .where((h) =>
            numOf(h['budget']) > 0 && numOf(h['spent']) > numOf(h['budget']))
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpiGrid(cards: [
        _StatCard(
            label: 'Spent in $monthName',
            value: inr(s['total']),
            caption: 'Approved expense entries'),
        _StatCard(
            label: 'Awaiting approval',
            value: inr(pending),
            dot: pending > 0 ? _orangeDot : null,
            caption: 'Pending expenses, not counted in the total'),
        _StatCard(
            label: 'Monthly budget',
            value: inr(budget),
            caption: 'Sum of the active heads\' budgets'),
        _StatCard(
            label: 'Over budget',
            value: '$over',
            dot: over > 0 ? ViniiColors.redSolid : null,
            valueColor:
                over > 0 ? ViniiColors.redSolid : ViniiColors.textPrimaryLight,
            caption: 'Heads that spent more than their budget'),
      ]),
      MasterSection(
        title: 'Spend by head',
        subtitle:
            'Approved expenses in $monthName by category. A budget applies when the category matches a head\'s name.',
        child: _byHeadTable(byHead),
      ),
      const SizedBox(height: 16),
      MasterSection(
        title: 'Expense entries (${entries.length})',
        subtitle:
            'Expenses dated in $monthName, every status. Pending ones count only once approved.',
        trailing: MasterButton(
          label: 'Export CSV',
          icon: Icons.description_outlined,
          onPressed: () => _copyEntriesCsv(context, 'expenses', entries,
              branches: widget.branches),
        ),
        child: _EntriesTable(
          rows: entries,
          canDelete: widget.canDelete,
          expenseView: true,
          branches: widget.branches,
          emptyTitle: 'No expenses in $monthName',
          emptyMessage: 'Use "+ Add expense" to record money spent.',
          onAction: _onEntry,
        ),
      ),
      if (d.entries.length >= 500)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'Only the latest 500 expense entries were read; older ones of this month may be missing from the list.',
              style: MasterStyle.muted),
        ),
      const SizedBox(height: 16),
      MasterSection(
        title: 'Expense heads',
        subtitle:
            'The expense master: categories of spending with a monthly budget.',
        trailing: MasterButton(
          key: const Key('finance-add-head'),
          label: '+ Add head',
          onPressed: _addHead,
        ),
        child: _headsTable(d.heads),
      ),
    ]);
  }

  Widget _byHeadTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const StaffEmptyState(
          icon: Icons.pie_chart_outline,
          title: 'No approved expenses this month',
          message:
              'Add an expense and it will be grouped by its category here.');
    }
    return MasterTable(
      minWidth: 680,
      columns: const [
        MasterColumn('Category', flex: 3),
        MasterColumn('Spent', flex: 2, alignEnd: true),
        MasterColumn('Entries', alignEnd: true),
        MasterColumn('Budget', flex: 2, alignEnd: true),
        MasterColumn('Budget used', flex: 3),
      ],
      rows: [
        for (final h in rows) _headCells(h),
      ],
    );
  }

  List<Widget> _headCells(Map<String, dynamic> h) {
    final spent = numOf(h['spent']);
    final budget = numOf(h['budget']);
    final over = budget > 0 && spent > budget;
    return [
      MasterCellText(textOf(h['category']), bold: true),
      MasterCellText(inr(spent)),
      MasterCellText('${numOf(h['entries']).toInt()}'),
      MasterCellText(budget > 0 ? inr(budget) : '—'),
      budget > 0
          ? MasterProgress(
              value: spent / budget,
              label: over ? 'Over budget' : 'Within budget',
              color: over ? ViniiColors.redSolid : ViniiColors.greenSolid,
            )
          : const MasterCellText('No budget set',
              color: ViniiColors.textMutedLight),
    ];
  }

  Widget _headsTable(List<Map<String, dynamic>> heads) {
    if (heads.isEmpty) {
      return const StaffEmptyState(
          icon: Icons.category_outlined,
          title: 'No expense heads yet',
          message:
              'Add heads like Rent, Salaries or Gas to budget and group your expenses.');
    }
    return MasterTable(
      minWidth: 600,
      columns: const [
        MasterColumn('Head', flex: 3),
        MasterColumn('Monthly budget', flex: 2, alignEnd: true),
        MasterColumn('Status', flex: 2),
        MasterColumn('Actions', flex: 3),
      ],
      rows: [
        for (final h in heads)
          [
            MasterCellText(textOf(h['name']), bold: true),
            MasterCellText(numOf(h['monthly_budget']) > 0
                ? inr(h['monthly_budget'])
                : 'No budget'),
            StatusPill(h['active'] == false ? 'inactive' : 'active',
                label: h['active'] == false ? 'Inactive' : 'Active'),
            MasterRowActions([
              'Edit',
              h['active'] == false ? 'Activate' : 'Deactivate',
              if (widget.canDelete) 'Delete',
            ], onTap: (a) => _headAction(h, a)),
          ],
      ],
    );
  }
}
