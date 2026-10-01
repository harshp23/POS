import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// Offer statuses understood by the Offers hub and the form.
const offerStatusOptions = [
  'Draft',
  'Approved',
  'Scheduled',
  'Active',
  'Paused',
  'Inactive',
  'Cancelled',
];

/// Campaign types offered in the form (plus any found in existing data).
const offerCampaignTypes = [
  'Flat Discount',
  'Percentage Off',
  'BOGO Free',
  'Free Item',
  'Combo Deal',
];

/// Sales channels offered in the form — the shared Master channel list
/// (older stored spellings are mapped onto it when an offer is opened).
const offerBaseChannels = masterSalesChannels;

/// How the "Discount Rule" is built in the form. The rule is still stored
/// as text ("30% OFF (Upto ₹75)", "₹50 OFF", "Free Garlic Naan") so
/// [discountedPrice], imports and sync read it as before.
enum OfferDiscountKind { percent, flat, free }

extension OfferDiscountKindLabel on OfferDiscountKind {
  String get label => switch (this) {
        OfferDiscountKind.percent => 'Percentage off (%)',
        OfferDiscountKind.flat => 'Flat amount off (₹)',
        OfferDiscountKind.free => 'Free item',
      };
}

String _num2(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Rule text for a percentage / flat discount, e.g. "30% OFF (Upto ₹75)".
String offerDiscountRuleText(OfferDiscountKind kind, double value,
        {double maxDiscount = 0, String freeItem = ''}) =>
    switch (kind) {
      OfferDiscountKind.percent =>
        '${_num2(value)}% OFF${maxDiscount > 0 ? ' (Upto ₹${_num2(maxDiscount)})' : ''}',
      OfferDiscountKind.flat => '₹${_num2(value)} OFF',
      OfferDiscountKind.free =>
        freeItem.trim().isEmpty ? 'Free item' : 'Free ${freeItem.trim()}',
    };

/// Splits a stored comma/semicolon separated list ("POS, App").
List<String> splitOfferList(String s) => s
    .split(RegExp(r'[,;]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// Case-insensitive status lookup; returns the canonical spelling or null.
String? canonicalOfferStatus(String s) {
  final t = s.trim().toLowerCase();
  for (final o in offerStatusOptions) {
    if (o.toLowerCase() == t) return o;
  }
  return null;
}

bool _channelsOverlap(String a, String b) {
  final x = a.toLowerCase(), y = b.toLowerCase();
  return x == y || x.contains(y) || y.contains(x);
}

/// Other Active/Approved/Scheduled offers whose date ranges overlap [o] and
/// that share a channel or a linked menu item with it. A missing start or
/// end date is treated as open-ended.
List<(MasterOffer, List<String>)> offerConflicts(
    MasterOffer o, List<MasterOffer> all) {
  const live = {'active', 'approved', 'scheduled'};
  final aStart = o.startDate ?? DateTime(1900);
  final aEnd = o.endDate ?? DateTime(3000);
  final channels = splitOfferList(o.channels);
  final items = splitOfferList(o.linkedItems).map((e) => e.toLowerCase());
  final result = <(MasterOffer, List<String>)>[];
  for (final other in all) {
    if (other.id == o.id || !live.contains(other.status.toLowerCase())) {
      continue;
    }
    final bStart = other.startDate ?? DateTime(1900);
    final bEnd = other.endDate ?? DateTime(3000);
    if (aStart.isAfter(bEnd) || bStart.isAfter(aEnd)) continue;
    final shared = <String>[
      for (final c in splitOfferList(other.channels))
        if (channels.any((mine) => _channelsOverlap(mine, c))) c,
      for (final i in splitOfferList(other.linkedItems))
        if (items.contains(i.toLowerCase())) i,
    ];
    if (shared.isNotEmpty) result.add((other, shared));
  }
  return result;
}

/// Price after applying a free-text discount rule such as "30% OFF (Upto
/// ₹75)" or "₹50 off". Returns null when the rule has no price effect we can
/// compute (BOGO, free item…).
double? discountedPrice(double price, String rule, double maxDiscount) {
  final pct = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(rule);
  double? off;
  if (pct != null) {
    off = price * double.parse(pct.group(1)!) / 100;
  } else {
    final flat =
        RegExp(r'(?:₹|rs\.?|inr)\s*(\d+(?:\.\d+)?)\s*off', caseSensitive: false)
            .firstMatch(rule);
    if (flat != null) off = double.parse(flat.group(1)!);
  }
  if (off == null) return null;
  if (maxDiscount > 0 && off > maxDiscount) off = maxDiscount;
  return (price - off).clamp(0, double.infinity).toDouble();
}

/// Offer create/edit form (Figma node 385:55901), opened from the Campaigns &
/// Offers Hub. [offerId] null creates a new campaign.
class MasterOfferDetail extends StatefulWidget {
  const MasterOfferDetail(
      {super.key, required this.store, this.offerId, required this.onBack});
  final DriftMasterStore store;
  final String? offerId;
  final VoidCallback onBack;

  @override
  State<MasterOfferDetail> createState() => _MasterOfferDetailState();
}

class _MasterOfferDetailState extends State<MasterOfferDetail> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _code = TextEditingController();

  /// The number of the discount rule (percent or rupees).
  final _rule = TextEditingController();
  final _minOrder = TextEditingController();
  final _maxDiscount = TextEditingController();
  OfferDiscountKind _kind = OfferDiscountKind.percent;

  /// Dish given free (free-item rules); '' = as described / any item.
  String _freeItem = '';

  /// The rule text as loaded, kept word for word until the rule is edited
  /// (older free-text rules may say more than the form can rebuild).
  String _originalRule = '';
  bool _ruleTouched = false;
  String _type = offerCampaignTypes.first;
  String _status = 'Draft';
  DateTime? _start;
  DateTime? _end;
  final Set<String> _channels = {};
  final Set<String> _items = {};
  int _usage = 0;

  String? _id;
  bool _loaded = false;
  bool _missing = false;
  bool _saving = false;
  List<MasterOffer> _offers = const [];
  List<MasterDishItem> _dishes = const [];
  StreamSubscription<List<MasterOffer>>? _offerSub;
  StreamSubscription<List<MasterDishItem>>? _dishSub;

  @override
  void initState() {
    super.initState();
    _id = widget.offerId;
    _loaded = _id == null;
    for (final c in [_title, _code, _rule, _minOrder, _maxDiscount]) {
      c.addListener(_onEdited);
    }
    _offerSub = widget.store.watchOffers().listen((list) {
      if (!mounted) return;
      setState(() {
        _offers = list;
        if (!_loaded) {
          _loaded = true;
          final o = list.where((e) => e.id == _id).firstOrNull;
          if (o == null) {
            _missing = true;
          } else {
            _fill(o);
          }
        } else if (_id != null) {
          final o = list.where((e) => e.id == _id).firstOrNull;
          if (o != null) _usage = o.usageCount;
        }
      });
    });
    _dishSub = widget.store.watchDishes().listen((d) {
      if (mounted) setState(() => _dishes = d);
    });
  }

  void _onEdited() {
    if (mounted) setState(() {});
  }

  /// Reads a stored rule ("30% OFF (Upto ₹75)", "₹50 off", "Free Dessert
  /// on ₹199") into the kind + value controls.
  void _parseRule(String rule) {
    final t = rule.trim();
    _originalRule = t;
    _ruleTouched = false;
    _freeItem = '';
    final pct = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(t);
    final flat =
        RegExp(r'(?:₹|rs\.?|inr)\s*(\d+(?:\.\d+)?)\s*off', caseSensitive: false)
            .firstMatch(t);
    if (pct != null) {
      _kind = OfferDiscountKind.percent;
      _rule.text = pct.group(1)!;
    } else if (flat != null) {
      _kind = OfferDiscountKind.flat;
      _rule.text = flat.group(1)!;
    } else if (t.isEmpty) {
      _kind = OfferDiscountKind.percent;
      _rule.text = '';
    } else {
      _kind = OfferDiscountKind.free;
      _rule.text = '';
      final m = RegExp(r'^free\s+(.+)$', caseSensitive: false).firstMatch(t);
      final item = m?.group(1)?.trim() ?? '';
      // "Free Garlic Naan" names a dish; "Free item on ₹350+" does not.
      if (item.isNotEmpty &&
          _dishes.any((d) => d.name.toLowerCase() == item.toLowerCase())) {
        _freeItem =
            _dishes.firstWhere((d) => d.name.toLowerCase() == item.toLowerCase()).name;
      }
    }
  }

  /// The discount value: the first number in the field, so "20", "20%" or
  /// "₹50" all read as a number. Null when there is none.
  static double? _firstNumber(String text) {
    final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(text.replaceAll(',', ''));
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  /// The rule text saved with the offer.
  String get _ruleText {
    if (!_ruleTouched && _originalRule.isNotEmpty) return _originalRule;
    if (_kind == OfferDiscountKind.free) {
      return offerDiscountRuleText(_kind, 0, freeItem: _freeItem);
    }
    final v = _firstNumber(_rule.text);
    if (v == null) return '';
    return offerDiscountRuleText(_kind, v, maxDiscount: _num(_maxDiscount));
  }

  void _fill(MasterOffer o) {
    _title.text = o.title;
    _code.text = o.code;
    _parseRule(o.discountRule);
    _minOrder.text = o.minOrder == 0 ? '' : o.minOrder.toStringAsFixed(2);
    _maxDiscount.text =
        o.maxDiscount == 0 ? '' : o.maxDiscount.toStringAsFixed(2);
    _type = o.campaignType;
    _status = canonicalOfferStatus(o.status) ?? o.status;
    _start = o.startDate;
    _end = o.endDate;
    _channels
      ..clear()
      ..addAll(splitOfferList(o.channels).map(canonicalSalesChannel));
    _items
      ..clear()
      ..addAll(splitOfferList(o.linkedItems));
    _usage = o.usageCount;
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _dishSub?.cancel();
    for (final c in [_title, _code, _rule, _minOrder, _maxDiscount]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  MasterOffer _build({String? status}) => MasterOffer(
        id: _id ?? 'OFF-${DateTime.now().millisecondsSinceEpoch}',
        title: _title.text.trim(),
        code: _code.text.trim().toUpperCase(),
        campaignType: _type,
        discountRule: _ruleText,
        status: status ?? _status,
        minOrder: _num(_minOrder),
        maxDiscount: _num(_maxDiscount),
        startDate: _start,
        endDate: _end,
        channels: _channels.join(', '),
        linkedItems: _items.join(', '),
        usageCount: _usage,
      );

  Future<void> _save(String status, String success) async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      showMasterError(context, 'Fix the highlighted fields first.');
      return;
    }
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      showMasterError(context, 'End date must be on or after the start date.');
      return;
    }
    final offer = _build(status: status);
    if (status == 'Active') {
      final conflicts = offerConflicts(offer, _offers);
      if (conflicts.isNotEmpty) {
        final ok = await confirmMasterAction(context,
            title: 'Publish with conflicts?',
            message:
                '${offer.title} overlaps with ${conflicts.map((c) => '"${c.$1.title}"').join(', ')}. '
                'Customers could receive stacked discounts. Publish anyway?',
            confirmLabel: 'Publish',
            destructive: false);
        if (!ok || !mounted) return;
      }
    }
    setState(() => _saving = true);
    final ok = await runMasterAction(
        context, () => widget.store.upsertOffer(offer),
        success: success);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _id = offer.id;
        _status = status;
        _code.text = offer.code;
      }
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _start : _end) ?? _start ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: start ? 'Campaign start date' : 'Campaign end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _editItems() async {
    final names = {for (final d in _dishes) d.name, ..._items}.toList()..sort();
    final result = await showMasterMultiSelect(
      context,
      title: 'Eligible menu items',
      options: names,
      selected: _items,
      emptyText: 'No menu items yet — add items in Master › Menu Items.',
    );
    if (result == null || !mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_missing) {
      return MasterPage(children: [
        MasterBackLink(
            label: 'Back to Campaigns & Offers', onTap: widget.onBack),
        const MasterBanner(
            tone: PillTone.red,
            icon: '⚠️',
            message: 'This campaign no longer exists — it may have been '
                'deleted.'),
      ]);
    }

    final current = _build();
    final conflicts = offerConflicts(current, _offers);
    final isNew = _id == null;

    final left =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _basicInfo(),
      const SizedBox(height: 24),
      _eligibleItems(current),
    ]);
    final right =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _schedule(),
      const SizedBox(height: 20),
      _audit(isNew),
    ]);

    return Form(
      key: _formKey,
      child: MasterPage(children: [
        MasterBackLink(
            label: 'Back to Campaigns & Offers', onTap: widget.onBack),
        MasterPageHeader(
          title: isNew
              ? 'Create Campaign'
              : 'Configure ${_title.text.trim().isEmpty ? 'Campaign' : _title.text.trim()}',
          titleTrailing: MasterStatusPill(_status),
          subtitle: isNew
              ? 'New campaign — not saved yet'
              : 'Coupon ${_code.text.trim().isEmpty ? '—' : _code.text.trim().toUpperCase()} · $_usage redemption${_usage == 1 ? '' : 's'}',
          actions: [
            MasterButton(
                label: 'Save Draft',
                onPressed: _saving
                    ? null
                    : () => _save('Draft', 'Campaign saved as draft')),
            MasterButton(
                label: 'Save Changes',
                onPressed: _saving
                    ? null
                    : () => _save(_status, 'Campaign saved ($_status)')),
            MasterButton(
                label: 'Publish Offer',
                kind: MasterButtonKind.primary,
                onPressed: _saving
                    ? null
                    : () => _save('Active', 'Offer published — now Active')),
          ],
        ),
        if (conflicts.isNotEmpty) ...[
          MasterBanner(
            icon: '⚠️',
            message: 'Promotion Conflict Warning: this campaign overlaps with '
                '${conflicts.map((c) => '"${c.$1.title}" (${c.$1.status} · ${c.$1.dateRange} · shared: ${c.$2.join(', ')})').join('; ')}. '
                'Stagger active periods to prevent double-discounting margin '
                'degradation.',
            trailing: MasterStatusPill(
                '${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}',
                tone: PillTone.amber),
          ),
          const SizedBox(height: 24),
        ],
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 24), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 692, child: left),
            const SizedBox(width: 24),
            Expanded(flex: 420, child: right),
          ]);
        }),
      ]),
    );
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? '$what is required' : null;

  String? _money(String? v) {
    final t = (v ?? '').trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Must be 0 or more';
    return null;
  }

  Widget _basicInfo() {
    final types = {...offerCampaignTypes, _type}.toList();
    return MasterSection(
      title: 'Basic Campaign Information',
      child: MasterGrid(
        columns: 2,
        minItemWidth: 200,
        children: [
          _OfferField(
              label: 'Offer Title',
              controller: _title,
              hint: 'e.g. Swiggy Super Weekend Fest',
              validator: (v) => _required(v, 'Title')),
          _OfferField(
              label: 'Coupon Code',
              controller: _code,
              hint: 'e.g. SUPERFEST30',
              capitalization: TextCapitalization.characters,
              validator: (v) {
                final r = _required(v, 'Coupon code');
                if (r != null) return r;
                if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v!.trim())) {
                  return 'Letters, digits, - and _ only';
                }
                return null;
              }),
          _OfferDropdown(
              label: 'Campaign Type',
              value: _type,
              options: types,
              onChanged: (v) => setState(() => _type = v)),
          _discountRuleField(),
          _OfferField(
              label: 'Minimum Cart Value (₹)',
              controller: _minOrder,
              hint: '0.00',
              numeric: true,
              validator: _money),
          _OfferField(
              label: 'Max Discount Cap (₹)',
              controller: _maxDiscount,
              hint: '0.00 = no cap',
              numeric: true,
              validator: _money),
        ],
      ),
    );
  }

  /// Discount type (percent / flat ₹ / free item) + its value. Writes the
  /// same rule text as before ("30% OFF (Upto ₹75)", "₹50 OFF", "Free …").
  Widget _discountRuleField() {
    void touched() => setState(() => _ruleTouched = true);
    final dishNames = {for (final d in _dishes) d.name}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final legacyFree = _kind == OfferDiscountKind.free &&
            _freeItem.isEmpty &&
            !_ruleTouched &&
            _originalRule.isNotEmpty
        ? _originalRule
        : '';
    final Widget valueField = switch (_kind) {
      OfferDiscountKind.free => DropdownButtonFormField<String>(
          key: ValueKey('free-item-$_freeItem'),
          initialValue: _freeItem,
          isExpanded: true,
          style: const TextStyle(
              fontSize: 13, color: ViniiColors.textPrimaryLight),
          decoration: _decoration(),
          items: [
            DropdownMenuItem(
                value: '',
                child: Text(
                    legacyFree.isEmpty ? 'Any item' : 'As written: $legacyFree',
                    overflow: TextOverflow.ellipsis)),
            for (final n in {...dishNames, if (_freeItem.isNotEmpty) _freeItem})
              DropdownMenuItem(
                  value: n, child: Text(n, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _freeItem = v ?? '';
            _ruleTouched = true;
          }),
        ),
      _ => TextFormField(
          controller: _rule,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 13),
          decoration: _decoration(
                  hint: _kind == OfferDiscountKind.percent ? 'e.g. 30' : 'e.g. 50')
              .copyWith(
                  prefixText: _kind == OfferDiscountKind.flat ? '₹ ' : null,
                  suffixText: _kind == OfferDiscountKind.percent ? '%' : null),
          onChanged: (_) => touched(),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Discount value is required';
            final n = _firstNumber(t);
            if (n == null) return 'Enter a number';
            if (n <= 0) return 'Must be more than 0';
            if (_kind == OfferDiscountKind.percent && n > 100) {
              return 'At most 100%';
            }
            return null;
          },
        ),
    };
    final rule = _ruleText;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Discount Rule', style: _fieldLabel),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: DropdownButtonFormField<OfferDiscountKind>(
                key: ValueKey('discount-kind-$_kind'),
                initialValue: _kind,
                isExpanded: true,
                style: const TextStyle(
                    fontSize: 13, color: ViniiColors.textPrimaryLight),
                decoration: _decoration(),
                items: [
                  for (final k in OfferDiscountKind.values)
                    DropdownMenuItem(
                        value: k,
                        child: Text(k.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (k) {
                  if (k == null || k == _kind) return;
                  setState(() {
                    _kind = k;
                    _ruleTouched = true;
                    if (k == OfferDiscountKind.free) _rule.clear();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: valueField),
          ]),
          if (rule.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Shown as: $rule',
                overflow: TextOverflow.ellipsis, style: MasterStyle.muted),
          ],
        ]);
  }

  Widget _eligibleItems(MasterOffer current) {
    final byName = {for (final d in _dishes) d.name.toLowerCase(): d};
    return MasterSection(
      title: 'Eligible Menu Items',
      subtitle: _items.isEmpty ? 'No items linked — applies to the cart' : null,
      trailing: InkWell(
        onTap: _editItems,
        child: const Text('Bulk edit eligibility', style: MasterStyle.link),
      ),
      child: _items.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: MasterButton(
                  label: 'Link menu items',
                  icon: Icons.add,
                  onPressed: _editItems),
            )
          : MasterTable(
              minWidth: 560,
              columns: const [
                MasterColumn('Dish', flex: 224),
                MasterColumn('Base Price', flex: 110),
                MasterColumn('Post-Discount', flex: 110),
                MasterColumn('Food Cost %', flex: 100),
                MasterColumn('', flex: 40),
              ],
              rows: [
                for (final name in _items)
                  () {
                    final d = byName[name.toLowerCase()];
                    final post = d == null
                        ? null
                        : discountedPrice(d.sellingPrice, current.discountRule,
                            current.maxDiscount);
                    final basis = post ?? d?.sellingPrice ?? 0;
                    return <Widget>[
                      MasterCellTitle(name,
                          subtitle: d == null ? 'Not in menu' : d.category),
                      MasterCellText(
                          d == null ? '—' : formatInr(d.sellingPrice)),
                      MasterCellText(post == null ? '—' : formatInr(post),
                          bold: true, color: ViniiColors.emeraldText),
                      MasterCellText(d == null || basis <= 0
                          ? '—'
                          : '${(d.foodCost / basis * 100).toStringAsFixed(1)}%'),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close,
                            size: 16, color: ViniiColors.textMutedLight),
                        onPressed: () => setState(() => _items.remove(name)),
                      ),
                    ];
                  }(),
              ],
            ),
    );
  }

  Widget _schedule() {
    // The shared channel list, plus any unusual channel this offer already
    // has (so nothing stored is lost).
    final channelOptions = {
      ...offerBaseChannels,
      ..._channels,
    }.toList();
    final statuses = {...offerStatusOptions, _status}.toList();
    return MasterSection(
      title: 'Campaign Schedule',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _DateRow(
            label: 'Start Date',
            value: _start,
            onTap: () => _pickDate(start: true),
            onClear: () => setState(() => _start = null)),
        const SizedBox(height: 12),
        _DateRow(
            label: 'End Date',
            value: _end,
            onTap: () => _pickDate(start: false),
            onClear: () => setState(() => _end = null)),
        const SizedBox(height: 16),
        const Text('Target Channels', style: MasterStyle.label),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in channelOptions)
            FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 12)),
              selected: _channels.contains(c),
              selectedColor: ViniiColors.lightGreenTint,
              checkmarkColor: ViniiColors.emeraldText,
              visualDensity: VisualDensity.compact,
              onSelected: (v) =>
                  setState(() => v ? _channels.add(c) : _channels.remove(c)),
            ),
        ]),
        const SizedBox(height: 16),
        _OfferDropdown(
            label: 'Status',
            value: _status,
            options: statuses,
            onChanged: (v) => setState(() => _status = v)),
      ]),
    );
  }

  Widget _audit(bool isNew) => MasterSection(
        title: 'System Audit Summary',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MasterKeyValue(
              'Coupon',
              _code.text.trim().isEmpty
                  ? 'Not set yet'
                  : _code.text.trim().toUpperCase()),
          const SizedBox(height: 12),
          MasterKeyValue('Discount', () {
            final rule = _ruleText;
            return rule.isEmpty ? 'Not set yet' : rule;
          }()),
          const SizedBox(height: 12),
          MasterKeyValue('Redemptions', '$_usage'),
          const SizedBox(height: 12),
          MasterKeyValue('Target',
              _channels.isEmpty ? 'All channels' : _channels.join(', ')),
          const SizedBox(height: 12),
          const Text('Validation', style: MasterStyle.label),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
                _channels.isEmpty
                    ? Icons.info_outline
                    : Icons.verified_outlined,
                size: 16,
                color: _channels.isEmpty
                    ? ViniiColors.textMutedLight
                    : ViniiColors.greenSolid),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                  _channels.isEmpty
                      ? 'Pick at least one target channel'
                      : isNew
                          ? 'Ready to save'
                          : 'Saved in local database',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _channels.isEmpty
                          ? ViniiColors.textMutedLight
                          : ViniiColors.greenSolid)),
            ),
          ]),
        ]),
      );
}

