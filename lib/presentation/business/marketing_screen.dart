import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';
import 'marketing_dialogs.dart';

export 'marketing_dialogs.dart'
    show showCampaignBuilder, showCreateOfferDialog, showCampaignOutcome;

/// Marketing (/v1/marketing): dashboard, customer campaigns, promotions
/// (the offers of Master → Offers) and ad requests for the Proviyaa
/// customer app. No messaging provider is connected yet, so campaigns are
/// queued with a note from the server saying nothing was delivered — the
/// screens show that note instead of pretending messages went out.

enum MarketingTab { dashboard, campaigns, promotions, ads }

class MarketingScreen extends StatefulWidget {
  const MarketingScreen(
      {super.key,
      required this.api,
      this.initialTab = MarketingTab.dashboard});
  final ProviyaaApiClient api;
  final MarketingTab initialTab;

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  static const _labels = [
    'Dashboard',
    'Campaigns',
    'Promotions',
    'Ads & notifications',
  ];
  late MarketingTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(covariant MarketingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  void _go(MarketingTab tab) => setState(() => _tab = tab);

  Widget _body() => switch (_tab) {
        MarketingTab.dashboard =>
          _MarketingDashboard(api: widget.api, onOpen: _go),
        MarketingTab.campaigns => _CampaignsTab(api: widget.api),
        MarketingTab.promotions => _PromotionsTab(api: widget.api),
        MarketingTab.ads => _AdsTab(api: widget.api),
      };

  @override
  Widget build(BuildContext context) => Material(
        color: ViniiColors.lightPageBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTabBar(
            tabs: _labels,
            selected: _tab.index,
            onSelect: (i) => _go(MarketingTab.values[i]),
            keyPrefix: 'marketing-tab',
          ),
          Expanded(child: KeyedSubtree(key: ValueKey(_tab), child: _body())),
        ]),
      );
}

// ── shared bits ────────────────────────────────────────────────────────────

String _count(dynamic v) => staffNumText(numOf(v));

String _money(dynamic v) => staffMoney(numOf(v));

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: MasterStyle.muted),
                  ],
                ]),
          ),
        ]),
      );
}

/// A bordered line with a leading icon, title (+ pill), caption and an
/// optional trailing widget.
class _Line extends StatelessWidget {
  const _Line(
      {required this.icon,
      required this.title,
      required this.caption,
      this.pill,
      this.trailing,
      this.note,
      this.noteColor = ViniiColors.redSolid});
  final Widget icon;
  final String title;
  final String caption;
  final Widget? pill;
  final Widget? trailing;
  final String? note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MasterCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ViniiColors.textPrimaryLight)),
                          if (pill != null) pill!,
                        ]),
                    const SizedBox(height: 3),
                    Text(caption, style: MasterStyle.muted),
                    if (note != null && note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(note!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: noteColor)),
                    ],
                  ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: ViniiColors.textSecondaryLight),
      );
}

// ── dashboard ──────────────────────────────────────────────────────────────

