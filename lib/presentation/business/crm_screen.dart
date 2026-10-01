import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api/api_client.dart';
import '../../data/csv.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';
import 'crm_common.dart';
import 'crm_insights.dart';
import 'crm_rewards.dart';
import 'crm_segments.dart';
import 'marketing_screen.dart';

/// Customers & CRM (/v1/crm): one customer profile across POS, QR and
/// online orders (bills are linked by phone), segments, loyalty points,
/// the store-credit wallet, feedback and ideas computed from the
/// restaurant's own sales. Every figure comes from the server.

enum CrmTab { dashboard, customers, segments, loyalty, wallet, feedback, ideas }

class CrmScreen extends StatefulWidget {
  const CrmScreen(
      {super.key,
      required this.api,
      this.initialTab = CrmTab.dashboard,
      this.branches = const []});
  final ProviyaaApiClient api;
  final CrmTab initialTab;

  /// The restaurant's branches: a customer's home branch is picked from
  /// them (the picker shows when there is more than one).
  final List<BranchLocation> branches;

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  static const _labels = [
    'Dashboard',
    'Customers',
    'Segments',
    'Loyalty',
    'Wallet',
    'Feedback',
    'Ideas',
  ];
  late CrmTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(covariant CrmScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  void _go(CrmTab tab) => setState(() => _tab = tab);

  Widget _body() => switch (_tab) {
        CrmTab.dashboard => _CrmDashboard(
            api: widget.api, onOpen: _go, branches: widget.branches),
        CrmTab.customers =>
          _CustomersTab(api: widget.api, branches: widget.branches),
        CrmTab.segments => CrmSegmentsTab(api: widget.api),
        CrmTab.loyalty => CrmLoyaltyTab(api: widget.api),
        CrmTab.wallet => CrmWalletTab(api: widget.api),
        CrmTab.feedback => CrmFeedbackTab(api: widget.api),
        CrmTab.ideas => CrmIdeasTab(api: widget.api),
      };

  @override
  Widget build(BuildContext context) => Material(
        color: ViniiColors.lightPageBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTabBar(
            tabs: _labels,
            selected: _tab.index,
            onSelect: (i) => _go(CrmTab.values[i]),
            keyPrefix: 'crm-tab',
          ),
          Expanded(child: KeyedSubtree(key: ValueKey(_tab), child: _body())),
        ]),
      );
}

// ── dashboard ──────────────────────────────────────────────────────────────

