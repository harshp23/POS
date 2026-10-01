import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';
import 'crm_common.dart';
import 'marketing_screen.dart';

/// Customers & CRM → Feedback (guest ratings and your responses) and
/// Ideas (recommendations computed from the restaurant's own bills).

const _amber = Color(0xFFF59E0B);

class _Stars extends StatelessWidget {
  const _Stars(this.rating, {this.size = 18, this.onTap, this.keyPrefix});
  final int rating;
  final double size;
  final ValueChanged<int>? onTap;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          onTap == null
              ? Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size, color: _amber)
              : InkWell(
                  key: keyPrefix == null ? null : Key('$keyPrefix-$i'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onTap!(i),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: size,
                        color: _amber),
                  ),
                ),
      ]);
}

// ── feedback ───────────────────────────────────────────────────────────────

class CrmFeedbackTab extends StatefulWidget {
  const CrmFeedbackTab({super.key, required this.api});
  final ProviyaaApiClient api;

  @override
  State<CrmFeedbackTab> createState() => _CrmFeedbackTabState();
}

class _CrmFeedbackTabState extends State<CrmFeedbackTab> {
  static const _filters = [
    ('all', 'All'),
    ('new', 'New'),
    ('acknowledged', 'Acknowledged'),
    ('resolved', 'Resolved'),
  ];
  int _filter = 0;

  ProviyaaApiClient get api => widget.api;