class _MarketingDashboard extends StatelessWidget {
  const _MarketingDashboard({required this.api, required this.onOpen});
  final ProviyaaApiClient api;
  final ValueChanged<MarketingTab> onOpen;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/marketing/dashboard')),
        builder: (context, d, reload) {
          Future<void> createCampaign() async {
            if (await showCampaignBuilder(context, api) && context.mounted) {
              reload();
            }
          }

          Future<void> createOffer() async {
            if (await showCreateOfferDialog(context, api) && context.mounted) {
              reload();
            }
          }

          final reach = numOf(d['reach']);
          final delivered = numOf(d['delivered']);
          final queued = numOf(d['queued_campaigns']).toInt();
          final roas = d['roas'];
          final cpc = d['cost_per_conversion'];
          final activity = jsonList(d['activity_30d']);
          final mix = jsonList(d['channel_mix']);
          final top = jsonList(d['top_campaigns']);
          final coupons = jsonList(d['coupon_performance']);
          return BusinessPage(
            title: 'Marketing overview',
            subtitle:
                'Campaigns, coupons and ads, measured from your own data.',
            actions: [
              MasterButton(
                  key: const Key('marketing-dashboard-create-campaign'),
                  label: 'Create campaign',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: createCampaign),
              MasterButton(
                  key: const Key('marketing-dashboard-create-offer'),
                  label: 'Create offer',
                  icon: Icons.card_giftcard,
                  onPressed: createOffer),
            ],
            children: [
              if (queued > 0)
                InfoNote(
                    '$queued campaign${queued == 1 ? ' is' : 's are'} queued '
                    'but not delivered. Messages go out only after a messaging '
                    'provider is connected in Integrations → Connected apps.',
                    tone: PillTone.amber),
              KpiGrid(columns: 5, cards: [
                MasterStatCard(
                    label: 'ATTRIBUTED REVENUE',
                    value: _money(d['attributed_revenue']),
                    caption: 'From campaigns & coupons'),
                MasterStatCard(
                    label: 'MARKETING SPEND',
                    value: _money(d['marketing_spend']),
                    caption: 'Campaigns & ads'),
                MasterStatCard(
                    label: 'BLENDED ROAS',
                    value: roas == null ? '—' : '${_count(roas)}x',
                    caption: 'Revenue ÷ ad spend'),
                MasterStatCard(
                    label: 'REACH',
                    value: _count(reach),
                    caption: '${_count(reach)} sent, '
                        '${reach > 0 ? (delivered / reach * 100).round() : 0}% delivered'),
                MasterStatCard(
                    label: 'CLICK THROUGH RATE',
                    value: '${_count(d['click_through_rate'])}%',
                    caption: '${_count(d['clicks'])} clicks'),
              ]),
              KpiGrid(columns: 5, cards: [
                MasterStatCard(
                    label: 'CONVERSION RATE',
                    value: '${_count(d['conversion_rate'])}%',
                    caption: '${_count(d['redemptions'])} redemptions'),
                MasterStatCard(
                    label: 'COST PER CONVERSION',
                    value: cpc == null ? '—' : _money(cpc),
                    caption: 'Spend ÷ redemptions'),
                MasterStatCard(
                    label: 'LIVE COUPONS',
                    value: _count(d['live_coupons']),
                    caption: '${_count(d['expiring_7d'])} expiring in 7 days • '
                        '${_count(d['auto_apply'])} auto-apply'),
                MasterStatCard(
                    label: 'AUTOMATION FLOWS',
                    value: _count(d['automation_flows']),
                    caption: '${_count(d['automation_flows'])} configured'),
                MasterStatCard(
                    label: 'ADS LIVE',
                    value: _count(d['ads_live']),
                    caption: '${_count(d['ad_clicks'])} clicks • '
                        '${_count(d['ad_orders'])} orders'),
              ]),
              MasterGrid(columns: 2, minItemWidth: 380, children: [
                MasterSection(
                  title: 'Revenue & reach – last 30 days',
                  subtitle: 'Campaigns created per day and their audience',
                  child: activity.isEmpty
                      ? StaffEmptyState(
                          icon: Icons.show_chart,
                          title: 'No campaign activity yet',
                          message: 'Send your first WhatsApp or SMS campaign '
                              'to start collecting performance data.',
                          actions: [
                            MasterButton(
                                label: 'Create campaign',
                                kind: MasterButtonKind.primary,
                                onPressed: createCampaign),
                          ],
                        )
                      : _ActivityBars(activity),
                ),
                MasterSection(
                  title: 'Channel mix',
                  subtitle: 'Campaigns per channel',
                  child: mix.isEmpty
                      ? const StaffEmptyState(
                          icon: Icons.share_outlined,
                          title: 'No channels used yet',
                          message: 'Connect WhatsApp or SMS in Integrations '
                              'to start sending.',
                        )
                      : _ChannelMix(mix),
                ),
                MasterSection(
                  title: 'Top campaigns by revenue',
                  trailing: top.isEmpty
                      ? null
                      : MasterButton(
                          label: 'View all',
                          kind: MasterButtonKind.text,
                          onPressed: () => onOpen(MarketingTab.campaigns)),
                  child: top.isEmpty
                      ? StaffEmptyState(
                          icon: Icons.mail_outline,
                          title: 'No campaigns yet',
                          message: 'Your first campaign will appear here with '
                              'delivery and revenue metrics.',
                          actions: [
                            MasterButton(
                                label: 'Create campaign',
                                kind: MasterButtonKind.primary,
                                onPressed: createCampaign),
                          ],
                        )
                      : Column(children: [
                          for (final c in top)
                            _Line(
                              icon: _IconBox(marketingChannelIcon(c['channel'])),
                              title: textOf(c['name']),
                              pill: StatusPill('${c['status'] ?? ''}'),
                              caption:
                                  '${marketingChannelLabel(c['channel'])} · '
                                  '${_count(c['audience_count'])} recipients',
                              trailing: Text(_money(c['revenue']),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                ),
                MasterSection(
                  title: 'Coupon performance',
                  trailing: coupons.isEmpty
                      ? null
                      : MasterButton(
                          label: 'View all',
                          kind: MasterButtonKind.text,
                          onPressed: () => onOpen(MarketingTab.promotions)),
                  child: coupons.isEmpty
                      ? StaffEmptyState(
                          icon: Icons.sell_outlined,
                          title: 'No coupons yet',
                          message: 'Create a coupon or auto-apply offer to '
                              'drive repeat visits.',
                          actions: [
                            MasterButton(
                                label: 'Create coupon',
                                kind: MasterButtonKind.primary,
                                onPressed: createOffer),
                          ],
                        )
                      : Column(children: [
                          for (final p in coupons)
                            _Line(
                              icon: const _IconBox(Icons.sell_outlined),
                              title: textOf(p['code']),
                              pill: StatusPill('${p['state'] ?? ''}'),
                              caption: textOf(p['title']),
                              trailing: Text(
                                  '${_count(p['usage_count'])} redemptions',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ]),
                ),
              ]),
            ],
          );
        },
      );
}

class _ActivityBars extends StatelessWidget {
  const _ActivityBars(this.days);
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    var most = 0.0;
    for (final d in days) {
      final a = numOf(d['audience']).toDouble();
      if (a > most) most = a;
    }
    return Column(children: [
      for (final d in days)
        ShareBar(
          label: fmtDate(d['day']),
          value: '${_count(d['campaigns'])} campaign'
              '${numOf(d['campaigns']) == 1 ? '' : 's'} · '
              '${_count(d['audience'])} recipients',
          share: most > 0 ? numOf(d['audience']) / most : 0.0,
        ),
    ]);
  }
}

class _ChannelMix extends StatelessWidget {
  const _ChannelMix(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<num>(0, (s, r) => s + numOf(r['campaigns']));
    return Column(children: [
      for (final r in rows)
        ShareBar(
          label: marketingChannelLabel(r['channel']),
          value: '${_count(r['campaigns'])} campaign'
              '${numOf(r['campaigns']) == 1 ? '' : 's'} · '
              '${_count(r['audience'])} recipients',
          share: total > 0 ? numOf(r['campaigns']) / total : 0.0,
        ),
    ]);
  }
}

// ── campaigns ──────────────────────────────────────────────────────────────

class _CampaignsTab extends StatefulWidget {
  const _CampaignsTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<_CampaignsTab> {
  final _loader = GlobalKey<ApiLoaderState<List<Map<String, dynamic>>>>();
  String _q = '';
  String _channel = '';
  Timer? _debounce;
  Map<String, String> _segmentNames = const {'all': 'All customers'};

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
      setState(() => _segmentNames = {
            'all': 'All customers',
            for (final x in jsonList(s['system']))
              '${x['key']}': textOf(x['name']),
            for (final x in jsonList(s['custom']))
              '${x['id']}': textOf(x['name']),
          });
    } catch (_) {
      // The server's segment_name is used instead.
    }
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      jsonList(await api.get('v1/marketing/campaigns', query: {
        if (_q.trim().isNotEmpty) 'q': _q.trim(),
        if (_channel.isNotEmpty) 'channel': _channel,
      }));

  void _reload() => _loader.currentState?.reload();

  void _onSearch(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload();
    });
  }

  /// The campaign's audience by name: the server's segment_name, else the
  /// loaded segment list; a segment that no longer exists reads
  /// "Deleted segment" (its id is never shown).
  String _segmentLabel(Map<String, dynamic> c) {
    final name = textOf(c['segment_name'], '');
    if (name.isNotEmpty) return name;
    final k = textOf(c['segment'], 'all');
    final known = _segmentNames[k];
    if (known != null) return known;
    if (isUuidLike(k) || c.containsKey('segment_name')) return 'Deleted segment';
    return humanize(k);
  }

  Future<void> _create() async {
    if (await showCampaignBuilder(context, api) && mounted) _reload();
  }

  Future<void> _action(Map<String, dynamic> c, String action) async {
    final id = '${c['id']}';
    final name = textOf(c['name'], 'this campaign');
    if (action == 'Edit') {
      if (await showCampaignBuilder(context, api, existing: c) && mounted) {
        _reload();
      }
      return;
    }
    if (action == 'Send now') {
      final ok = await staffConfirm(context,
          title: 'Send "$name" now?',
          message: 'It is queued for ${_count(c['audience_count'])} '
              'opted-in customers. Nothing is delivered until a messaging '
              'provider is connected in Integrations.',
          confirmLabel: 'Send now',
          danger: false);
      if (!ok || !mounted) return;
      final out = await runAction<Map<String, dynamic>>(
          context,
          () async =>
              jsonMap(await api.post('v1/marketing/campaigns/$id/send')));
      if (!mounted) return;
      _reload();
      if (out != null) await showCampaignOutcome(context, out);
      return;
    }
    final cancel = action == 'Cancel';
    final ok = await staffConfirm(context,
        title: cancel ? 'Cancel "$name"?' : 'Delete "$name"?',
        message: cancel
            ? 'The campaign will not be sent.'
            : 'The campaign is removed from the list.',
        confirmLabel: cancel ? 'Cancel campaign' : 'Delete');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      if (cancel) {
        await api.post('v1/marketing/campaigns/$id/cancel');
      } else {
        await api.delete('v1/marketing/campaigns/$id');
      }
      return true;
    }, success: cancel ? 'Cancelled "$name"' : 'Deleted "$name"');
    if (done == true && mounted) _reload();
  }

