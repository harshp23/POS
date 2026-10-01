part of 'finance_screen.dart';

/// A summary block plus the rows of one list, loaded together.
typedef _Listed = ({
  Map<String, dynamic> summary,
  List<Map<String, dynamic>> rows,
});

const _settlementSources = <(String, String)>[
  ('zomato', 'Zomato'),
  ('swiggy', 'Swiggy'),
  ('online_orders', 'Online Orders'),
  ('pos_collections', 'POS Collections'),
  ('upi', 'UPI Payments'),
  ('card', 'Card Payments'),
  ('cash', 'Cash Collections'),
];

const _settlementMethods = <(String, String)>[
  ('bank_transfer', 'Bank Transfer'),
  ('bank_deposit', 'Bank Deposit'),
  ('upi', 'UPI'),
  ('cheque', 'Cheque'),
];

const _docTypes = <(String, String)>[
  ('tax', 'Tax'),
  ('food_safety', 'Food Safety'),
  ('business', 'Business'),
  ('safety', 'Safety'),
  ('liquor', 'Liquor'),
  ('environment', 'Environment'),
  ('other', 'Other'),
];

// ── settlements ──────────────────────────────────────────────────────────

/// Payouts from aggregators, online orders and collections
/// (v1/fianance/finance-settlements-panel.png).
class _SettlementsTab extends StatefulWidget {
  const _SettlementsTab(
      {required this.api, required this.canDelete, this.branches = const []});
  final ProviyaaApiClient api;
  final bool canDelete;
  final List<BranchLocation> branches;

  @override
  State<_SettlementsTab> createState() => _SettlementsTabState();
}

class _SettlementsTabState extends State<_SettlementsTab> {
  int _filter = 0;
  int _rev = 0;

  static const _statuses = ['', 'completed', 'pending', 'failed'];

  Future<_Listed> _load() async {
    final status = _statuses[_filter];
    final r = await Future.wait<dynamic>([
      widget.api.get('v1/finance/settlements-summary'),
      widget.api.get('v1/finance/settlements', query: {
        if (status.isNotEmpty) 'status': status,
        'limit': '500',
      }),
    ]);
    return (summary: jsonMap(r[0]), rows: jsonList(r[1]));
  }

  Future<void> _write(Future<dynamic> Function() call, String success) async {
    final ok = await runAction(context, () async {
      await call();
      return true;
    }, success: success);
    if (ok == true && mounted) setState(() => _rev++);
  }

