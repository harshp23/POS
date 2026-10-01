import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';
import 'crm_common.dart';
import 'marketing_screen.dart';

/// Customers & CRM → Segments: the built-in dynamic segments with their
/// live counts, and the restaurant's own rule-based segments
/// (GET/POST/DELETE v1/crm/segments).
class CrmSegmentsTab extends StatelessWidget {
  const CrmSegmentsTab({super.key, required this.api});
  final ProviyaaApiClient api;

  static String rulesText(Map<String, dynamic> rules) {
    final parts = <String>[];
    final tags = rules['tags'];
    if (tags is List && tags.isNotEmpty) parts.add('Tags: ${tags.join(', ')}');
    if (rules['min_spend'] != null) {
      parts.add('Spend ≥ ${crmMoney(rules['min_spend'])}');
    }
    if (rules['min_orders'] != null) {
      parts.add('${crmCount(rules['min_orders'])}+ orders');
    }
    if (rules['inactive_days'] != null) {
      parts.add('No order in ${crmCount(rules['inactive_days'])}+ days');
    }
    if (rules['channel'] != null) {
      parts.add('Ordered via ${crmChannelLabel(rules['channel'])}');
    }
    return parts.isEmpty ? 'Every customer' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/crm/segments')),
        builder: (context, d, reload) {
          final system = jsonList(d['system']);
          final custom = jsonList(d['custom']);
          final profiles = numOf(d['profiles']).toInt();

          Future<void> create() async {
            final saved = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _SegmentDialog(api: api),
            );
            if (saved == true && context.mounted) {
              showStaffNotice(context, 'Segment created');
              reload();
            }
          }

          Future<void> remove(Map<String, dynamic> s) async {
            final name = textOf(s['name'], 'this segment');
            final ok = await staffConfirm(context,
                title: 'Delete $name?',
                message: 'The segment is removed. Customers are not affected, '
                    'and campaigns already saved keep their audience count.');
            if (!ok || !context.mounted) return;
            final done = await runAction<bool>(context, () async {
              await api.delete('v1/crm/segments/${s['id']}');
              return true;
            }, success: 'Deleted $name');
            if (done == true && context.mounted) reload();
          }

          return BusinessPage(
            title: 'Segments',
            subtitle: 'Divide your customer base into lists for targeted '
                'campaigns and offers.',
            badge: '$profiles PROFILE${profiles == 1 ? '' : 'S'}',
            actions: [
              MasterButton(
                  key: const Key('crm-new-segment'),
                  label: 'New Segment',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: create),
            ],
            children: [
              const CrmHeading('System dynamic segments',
                  subtitle: 'Built-in rules that update automatically from '
                      'your bills and customer profiles. Tap one to see who '
                      'is in it.'),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: MasterGrid(columns: 4, minItemWidth: 200, children: [
                  for (final s in system)
                    _SegmentCard(
                      cardKey: Key('segment-${s['key']}'),
                      name: textOf(s['name']),
                      detail: textOf(s['rule']),
                      count: numOf(s['count']),
                      onTap: () => _showMembers(context, api, '${s['key']}',
                          textOf(s['name'])),
                    ),
                ]),
              ),
              CrmHeading('Custom user segments',
                  subtitle: 'Your own rules: tags, spend, visits, '
                      'inactivity or channel.',
                  trailing: MasterButton(
                      key: const Key('crm-create-segment'),
                      label: 'Create custom segment',
                      onPressed: create)),
              if (custom.isEmpty)
                const MasterCard(
                  child: Center(
                    child: StaffEmptyState(
                      icon: Icons.sell_outlined,
                      title: 'No custom segments yet',
                      message: 'Target buyers by tags, lifetime spend, number '
                          'of orders, inactivity or ordering channel.',
                    ),
                  ),
                )
              else
                MasterGrid(columns: 3, minItemWidth: 240, children: [
                  for (final s in custom)
                    _SegmentCard(
                      cardKey: Key('segment-custom-${s['id']}'),
                      name: textOf(s['name']),
                      detail: [
                        if ('${s['description'] ?? ''}'.trim().isNotEmpty)
                          '${s['description']}'.trim(),
                        rulesText(jsonMap(s['rules'])),
                      ].join('\n'),
                      count: numOf(s['count']),
                      onTap: () => _showMembers(
                          context, api, '${s['id']}', textOf(s['name'])),
                      onDelete: () => remove(s),
                    ),
                ]),
            ],
          );
        },
      );
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard(
      {required this.name,
      required this.detail,
      required this.count,
      this.onTap,
      this.onDelete,
      this.cardKey});
  final String name;
  final String detail;
  final num count;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MasterStyle.radius);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        key: cardKey,
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: MasterStyle.cardBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.textPrimaryLight)),
                  ),
                  const SizedBox(width: 8),
                  CrmCountPill(count),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    StaffIconAction(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete segment',
                        color: ViniiColors.redSolid,
                        onPressed: onDelete),
                  ],
                ]),
                const SizedBox(height: 10),
                Text(detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: MasterStyle.muted),
              ]),
        ),
      ),
    );
  }
}

