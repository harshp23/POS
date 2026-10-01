import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

/// The campaign builder and the create-offer dialog. They are exported by
/// marketing_screen.dart and also opened from Customers & CRM (dashboard
/// quick actions, segment members, ideas).

// ── shared helpers ─────────────────────────────────────────────────────────

/// Campaign channels the backend accepts.
const kMarketingChannels = [
  ('whatsapp', 'WhatsApp'),
  ('sms', 'SMS'),
  ('email', 'Email'),
  ('push', 'Push'),
];

String marketingChannelLabel(dynamic channel) => switch ('${channel ?? ''}') {
      'whatsapp' => 'WhatsApp',
      'sms' => 'SMS',
      'email' => 'Email',
      'push' => 'Push',
      final other => humanize(other),
    };

IconData marketingChannelIcon(dynamic channel) => switch ('${channel ?? ''}') {
      'whatsapp' => Icons.chat_outlined,
      'sms' => Icons.sms_outlined,
      'email' => Icons.mail_outline,
      'push' => Icons.notifications_none,
      _ => Icons.campaign_outlined,
    };

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-');

DateTime? _localTime(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  if (d == null) return null;
  return d.isUtc ? d.toLocal() : d;
}

/// Tells the user what happened to a sent campaign — the server's
/// status_note says whether anything was delivered (without a connected
/// messaging provider nothing is).
Future<void> showCampaignOutcome(
    BuildContext context, Map<String, dynamic> row) {
  final note = '${row['status_note'] ?? ''}'.trim();
  final notSent = note.toLowerCase().startsWith('not sent');
  final audience = numOf(row['audience_count']).toInt();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StaffDialog(
      title: notSent ? 'Campaign queued — not delivered' : 'Campaign queued',
      subtitle: textOf(row['name'], ''),
      width: 520,
      actions: [
        MasterButton(
            key: const Key('campaign-outcome-ok'),
            label: 'OK',
            kind: MasterButtonKind.primary,
            onPressed: () => Navigator.pop(dialogContext)),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MasterBanner(
          tone: notSent ? PillTone.amber : PillTone.green,
          title: notSent ? 'Nothing was delivered' : 'Queued',
          message: note.isEmpty ? 'The campaign was queued.' : note,
        ),
        const SizedBox(height: 12),
        Text(
            '$audience customer${audience == 1 ? '' : 's'} in the audience '
            'after the opt-in filter.',
            style: MasterStyle.body),
      ]),
    ),
  );
}

/// Date + time box for optional timestamps (tap to pick, × to clear).
class _DateTimeBox extends StatelessWidget {
  const _DateTimeBox(
      {super.key,
      required this.value,
      required this.onChanged,
      this.hint = 'Not set',
      this.defaultTime = const TimeOfDay(hour: 12, minute: 0)});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hint;
  final TimeOfDay defaultTime;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final current = value;
    final start = current ?? now;
    final firstYear = start.year < now.year - 1 ? start.year : now.year - 1;
    final lastYear = start.year > now.year + 3 ? start.year : now.year + 3;
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(firstYear),
      lastDate: DateTime(lastYear, 12, 31),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          current == null ? defaultTime : TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    onChanged(DateTime(day.year, day.month, day.day, time.hour, time.minute));
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
            child: Text(v == null ? hint : fmtDateTime(v.toIso8601String()),
                overflow: TextOverflow.ellipsis,
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

Widget _textField(String label, TextEditingController controller,
        {Key? key,
        String? hint,
        bool required = false,
        int maxLines = 1,
        int? minLines,
        bool number = false,
        InputDecoration? decoration}) =>
    StaffField(
      label: label,
      required: required,
      child: TextField(
        key: key,
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        style: const TextStyle(fontSize: 13.5),
        decoration: decoration ?? staffInput(hint: hint),
      ),
    );

// ── campaign builder ───────────────────────────────────────────────────────

/// Opens the campaign builder. With an [existing] campaign (one that has an
/// `id`) it edits that draft / scheduled campaign; a map without `id`
/// only prefills the form (e.g. `{'segment': 'vip'}`). Returns true when
/// something was saved or sent.
Future<bool> showCampaignBuilder(BuildContext context, ProviyaaApiClient api,
    {Map<String, dynamic>? existing}) async {
  final result = await showDialog<(String, Map<String, dynamic>)>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CampaignBuilder(api: api, existing: existing),
  );
  if (result == null) return false;
  if (!context.mounted) return true;
  final (action, row) = result;
  final name = textOf(row['name'], 'Campaign');
  if (action == 'send') {
    await showCampaignOutcome(context, row);
  } else if (action == 'schedule') {
    showStaffNotice(
        context, 'Scheduled "$name" for ${fmtDateTime(row['schedule_at'])}');
  } else {
    showStaffNotice(
        context,
        existing?['id'] != null
            ? 'Saved "$name"'
            : 'Saved "$name" as a draft');
  }
  return true;
}

class _CampaignBuilder extends StatefulWidget {
  const _CampaignBuilder({required this.api, this.existing});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;