  Future<void> _record() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SettlementDialog(api: widget.api, branches: widget.branches),
    );
    if (saved != true || !mounted) return;
    showStaffNotice(context, 'Settlement recorded');
    setState(() => _rev++);
  }

  Future<void> _act(Map<String, dynamic> r, String action) async {
    final id = '${r['id']}';
    final no = textOf(r['settlement_no'], 'this settlement');
    if (action == 'Mark completed') {
      final v = await showStaffPrompt(
        context,
        title: 'Mark $no completed',
        subtitle: 'The payout reached your bank. Add its bank reference.',
        fields: [
          StaffPromptField('utr', 'UTR / reference no.',
              initial: textOf(r['utr'], ''),
              key: const Key('settlement-utr'),
              hint: 'e.g. UTR9283746501'),
        ],
        confirmLabel: 'Mark completed',
        confirmKey: const Key('settlement-complete-confirm'),
      );
      if (v == null || !mounted) return;
      await _write(
          () => widget.api.patch('v1/finance/settlements/$id',
              {'status': 'completed', 'utr': v['utr'] ?? ''}),
          '$no marked completed');
    } else if (action == 'Mark failed') {
      final ok = await staffConfirm(context,
          title: 'Mark $no as failed?',
          message:
              'Use this when the payout did not arrive. You can still mark it completed later if it does.',
          confirmLabel: 'Mark failed');
      if (!ok || !mounted) return;
      await _write(
          () => widget.api
              .patch('v1/finance/settlements/$id', {'status': 'failed'}),
          '$no marked failed');
    } else if (action == 'Delete') {
      final ok = await staffConfirm(context,
          title: 'Delete $no?',
          message:
              'The ${inr(r['amount'])} settlement will be removed from the list and the totals.');
      if (!ok || !mounted) return;
      await _write(() => widget.api.delete('v1/finance/settlements/$id'),
          '$no deleted');
    }
  }

  Future<void> _export(List<Map<String, dynamic>> rows) {
    final withBranch = hasManyBranches(widget.branches);
    return _copyCsv(
      context,
      'settlements',
      [
        'Date',
        'Settlement ID',
        'Source',
        'Amount',
        'UTR',
        'Method',
        'Status',
        'Expected on',
        'Settled at',
        if (withBranch) 'Branch',
        'Note',
      ],
      [
        for (final r in rows)
          [
            fmtDateTime(r['created_at']),
            textOf(r['settlement_no'], ''),
            _labelOf(_settlementSources, r['source']),
            numOf(r['amount']),
            textOf(r['utr'], ''),
            _labelOf(_settlementMethods, r['method']),
            humanize(r['status']),
            r['expected_on'] == null ? '' : fmtDate(r['expected_on']),
            r['settled_at'] == null ? '' : fmtDateTime(r['settled_at']),
            if (withBranch) branchLabel(widget.branches, r['location_id']),
            textOf(r['note'], ''),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
        title: 'Settlements',
        subtitle:
            'Payouts you expect from Zomato, Swiggy, online orders and collections, and what reached your bank',
        children: [
          ApiLoader<_Listed>(
            key: ValueKey('finance-settlements-$_filter-$_rev'),
            load: _load,
            builder: (context, d, _) => _body(d),
          ),
        ],
      );

  Widget _body(_Listed d) {
    final s = d.summary;
    final counts = jsonMap(s['counts']);
    int count(String k) => numOf(counts[k]).toInt();
    final last = s['last'] is Map ? jsonMap(s['last']) : null;
    final next = s['next'] is Map ? jsonMap(s['next']) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpiGrid(cards: [
        _StatCard(
            label: 'Total settled',
            value: inr(s['total_settled']),
            caption: 'Completed settlements, all time'),
        _StatCard(
            label: 'Pending settlement',
            value: inr(s['pending_amount']),
            dot: _orangeDot,
            caption: '${count('pending')} payout(s) not received yet'),
        _StatCard(
            label: 'Last settlement',
            value: last == null ? '—' : inr(last['amount']),
            caption: last == null
                ? 'No completed settlement yet'
                : 'Transferred on ${fmtDate(last['settled_at'])}'),
        _StatCard(
            label: 'Next expected',
            value: next == null ? '—' : inr(next['amount']),
            caption: next == null
                ? 'Nothing pending'
                : (next['expected_on'] == null
                    ? 'No expected date recorded'
                    : 'Est. payout by ${fmtDate(next['expected_on'])}')),
      ]),
      _ToolRow(
        left: _FilterTabs(
          keyPrefix: 'settlement-filter',
          labels: [
            'All (${count('all')})',
            'Completed (${count('completed')})',
            'Pending (${count('pending')})',
            'Failed (${count('failed')})',
          ],
          selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
        ),
        actions: [
          MasterButton(
            label: 'Export CSV',
            icon: Icons.description_outlined,
            onPressed: () => _export(d.rows),
          ),
          MasterButton(
            key: const Key('finance-record-settlement'),
            label: 'Record settlement',
            kind: MasterButtonKind.primary,
            onPressed: _record,
          ),
        ],
      ),
      if (d.rows.isEmpty)
        _emptyCard(Icons.account_balance_outlined, 'No settlements here',
            'Record a payout you expect or have received to track it.')
      else
        MasterTable(
          minWidth: hasManyBranches(widget.branches) ? 1260.0 : 1120.0,
          columns: [
            const MasterColumn('Date', flex: 2),
            const MasterColumn('Settlement ID', flex: 2),
            const MasterColumn('Source', flex: 2),
            if (hasManyBranches(widget.branches))
              const MasterColumn('Branch', flex: 2),
            const MasterColumn('Amount', flex: 2, alignEnd: true),
            const MasterColumn('UTR no.', flex: 2),
            const MasterColumn('Method', flex: 2),
            const MasterColumn('Status', flex: 2),
            const MasterColumn('Actions', flex: 3),
          ],
          rows: [for (final r in d.rows) _cells(r)],
        ),
    ]);
  }

  List<Widget> _cells(Map<String, dynamic> r) {
    final status = textOf(r['status'], 'pending');
    final actions = <String>[
      if (status == 'pending' || status == 'failed') 'Mark completed',
      if (status == 'pending') 'Mark failed',
      if (widget.canDelete) 'Delete',
    ];
    String? when;
    if (status == 'completed' && r['settled_at'] != null) {
      when = 'Settled ${fmtDate(r['settled_at'])}';
    } else if (r['expected_on'] != null) {
      when = 'Expected ${fmtDate(r['expected_on'])}';
    }
    return [
      MasterCellTitle(fmtDateTime(r['created_at']), subtitle: when),
      MasterCellText(textOf(r['settlement_no']), bold: true),
      StaffChip(_labelOf(_settlementSources, r['source']),
          color: ViniiColors.textPrimaryLight, tint: _chipTint),
      if (hasManyBranches(widget.branches))
        MasterCellText(branchLabel(widget.branches, r['location_id'])),
      MasterCellText(inr(r['amount']), bold: true),
      MasterCellText(textOf(r['utr'])),
      MasterCellText(_labelOf(_settlementMethods, r['method'])),
      StatusPill(status),
      actions.isEmpty
          ? const MasterCellText('—', color: ViniiColors.textMutedLight)
          : MasterRowActions(actions, onTap: (a) => _act(r, a)),
    ];
  }
}