/// Who is in a segment right now (GET v1/crm/segments/:key/customers),
/// with a shortcut to a campaign for them.
Future<void> _showMembers(BuildContext context, ProviyaaApiClient api,
        String key, String name) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StaffDialog(
        title: name,
        subtitle: 'Customers in this segment right now',
        width: 640,
        actions: [
          MasterButton(
              key: const Key('segment-members-campaign'),
              label: 'Create campaign',
              icon: Icons.send_outlined,
              onPressed: () {
                Navigator.pop(dialogContext);
                showCampaignBuilder(context, api, existing: {'segment': key});
              }),
          MasterButton(
              label: 'Close',
              kind: MasterButtonKind.primary,
              onPressed: () => Navigator.pop(dialogContext)),
        ],
        body: ApiLoader<List<Map<String, dynamic>>>(
          load: () async =>
              jsonList(await api.get('v1/crm/segments/$key/customers')),
          builder: (context, rows, _) => rows.isEmpty
              ? const StaffEmptyState(
                  icon: Icons.group_outlined,
                  title: 'Nobody is in this segment yet')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                            '${rows.length} customer${rows.length == 1 ? '' : 's'}',
                            style: MasterStyle.label),
                      ),
                      for (final c in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CrmCustomerLine(
                            name: crmName(c),
                            caption: '${crmCount(c['orders'])} order'
                                '${numOf(c['orders']) == 1 ? '' : 's'} · '
                                '${textOf(c['phone'])}',
                            trailing: crmMoney(c['spent']),
                            onTap: () =>
                                showCrmCustomerDetail(context, api, '${c['id']}'),
                          ),
                        ),
                    ]),
        ),
      ),
    );