class _CrmDashboard extends StatelessWidget {
  const _CrmDashboard(
      {required this.api, required this.onOpen, this.branches = const []});
  final ProviyaaApiClient api;
  final ValueChanged<CrmTab> onOpen;
  final List<BranchLocation> branches;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/crm/dashboard')),
        builder: (context, d, reload) {
          Future<void> addCustomer() async {
            if (await showCrmCustomerEditor(context, api, branches: branches) &&
                context.mounted) {
              reload();
            }
          }

          Future<void> importList() async {
            if (await showCrmCustomerImport(context, api) && context.mounted) {
              reload();
            }
          }

          Future<void> createCampaign() async {
            await showCampaignBuilder(context, api);
          }

          Future<void> createOffer() async {
            await showCreateOfferDialog(context, api);
          }

          final profiles = numOf(d['profiles']).toInt();
          final total = d['total_customers'];
          final top = jsonList(d['top_customers']);
          final winBack = jsonList(d['win_back']);
          final mix = jsonList(d['channel_mix']);
          return BusinessPage(
            title: 'Customer CRM & Loyalty',
            subtitle: 'One profile across POS, QR ordering and online orders.',
            badge: '$profiles PROFILE${profiles == 1 ? '' : 'S'}',
            actions: [
              MasterButton(
                  key: const Key('crm-add-customer'),
                  label: 'Add customer',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: addCustomer),
              MasterButton(
                  key: const Key('crm-import'),
                  label: 'Import',
                  icon: Icons.download_outlined,
                  onPressed: importList),
            ],
            children: [
              KpiGrid(columns: 5, cards: [
                MasterStatCard(
                    label: 'LIFETIME REVENUE TRACKED',
                    value: crmMoney(d['lifetime_revenue']),
                    valueColor: ViniiColors.emeraldText,
                    caption: 'Paid bills of saved customers'),
                MasterStatCard(
                    label: 'CUSTOMER LIFETIME VALUE',
                    value: crmMoney(d['customer_lifetime_value']),
                    caption: 'Avg spent per paying customer'),
                MasterStatCard(
                    label: 'AVERAGE SPENT / BILL',
                    value: crmMoney(d['average_bill']),
                    caption: 'Across all channels'),
                MasterStatCard(
                    label: 'REPEAT RATE',
                    value: crmPct(d['repeat_rate']),
                    caption: 'Paying customers with 2+ orders'),
                MasterStatCard(
                    label: 'CHURN RATE (30D)',
                    value: crmPct(d['churn_rate_30d']),
                    caption: "Paying customers who haven't ordered"),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: MasterCard(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('QUICK ACTIONS:', style: MasterStyle.label),
                      MasterButton(
                          key: const Key('crm-quick-add-customer'),
                          label: 'Add customer',
                          icon: Icons.add,
                          kind: MasterButtonKind.primary,
                          onPressed: addCustomer),
                      MasterButton(
                          key: const Key('crm-quick-import'),
                          label: 'Import list',
                          icon: Icons.download_outlined,
                          onPressed: importList),
                      MasterButton(
                          key: const Key('crm-quick-campaign'),
                          label: 'Create campaign',
                          icon: Icons.send_outlined,
                          onPressed: createCampaign),
                      MasterButton(
                          key: const Key('crm-quick-offer'),
                          label: 'Create offer',
                          icon: Icons.card_giftcard,
                          onPressed: createOffer),
                    ],
                  ),
                ),
              ),
              KpiGrid(columns: 4, cards: [
                MasterStatCard(
                    label: 'TOTAL CUSTOMERS',
                    value: crmCount(total),
                    caption:
                        '${crmCount(d['added_30d'])} added in last 30 days'),
                MasterStatCard(
                    label: 'REPEAT CUSTOMERS',
                    value: crmCount(d['repeat_customers']),
                    caption:
                        '${crmShare(d['repeat_customers'], total)} of total base'),
                MasterStatCard(
                    label: 'VIP CUSTOMERS',
                    value: crmCount(d['vip_customers']),
                    caption: 'Lifetime spend ₹15k+'),
                MasterStatCard(
                    label: 'AT RISK (90D+)',
                    value: crmCount(d['at_risk_90d']),
                    caption: '${crmShare(d['at_risk_90d'], total)} gone quiet'),
                MasterStatCard(
                    label: 'NEW (30 DAYS)',
                    value: crmCount(d['added_30d']),
                    caption: 'Profiles created in 30 days'),
                MasterStatCard(
                    label: 'LOYALTY MEMBERS',
                    value: crmCount(d['loyalty_members']),
                    caption:
                        '${crmShare(d['loyalty_members'], total)} enrolled'),
                MasterStatCard(
                    label: 'WALLET FLOAT',
                    value: crmMoney(d['wallet_float']),
                    caption: 'Total customer credit'),
                MasterStatCard(
                    label: 'BIRTHDAYS THIS MONTH',
                    value: crmCount(d['birthdays_this_month']),
                    caption: 'Send a treat'),
              ]),
              MasterGrid(columns: 2, minItemWidth: 380, children: [
                MasterSection(
                  title: 'Top customers',
                  subtitle: 'Highest lifetime spend',
                  trailing: MasterButton(
                      label: 'View all',
                      kind: MasterButtonKind.text,
                      onPressed: () => onOpen(CrmTab.customers)),
                  child: top.isEmpty
                      ? const StaffEmptyState(
                          icon: Icons.emoji_events_outlined,
                          title: 'No paying customers yet',
                          message: 'Customers appear here once their bills '
                              'are paid. Bills are matched to profiles by '
                              'phone number.',
                        )
                      : Column(children: [
                          for (final c in top)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CrmCustomerLine(
                                name: crmName(c),
                                tier: '${c['tier'] ?? ''}',
                                caption: '${crmCount(c['orders'])} order'
                                    '${numOf(c['orders']) == 1 ? '' : 's'} · '
                                    '${textOf(c['phone'])}',
                                trailing: crmMoney(c['spent']),
                                onTap: () => showCrmCustomerDetail(
                                    context, api, '${c['id']}'),
                              ),
                            ),
                        ]),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  MasterSection(
                    title: 'Win-back list',
                    subtitle: 'Repeat customers with no order in 45+ days',
                    child: winBack.isEmpty
                        ? const StaffEmptyState(
                            icon: Icons.sentiment_satisfied_alt_outlined,
                            title: 'Nobody is slipping away',
                            message: 'Every repeat customer has ordered in '
                                'the last 45 days.',
                          )
                        : Column(children: [
                            for (final c in winBack)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CrmCustomerLine(
                                  name: crmName(c),
                                  tier: '${c['tier'] ?? ''}',
                                  caption:
                                      'Last order ${fmtDate(c['last_order_at'])} · '
                                      '${textOf(c['phone'])}',
                                  trailing: crmMoney(c['spent']),
                                  onTap: () => showCrmCustomerDetail(
                                      context, api, '${c['id']}'),
                                ),
                              ),
                          ]),
                  ),
                  const SizedBox(height: 16),
                  MasterSection(
                    title: 'Channel mix (last 180 days)',
                    child: mix.isEmpty
                        ? const Text('No paid bills in the last 180 days.',
                            style: MasterStyle.muted)
                        : Column(children: [
                            for (final m in mix)
                              ShareBar(
                                label: crmChannelLabel(m['channel']),
                                value: '${crmMoney(m['amount'])} '
                                    '(${numOf(m['share']).round()}%)',
                                share: numOf(m['share']) / 100,
                              ),
                          ]),
                  ),
                ]),
              ]),
            ],
          );
        },
      );
}