  Widget _nameCell(Map<String, dynamic> c) {
    final note = '${c['status_note'] ?? ''}'.trim();
    final notSent = note.toLowerCase().startsWith('not sent');
    final schedule = c['schedule_at'];
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(textOf(c['name']),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 2),
          Text(
              '${_segmentLabel(c)} · '
              '${schedule == null ? 'Created ${fmtDate(c['created_at'])}' : 'For ${fmtDateTime(schedule)}'}',
              overflow: TextOverflow.ellipsis,
              style: MasterStyle.muted),
          if (note.isNotEmpty && note != 'Cancelled') ...[
            const SizedBox(height: 4),
            Text(note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: notSent
                        ? const Color(0xFFB45309)
                        : ViniiColors.textSecondaryLight)),
          ],
        ]);
  }

  List<String> _actionsFor(String status) => [
        if (status == 'draft' || status == 'scheduled') ...['Send now', 'Edit'],
        if (status == 'scheduled' || status == 'queued') 'Cancel',
        'Delete',
      ];

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        key: _loader,
        load: _load,
        builder: (context, rows, reload) {
          final filtered = _q.trim().isNotEmpty || _channel.isNotEmpty;
          return BusinessPage(
            title: 'Campaigns',
            subtitle:
                'WhatsApp, SMS, email and push broadcasts to your customer segments.',
            actions: [
              MasterButton(
                  key: const Key('marketing-create-campaign'),
                  label: 'Create Campaign',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: _create),
            ],
            children: [
              const InfoNote(
                  'Campaigns are queued with their audience counted (customers '
                  'in the segment who opted in to the channel). Nothing is '
                  'delivered until a messaging provider — WhatsApp Business, '
                  'an SMS gateway, email SMTP or push — is connected in '
                  'Integrations.'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MasterSearchField(
                          key: const Key('marketing-campaign-search'),
                          hint: 'Search campaigns…',
                          width: 300,
                          onChanged: _onSearch),
                      SizedBox(
                        width: 200,
                        child: StaffSelect<String>(
                          key: const Key('marketing-campaign-channel'),
                          value: _channel,
                          items: const [
                            ('', 'Channels (All)'),
                            ...kMarketingChannels,
                          ],
                          onChanged: (v) {
                            setState(() => _channel = v ?? '');
                            _reload();
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
              MasterTable(
                minWidth: 1000,
                columns: const [
                  MasterColumn('Campaign name', flex: 28),
                  MasterColumn('Channel', flex: 10),
                  MasterColumn('Recipients', flex: 9),
                  MasterColumn('Delivered', flex: 9),
                  MasterColumn('Revenue', flex: 9),
                  MasterColumn('Status', flex: 10),
                  MasterColumn('Actions', flex: 17, alignEnd: true),
                ],
                rows: [
                  for (final c in rows)
                    [
                      _nameCell(c),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(marketingChannelIcon(c['channel']),
                            size: 15, color: ViniiColors.textSecondaryLight),
                        const SizedBox(width: 6),
                        Flexible(
                            child: MasterCellText(
                                marketingChannelLabel(c['channel']))),
                      ]),
                      MasterCellText(_count(c['audience_count'])),
                      MasterCellText(_count(c['delivered_count'])),
                      MasterCellText(_money(c['revenue'])),
                      StatusPill('${c['status'] ?? ''}'),
                      MasterRowActions(
                          _actionsFor('${c['status'] ?? ''}'),
                          onTap: (a) => _action(c, a)),
                    ]
                ],
                footer: rows.isEmpty
                    ? StaffEmptyState(
                        icon: Icons.mail_outline,
                        title: filtered
                            ? 'No campaigns match'
                            : 'No campaigns launched yet',
                        message: filtered
                            ? 'Try another search or channel.'
                            : 'Launch a promotional broadcast via WhatsApp or '
                                'SMS to engage your customers.',
                        actions: [
                          if (!filtered)
                            MasterButton(
                                key: const Key('marketing-launch-first'),
                                label: 'Launch first campaign',
                                kind: MasterButtonKind.primary,
                                onPressed: _create),
                        ],
                      )
                    : null,
              ),
            ],
          );
        },
      );
}