  Future<void> _add(VoidCallback reload) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeedbackDialog(api: api),
    );
    if (saved == true && mounted) {
      showStaffNotice(context, 'Feedback recorded');
      reload();
    }
  }

  Future<void> _patch(Map<String, dynamic> f, Map<String, dynamic> patch,
      String success, VoidCallback reload) async {
    final done = await runAction<bool>(context, () async {
      await api.patch('v1/crm/feedback/${f['id']}', patch);
      return true;
    }, success: success);
    if (done == true && mounted) reload();
  }

  Future<void> _resolve(Map<String, dynamic> f, VoidCallback reload) async {
    final values = await showStaffPrompt(
      context,
      title: 'Resolve feedback',
      subtitle: 'From ${textOf(f['customer_name'], 'a guest')}',
      fields: [
        StaffPromptField('response', 'Your response',
            key: const Key('feedback-response'),
            initial: '${f['response'] ?? ''}',
            maxLines: 3,
            hint: 'What you did or told the guest'),
      ],
      confirmLabel: 'Resolve',
      confirmKey: const Key('feedback-resolve-confirm'),
      width: 520,
    );
    if (values == null || !mounted) return;
    await _patch(
        f,
        {'status': 'resolved', 'response': values['response'] ?? ''},
        'Feedback resolved',
        reload);
  }

  Future<void> _delete(Map<String, dynamic> f, VoidCallback reload) async {
    final ok = await staffConfirm(context,
        title: 'Delete this feedback?',
        message: 'It is removed from the list.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await api.delete('v1/crm/feedback/${f['id']}');
      return true;
    }, success: 'Feedback deleted');
    if (done == true && mounted) reload();
  }

  Widget _card(Map<String, dynamic> f, VoidCallback reload) {
    final rating = numOf(f['rating']).clamp(0, 5).toInt();
    final status = '${f['status'] ?? 'new'}';
    final comment = '${f['comment'] ?? ''}'.trim();
    final response = '${f['response'] ?? ''}'.trim();
    final ref = '${f['order_ref'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MasterCard(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Stars(rating),
                        Text(textOf(f['customer_name'], 'Guest'),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ViniiColors.textPrimaryLight)),
                        StatusPill(status),
                      ]),
                  const SizedBox(height: 4),
                  Text(
                      [
                        crmChannelLabel(f['channel']),
                        fmtDateTime(f['created_at']),
                        if (ref.isNotEmpty) 'Bill $ref',
                      ].join(' · '),
                      style: MasterStyle.muted),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment, style: MasterStyle.body),
                  ],
                  if (response.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ViniiColors.greenTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Your response: $response',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: ViniiColors.emeraldText)),
                    ),
                  ],
                ]),
          ),
          const SizedBox(width: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (status == 'new') ...[
              MasterButton(
                  key: Key('feedback-ack-${f['id']}'),
                  label: 'Acknowledge',
                  onPressed: () => _patch(f, {'status': 'acknowledged'},
                      'Feedback acknowledged', reload)),
              const SizedBox(width: 8),
            ],
            if (status != 'resolved') ...[
              MasterButton(
                  key: Key('feedback-resolve-${f['id']}'),
                  label: 'Resolve',
                  kind: MasterButtonKind.primary,
                  onPressed: () => _resolve(f, reload)),
              const SizedBox(width: 4),
            ],
            StaffIconAction(
                key: Key('feedback-delete-${f['id']}'),
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: ViniiColors.redSolid,
                onPressed: () => _delete(f, reload)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        load: () async => jsonList(
            await api.get('v1/crm/feedback', query: {'limit': '500'})),
        builder: (context, all, reload) {
          final key = _filters[_filter].$1;
          final rows = [
            for (final f in all)
              if (key == 'all' || f['status'] == key) f
          ];
          final rated = [
            for (final f in all)
              if (numOf(f['rating']) > 0) numOf(f['rating'])
          ];
          final average = rated.isEmpty
              ? null
              : rated.fold<num>(0, (s, r) => s + r) / rated.length;
          int count(String s) => all.where((f) => f['status'] == s).length;
          return BusinessPage(
            title: 'Customer Feedback',
            subtitle: 'Ratings and comments from guests, and how you '
                'responded.',
            actions: [
              MasterButton(
                  key: const Key('crm-add-feedback'),
                  label: 'Add feedback',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: () => _add(reload)),
            ],
            children: [
              KpiGrid(columns: 4, cards: [
                MasterStatCard(
                    label: 'AVERAGE RATING',
                    value: average == null
                        ? '—'
                        : '${average.toStringAsFixed(1)} ★',
                    caption: 'Across ${all.length} review'
                        '${all.length == 1 ? '' : 's'}'),
                MasterStatCard(
                    label: 'NEW',
                    value: '${count('new')}',
                    caption: 'Waiting for a reply'),
                MasterStatCard(
                    label: 'ACKNOWLEDGED',
                    value: '${count('acknowledged')}',
                    caption: 'Seen, not yet resolved'),
                MasterStatCard(
                    label: 'RESOLVED',
                    value: '${count('resolved')}',
                    caption: 'Closed with a response'),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StaffPills(
                  keyPrefix: 'feedback-filter',
                  options: [
                    for (final f in _filters)
                      f.$1 == 'all'
                          ? '${f.$2} (${all.length})'
                          : '${f.$2} (${count(f.$1)})',
                  ],
                  selected: _filter,
                  onSelect: (i) => setState(() => _filter = i),
                ),
              ),
              if (rows.isEmpty)
                MasterCard(
                  child: Center(
                    child: StaffEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: all.isEmpty
                          ? 'No feedback yet'
                          : 'Nothing ${_filters[_filter].$2.toLowerCase()}',
                      message: all.isEmpty
                          ? 'Record what guests tell you at the table, on the '
                              'phone or in reviews, and track your replies.'
                          : null,
                    ),
                  ),
                )
              else
                for (final f in rows) _card(f, reload),
            ],
          );
        },
      );
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

/// "Guest" in the customer picker: feedback from someone without a profile.
const _guest = '__guest__';

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _name = TextEditingController();
  final _comment = TextEditingController();
  final _orderRef = TextEditingController();
  int _rating = 0;
  String _channel = 'dine_in';
  bool _saving = false;
  String? _error;

  /// Saved customers (null while loading).
  List<Map<String, dynamic>>? _customers;
  String _search = '';
  String _customerId = _guest;

  /// The picked customer's recent bills (null while loading).
  List<Map<String, dynamic>>? _bills;
  String _bill = '';
  int _billsCall = 0;

  bool get _isGuest => _customerId == _guest;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    _orderRef.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = jsonList(await widget.api.get('v1/crm/customers'));
      if (mounted) setState(() => _customers = list);
    } catch (_) {
      // Feedback can still be recorded for a guest.
      if (mounted) setState(() => _customers = const []);
    }
  }

  void _pickCustomer(String? id) {
    final v = id ?? _guest;
    setState(() {
      _customerId = v;
      _bill = '';
      _bills = v == _guest ? const [] : null;
    });
    if (v != _guest) _loadBills(v);
  }

  Future<void> _loadBills(String id) async {
    final call = ++_billsCall;
    try {
      final c = jsonMap(await widget.api.get('v1/crm/customers/$id'));
      if (!mounted || call != _billsCall) return;
      setState(() => _bills = jsonList(c['recent_orders']));
    } catch (_) {
      if (!mounted || call != _billsCall) return;
      setState(() => _bills = const []);
    }
  }

  Map<String, dynamic>? get _customer => (_customers ?? const [])
      .where((c) => '${c['id']}' == _customerId)
      .firstOrNull;

  Future<void> _save() async {
    if (_rating < 1) {
      setState(() => _error = 'Pick a rating from 1 to 5 stars.');
      return;
    }
    final customer = _customer;
    final ref = customer == null ? _orderRef.text.trim() : _bill;
    final name = customer == null ? _name.text.trim() : crmName(customer);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/crm/feedback', {
        if (customer != null) 'customer_id': '${customer['id']}',
        'customer_name': name.isEmpty ? 'Guest' : name,
        'rating': _rating,
        'channel': _channel,
        'comment': _comment.text.trim(),
        if (ref.isNotEmpty) 'order_ref': ref,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  /// "#12 · 12 Sep 2026 · ₹540" for a recent bill.
  static String _billText(Map<String, dynamic> o) => [
        '#${textOf(o['number'], '—')}',
        fmtDate(o['created_at']),
        crmMoney(o['total']),
      ].join(' · ');

  Widget _billField() {
    if (_isGuest) {
      return StaffField(
        label: 'Bill number',
        child: TextField(
          key: const Key('feedback-order-ref'),
          controller: _orderRef,
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(hint: 'Optional'),
        ),
      );
    }
    final bills = _bills;
    final seen = <String>{};
    return StaffField(
      label: 'Bill',
      child: StaffSelect<String>(
        key: const Key('feedback-order-ref'),
        value: bills == null ? null : _bill,
        hint: bills == null ? 'Loading bills…' : 'Not linked to a bill',
        items: [
          ('', bills != null && bills.isEmpty
              ? 'No bills for this customer'
              : 'Not linked to a bill'),
          for (final o in bills ?? const <Map<String, dynamic>>[])
            if (textOf(o['number'], '').isNotEmpty &&
                seen.add(textOf(o['number'], '')))
              (textOf(o['number'], ''), _billText(o)),
        ],
        onChanged: bills == null ? null : (v) => setState(() => _bill = v ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;
    return StaffDialog(
        title: 'Add feedback',
        subtitle: 'Record what a guest told you.',
        width: 560,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.pop(context)),
          MasterButton(
              key: const Key('feedback-save'),
              label: _saving ? 'Saving…' : 'Save feedback',
              kind: MasterButtonKind.primary,
              onPressed: _saving ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            StaffField(
              label: 'Search customer',
              child: TextField(
                key: const Key('feedback-customer-search'),
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(hint: 'Name or phone'),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            StaffField(
              label: 'Customer',
              child: StaffSelect<String>(
                key: const Key('feedback-customer'),
                value: customers == null ? null : _customerId,
                hint: 'Loading customers…',
                items: [
                  (_guest, 'Guest (no profile)'),
                  ...crmCustomerItems(customers ?? const [], _search,
                      _isGuest ? null : _customerId),
                ],
                onChanged: customers == null ? null : _pickCustomer,
              ),
            ),
          ]),
          StaffFormRow(children: [
            if (_isGuest)
              StaffField(
                label: 'Guest name',
                child: TextField(
                  key: const Key('feedback-name'),
                  controller: _name,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput(hint: 'Optional'),
                ),
              )
            else
              _billField(),
            StaffField(
              label: 'Channel',
              child: StaffSelect<String>(
                key: const Key('feedback-channel'),
                value: _channel,
                items: const [
                  ('dine_in', 'Dine-in'),
                  ('takeaway', 'Takeaway'),
                  ('delivery', 'Delivery'),
                  ('qr', 'QR ordering'),
                  ('online', 'Online'),
                ],
                onChanged: (v) => setState(() => _channel = v ?? 'dine_in'),
              ),
            ),
          ]),
          StaffField(
            label: 'Rating',
            required: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Stars(_rating,
                  size: 28,
                  keyPrefix: 'feedback-star',
                  onTap: (v) => setState(() => _rating = v)),
            ),
          ),
          const SizedBox(height: 14),
          StaffFormRow(children: [
            StaffField(
              label: 'Comment',
              child: TextField(
                key: const Key('feedback-comment'),
                controller: _comment,
                minLines: 3,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(hint: 'What did the guest say?'),
              ),
            ),
          ]),
          if (_isGuest) StaffFormRow(children: [_billField()]),
        ]),
      );
  }
}