// ── customers ──────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  const _CustomersTab({required this.api, this.branches = const []});
  final ProviyaaApiClient api;
  final List<BranchLocation> branches;

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _loader = GlobalKey<ApiLoaderState<List<Map<String, dynamic>>>>();
  String _q = '';
  String _segment = 'all';
  List<(String, String)> _segments = const [('all', 'All customers')];
  int? _profiles;
  Timer? _debounce;

  ProviyaaApiClient get api => widget.api;

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSegments() async {
    try {
      final s = jsonMap(await api.get('v1/crm/segments'));
      if (!mounted) return;
      setState(() {
        _profiles = numOf(s['profiles']).toInt();
        _segments = [
          ('all', 'All customers'),
          for (final x in jsonList(s['system']))
            ('${x['key']}', textOf(x['name'])),
          for (final x in jsonList(s['custom']))
            ('${x['id']}', textOf(x['name'])),
        ];
      });
    } catch (_) {
      // The filter keeps "All customers".
    }
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      jsonList(await api.get('v1/crm/customers', query: {
        if (_q.trim().isNotEmpty) 'q': _q.trim(),
        'segment': _segment,
      }));

  void _reload() {
    _loader.currentState?.reload();
    _loadSegments();
  }

  void _onSearch(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loader.currentState?.reload();
    });
  }

  Future<void> _add() async {
    if (await showCrmCustomerEditor(context, api, branches: widget.branches) &&
        mounted) {
      _reload();
    }
  }

  Future<void> _edit(Map<String, dynamic> c) async {
    if (await showCrmCustomerEditor(context, api,
            existing: c, branches: widget.branches) &&
        mounted) {
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final name = crmName(c);
    final ok = await staffConfirm(context,
        title: 'Delete $name?',
        message: 'The profile is removed from your customer lists. Their '
            'past bills stay in your sales reports.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await api.delete('v1/crm/customers/${c['id']}');
      return true;
    }, success: 'Deleted $name');
    if (done == true && mounted) _reload();
  }

  Future<void> _export(List<Map<String, dynamic>> rows) async {
    final csv = Csv.encode(const [
      'first_name',
      'last_name',
      'phone',
      'email',
      'tier',
      'orders',
      'total_spent',
      'points',
      'wallet',
      'tags',
      'branch',
      'joined',
    ], [
      for (final c in rows)
        [
          '${c['first_name'] ?? ''}',
          '${c['last_name'] ?? ''}',
          '${c['phone'] ?? ''}',
          '${c['email'] ?? ''}',
          '${c['tier'] ?? ''}',
          crmCount(c['orders']),
          crmCount(c['spent']),
          crmCount(c['points']),
          crmCount(c['wallet']),
          crmTags(c).join('; '),
          branchLabel(widget.branches, c['location_id']),
          fmtDate(c['created_at']),
        ]
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    showStaffNotice(
        context,
        'Copied ${rows.length} customer${rows.length == 1 ? '' : 's'} '
        'as CSV to the clipboard');
  }

  Widget _card(Map<String, dynamic> c) {
    final name = crmName(c);
    final phone = '${c['phone'] ?? ''}';
    final email = '${c['email'] ?? ''}'.trim();
    final orders = numOf(c['orders']).toInt();
    final tags = crmTags(c);
    final radius = BorderRadius.circular(MasterStyle.radius);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: Key('customer-row-$phone'),
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => showCrmCustomerDetail(context, api, '${c['id']}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: MasterStyle.cardBorder),
            ),
            child: Row(children: [
              StaffAvatar(initials: crmInitials(name), size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ViniiColors.textPrimaryLight)),
                        ),
                        const SizedBox(width: 8),
                        CrmTierChip('${c['tier'] ?? ''}'),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _IconText(Icons.phone_outlined, phone),
                            if (email.isNotEmpty)
                              _IconText(Icons.mail_outline, email),
                            Text(
                                '$orders order${orders == 1 ? '' : 's'} · '
                                '${crmCount(c['points'])} pts',
                                style: MasterStyle.muted),
                            if (numOf(c['wallet']) > 0)
                              Text('Wallet ${crmMoney(c['wallet'])}',
                                  style: MasterStyle.muted),
                            if (hasManyBranches(widget.branches))
                              _IconText(
                                  Icons.storefront_outlined,
                                  branchLabel(
                                      widget.branches, c['location_id'])),
                          ]),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final t in tags)
                            StaffChip(t, color: ViniiColors.blueSolid),
                        ]),
                      ],
                    ]),
              ),
              const SizedBox(width: 16),
              _Figure('TOTAL SPENT', crmMoney(c['spent']), big: true),
              const SizedBox(width: 24),
              _Figure('JOINED', fmtDate(c['created_at'])),
              const SizedBox(width: 16),
              MasterButton(
                  key: Key('customer-edit-$phone'),
                  label: 'Edit',
                  onPressed: () => _edit(c)),
              const SizedBox(width: 6),
              StaffIconAction(
                  key: Key('customer-delete-$phone'),
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  color: ViniiColors.redSolid,
                  onPressed: () => _delete(c)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        key: _loader,
        load: _load,
        builder: (context, rows, reload) {
          final filtered = _q.trim().isNotEmpty || _segment != 'all';
          final profiles = _profiles ?? rows.length;
          return BusinessPage(
            title: 'Customers',
            subtitle: 'View and manage customer profiles, transaction '
                'history, and loyalty.',
            badge: '$profiles PROFILE${profiles == 1 ? '' : 'S'}',
            actions: [
              MasterButton(
                  key: const Key('crm-customers-add'),
                  label: 'Add customer',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: _add),
            ],
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Expanded(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MasterSearchField(
                              key: const Key('crm-customer-search'),
                              hint: 'Search name, phone, email, tag…',
                              width: 320,
                              onChanged: _onSearch),
                          SizedBox(
                            width: 220,
                            child: StaffSelect<String>(
                              key: const Key('crm-customer-segment'),
                              value: _segment,
                              items: _segments,
                              onChanged: (v) {
                                setState(() => _segment = v ?? 'all');
                                _loader.currentState?.reload();
                              },
                            ),
                          ),
                          Text('${rows.length} SHOWN',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: ViniiColors.greenSolid)),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  MasterButton(
                      key: const Key('crm-customers-export'),
                      label: 'Export',
                      icon: Icons.upload_outlined,
                      onPressed: () => _export(rows)),
                ]),
              ),
              if (rows.isEmpty)
                MasterCard(
                  child: Center(
                    child: StaffEmptyState(
                      icon: Icons.people_outline,
                      title: filtered ? 'No customers match' : 'No customers yet',
                      message: filtered
                          ? 'Try another search or segment.'
                          : 'Add your first customer, or import a list. Bills '
                              'are linked to a profile by phone number.',
                      actions: [
                        if (!filtered)
                          MasterButton(
                              label: 'Add customer',
                              kind: MasterButtonKind.primary,
                              onPressed: _add),
                      ],
                    ),
                  ),
                )
              else
                for (final c in rows) _card(c),
            ],
          );
        },
      );
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: ViniiColors.textMutedLight),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12.5, color: ViniiColors.textSecondaryLight)),
      ]);
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.big = false});
  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textMutedLight)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: big ? 16 : 13,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w500,
                    color: ViniiColors.textPrimaryLight)),
          ]);
}