// ── promotions ─────────────────────────────────────────────────────────────

class _PromotionsTab extends StatefulWidget {
  const _PromotionsTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_PromotionsTab> createState() => _PromotionsTabState();
}

class _PromotionsTabState extends State<_PromotionsTab> {
  static const _states = [
    ('active', 'Active Offers'),
    ('scheduled', 'Scheduled'),
    ('ended', 'Ended'),
  ];
  int _state = 0;

  ProviyaaApiClient get api => widget.api;

  static String _validity(Map<String, dynamic> p) {
    final start = p['start_date'];
    final end = p['end_date'];
    if (start == null && end == null) return 'Always on';
    final from = start == null ? 'Now' : fmtDate(start);
    final until = end == null ? 'No end date' : fmtDate(end);
    return '$from – $until';
  }

  Widget _subTab(int i, int count) {
    final on = _state == i;
    return Material(
      color: on ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('promo-state-${_states[i].$1}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _state = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on ? MasterStyle.cardBorder : Colors.transparent),
          ),
          child: Text('${_states[i].$2} ($count)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on
                      ? ViniiColors.textPrimaryLight
                      : ViniiColors.textSecondaryLight)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        load: () async => jsonList(await api.get('v1/marketing/promotions')),
        builder: (context, all, reload) {
          Future<void> create() async {
            if (await showCreateOfferDialog(context, api) && context.mounted) {
              reload();
            }
          }

          Future<void> act(Map<String, dynamic> p, String action) async {
            final name = textOf(p['code'], textOf(p['title'], 'this offer'));
            if (action == 'Edit') {
              if (await showCreateOfferDialog(context, api, existing: p) &&
                  context.mounted) {
                reload();
              }
              return;
            }
            final ok = await staffConfirm(context,
                title: 'Delete $name?',
                message: 'The offer is removed here and from Master → Offers.');
            if (!ok || !context.mounted) return;
            final done = await runAction<bool>(context, () async {
              await api.delete('v1/marketing/promotions/${p['id']}');
              return true;
            }, success: 'Deleted $name');
            if (done == true && context.mounted) reload();
          }

          final key = _states[_state].$1;
          final rows = [
            for (final p in all)
              if (p['state'] == key) p
          ];
          int countOf(String s) => all.where((p) => p['state'] == s).length;
          return BusinessPage(
            title: 'Promotions & coupons',
            subtitle: 'Offers created here are shared with Master → Offers.',
            actions: [
              MasterButton(
                  key: const Key('marketing-create-offer'),
                  label: 'Create Offer',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: create),
            ],
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < _states.length; i++)
                    _subTab(i, countOf(_states[i].$1)),
                ]),
              ),
              MasterTable(
                minWidth: 1000,
                columns: const [
                  MasterColumn('Coupon code / offer name', flex: 22),
                  MasterColumn('Discount type', flex: 16),
                  MasterColumn('Applies to', flex: 16),
                  MasterColumn('Validity period', flex: 20),
                  MasterColumn('Redemptions', flex: 9),
                  MasterColumn('Status', flex: 9),
                  MasterColumn('Actions', flex: 10, alignEnd: true),
                ],
                rows: [
                  for (final p in rows)
                    [
                      MasterCellTitle(textOf(p['code']),
                          subtitle: textOf(p['title'])),
                      MasterCellText(textOf(p['discount_rule'])),
                      MasterCellText(textOf(p['channels'])),
                      MasterCellText(_validity(p)),
                      MasterCellText(_count(p['usage_count'])),
                      StatusPill('${p['status'] ?? ''}'),
                      MasterRowActions(const ['Edit', 'Delete'],
                          onTap: (a) => act(p, a)),
                    ]
                ],
                footer: rows.isEmpty
                    ? StaffEmptyState(
                        icon: Icons.sell_outlined,
                        title: switch (key) {
                          'scheduled' => 'No scheduled offers',
                          'ended' => 'No ended offers',
                          _ => 'No promotions running currently',
                        },
                        message: 'Boost order counts by offering free '
                            'delivery, percentage markdowns, or combo deals.',
                        actions: [
                          MasterButton(
                              key: const Key('marketing-setup-offer'),
                              label: 'Setup an offer',
                              kind: MasterButtonKind.primary,
                              onPressed: create),
                        ],
                      )
                    : null,
              ),
            ],
          );
        },
      );
}

