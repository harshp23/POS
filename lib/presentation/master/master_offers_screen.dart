import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_master_store.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_offer_detail.dart';
import 'master_ui.dart';

const _all = 'All';
const _pageSize = 10;

const _csvHeaders = [
  'id',
  'title',
  'code',
  'campaign_type',
  'discount_rule',
  'min_order',
  'max_discount',
  'start_date',
  'end_date',
  'channels',
  'linked_items',
  'status',
  'usage_count',
];

String _isoDate(DateTime? d) => d == null
    ? ''
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// "Campaigns & Offers Hub" (Figma offers hub), backed by the offers table.
/// Tapping a row, "Edit" or "Create Campaign" opens [MasterOfferDetail] in
/// place.
class MasterOffersScreen extends StatefulWidget {
  const MasterOffersScreen({super.key, required this.store});
  final DriftMasterStore store;

  @override
  State<MasterOffersScreen> createState() => _MasterOffersScreenState();
}

class _MasterOffersScreenState extends State<MasterOffersScreen> {
  StreamSubscription<List<MasterOffer>>? _sub;
  List<MasterOffer>? _offers;

  bool _detailOpen = false;
  String? _openId;
  String _query = '';
  String _type = _all;
  String _channel = _all;
  String _status = _all;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.store.watchOffers().listen((list) {
      if (mounted) setState(() => _offers = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<MasterOffer> get _all$ => _offers ?? const [];

  List<MasterOffer> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all$.where((o) {
      if (q.isNotEmpty &&
          !o.title.toLowerCase().contains(q) &&
          !o.code.toLowerCase().contains(q) &&
          !o.linkedItems.toLowerCase().contains(q)) {
        return false;
      }
      if (_type != _all && o.campaignType != _type) return false;
      if (_status != _all && o.status != _status) return false;
      if (_channel != _all &&
          !splitOfferList(o.channels)
              .any((c) => c.toLowerCase() == _channel.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void _open(String? id) => setState(() {
        _openId = id;
        _detailOpen = true;
      });

  List<String> _actionsFor(MasterOffer o) {
    final primary = switch (o.status) {
      'Active' => 'Pause',
      'Paused' || 'Inactive' => 'Resume',
      'Cancelled' => null,
      _ => 'Activate',
    };
    return ['Edit', if (primary != null) primary];
  }

  Future<void> _onAction(MasterOffer o, String action) async {
    final store = widget.store;
    switch (action) {
      case 'Edit':
        _open(o.id);
      case 'Pause':
        await runMasterAction(
            context, () => store.setOfferStatus(o.id, 'Paused'),
            success: '${o.title} paused');
      case 'Resume':
      case 'Activate':
        await runMasterAction(
            context, () => store.setOfferStatus(o.id, 'Active'),
            success: '${o.title} is now Active');
      case 'Cancel':
        final ok = await confirmMasterAction(context,
            title: 'Cancel campaign?',
            message:
                '${o.title} (${o.code}) will stop applying on all channels. You can clone it later.',
            confirmLabel: 'Cancel Campaign');
        if (!ok || !mounted) return;
        await runMasterAction(
            context, () => store.setOfferStatus(o.id, 'Cancelled'),
            success: '${o.title} cancelled');
      case 'Delete':
        final ok = await confirmMasterAction(context,
            title: 'Delete campaign?',
            message:
                'Permanently delete ${o.title} (${o.code})? This cannot be undone.');
        if (!ok || !mounted) return;
        await runMasterAction(context, () => store.deleteOffer(o.id),
            success: '${o.title} deleted');
      case 'Clone':
        MasterOffer? copy;
        final ok = await runMasterAction(
            context, () async => copy = await store.cloneOffer(o.id));
        if (ok && mounted && copy != null) {
          showMasterNotice(
              context, 'Cloned as ${copy!.code} (Draft) — opening it now');
          _open(copy!.id);
        }
      case 'Stats':
        _showStats(o);
    }
  }

  void _showStats(MasterOffer o) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String timing;
    if (o.startDate == null) {
      timing = 'Not scheduled';
    } else if (o.startDate!.isAfter(today)) {
      timing = 'Starts in ${o.startDate!.difference(today).inDays} days';
    } else if (o.endDate != null && o.endDate!.isBefore(today)) {
      timing = 'Ended ${today.difference(o.endDate!).inDays} days ago';
    } else {
      final ran = today.difference(o.startDate!).inDays + 1;
      timing = o.endDate == null
          ? 'Running for $ran days (open-ended)'
          : 'Day $ran of ${o.endDate!.difference(o.startDate!).inDays + 1}';
    }
    final days = o.startDate == null
        ? 0
        : ((o.endDate != null && o.endDate!.isBefore(today)
                    ? o.endDate!
                    : today)
                .difference(o.startDate!)
                .inDays +
            1);
    final perDay =
        days > 0 && !o.startDate!.isAfter(today) ? o.usageCount / days : null;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${o.title} — Stats'),
        content: SizedBox(
          width: 440,
          child: MasterGrid(columns: 2, minItemWidth: 180, children: [
            MasterKeyValue('Coupon code', o.code),
            MasterKeyValue('Status', o.status),
            MasterKeyValue('Redemptions', '${o.usageCount}'),
            MasterKeyValue('Avg per day',
                perDay == null ? '—' : perDay.toStringAsFixed(1)),
            MasterKeyValue('Date range', o.dateRange),
            MasterKeyValue('Timing', timing),
            MasterKeyValue('Min order', formatInr(o.minOrder)),
            MasterKeyValue('Max discount',
                o.maxDiscount > 0 ? formatInr(o.maxDiscount) : 'No cap'),
            MasterKeyValue('Channels', o.channels.isEmpty ? 'All' : o.channels),
            MasterKeyValue('Linked items',
                o.linkedItems.isEmpty ? 'Whole cart' : o.linkedItems),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _export(List<MasterOffer> rows) async {
    final now = DateTime.now();
    await exportCsv(context,
        fileName: 'offers-${_isoDate(now)}.csv',
        headers: _csvHeaders,
        rows: [
          for (final o in rows)
            [
              o.id,
              o.title,
              o.code,
              o.campaignType,
              o.discountRule,
              _num(o.minOrder),
              _num(o.maxDiscount),
              _isoDate(o.startDate),
              _isoDate(o.endDate),
              o.channels,
              o.linkedItems,
              o.status,
              o.usageCount,
            ],
        ]);
  }

  Future<void> _import() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    final existing = await widget.store.getOffers();
    final byId = {for (final o in existing) o.id: o};
    final byCode = {for (final o in existing) o.code.toUpperCase(): o};
    var seq = 0;
    for (final r in records) {
      final err = <String>[];
      final title = r('title');
      final code = r('code').toUpperCase();
      if (title.isEmpty) err.add('title is required');
      if (code.isEmpty) {
        err.add('code is required');
      } else if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(code)) {
        err.add('code "$code" may only contain letters, digits, - and _');
      }
      double money(String h) {
        if (!r.has(h)) return 0;
        final v = r.number(h);
        if (v == null) {
          err.add('$h "${r(h)}" is not a number');
          return 0;
        }
        if (v < 0) err.add('$h must be 0 or more');
        return v;
      }

      DateTime? date(String h) {
        if (!r.has(h)) return null;
        final d = parseShortDate(r(h));
        if (d == null) err.add('$h "${r(h)}" is not a date (use YYYY-MM-DD)');
        return d;
      }

      final minOrder = money('min_order');
      final maxDiscount = money('max_discount');
      final start = date('start_date');
      final end = date('end_date');
      if (start != null && end != null && end.isBefore(start)) {
        err.add('end_date is before start_date');
      }
      var status = 'Draft';
      if (r.has('status')) {
        final s = canonicalOfferStatus(r('status'));
        if (s == null) {
          err.add('unknown status "${r('status')}" '
              '(use ${offerStatusOptions.join('/')})');
        } else {
          status = s;
        }
      }
      int? usage;
      if (r.has('usage_count')) {
        final u = int.tryParse(r('usage_count'));
        if (u == null || u < 0) {
          err.add('usage_count must be a whole number ≥ 0');
        } else {
          usage = u;
        }
      }
      if (err.isNotEmpty) {
        summary.errors.add('Line ${r.line}: ${err.join('; ')}');
        continue;
      }
      final match = byId[r('id')] ?? byCode[code];
      final offer = MasterOffer(
        id: match?.id ??
            (r.has('id')
                ? r('id')
                : 'OFF-${DateTime.now().millisecondsSinceEpoch}-${seq++}'),
        title: title,
        code: code,
        campaignType: r('campaign_type', offerCampaignTypes.first),
        discountRule: r('discount_rule'),
        status: status,
        minOrder: minOrder,
        maxDiscount: maxDiscount,
        startDate: start,
        endDate: end,
        channels: splitOfferList(r('channels')).join(', '),
        linkedItems: splitOfferList(r('linked_items')).join(', '),
        usageCount: usage ?? match?.usageCount ?? 0,
      );
      try {
        await widget.store.upsertOffer(offer);
        if (match == null) {
          summary.added++;
        } else {
          summary.updated++;
        }
        byId[offer.id] = offer;
        byCode[offer.code] = offer;
      } catch (e) {
        final why = masterErrorMessage(e,
            fallback: '"$title" could not be saved. Check the row and try again.');
        summary.errors.add('Line ${r.line}: $why');
      }
    }
    if (mounted) showImportSummary(context, summary);
  }

  @override
  Widget build(BuildContext context) {
    if (_detailOpen) {
      return MasterOfferDetail(
          key: ValueKey(_openId ?? 'new'),
          store: widget.store,
          offerId: _openId,
          onBack: () => setState(() {
                _detailOpen = false;
                _openId = null;
              }));
    }
    final loading = _offers == null;
    final all = _all$;
    final rows = _filtered;
    final pageCount = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final pageRows = rows.skip(page * _pageSize).take(_pageSize).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = all.where((o) => o.status == 'Active').length;
    final scheduled = all
        .where((o) =>
            (o.status == 'Approved' || o.status == 'Scheduled') &&
            o.startDate != null &&
            o.startDate!.isAfter(today))
        .length;
    final totalUses = all.fold<int>(0, (s, o) => s + o.usageCount);
    final used = all.where((o) => o.usageCount > 0).toList();
    final avgUses = used.isEmpty ? 0 : totalUses / used.length;
    final activeUses = all
        .where((o) => o.status == 'Active')
        .fold<int>(0, (s, o) => s + o.usageCount);

    final types = {for (final o in all) o.campaignType}.toList()..sort();
    final channels = {
      for (final o in all) ...splitOfferList(o.channels),
    }.toList()
      ..sort();
    final statuses = {for (final o in all) o.status}.toList()
      ..sort((a, b) => offerStatusOptions
          .indexOf(a)
          .compareTo(offerStatusOptions.indexOf(b)));

    return MasterPage(children: [
      MasterPageHeader(
        title: 'Campaigns & Offers Hub',
        subtitle:
            'Deploy, schedule, and track customer engagement promotions across Zomato, Swiggy & POS terminals',
        actions: [
          MasterButton(
              label: 'Import CSV',
              icon: Icons.file_upload_outlined,
              onPressed: _import),
          MasterButton(
              label: 'Export CSV',
              icon: Icons.file_download_outlined,
              onPressed: rows.isEmpty
                  ? () => showMasterNotice(context, 'No campaigns to export')
                  : () => _export(rows)),
          MasterButton(
            label: 'Create Campaign',
            icon: Icons.add,
            kind: MasterButtonKind.primary,
            onPressed: () => _open(null),
          ),
        ],
      ),
      MasterGrid(children: [
        MasterStatCard(
            label: 'Active Offers',
            value: loading ? '—' : '$active',
            caption: 'Currently running live'),
        MasterStatCard(
            label: 'Scheduled Promotions',
            value: loading ? '—' : '$scheduled',
            caption: 'Approved, starting after today'),
        MasterStatCard(
            label: 'Avg Redemptions / Campaign',
            value: loading ? '—' : avgUses.toStringAsFixed(1),
            caption: used.isEmpty
                ? 'No coupon usage recorded yet'
                : '$activeUses uses on live offers',
            captionColor: ViniiColors.greenSolid),
        MasterStatCard(
            label: 'Total Redemptions',
            value: loading ? '—' : '$totalUses',
            caption: 'Coupon uses across all campaigns'),
      ]),
      const SizedBox(height: 24),
      MasterFilterBar(children: [
        MasterSearchField(
          hint: 'Search campaigns or coupon codes...',
          onChanged: (v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
        MasterFilterButton(
          label: 'Type: $_type',
          options: [_all, ...types],
          onSelected: (v) => setState(() {
            _type = v;
            _page = 0;
          }),
        ),
        MasterFilterButton(
          label: 'Channel: $_channel',
          options: [_all, ...channels],
          onSelected: (v) => setState(() {
            _channel = v;
            _page = 0;
          }),
        ),
        MasterFilterButton(
          label: 'Status: $_status',
          options: [_all, ...statuses],
          onSelected: (v) => setState(() {
            _status = v;
            _page = 0;
          }),
        ),
      ]),
      const SizedBox(height: 24),
      MasterTable(
        columns: const [
          MasterColumn('Offer Details', flex: 24),
          MasterColumn('Campaign Type', flex: 12),
          MasterColumn('Discount Rule', flex: 14),
          MasterColumn('Date Range', flex: 15),
          MasterColumn('Target Channel', flex: 13),
          MasterColumn('Status', flex: 10),
          MasterColumn('Actions', flex: 15),
        ],
        onRowTap: (i) => _open(pageRows[i].id),
        rows: [
          for (final o in pageRows)
            [
              MasterCellTitle(o.title,
                  subtitle: [
                    'Code: ${o.code}',
                    if (o.minOrder > 0) 'Min Order ₹${_num(o.minOrder)}',
                    if (o.linkedItems.isNotEmpty) 'Link: ${o.linkedItems}',
                  ].join(' · ')),
              MasterCellText(o.campaignType),
              MasterCellText(o.discountRule.isEmpty ? '—' : o.discountRule),
              MasterCellText(o.dateRange,
                  color:
                      o.startDate == null ? ViniiColors.textMutedLight : null),
              MasterCellText(o.channels.isEmpty ? 'All' : o.channels),
              MasterStatusPill(o.status),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: MasterRowActions(_actionsFor(o),
                      onTap: (a) => _onAction(o, a)),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(Icons.more_horiz,
                        size: 18, color: ViniiColors.textSecondaryLight),
                  ),
                  onSelected: (a) => _onAction(o, a),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'Clone', child: Text('Clone')),
                    const PopupMenuItem(value: 'Stats', child: Text('Stats')),
                    if (o.status != 'Cancelled')
                      const PopupMenuItem(
                          value: 'Cancel', child: Text('Cancel campaign')),
                    const PopupMenuItem(
                        value: 'Delete',
                        child: Text('Delete',
                            style: TextStyle(color: ViniiColors.redSolid))),
                  ],
                ),
              ]),
            ],
        ],
        footer: loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            : rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                        child: Text(
                            all.isEmpty
                                ? 'No campaigns yet — click Create Campaign or Import CSV'
                                : 'No campaigns match these filters',
                            style: MasterStyle.muted)),
                  )
                : null,
      ),
      const SizedBox(height: 16),
      _Pagination(
        page: page,
        pageCount: pageCount,
        from: rows.isEmpty ? 0 : page * _pageSize + 1,
        to: page * _pageSize + pageRows.length,
        total: rows.length,
        onPage: (p) => setState(() => _page = p),
      ),
    ]);
  }
}

/// Centered "‹ 1 2 3 ›" pagination bar (Figma "Table / Pagination").
class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.from,
    required this.to,
    required this.total,
    required this.onPage,
  });
  final int page;
  final int pageCount;
  final int from;
  final int to;
  final int total;
  final ValueChanged<int> onPage;

  Widget _box(Widget child, {bool active = false, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? ViniiColors.brandGreen : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    active ? ViniiColors.brandGreen : MasterStyle.cardBorder),
          ),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Show at most 7 page numbers around the current page.
    final first = (page - 3).clamp(0, (pageCount - 7).clamp(0, pageCount));
    final last = (first + 7).clamp(0, pageCount);
    final canPrev = page > 0;
    final canNext = page < pageCount - 1;
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
              total == 0
                  ? 'Showing 0 campaigns'
                  : 'Showing $from–$to of $total campaigns',
              style: MasterStyle.muted),
          const SizedBox(width: 8),
          _box(
              Icon(Icons.chevron_left,
                  size: 18,
                  color: canPrev
                      ? ViniiColors.textPrimaryLight
                      : ViniiColors.textMutedLight),
              onTap: canPrev ? () => onPage(page - 1) : null),
          for (var p = first; p < last; p++)
            _box(
                Text('${p + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p == page
                            ? Colors.black
                            : ViniiColors.textPrimaryLight)),
                active: p == page,
                onTap: p == page ? null : () => onPage(p)),
          _box(
              Icon(Icons.chevron_right,
                  size: 18,
                  color: canNext
                      ? ViniiColors.textPrimaryLight
                      : ViniiColors.textMutedLight),
              onTap: canNext ? () => onPage(page + 1) : null),
        ],
      ),
    );
  }
}