InputDecoration _decoration({String? hint}) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
    );

const _fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: ViniiColors.textPrimaryLight);

/// Labelled, validated text input in the MasterTextField style.
class _OfferField extends StatelessWidget {
  const _OfferField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.numeric = false,
    this.capitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final bool numeric;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _fieldLabel),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              validator: validator,
              textCapitalization: capitalization,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration(hint: hint),
            ),
          ]);
}

class _OfferDropdown extends StatelessWidget {
  const _OfferDropdown(
      {required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _fieldLabel),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('$label=$value'),
              initialValue: value,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 13, color: ViniiColors.textPrimaryLight),
              decoration: _decoration(),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ]);
}

/// "Start Date   08 Sep 2026 [x]" row that opens a date picker.
class _DateRow extends StatelessWidget {
  const _DateRow(
      {required this.label,
      required this.value,
      required this.onTap,
      required this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(label,
                style: MasterStyle.body
                    .copyWith(color: ViniiColors.textSecondaryLight))),
        const SizedBox(width: 12),
        Flexible(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MasterStyle.cardBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: ViniiColors.textSecondaryLight),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      value == null ? 'Not set' : formatShortDate(value!),
                      overflow: TextOverflow.ellipsis,
                      style: MasterStyle.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value == null
                              ? ViniiColors.textMutedLight
                              : null)),
                ),
              ]),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: 'Clear',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close,
                size: 16, color: ViniiColors.textMutedLight),
            onPressed: onClear,
          ),
      ]);
}