/// "Record settlement": POST /v1/finance/settlements.
class _SettlementDialog extends StatefulWidget {
  const _SettlementDialog({required this.api, this.branches = const []});
  final ProviyaaApiClient api;
  final List<BranchLocation> branches;

  @override
  State<_SettlementDialog> createState() => _SettlementDialogState();
}

class _SettlementDialogState extends State<_SettlementDialog> {
  String _source = 'zomato';
  String _method = 'bank_transfer';
  String _status = 'pending';
  DateTime? _expected;
  late String? _branch = defaultBranchId(widget.branches);
  final _amount = TextEditingController();
  final _utr = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _utr.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = staffParseNum(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter the amount as a number, e.g. 12800.');
      return;
    }
    final expected = _expected;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/finance/settlements', {
        'source': _source,
        'amount': amount,
        'method': _method,
        'utr': _utr.text.trim(),
        'status': _status,
        'note': _note.text.trim(),
        if (expected != null) 'expected_on': isoDay(expected),
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

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Record settlement',
        subtitle: 'A payout you expect, or one that reached your bank',
        width: 620,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
            key: const Key('settlement-save'),
            label: _saving ? 'Saving…' : 'Save',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save,
          ),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            StaffField(
              label: 'Source',
              child: StaffSelect<String>(
                key: const Key('settlement-source'),
                value: _source,
                items: _settlementSources,
                onChanged: (v) => setState(() => _source = v ?? _source),
              ),
            ),
            BizTextField(
              key: const Key('settlement-amount'),
              label: 'Amount',
              controller: _amount,
              number: true,
              prefix: '₹ ',
              required: true,
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Method',
              child: StaffSelect<String>(
                value: _method,
                items: _settlementMethods,
                onChanged: (v) => setState(() => _method = v ?? _method),
              ),
            ),
            BizTextField(
                label: 'UTR no.',
                controller: _utr,
                hint: 'Bank reference, when received'),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Status',
              child: StaffSelect<String>(
                key: const Key('settlement-status'),
                value: _status,
                items: const [
                  ('pending', 'Pending (expected)'),
                  ('completed', 'Completed (received)'),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ),
            StaffField(
              label: 'Expected payout date',
              child: _OptionalDate(
                value: _expected,
                emptyLabel: 'Not known',
                onChanged: (d) => setState(() => _expected = d),
              ),
            ),
          ]),
          if (hasManyBranches(widget.branches))
            StaffFormRow(children: [
              BizBranchSelect(
                selectKey: const Key('settlement-branch'),
                branches: widget.branches,
                value: _branch,
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox.shrink(),
            ]),
          BizTextField(label: 'Note', controller: _note, maxLines: 2),
          const SizedBox(height: 14),
          const InfoNote(
              'Proviyaa does not request payouts from Zomato, Swiggy or your bank: this records a payout so you can '
              'track it. A completed Zomato, Swiggy or online-orders settlement adds to the bank balance on the dashboard.'),
        ]),
      );
}

// ── documents ────────────────────────────────────────────────────────────