// ── ads & notifications ────────────────────────────────────────────────────

const _placements = [
  ('home_carousel', 'Home Carousel'),
  ('offer_strip', 'Offer strip'),
  ('restaurant_section', 'Restaurant section'),
];

String _placementLabel(dynamic v) {
  for (final p in _placements) {
    if (p.$1 == '$v') return p.$2;
  }
  return humanize(v);
}

class _AdThumb extends StatelessWidget {
  const _AdThumb(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    const fallback = _IconBox(Icons.image_outlined);
    if (url.trim().isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => fallback),
    );
  }
}

class _AdsTab extends StatelessWidget {
  const _AdsTab({required this.api});
  final ProviyaaApiClient api;

  static Widget _metric(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: MasterStyle.muted),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]);

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        load: () async => jsonList(await api.get('v1/marketing/ads')),
        builder: (context, ads, reload) {
          Future<void> withdraw(Map<String, dynamic> a) async {
            final title = textOf(a['title'], 'this request');
            final ok = await staffConfirm(context,
                title: 'Withdraw "$title"?',
                message: 'The request is removed before the Proviyaa team '
                    'reviews it.',
                confirmLabel: 'Withdraw');
            if (!ok || !context.mounted) return;
            final done = await runAction<bool>(context, () async {
              await api.delete('v1/marketing/ads/${a['id']}');
              return true;
            }, success: 'Withdrew "$title"');
            if (done == true && context.mounted) reload();
          }

          final live = ads.where((a) => a['status'] == 'live').length;
          final impressions =
              ads.fold<num>(0, (s, a) => s + numOf(a['impressions']));
          final clicks = ads.fold<num>(0, (s, a) => s + numOf(a['clicks']));
          final orders = ads.fold<num>(0, (s, a) => s + numOf(a['orders']));
          final spend = ads.fold<num>(0, (s, a) => s + numOf(a['spend']));
          final ctr = impressions > 0 ? clicks / impressions * 100 : 0;
          final running = [
            for (final a in ads)
              if (const ['approved', 'live', 'ended'].contains(a['status'])) a
          ];
          return BusinessPage(
            title: 'Ads & notifications',
            subtitle:
                'Promotion slots in the Proviyaa customer app for your restaurant.',
            children: [
              KpiGrid(columns: 5, cards: [
                MasterStatCard(
                    label: 'LIVE ADS',
                    value: '$live',
                    caption: 'Currently running'),
                MasterStatCard(
                    label: 'IMPRESSIONS',
                    value: _count(impressions),
                    caption: 'Across all your ads'),
                MasterStatCard(
                    label: 'CLICKS',
                    value: _count(clicks),
                    caption: 'CTR ${ctr.toStringAsFixed(1)}%'),
                MasterStatCard(
                    label: 'ORDERS ATTRIBUTED',
                    value: _count(orders),
                    caption: 'From ad clicks'),
                MasterStatCard(
                    label: 'SPEND',
                    value: _money(spend),
                    caption: 'Total ad spend'),
              ]),
              const _Heading('Running & past ads',
                  subtitle:
                      'Approved, live and completed ads for your restaurant.'),
              if (running.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: MasterCard(
                    child: Center(
                      child: StaffEmptyState(
                        icon: Icons.image_outlined,
                        title: 'No ads yet',
                        message: 'Your approved ads will appear here. Submit a '
                            'request below to get started.',
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    for (final a in running)
                      _Line(
                        icon: _AdThumb('${a['banner_url'] ?? ''}'),
                        title: textOf(a['title']),
                        pill: StatusPill('${a['status'] ?? ''}'),
                        caption: [
                          _placementLabel(a['placement']),
                          fmtDateTime(a['created_at']),
                          if ('${a['discount_text'] ?? ''}'.trim().isNotEmpty)
                            '${a['discount_text']}',
                        ].join(' • '),
                        trailing: Wrap(spacing: 18, children: [
                          _metric('Impressions', _count(a['impressions'])),
                          _metric('Clicks', _count(a['clicks'])),
                          _metric('Orders', _count(a['orders'])),
                          _metric('Spend', _money(a['spend'])),
                        ]),
                      ),
                  ]),
                ),
              const _Heading('Ad requests',
                  subtitle:
                      'Raise and track promotion slots on the customer app.'),
              _AdRequestForm(api: api, onSubmitted: reload),
              const SizedBox(height: 24),
              const _Heading('My requests'),
              if (ads.isEmpty)
                const MasterCard(
                  child: Text('No requests yet. Submit one above.',
                      style: MasterStyle.muted),
                )
              else
                Column(children: [
                  for (final a in ads)
                    _Line(
                      icon: _AdThumb('${a['banner_url'] ?? ''}'),
                      title: textOf(a['title']),
                      pill: StatusPill('${a['status'] ?? ''}'),
                      caption: '${_placementLabel(a['placement'])} • '
                          '${fmtDateTime(a['created_at'])}',
                      note: '${a['review_note'] ?? ''}'.trim().isEmpty
                          ? null
                          : 'Note: ${a['review_note']}',
                      noteColor: a['status'] == 'rejected'
                          ? ViniiColors.redSolid
                          : ViniiColors.textSecondaryLight,
                      trailing: a['status'] == 'pending'
                          ? MasterButton(
                              key: Key('ad-withdraw-${a['id']}'),
                              label: 'Withdraw',
                              kind: MasterButtonKind.dangerOutline,
                              onPressed: () => withdraw(a))
                          : null,
                    ),
                ]),
            ],
          );
        },
      );
}