  @override
  State<_CampaignBuilder> createState() => _CampaignBuilderState();
}

class _CampaignBuilderState extends State<_CampaignBuilder> {
  static const _defaultMessage =
      'Hi {name}, we have something special for you this week. See you soon!';

  Map<String, dynamic> get _e => widget.existing ?? const <String, dynamic>{};
  String? get _id => _e['id'] == null ? null : '${_e['id']}';

  late final _name = TextEditingController(text: '${_e['name'] ?? ''}');
  late final _title = TextEditingController(text: '${_e['title'] ?? ''}');
  late final _message =
      TextEditingController(text: '${_e['message'] ?? _defaultMessage}');
  late String _channel = kMarketingChannels.any((c) => c.$1 == _e['channel'])
      ? '${_e['channel']}'
      : 'whatsapp';
  late final String _startSegment = '${_e['segment'] ?? 'all'}';
  late String _dynamic =
      _uuid.hasMatch(_startSegment) ? 'all' : _startSegment;
  late String _saved = _uuid.hasMatch(_startSegment) ? _startSegment : '';
  late String _offer = '${_e['offer_code'] ?? ''}';
  late DateTime? _scheduleAt = _localTime(_e['schedule_at']);
  late String _recurrence =
      const ['once', 'daily', 'weekly', 'monthly'].contains(_e['recurrence'])
          ? '${_e['recurrence']}'
          : 'once';

  List<Map<String, dynamic>> _system = const [];
  List<Map<String, dynamic>> _custom = const [];
  List<Map<String, dynamic>> _promotions = const [];
  bool _segmentsFailed = false;
  bool _segmentsLoaded = false;
  String _audience = 'Counting audience…';
  int _audienceCall = 0;

  /// The action being saved ('draft' / 'schedule' / 'send'), or null.
  String? _busy;
  String? _error;

  String get _segment => _saved.isNotEmpty ? _saved : _dynamic;