// ── ideas ──────────────────────────────────────────────────────────────────

class CrmIdeasTab extends StatelessWidget {
  const CrmIdeasTab({super.key, required this.api});
  final ProviyaaApiClient api;

  static String _kindLabel(String kind) => switch (kind) {
        'bundle' => 'Combo',
        'upsell' => 'Upsell',
        'channel' => 'Channel',
        _ => humanize(kind),
      };

  static IconData _icon(String kind) => switch (kind) {
        'bundle' => Icons.card_giftcard,
        'upsell' => Icons.trending_up,
        'channel' => Icons.sell_outlined,
        _ => Icons.lightbulb_outline,
      };

  Widget _ideaCard(BuildContext context, Map<String, dynamic> idea, int i) {
    final kind = '${idea['kind'] ?? ''}';
    final offer = jsonMap(idea['offer']);
    return MasterCard(
      padding: const EdgeInsets.all(18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_icon(kind), size: 18, color: ViniiColors.greenSolid),
              const SizedBox(width: 8),
              Expanded(
                child: Text(textOf(idea['title']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
              ),
              const SizedBox(width: 8),
              MasterStatusPill(_kindLabel(kind), tone: PillTone.gray),
            ]),
            const SizedBox(height: 10),
            Text(textOf(idea['detail'], ''),
                style: const TextStyle(
                    fontSize: 13, color: ViniiColors.textSecondaryLight)),
            const SizedBox(height: 14),
            Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(textOf(idea['metric'], ''),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  MasterButton(
                      key: Key('crm-idea-action-$i'),
                      label: textOf(idea['action'], 'Create offer'),
                      kind: MasterButtonKind.primary,
                      onPressed: () =>
                          showCreateOfferDialog(context, api, prefill: offer)),
                ]),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/crm/ideas')),
        builder: (context, d, reload) {
          final ideas = jsonList(d['ideas']);
          final items = jsonList(d['top_items']);
          return BusinessPage(
            title: 'Ideas & Recommendations',
            subtitle: 'Suggestions computed from your own POS bills.',
            badge: 'FROM YOUR SALES',
            children: [
              const InfoNote(
                  'These ideas are computed from this restaurant\'s own paid '
                  'bills and menu over the last 180 days. No external data '
                  'and no AI service is used.'),
              if (ideas.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: MasterCard(
                    child: Center(
                      child: StaffEmptyState(
                        icon: Icons.lightbulb_outline,
                        title: 'No ideas yet',
                        message: 'Ideas appear once there are enough paid '
                            'bills to compare items and channels.',
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: MasterGrid(columns: 3, minItemWidth: 280, children: [
                    for (var i = 0; i < ideas.length; i++)
                      _ideaCard(context, ideas[i], i),
                  ]),
                ),
              MasterSection(
                title: 'Top selling items (180 days)',
                subtitle: 'By quantity on paid bills',
                child: items.isEmpty
                    ? const Text('No paid bills in the last 180 days.',
                        style: MasterStyle.muted)
                    : Column(children: [
                        for (var i = 0; i < items.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: ViniiColors.lightPageBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: ViniiColors.brandGreen,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(textOf(items[i]['name']),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                  '${crmCount(items[i]['qty'])} sold · '
                                  '${crmCount(items[i]['bills'])} bills · '
                                  '${crmMoney(items[i]['revenue'])}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: ViniiColors.textSecondaryLight)),
                            ]),
                          ),
                      ]),
              ),
            ],
          );
        },
      );
}