/// Expiry status of a document on [today]: label, tone, and a hint such as
/// "34 days left".
(String, PillTone, String?) _docStatus(
    Map<String, dynamic> d, DateTime today) {
  final exp = DateTime.tryParse('${d['expiry_date'] ?? ''}');
  if (exp == null) return ('ACTIVE', PillTone.green, 'No expiry date');
  final days = DateTime.utc(exp.year, exp.month, exp.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days < 0) {
    return ('EXPIRED', PillTone.red, '${-days} day(s) ago');
  }
  if (days <= 90) {
    return (
      'EXPIRING SOON',
      PillTone.amber,
      days == 0 ? 'Expires today' : '$days day(s) left'
    );
  }
  return ('ACTIVE', PillTone.green, null);
}

/// Licences and compliance certificates
/// (v1/fianance/finance-documents-panel.png).
class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab(
      {required this.api, required this.canDelete, this.branches = const []});
  final ProviyaaApiClient api;
  final bool canDelete;
  final List<BranchLocation> branches;

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  int _filter = 0;
  int _rev = 0;

  Future<_Listed> _load() async {
    final r = await Future.wait<dynamic>([
      widget.api.get('v1/finance/documents-summary'),
      widget.api.get('v1/finance/documents', query: {
        if (_filter == 1) 'review_status': 'pending',
        'limit': '500',
      }),
    ]);
    return (summary: jsonMap(r[0]), rows: jsonList(r[1]));
  }

  Future<void> _edit([Map<String, dynamic>? doc]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DocumentDialog(
          api: widget.api, existing: doc, branches: widget.branches),
    );
    if (saved != true || !mounted) return;
    showStaffNotice(
        context, doc == null ? 'Document added' : 'Document saved');
    setState(() => _rev++);
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final name = textOf(doc['name']);
    final ok = await staffConfirm(context,
        title: 'Delete $name?',
        message: 'The document record will be removed from the list.');
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await widget.api.delete('v1/finance/documents/${doc['id']}');
      return true;
    }, success: '$name deleted');
    if (done == true && mounted) setState(() => _rev++);
  }

  Future<void> _view(Map<String, dynamic> doc, DateTime today) {
    final (label, tone, hint) = _docStatus(doc, today);
    final url = textOf(doc['file_url'], '');
    final note = textOf(doc['note'], '');
    return showDialog<void>(
      context: context,
      builder: (context) => StaffDialog(
        title: textOf(doc['name']),
        subtitle: _labelOf(_docTypes, doc['doc_type']),
        width: 580,
        actions: [
          if (url.isNotEmpty)
            MasterButton(
              label: 'Copy file link',
              icon: Icons.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                showStaffNotice(context, 'File link copied');
              },
            ),
          MasterButton(
              label: 'Close',
              kind: MasterButtonKind.primary,
              onPressed: () => Navigator.pop(context)),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 28, runSpacing: 14, children: [
            MasterKeyValue('Document no.', textOf(doc['doc_no'])),
            MasterKeyValue('Type', _labelOf(_docTypes, doc['doc_type'])),
            MasterKeyValue('Issue date', fmtDate(doc['issue_date'])),
            MasterKeyValue('Expiry date', fmtDate(doc['expiry_date'])),
            MasterKeyValue('Review',
                doc['review_status'] == 'pending' ? 'Pending review' : 'Verified'),
            if (hasManyBranches(widget.branches))
              MasterKeyValue(
                  'Branch', branchLabel(widget.branches, doc['location_id'])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            MasterStatusPill(label, tone: tone),
            if (hint != null) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(hint, style: MasterStyle.muted)),
            ],
          ]),
          const SizedBox(height: 18),
          const Text('File', style: MasterStyle.label),
          const SizedBox(height: 4),
          url.isEmpty
              ? const Text('No file link saved for this document.',
                  style: MasterStyle.muted)
              : SelectableText(url, style: MasterStyle.link),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Note', style: MasterStyle.label),
            const SizedBox(height: 4),
            Text(note, style: MasterStyle.body),
          ],
        ]),
      ),
    );
  }

  Future<void> _export(List<Map<String, dynamic>> rows, DateTime today) =>
      _copyCsv(
        context,
        'documents',
        const [
          'Document name',
          'Type',
          'Document no.',
          'Issue date',
          'Expiry date',
          'Status',
          'Review',
          'File URL',
        ],
        [
          for (final d in rows)
            [
              textOf(d['name'], ''),
              _labelOf(_docTypes, d['doc_type']),
              textOf(d['doc_no'], ''),
              d['issue_date'] == null ? '' : fmtDate(d['issue_date']),
              d['expiry_date'] == null ? '' : fmtDate(d['expiry_date']),
              _docStatus(d, today).$1,
              d['review_status'] == 'pending' ? 'Pending review' : 'Verified',
              textOf(d['file_url'], ''),
            ],
        ],
      );

  @override
  Widget build(BuildContext context) => BusinessPage(
        title: 'Documents',
        subtitle:
            'Licences and compliance certificates, with their expiry dates',
        children: [
          ApiLoader<_Listed>(
            key: ValueKey('finance-documents-$_filter-$_rev'),
            load: _load,
            builder: (context, d, _) => _body(d),
          ),
        ],
      );

  Widget _body(_Listed d) {
    final s = d.summary;
    final today = DateTime.tryParse('${s['today'] ?? ''}') ?? staffToday();
    int count(String k) => numOf(s[k]).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpiGrid(cards: [
        _StatCard(
            label: 'Total documents',
            value: '${count('total')}',
            caption: 'All registered business files'),
        _StatCard(
            label: 'Active status',
            value: '${count('active')}',
            dot: ViniiColors.greenSolid,
            caption: 'No expiry, or valid for more than 90 days'),
        _StatCard(
            label: 'Expiring soon',
            value: '${count('expiring_soon')}',
            dot: _orangeDot,
            caption: 'Action required under 90 days'),
        _StatCard(
            label: 'Expired documents',
            value: '${count('expired')}',
            dot: ViniiColors.redSolid,
            caption: 'Needs immediate renewal'),
      ]),
      _ToolRow(
        left: _FilterTabs(
          keyPrefix: 'document-filter',
          labels: [
            'All Compliance Docs (${count('total')})',
            'Pending Review (${count('pending_review')})',
          ],
          selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
        ),
        actions: [
          MasterButton(
            label: 'Export List',
            icon: Icons.description_outlined,
            onPressed: () => _export(d.rows, today),
          ),
          MasterButton(
            key: const Key('finance-add-document'),
            label: '+ Add Document',
            kind: MasterButtonKind.primary,
            onPressed: () => _edit(),
          ),
        ],
      ),
      if (d.rows.isEmpty)
        _emptyCard(
            Icons.folder_open_outlined,
            _filter == 1 ? 'Nothing waiting for review' : 'No documents yet',
            'Add your GST, FSSAI, trade and fire-safety certificates to track their expiry.')
      else
        MasterTable(
          minWidth: 1060,
          columns: const [
            MasterColumn('Document name', flex: 3),
            MasterColumn('Type', flex: 2),
            MasterColumn('Document no.', flex: 2),
            MasterColumn('Issue date', flex: 2),
            MasterColumn('Expiry date', flex: 2),
            MasterColumn('Status', flex: 2),
            MasterColumn('Actions', flex: 2),
          ],
          rows: [for (final doc in d.rows) _cells(doc, today)],
        ),
    ]);
  }

  List<Widget> _cells(Map<String, dynamic> doc, DateTime today) {
    final (label, tone, hint) = _docStatus(doc, today);
    final pendingReview = doc['review_status'] == 'pending';
    final subtitle = [
      if (hasManyBranches(widget.branches))
        branchLabel(widget.branches, doc['location_id']),
      if (pendingReview) 'Pending review',
    ].join(' · ');
    return [
      MasterCellTitle(textOf(doc['name']),
          subtitle: subtitle.isEmpty ? null : subtitle),
      StaffChip(_labelOf(_docTypes, doc['doc_type']),
          color: ViniiColors.textPrimaryLight, tint: _chipTint),
      MasterCellText(textOf(doc['doc_no']), bold: true),
      MasterCellText(fmtDate(doc['issue_date'])),
      MasterCellText(fmtDate(doc['expiry_date'])),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MasterStatusPill(label, tone: tone),
          if (hint != null && tone != PillTone.green) ...[
            const SizedBox(height: 3),
            Text(hint, style: MasterStyle.muted),
          ],
        ],
      ),
      MasterRowActions([
        'View',
        'Edit',
        if (widget.canDelete) 'Delete',
      ], onTap: (a) {
        if (a == 'View') {
          _view(doc, today);
        } else if (a == 'Edit') {
          _edit(doc);
        } else if (a == 'Delete') {
          _delete(doc);
        }
      }),
    ];
  }
}