class _AdRequestForm extends StatefulWidget {
  const _AdRequestForm({required this.api, required this.onSubmitted});
  final ProviyaaApiClient api;
  final VoidCallback onSubmitted;

  @override
  State<_AdRequestForm> createState() => _AdRequestFormState();
}

class _AdRequestFormState extends State<_AdRequestForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _discount = TextEditingController();
  final _banner = TextEditingController();
  String _placement = 'home_carousel';
  bool _busy = false;

  /// Offers that can fill the discount text.
  List<Map<String, dynamic>> _offers = const [];
  String _offer = '';

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final rows = jsonList(await widget.api.get('v1/marketing/promotions'));
      if (mounted) {
        setState(() => _offers = [
              for (final p in rows)
                if (p['state'] != 'ended' &&
                    textOf(p['discount_rule'], '').isNotEmpty)
                  p
            ]);
      }
    } catch (_) {
      // The discount text is typed by hand.
    }
  }

  void _useOffer(String? id) {
    final v = id ?? '';
    final offer = _offers.where((p) => '${p['id']}' == v).firstOrNull;
    setState(() {
      _offer = v;
      if (offer != null) {
        _discount.text = textOf(offer['discount_rule'], '');
        if (_title.text.trim().isEmpty) {
          _title.text = textOf(offer['title'], '');
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _discount, _banner]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final banner = _banner.text.trim();
    if (title.isEmpty) {
      showStaffError(context, 'Give the ad a title.');
      return;
    }
    if (banner.isNotEmpty &&
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(banner)) {
      showStaffError(
          context, 'The banner image URL must start with http:// or https://');
      return;
    }
    setState(() => _busy = true);
    final done = await runAction<bool>(context, () async {
      await widget.api.post('v1/marketing/ads', {
        'title': title,
        'description': _description.text.trim(),
        'discount_text': _discount.text.trim(),
        'placement': _placement,
        'banner_url': banner.isEmpty ? null : banner,
      });
      return true;
    }, success: 'Ad request submitted — the Proviyaa team will review it.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) {
      for (final c in [_title, _description, _discount, _banner]) {
        c.clear();
      }
      setState(() {
        _placement = 'home_carousel';
        _offer = '';
      });
      widget.onSubmitted();
    }
  }

  Widget _field(String label, TextEditingController c,
          {required Key key, String? hint, int maxLines = 1}) =>
      StaffField(
        label: label,
        child: TextField(
          key: key,
          controller: c,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(hint: hint),
        ),
      );

  @override
  Widget build(BuildContext context) => MasterSection(
        title: 'Request an Ad',
        subtitle: 'Submit a banner for the Proviyaa customer app. The '
            'Proviyaa team reviews every request before it goes live.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            _field('Title', _title,
                key: const Key('ad-title'), hint: 'Enter ad title'),
          ]),
          StaffFormRow(children: [
            _field('Description', _description,
                key: const Key('ad-description'),
                hint: 'Describe your offer or promotion details…',
                maxLines: 3),
          ]),
          if (_offers.isNotEmpty)
            StaffFormRow(children: [
              StaffField(
                label: 'Fill from an offer (optional)',
                child: StaffSelect<String>(
                  key: const Key('ad-offer'),
                  value: _offer,
                  items: [
                    ('', 'Type the discount yourself'),
                    for (final p in _offers)
                      (
                        '${p['id']}',
                        [
                          textOf(p['code'], ''),
                          textOf(p['title'], ''),
                          textOf(p['discount_rule'], ''),
                        ].where((s) => s.isNotEmpty).join(' · ')
                      ),
                  ],
                  onChanged: _useOffer,
                ),
              ),
            ]),
          StaffFormRow(children: [
            _field('Discount text', _discount,
                key: const Key('ad-discount'), hint: 'e.g. 20% OFF'),
            StaffField(
              label: 'Placement',
              child: StaffSelect<String>(
                key: const Key('ad-placement'),
                value: _placement,
                items: _placements,
                onChanged: (v) => setState(() => _placement = v ?? _placement),
              ),
            ),
          ]),
          StaffFormRow(children: [
            _field('Banner image URL', _banner,
                key: const Key('ad-banner'), hint: 'https://…'),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: MasterButton(
                key: const Key('ad-submit'),
                label: _busy ? 'Submitting…' : 'Submit for approval',
                kind: MasterButtonKind.primary,
                onPressed: _busy ? null : _submit),
          ),
        ]),
      );
}