  @override
  void initState() {
    super.initState();
    _loadLists();
    _countAudience();
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final s = jsonMap(await widget.api.get('v1/crm/segments'));
      if (mounted) {
        setState(() {
          _system = jsonList(s['system']);
          _custom = jsonList(s['custom']);
          _segmentsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _segmentsFailed = true);
    }
    try {
      final p = jsonList(await widget.api.get('v1/marketing/promotions'));
      if (mounted) setState(() => _promotions = p);
    } catch (_) {
      // "No offer" stays available.
    }
  }

  Future<void> _countAudience() async {
    final call = ++_audienceCall;
    try {
      final a = jsonMap(await widget.api.get('v1/marketing/audience',
          query: {'segment': _segment, 'channel': _channel}));
      if (!mounted || call != _audienceCall) return;
      final reachable = numOf(a['reachable']).toInt();
      final total = numOf(a['total']).toInt();
      setState(() => _audience =
          'Audience after opt-in filter: $reachable customer${reachable == 1 ? '' : 's'}'
          '${total != reachable ? ' (of $total in the segment)' : ''}');
    } catch (e) {
      if (!mounted || call != _audienceCall) return;
      setState(() =>
          _audience = 'Audience could not be counted: ${apiErrorText(e)}');
    }
  }

  /// Applies a change that affects the audience, then recounts it.
  void _audienceChange(VoidCallback change) {
    setState(() {
      change();
      _audience = 'Counting audience…';
    });
    _countAudience();
  }

  Future<void> _submit(String action) async {
    final name = _name.text.trim();
    final message = _message.text.trim();
    final at = _scheduleAt;
    String? problem;
    if (name.isEmpty) {
      problem = 'Give the campaign a name.';
    } else if (message.isEmpty) {
      problem = 'Write the message.';
    } else if (action == 'schedule' &&
        (at == null || !at.isAfter(DateTime.now()))) {
      problem = 'Pick a time in the future to schedule the campaign.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final body = <String, dynamic>{
      'name': name,
      'channel': _channel,
      'segment': _segment,
      'offer_code': _offer.isEmpty ? null : _offer,
      'schedule_at': at?.toUtc().toIso8601String(),
      'recurrence': _recurrence,
      'title': _title.text.trim(),
      'message': message,
    };
    setState(() {
      _busy = action;
      _error = null;
    });
    try {
      final id = _id;
      Map<String, dynamic> row;
      if (id == null) {
        row = jsonMap(await widget.api
            .post('v1/marketing/campaigns', {...body, 'action': action}));
      } else {
        row = jsonMap(
            await widget.api.patch('v1/marketing/campaigns/$id', body));
        if (action == 'send') {
          row = jsonMap(
              await widget.api.post('v1/marketing/campaigns/$id/send'));
        }
      }
      if (mounted) Navigator.pop(context, (action, row));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = null;
          _error = apiErrorText(e);
        });
      }
    }
  }

  List<(String, String)> get _offerItems {
    final seen = <String>{};
    final items = <(String, String)>[('', 'No offer')];
    for (final p in _promotions) {
      final code = '${p['code'] ?? ''}'.trim();
      if (code.isEmpty || !seen.add(code)) continue;
      items.add((code, '$code · ${textOf(p['title'])}'));
    }
    if (_offer.isNotEmpty && !seen.contains(_offer)) {
      items.add((_offer, _offer));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final at = _scheduleAt;
    final editing = _id != null;
    final canSchedule = !editing && at != null && at.isAfter(DateTime.now());
    final dynamicItems = <(String, String)>[
      ('all', 'All customers'),
      for (final s in _system)
        ('${s['key']}', '${textOf(s['name'])} (${numOf(s['count']).toInt()})'),
      if (_dynamic != 'all' && !_system.any((s) => s['key'] == _dynamic))
        (_dynamic, humanize(_dynamic)),
    ];
    final savedItems = <(String, String)>[
      ('', 'None'),
      for (final s in _custom)
        ('${s['id']}', '${textOf(s['name'])} (${numOf(s['count']).toInt()})'),
      if (_saved.isNotEmpty && !_custom.any((s) => '${s['id']}' == _saved))
        (
          _saved,
          textOf(_e['segment_name'], '').isNotEmpty
              ? textOf(_e['segment_name'], '')
              : (_segmentsLoaded || _segmentsFailed
                  ? 'Deleted segment'
                  : 'Loading segment…')
        ),
    ];
    final idle = _busy == null;
    return StaffDialog(
      title: editing ? 'Edit campaign' : 'Campaign builder',
      subtitle: 'Customers only receive channels they opted in to.',
      width: 720,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: idle ? () => Navigator.pop(context) : null),
        MasterButton(
            key: const Key('campaign-save-draft'),
            label: _busy == 'draft'
                ? 'Saving…'
                : (editing ? 'Save changes' : 'Save draft'),
            onPressed: idle ? () => _submit('draft') : null),
        if (canSchedule)
          MasterButton(
              key: const Key('campaign-schedule'),
              label: _busy == 'schedule' ? 'Scheduling…' : 'Schedule',
              icon: Icons.schedule,
              onPressed: idle ? () => _submit('schedule') : null),
        MasterButton(
            key: const Key('campaign-send'),
            label: _busy == 'send' ? 'Sending…' : 'Send now',
            icon: Icons.send,
            kind: MasterButtonKind.primary,
            onPressed: idle ? () => _submit('send') : null),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          _textField('Campaign name', _name,
              key: const Key('campaign-name'),
              hint: 'e.g. Weekend win-back',
              required: true),
          StaffField(
            label: 'Channel',
            child: StaffSelect<String>(
              key: const Key('campaign-channel'),
              value: _channel,
              items: kMarketingChannels,
              onChanged: (v) {
                if (v == null || v == _channel) return;
                _audienceChange(() => _channel = v);
              },
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Dynamic segment',
            child: StaffSelect<String>(
              key: const Key('campaign-segment'),
              value: _dynamic,
              items: dynamicItems,
              onChanged: (v) {
                if (v == null) return;
                _audienceChange(() {
                  _dynamic = v;
                  if (v != 'all') _saved = '';
                });
              },
            ),
          ),
          StaffField(
            label: 'Saved segment',
            child: StaffSelect<String>(
              key: const Key('campaign-saved-segment'),
              value: _saved,
              items: savedItems,
              onChanged: (v) {
                if (v == null) return;
                _audienceChange(() {
                  _saved = v;
                  if (v.isNotEmpty) _dynamic = 'all';
                });
              },
            ),
          ),
        ]),
        if (_segmentsFailed)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: MasterBanner(
              tone: PillTone.amber,
              message: 'Segments could not be loaded (they come from '
                  'Customers & CRM), so this campaign goes to all customers.',
            ),
          ),
        StaffFormRow(children: [
          StaffField(
            label: 'Attach offer',
            child: StaffSelect<String>(
              key: const Key('campaign-offer'),
              value: _offer,
              items: _offerItems,
              onChanged: (v) => setState(() => _offer = v ?? ''),
            ),
          ),
          StaffField(
            label: 'Schedule at',
            child: _DateTimeBox(
              key: const Key('campaign-schedule-at'),
              value: at,
              hint: 'Not scheduled',
              onChanged: (v) => setState(() => _scheduleAt = v),
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Recurrence',
            child: StaffSelect<String>(
              key: const Key('campaign-recurrence'),
              value: _recurrence,
              items: const [
                ('once', 'One-off'),
                ('daily', 'Daily'),
                ('weekly', 'Weekly'),
                ('monthly', 'Monthly'),
              ],
              onChanged: (v) => setState(() => _recurrence = v ?? 'once'),
            ),
          ),
          const SizedBox.shrink(),
        ]),
        StaffFormRow(children: [
          _textField('Title / subject', _title,
              key: const Key('campaign-title'),
              hint: 'Shown as the email subject or push title'),
        ]),
        _textField('Message', _message,
            key: const Key('campaign-message'),
            required: true,
            maxLines: 6,
            minLines: 4),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Use {name} to personalize.', style: MasterStyle.muted),
        ),
        const SizedBox(height: 14),
        Container(
          key: const Key('campaign-audience'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_audience,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
        ),
        if (at != null || _recurrence != 'once')
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
                'The schedule and recurrence are saved with the campaign. '
                'Nothing is delivered until a messaging provider is connected '
                'in Integrations → Connected apps.',
                style: MasterStyle.muted),
          ),
        if (editing && at != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Saving changes keeps the campaign\'s current status; use '
                'Send now to queue it.',
                style: MasterStyle.muted),
          ),
      ]),
    );
  }
}