/// "+ Add Document" / "Edit": POST or PATCH /v1/finance/documents.
class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog(
      {required this.api, this.existing, this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final List<BranchLocation> branches;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late final Map<String, dynamic> _e =
      widget.existing ?? const <String, dynamic>{};
  late final _name = TextEditingController(text: textOf(_e['name'], ''));
  late final _docNo = TextEditingController(text: textOf(_e['doc_no'], ''));
  late final _fileUrl =
      TextEditingController(text: textOf(_e['file_url'], ''));
  late final _note = TextEditingController(text: textOf(_e['note'], ''));
  late String _type = textOf(_e['doc_type'], 'business');
  late String _review = textOf(_e['review_status'], 'verified');
  late DateTime? _issue = DateTime.tryParse('${_e['issue_date'] ?? ''}');
  late DateTime? _expiry = DateTime.tryParse('${_e['expiry_date'] ?? ''}');
  late String? _branch = widget.existing == null
      ? defaultBranchId(widget.branches)
      : (textOf(_e['location_id'], '').isEmpty
          ? null
          : textOf(_e['location_id'], ''));
  String? _error;
  bool _saving = false;

  /// A new document of a one-branch restaurant belongs to that branch; with
  /// several branches the picker decides.
  bool get _sendBranch =>
      hasManyBranches(widget.branches) ||
      (widget.existing == null && widget.branches.length == 1);

  @override
  void dispose() {
    _name.dispose();
    _docNo.dispose();
    _fileUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final issue = _issue;
    final expiry = _expiry;
    if (name.isEmpty) {
      setState(() => _error = 'Give the document a name.');
      return;
    }
    if (issue != null && expiry != null && expiry.isBefore(issue)) {
      setState(() => _error = 'The expiry date is before the issue date.');
      return;
    }
    final url = _fileUrl.text.trim();
    final body = <String, Object?>{
      'name': name,
      'doc_type': _type,
      'doc_no': _docNo.text.trim(),
      'issue_date': issue == null ? null : isoDay(issue),
      'expiry_date': expiry == null ? null : isoDay(expiry),
      'file_url': url.isEmpty ? null : url,
      'review_status': _review,
      'note': _note.text.trim(),
      if (_sendBranch) 'location_id': _branch,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.existing?['id'];
      if (id == null) {
        await widget.api.post('v1/finance/documents', body);
      } else {
        await widget.api.patch('v1/finance/documents/$id', body);
      }
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

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: widget.existing == null ? 'Add document' : 'Edit document',
        subtitle: 'A licence or certificate, with its expiry date',
        width: 620,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
            key: const Key('document-save'),
            label: _saving ? 'Saving…' : 'Save',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save,
          ),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            BizTextField(
              key: const Key('document-name'),
              label: 'Document name',
              controller: _name,
              required: true,
              hint: 'e.g. FSSAI Food License',
            ),
            StaffField(
              label: 'Type',
              child: StaffSelect<String>(
                key: const Key('document-type'),
                value: _type,
                items: _docTypes,
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ),
          ]),
          StaffFormRow(children: [
            BizTextField(
              key: const Key('document-no'),
              label: 'Document no.',
              controller: _docNo,
              hint: 'Licence or registration number',
            ),
            StaffField(
              label: 'Review status',
              child: StaffSelect<String>(
                value: _review,
                items: const [
                  ('verified', 'Verified'),
                  ('pending', 'Pending review'),
                ],
                onChanged: (v) => setState(() => _review = v ?? _review),
              ),
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Issue date',
              child: _OptionalDate(
                value: _issue,
                onChanged: (d) => setState(() => _issue = d),
              ),
            ),
            StaffField(
              label: 'Expiry date',
              child: _OptionalDate(
                key: const Key('document-expiry'),
                value: _expiry,
                emptyLabel: 'Does not expire',
                onChanged: (d) => setState(() => _expiry = d),
              ),
            ),
          ]),
          if (hasManyBranches(widget.branches))
            StaffFormRow(children: [
              BizBranchSelect(
                selectKey: const Key('document-branch'),
                branches: widget.branches,
                value: _branch,
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox.shrink(),
            ]),
          BizTextField(
            label: 'File URL',
            controller: _fileUrl,
            hint: 'Link to the scanned copy (Drive, Dropbox…)',
          ),
          const SizedBox(height: 14),
          BizTextField(label: 'Note', controller: _note, maxLines: 2),
        ]),
      );
}