// ── add / edit customer ────────────────────────────────────────────────────

/// "Add New Customer" / "Edit Customer". Returns true when saved.
Future<bool> showCrmCustomerEditor(BuildContext context, ProviyaaApiClient api,
    {Map<String, dynamic>? existing,
    List<BranchLocation> branches = const []}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _CustomerDialog(api: api, existing: existing, branches: branches),
  );
  if (saved == true && context.mounted) {
    showStaffNotice(
        context, existing == null ? 'Customer added' : 'Customer saved');
  }
  return saved == true;
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog(
      {required this.api, this.existing, this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final List<BranchLocation> branches;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  Map<String, dynamic> get _e => widget.existing ?? const <String, dynamic>{};

  String _text(String key) => '${_e[key] ?? ''}';

  bool _flag(String key, bool fallback) {
    final v = _e[key];
    return v is bool ? v : fallback;
  }

  late final _first = TextEditingController(text: _text('first_name'));
  late final _last = TextEditingController(text: _text('last_name'));
  late final _phone = TextEditingController(text: _text('phone'));
  late final _email = TextEditingController(text: _text('email'));
  late final _gst = TextEditingController(text: _text('gst_number'));
  late final _address = TextEditingController(text: _text('address'));
  late List<String> _tagList = crmTags(_e);
  final _tagInput = TextEditingController();
  List<String> _knownTags = const [];
  late final _notes = TextEditingController(text: _text('notes'));
  late String? _branch = widget.existing == null
      ? defaultBranchId(widget.branches)
      : (_text('location_id').isEmpty ? null : _text('location_id'));
  late DateTime? _dob = crmDay(_e['date_of_birth']);
  late DateTime? _anniversary = crmDay(_e['anniversary']);
  late String _dining =
      const ['dine_in', 'takeaway', 'delivery'].contains(_e['preferred_dining'])
          ? _text('preferred_dining')
          : 'dine_in';
  late bool _whatsapp = _flag('allow_whatsapp', true);
  late bool _sms = _flag('allow_sms', true);
  late bool _mail = _flag('allow_email', false);
  late bool _push = _flag('allow_push', false);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  /// Tags already used on customers, offered while typing.
  Future<void> _loadTags() async {
    try {
      final rows = jsonList(await widget.api.get('v1/crm/customers'));
      if (mounted) setState(() => _knownTags = crmAllTags(rows));
    } catch (_) {
      // Tags can still be typed.
    }
  }

  /// A new customer of a one-branch restaurant belongs to that branch; with
  /// several branches the picker decides.
  bool get _sendBranch =>
      hasManyBranches(widget.branches) ||
      (widget.existing == null && widget.branches.length == 1);

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _phone,
      _email,
      _gst,
      _address,
      _tagInput,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final first = _first.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final gst = _gst.text.trim();
    String? problem;
    if (first.isEmpty) {
      problem = 'Enter the first name.';
    } else if (phone.isEmpty) {
      problem = 'Enter the phone number.';
    } else if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      problem = 'Enter a valid email address, or leave it empty.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final dob = _dob;
    final anniversary = _anniversary;
    final body = <String, dynamic>{
      'first_name': first,
      'last_name': _last.text.trim(),
      'phone': phone,
      'email': email.isEmpty ? null : email,
      'gst_number': gst.isEmpty ? null : gst,
      'date_of_birth': dob == null ? null : isoDay(dob),
      'anniversary': anniversary == null ? null : isoDay(anniversary),
      'preferred_dining': _dining,
      'address': _address.text.trim(),
      'tags': tagsWithPending(_tagList, _tagInput.text),
      'notes': _notes.text.trim(),
      if (_sendBranch) 'location_id': _branch,
      'allow_whatsapp': _whatsapp,
      'allow_sms': _sms,
      'allow_email': _mail,
      'allow_push': _push,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = _e['id'];
      if (id == null) {
        await widget.api.post('v1/crm/customers', body);
      } else {
        await widget.api.patch('v1/crm/customers/$id', body);
      }
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

  Widget _field(String label, TextEditingController c,
          {Key? key,
          String? hint,
          bool required = false,
          int maxLines = 1,
          TextInputType? keyboard}) =>
      StaffField(
        label: label,
        required: required,
        child: TextField(
          key: key,
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard ??
              (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(hint: hint),
        ),
      );

  Widget _diningChip(String value, String label) {
    final on = _dining == value;
    return Material(
      color: on ? ViniiColors.successPillBg : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('customer-dining-$value'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _dining = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on ? ViniiColors.greenSolid : kStaffBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on
                      ? ViniiColors.emeraldText
                      : ViniiColors.textPrimaryLight)),
        ),
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged,
          String keyName) =>
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(!value),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
            key: Key('customer-allow-$keyName'),
            value: value,
            activeColor: ViniiColors.greenSolid,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Text(label, style: MasterStyle.body),
          const SizedBox(width: 10),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return StaffDialog(
      title: editing ? 'Edit Customer' : 'Add New Customer',
      width: 640,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('customer-save'),
            label: _saving ? 'Saving…' : 'Save Customer',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          _field('First name', _first,
              key: const Key('customer-first-name'),
              hint: 'Enter first name',
              required: true),
          _field('Last name', _last,
              key: const Key('customer-last-name'), hint: 'Enter last name'),
        ]),
        StaffFormRow(children: [
          _field('Phone number', _phone,
              key: const Key('customer-phone'),
              hint: 'Enter 10-digit number',
              required: true,
              keyboard: TextInputType.phone),
          _field('Email address', _email,
              key: const Key('customer-email'),
              hint: 'example@domain.com',
              keyboard: TextInputType.emailAddress),
        ]),
        StaffFormRow(children: [
          _field('GST number (business)', _gst,
              key: const Key('customer-gst'), hint: 'Enter GST number'),
          StaffField(
            label: 'Date of birth',
            child: _OptionalDate(
              key: const Key('customer-dob'),
              value: _dob,
              onChanged: (v) => setState(() => _dob = v),
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Anniversary',
            child: _OptionalDate(
              key: const Key('customer-anniversary'),
              value: _anniversary,
              onChanged: (v) => setState(() => _anniversary = v),
            ),
          ),
          const SizedBox.shrink(),
        ]),
        StaffField(
          label: 'Preferred dining type',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _diningChip('dine_in', 'Dine-In'),
            _diningChip('takeaway', 'Takeaway'),
            _diningChip('delivery', 'Delivery'),
          ]),
        ),
        const SizedBox(height: 14),
        StaffFormRow(children: [
          _field('Address', _address,
              key: const Key('customer-address'),
              hint: 'Enter full address',
              maxLines: 2),
        ]),
        if (hasManyBranches(widget.branches))
          StaffFormRow(children: [
            BizBranchSelect(
              selectKey: const Key('customer-branch'),
              label: 'Home branch',
              branches: widget.branches,
              value: _branch,
              onChanged: (v) => setState(() => _branch = v),
            ),
            const SizedBox.shrink(),
          ]),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: StaffField(
            label: 'Tags',
            child: BizTagInput(
              inputKey: const Key('customer-tags'),
              tags: _tagList,
              input: _tagInput,
              suggestions: _knownTags,
              hint: 'Type a tag and press Enter, e.g. VIP',
              onChanged: (v) => setState(() => _tagList = v),
            ),
          ),
        ),
        StaffFormRow(children: [
          _field('Notes', _notes,
              key: const Key('customer-notes'),
              hint: 'Add any notes about this customer…',
              maxLines: 2),
        ]),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kStaffBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMMUNICATION PREFERENCES',
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textSecondaryLight)),
                const SizedBox(height: 4),
                Wrap(runSpacing: 2, children: [
                  _check('WhatsApp', _whatsapp,
                      (v) => setState(() => _whatsapp = v), 'whatsapp'),
                  _check('SMS', _sms, (v) => setState(() => _sms = v), 'sms'),
                  _check('Email', _mail, (v) => setState(() => _mail = v),
                      'email'),
                  _check('Push', _push, (v) => setState(() => _push = v),
                      'push'),
                ]),
              ]),
        ),
      ]),
    );
  }
}