class _SegmentDialog extends StatefulWidget {
  const _SegmentDialog({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_SegmentDialog> createState() => _SegmentDialogState();
}

class _SegmentDialogState extends State<_SegmentDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _minSpend = TextEditingController();
  final _minOrders = TextEditingController();
  final _inactive = TextEditingController();
  String _channel = '';
  Set<String> _tags = {};

  /// Tags used on customers (null while loading).
  List<String>? _knownTags;
  bool _saving = false;
  String? _error;

  static const _channels = [
    ('', 'Any channel'),
    ('dine_in', 'Dine-in'),
    ('delivery', 'Delivery'),
    ('pickup', 'Pickup'),
    ('online', 'QR / online ordering'),
    ('swiggy', 'Swiggy'),
    ('zomato', 'Zomato'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final rows = jsonList(await widget.api.get('v1/crm/customers'));
      if (mounted) setState(() => _knownTags = crmAllTags(rows));
    } catch (_) {
      if (mounted) setState(() => _knownTags = const []);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _minSpend, _minOrders, _inactive]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final spendText = _minSpend.text.trim();
    final ordersText = _minOrders.text.trim();
    final inactiveText = _inactive.text.trim();
    final minSpend = spendText.isEmpty ? null : double.tryParse(spendText);
    final minOrders = ordersText.isEmpty ? null : int.tryParse(ordersText);
    final inactive = inactiveText.isEmpty ? null : int.tryParse(inactiveText);
    String? problem;
    if (name.isEmpty) {
      problem = 'Give the segment a name.';
    } else if (spendText.isNotEmpty && (minSpend == null || minSpend < 0)) {
      problem = 'Minimum spend must be a number.';
    } else if (ordersText.isNotEmpty && (minOrders == null || minOrders < 0)) {
      problem = 'Minimum orders must be a whole number.';
    } else if (inactiveText.isNotEmpty && (inactive == null || inactive < 1)) {
      problem = 'Inactive days must be a whole number of at least 1.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final known = _knownTags ?? const <String>[];
    final tags = [
      for (final t in known)
        if (_tags.contains(t)) t
    ];
    final rules = <String, dynamic>{
      if (tags.isNotEmpty) 'tags': tags,
      if (minSpend != null) 'min_spend': minSpend,
      if (minOrders != null) 'min_orders': minOrders,
      if (inactive != null) 'inactive_days': inactive,
      if (_channel.isNotEmpty) 'channel': _channel,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/crm/segments', {
        'name': name,
        'description': _description.text.trim(),
        'rules': rules,
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

  Widget _field(String label, TextEditingController c,
          {required Key key, String? hint, bool required = false,
          bool number = false}) =>
      StaffField(
        label: label,
        required: required,
        child: TextField(
          key: key,
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(hint: hint),
        ),
      );

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Create custom segment',
        subtitle: 'A customer must match every rule you fill in. Leave a '
            'rule empty to ignore it.',
        width: 620,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.pop(context)),
          MasterButton(
              key: const Key('segment-save'),
              label: _saving ? 'Saving…' : 'Create segment',
              kind: MasterButtonKind.primary,
              onPressed: _saving ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            _field('Segment name', _name,
                key: const Key('segment-name'),
                hint: 'e.g. Weekend regulars',
                required: true),
          ]),
          StaffFormRow(children: [
            _field('Description', _description,
                key: const Key('segment-description'), hint: 'Optional'),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: StaffField(
              label: 'Customers with any of these tags',
              child: switch (_knownTags) {
                null => const Text('Loading tags…', style: MasterStyle.muted),
                final List<String> known when known.isEmpty => const Text(
                    'No customer has a tag yet. Add tags on a customer '
                    'profile to target them here.',
                    style: MasterStyle.muted),
                final List<String> known => BizChipSelect(
                    key: const Key('segment-tags'),
                    keyPrefix: 'segment-tag',
                    options: [for (final t in known) (t, t)],
                    selected: _tags,
                    onChanged: (v) => setState(() => _tags = v),
                  ),
              },
            ),
          ),
          StaffFormRow(children: [
            _field('Minimum lifetime spend (₹)', _minSpend,
                key: const Key('segment-min-spend'), hint: 'e.g. 5000',
                number: true),
            _field('Minimum paid orders', _minOrders,
                key: const Key('segment-min-orders'), hint: 'e.g. 3',
                number: true),
          ]),
          StaffFormRow(children: [
            _field('No order in the last (days)', _inactive,
                key: const Key('segment-inactive-days'), hint: 'e.g. 30',
                number: true),
            StaffField(
              label: 'Ordered via channel',
              child: StaffSelect<String>(
                key: const Key('segment-channel'),
                value: _channel,
                items: _channels,
                onChanged: (v) => setState(() => _channel = v ?? ''),
              ),
            ),
          ]),
        ]),
      );
}