// ── create offer ───────────────────────────────────────────────────────────

/// Opens "Create new offer". [existing] (a promotion row from
/// GET v1/marketing/promotions) edits that offer; [prefill] starts a new
/// one from e.g. an idea's `offer` ({title, campaign_type, linked_items}).
/// Returns true when saved.
Future<bool> showCreateOfferDialog(BuildContext context, ProviyaaApiClient api,
    {Map<String, dynamic>? existing, Map<String, dynamic>? prefill}) async {
  final saved = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _OfferDialog(api: api, existing: existing, prefill: prefill),
  );
  if (saved == null) return false;
  if (context.mounted) {
    final label = textOf(saved['code'], textOf(saved['title'], 'offer'));
    showStaffNotice(
        context, existing == null ? 'Created offer $label' : 'Saved $label');
  }
  return true;
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.api, this.existing, this.prefill});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? prefill;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  static const _offerTypes = [
    ('promo_code', 'Promo Code'),
    ('auto_apply', 'Auto-apply'),
    ('combo', 'Combo'),
    ('free_delivery', 'Free delivery'),
  ];
  static const _channelOptions = [
    ('pos', 'Store POS'),
    ('qr', 'QR Ordering'),
    ('app', 'Online App'),
  ];

  bool get _editing => widget.existing != null;
  Map<String, dynamic> get _e =>
      widget.existing ?? widget.prefill ?? const <String, dynamic>{};

  static String _numText(dynamic v) =>
      v == null || '$v'.trim().isEmpty ? '' : staffNumText(numOf(v));

  late final _title = TextEditingController(text: '${_e['title'] ?? ''}');
  late final _code = TextEditingController(
      text: _editing ? '${_e['code'] ?? ''}' : '');
  late final _value = TextEditingController(text: _initialValue());
  late final _maxDiscount = TextEditingController(
      text: _editing ? _numText(_e['max_discount']) : '');
  late final _minOrder =
      TextEditingController(text: _editing ? _numText(_e['min_order']) : '');
  late final _limit = TextEditingController(
      text: _e['per_customer_limit'] == null
          ? '1'
          : _numText(_e['per_customer_limit']));
  /// Linked menu items, saved as their names separated by commas.
  late List<String> _linked = distinctText('${_e['linked_items'] ?? ''}'
      .split(',')
      .map((s) => s.trim()));

  /// Menu item names to link (null while loading).
  List<String>? _menuItems;
  late String _offerType = _initialOfferType();
  late String _discountType = _initialDiscountType();
  late String _segment = '${_e['target_segment'] ?? 'all'}';
  late DateTime? _from = _localTime(_e['start_date']);
  late DateTime? _until = _localTime(_e['end_date']);
  late final Set<String> _channels = _initialChannels();
  late bool _autoApply = _e['auto_apply'] == true;
  late bool _active = !_editing ||
      !const ['Paused', 'Inactive', 'Cancelled'].contains('${_e['status']}');

  List<Map<String, dynamic>> _system = const [];
  List<Map<String, dynamic>> _custom = const [];
  bool _segmentsLoaded = false;
  bool _saving = false;
  String? _error;

  String _campaignType() => '${_e['campaign_type'] ?? ''}';

  String _initialOfferType() {
    final t = '${_e['offer_type'] ?? ''}';
    if (_offerTypes.any((o) => o.$1 == t)) return t;
    return _campaignType() == 'Combo Deal' ? 'combo' : 'promo_code';
  }

  String _initialDiscountType() {
    final t = '${_e['discount_type'] ?? ''}';
    if (t == 'percent' || t == 'flat') return t;
    if (_campaignType() == 'Flat Discount') return 'flat';
    if (_campaignType() == 'Percentage Off') return 'percent';
    return '${_e['discount_rule'] ?? ''}'.trim().startsWith('₹')
        ? 'flat'
        : 'percent';
  }

  String _initialValue() {
    if (_e['discount_value'] != null) return _numText(_e['discount_value']);
    final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)')
        .firstMatch('${_e['discount_rule'] ?? ''}');
    return m?.group(1) ?? '';
  }

  Set<String> _initialChannels() {
    const byLabel = {
      'pos dine-in': 'pos',
      'pos': 'pos',
      'qr ordering': 'qr',
      'qr': 'qr',
      'app': 'app',
      'online app': 'app',
    };
    final raw = _e['channels'];
    final parts =
        raw is List ? [for (final x in raw) '$x'] : '${raw ?? ''}'.split(',');
    final out = <String>{
      for (final p in parts)
        if (byLabel[p.trim().toLowerCase()] != null)
          byLabel[p.trim().toLowerCase()]!
    };
    return out.isEmpty ? {'pos', 'qr', 'app'} : out;
  }

  @override
  void initState() {
    super.initState();
    _loadSegments();
    _loadMenuItems();
  }

  @override
  void dispose() {
    for (final c in [_title, _code, _value, _maxDiscount, _minOrder, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMenuItems() async {
    try {
      final rows = jsonList(await widget.api
          .get('v1/master/menu-items', query: const {'limit': '500'}));
      if (mounted) {
        setState(() => _menuItems = distinctText([
              for (final r in rows) r['name'],
            ]));
      }
    } catch (_) {
      if (mounted) setState(() => _menuItems = const []);
    }
  }

  Future<void> _pickItems() async {
    final picked = await showBizMultiPick(
      context,
      title: 'Linked items',
      subtitle: 'Menu items this offer applies to',
      options: _menuItems ?? const [],
      selected: _linked,
      searchHint: 'Search menu items…',
      emptyText: 'No menu items yet. Add dishes in Master → Menu.',
    );
    if (picked != null && mounted) setState(() => _linked = picked);
  }

  Future<void> _loadSegments() async {
    try {
      final s = jsonMap(await widget.api.get('v1/crm/segments'));
      if (mounted) {
        setState(() {
          _system = jsonList(s['system']);
          _custom = jsonList(s['custom']);
          _segmentsLoaded = true;
        });
      }
    } catch (_) {
      // "All customers" stays available.
      if (mounted) setState(() => _segmentsLoaded = true);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final code = _code.text.trim().toUpperCase();
    final value = double.tryParse(_value.text.trim());
    final maxText = _maxDiscount.text.trim();
    final minText = _minOrder.text.trim();
    final limitText = _limit.text.trim();
    final maxDiscount = maxText.isEmpty ? 0.0 : double.tryParse(maxText);
    final minOrder = minText.isEmpty ? 0.0 : double.tryParse(minText);
    final limit = limitText.isEmpty ? 1 : int.tryParse(limitText);
    final from = _from;
    final until = _until;
    String? problem;
    if (title.isEmpty) {
      problem = 'Give the offer a name.';
    } else if (_offerType == 'promo_code' && code.isEmpty) {
      problem = 'A promo code offer needs a coupon code.';
    } else if (value == null || value < 0) {
      problem = 'Enter the discount value.';
    } else if (_discountType == 'percent' && value > 100) {
      problem = 'A percentage discount cannot be over 100%.';
    } else if (maxDiscount == null || maxDiscount < 0) {
      problem = 'Max discount must be a number (0 for no cap).';
    } else if (minOrder == null || minOrder < 0) {
      problem = 'Min order value must be a number (0 for none).';
    } else if (limit == null || limit < 0) {
      problem = 'Usage limit per customer must be a whole number.';
    } else if (_channels.isEmpty) {
      problem = 'Pick at least one channel.';
    } else if (from != null && until != null && !until.isAfter(from)) {
      problem = '"Valid until" must be after "Valid from".';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final body = <String, dynamic>{
      'title': title,
      'offer_type': _offerType,
      'code': code,
      'target_segment': _segment,
      'discount_type': _discountType,
      'discount_value': value,
      'max_discount': maxDiscount,
      'min_order': minOrder,
      'per_customer_limit': limit,
      'start_date': from?.toUtc().toIso8601String(),
      'end_date': until?.toUtc().toIso8601String(),
      'channels': [
        for (final c in _channelOptions)
          if (_channels.contains(c.$1)) c.$1
      ],
      'auto_apply': _autoApply,
      'active': _active,
      'linked_items': _linked.join(', '),
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final out = existing == null
          ? await widget.api.post('v1/marketing/promotions', body)
          : await widget.api
              .patch('v1/marketing/promotions/${existing['id']}', body);
      if (mounted) Navigator.pop(context, jsonMap(out));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  Widget _channelCheck(String value, String label) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _channels.contains(value)
            ? _channels.remove(value)
            : _channels.add(value)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
            key: Key('offer-channel-$value'),
            value: _channels.contains(value),
            activeColor: ViniiColors.greenSolid,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => setState(
                () => v == true ? _channels.add(value) : _channels.remove(value)),
          ),
          Text(label, style: MasterStyle.body),
          const SizedBox(width: 10),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final segmentItems = <(String, String)>[
      ('all', 'All customers'),
      for (final s in _system) ('${s['key']}', textOf(s['name'])),
      for (final s in _custom) ('${s['id']}', textOf(s['name'])),
    ];
    if (!segmentItems.any((i) => i.$1 == _segment)) {
      final name = textOf(_e['target_segment_name'], '');
      segmentItems.add((
        _segment,
        name.isNotEmpty
            ? name
            : (!_segmentsLoaded
                ? 'Loading segment…'
                : (isUuidLike(_segment)
                    ? 'Deleted segment'
                    : humanize(_segment)))
      ));
    }
    final percent = _discountType == 'percent';
    return StaffDialog(
      title: _editing ? 'Edit offer' : 'Create new offer',
      subtitle: 'Saved with your offers in Master → Offers.',
      width: 700,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('offer-save'),
            label: _saving
                ? 'Saving…'
                : (_editing ? 'Save offer' : 'Create offer'),
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          _textField('Offer name', _title,
              key: const Key('offer-name'),
              hint: 'e.g. Monsoon Feast Special',
              required: true),
          StaffField(
            label: 'Offer type',
            child: StaffSelect<String>(
              key: const Key('offer-type'),
              value: _offerType,
              items: _offerTypes,
              onChanged: (v) => setState(() => _offerType = v ?? _offerType),
            ),
          ),
        ]),
        StaffFormRow(children: [
          _textField('Coupon code', _code,
              key: const Key('offer-code'),
              hint: _offerType == 'promo_code'
                  ? 'e.g. MONSOON50'
                  : 'Optional — made from the name when empty',
              required: _offerType == 'promo_code'),
          StaffField(
            label: 'Target segment',
            child: StaffSelect<String>(
              key: const Key('offer-segment'),
              value: _segment,
              items: segmentItems,
              onChanged: (v) => setState(() => _segment = v ?? 'all'),
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Discount type / value',
            required: true,
            child: Row(children: [
              Expanded(
                child: StaffSelect<String>(
                  key: const Key('offer-discount-type'),
                  value: _discountType,
                  items: const [
                    ('percent', 'Percentage (% off)'),
                    ('flat', 'Flat (₹ off)'),
                  ],
                  onChanged: (v) =>
                      setState(() => _discountType = v ?? _discountType),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const Key('offer-discount-value'),
                  controller: _value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: staffInput(
                          hint: '0', prefix: percent ? null : '₹ ')
                      .copyWith(suffixText: percent ? '%' : null),
                ),
              ),
            ]),
          ),
          _textField('Max discount (₹)', _maxDiscount,
              key: const Key('offer-max-discount'),
              hint: '0 = no cap',
              number: true),
        ]),
        StaffFormRow(children: [
          _textField('Min order value (₹)', _minOrder,
              key: const Key('offer-min-order'), hint: '0', number: true),
          _textField('Usage limit per customer', _limit,
              key: const Key('offer-usage-limit'),
              hint: '0 = unlimited',
              number: true),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Valid from',
            child: _DateTimeBox(
              key: const Key('offer-valid-from'),
              value: _from,
              hint: 'Starts now',
              defaultTime: const TimeOfDay(hour: 0, minute: 0),
              onChanged: (v) => setState(() => _from = v),
            ),
          ),
          StaffField(
            label: 'Valid until',
            child: _DateTimeBox(
              key: const Key('offer-valid-until'),
              value: _until,
              hint: 'No end date',
              defaultTime: const TimeOfDay(hour: 23, minute: 59),
              onChanged: (v) => setState(() => _until = v),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: BizPickField(
            boxKey: const Key('offer-linked-items'),
            label: 'Linked items',
            values: _linked,
            hint: _menuItems == null
                ? 'Loading menu items…'
                : 'Optional — pick menu items',
            onTap: _menuItems == null ? null : _pickItems,
          ),
        ),
        StaffField(
          label: 'Applicable channels',
          child: Wrap(runSpacing: 4, children: [
            for (final c in _channelOptions) _channelCheck(c.$1, c.$2),
          ]),
        ),
        const SizedBox(height: 14),
        StaffFormRow(children: [
          BizToggle(
            key: const Key('offer-auto-apply'),
            label: 'Auto-apply best offer',
            value: _autoApply,
            onChanged: (v) => setState(() => _autoApply = v),
          ),
          BizToggle(
            key: const Key('offer-active'),
            label: 'Active status',
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ]),
      ]),
    );
  }
}