/// A date that may be empty: tap to pick, × to clear.
class _OptionalDate extends StatelessWidget {
  const _OptionalDate({super.key, required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day);
    final current = value;
    final initial = current == null
        ? DateTime(now.year - 25, 1, 1)
        : (current.isAfter(last) ? last : current);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(1900)) ? DateTime(1900) : initial,
      firstDate: DateTime(1900),
      lastDate: last,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _pick(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kStaffBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Text(v == null ? 'DD/MM/YYYY' : staffSlashDate(v),
                style: TextStyle(
                    fontSize: 13.5,
                    color: v == null
                        ? ViniiColors.textMutedLight
                        : ViniiColors.textPrimaryLight)),
          ),
          if (v != null)
            IconButton(
              tooltip: 'Clear',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              iconSize: 16,
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close,
                  color: ViniiColors.textSecondaryLight),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.calendar_today_outlined,
              size: 15, color: ViniiColors.textSecondaryLight),
        ]),
      ),
    );
  }
}

// ── import ─────────────────────────────────────────────────────────────────

/// Paste-a-CSV import (POST v1/crm/customers/import). Returns true when at
/// least one customer was added.
Future<bool> showCrmCustomerImport(
    BuildContext context, ProviyaaApiClient api) async {
  final added = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportDialog(api: api),
  );
  return added == true;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  static const _header = 'first_name,last_name,phone,email,tags';
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  int? _added;
  List<Map<String, dynamic>> _skipped = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _close() => Navigator.pop(context, (_added ?? 0) > 0);

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() => _error = 'The clipboard has no text to paste.');
      return;
    }
    setState(() {
      _text.text = text;
      _error = null;
    });
  }

  Future<void> _import() async {
    final raw = _text.text;
    final table = Csv.decodeRows(raw);
    final header = table.isEmpty
        ? const <String>[]
        : [for (final h in table.first) h.trim().toLowerCase()];
    if (!header.contains('phone') ||
        !(header.contains('first_name') || header.contains('name'))) {
      setState(() => _error =
          'The first row must be the header: $_header (last_name, email and '
          'tags are optional).');
      return;
    }
    final records = Csv.decode(raw);
    if (records.isEmpty) {
      setState(() => _error = 'Add at least one customer under the header row.');
      return;
    }
    if (records.length > 1000) {
      setState(() => _error =
          'Import up to 1000 customers at a time (this list has ${records.length}).');
      return;
    }
    final customers = <Map<String, dynamic>>[
      for (final r in records)
        {
          'first_name': r('first_name', r('name')),
          'last_name': r('last_name'),
          'phone': r('phone'),
          if (r.has('email')) 'email': r('email'),
          if (r.has('tags'))
            'tags': [
              for (final t in r('tags').split(RegExp(r'[;|,]')))
                if (t.trim().isNotEmpty) t.trim()
            ],
        }
    ];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final out = jsonMap(await widget.api
          .post('v1/crm/customers/import', {'customers': customers}));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _added = numOf(out['added']).toInt();
        _skipped = jsonList(out['skipped']);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final added = _added;
    return StaffDialog(
      title: 'Import customers',
      subtitle: 'Paste a CSV list — one customer per row.',
      width: 640,
      error: _error,
      onClose: _busy ? () {} : _close,
      actions: added != null
          ? [
              MasterButton(
                  key: const Key('crm-import-done'),
                  label: 'Done',
                  kind: MasterButtonKind.primary,
                  onPressed: _close),
            ]
          : [
              MasterButton(
                  label: 'Cancel', onPressed: _busy ? null : _close),
              MasterButton(
                  key: const Key('crm-import-paste'),
                  label: 'Paste from clipboard',
                  icon: Icons.content_paste,
                  onPressed: _busy ? null : _paste),
              MasterButton(
                  key: const Key('crm-import-submit'),
                  label: _busy ? 'Importing…' : 'Import',
                  kind: MasterButtonKind.primary,
                  onPressed: _busy ? null : _import),
            ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'First row: $_header. Separate several tags with ";" (or quote '
            'the field). Rows whose phone number already belongs to a '
            'customer are skipped.',
            style: MasterStyle.body),
        const SizedBox(height: 12),
        TextField(
          key: const Key('crm-import-text'),
          controller: _text,
          enabled: added == null,
          minLines: 8,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
          decoration: staffInput(
              hint: '$_header\nAsha,Rao,9876543210,asha@example.com,VIP;Weekend'),
        ),
        if (added != null) ...[
          const SizedBox(height: 14),
          MasterBanner(
            tone: _skipped.isEmpty ? PillTone.green : PillTone.amber,
            title: 'Added $added, skipped ${_skipped.length}',
            message: _skipped.isEmpty
                ? 'Every row was imported.'
                : 'The rows below were not imported:',
          ),
          if (_skipped.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in _skipped)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    'Row ${crmCount(s['row'])}: ${textOf(s['reason'])}',
                    style: const TextStyle(
                        fontSize: 12.5, color: ViniiColors.redSolid)),
              ),
          ],
        ],
      ]),
    );
  }
}
