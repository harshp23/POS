import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../domain/inventory.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_raw_material_detail.dart';
import 'master_ui.dart';

/// Master → Supplier Price Detail (Figma 385:57856). Opened in place from
/// [MasterSuppliersScreen]. The quote, its supplier, the linked raw
/// material and competing quotes are read live from [DriftInventoryStore].
class MasterSupplierPriceDetail extends StatefulWidget {
  const MasterSupplierPriceDetail({
    super.key,
    required this.inventory,
    required this.quoteId,
    required this.onBack,
    this.onOpenQuote,
    this.master,
  });
  final DriftInventoryStore inventory;
  final String quoteId;
  final VoidCallback onBack;

  /// Opens another quote's detail (from Alternative Bids).
  final ValueChanged<String>? onOpenQuote;

  /// Optional: supplies the menu items offered as "Linked Menu Items" in
  /// the Edit Quote form (a free-text field without it).
  final DriftMasterStore? master;

  @override
  State<MasterSupplierPriceDetail> createState() =>
      _MasterSupplierPriceDetailState();
}

const _tabs = ['Overview & Trends', 'Alternative Bids', 'Quality Audit'];

class _MasterSupplierPriceDetailState extends State<MasterSupplierPriceDetail> {
  int _tab = 0;
  final _subs = <StreamSubscription<Object?>>[];
  List<SupplierPriceQuote>? _quotes;

  /// Every supplier, archived included (forms offer only active ones).
  List<InventorySupplier> _suppliers = const [];
  List<RawMaterial> _materials = const [];

  /// Menu item names for the "Linked Menu Items" picker.
  List<String>? _menuItemNames;

  DriftInventoryStore get _store => widget.inventory;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_store
          .watchSupplierPrices()
          .listen((v) => setState(() => _quotes = v)))
      ..add(_store
          .watchAllSuppliers()
          .listen((v) => setState(() => _suppliers = v)))
      ..add(_store
          .watchMaterials()
          .listen((v) => setState(() => _materials = v)));
    final master = widget.master;
    if (master != null) {
      _subs.add(master.watchDishes().listen((v) => setState(
          () => _menuItemNames = [for (final d in v) d.name]..sort())));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  InventorySupplier? _supplierOf(String id) =>
      _suppliers.where((s) => s.id == id).firstOrNull;
  String _supplierName(String id) => supplierLabel(_suppliers, id);
  RawMaterial? _material(String? id) =>
      id == null ? null : _materials.where((m) => m.id == id).firstOrNull;

  /// Other quotes for the same raw material (or same ingredient name).
  List<SupplierPriceQuote> _alternatives(SupplierPriceQuote q) =>
      (_quotes ?? const <SupplierPriceQuote>[])
          .where((o) =>
              o.id != q.id &&
              ((q.materialId != null && o.materialId == q.materialId) ||
                  o.ingredientName.trim().toLowerCase() ==
                      q.ingredientName.trim().toLowerCase()))
          .toList()
        ..sort((a, b) => a.currentPrice.compareTo(b.currentPrice));

  @override
  Widget build(BuildContext context) {
    final quotes = _quotes;
    if (quotes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = quotes.where((x) => x.id == widget.quoteId).firstOrNull;
    if (q == null) {
      return MasterPage(children: [
        MasterBackLink(
            label: 'Back to Supplier Price Integration', onTap: widget.onBack),
        const MasterBanner(
            tone: PillTone.gray, message: 'This price quote no longer exists.'),
      ]);
    }
    return MasterPage(children: [
      MasterBackLink(
          label: 'Back to Supplier Price Integration', onTap: widget.onBack),
      MasterPageHeader(
        title: q.ingredientName,
        titleTrailing: Row(mainAxisSize: MainAxisSize.min, children: [
          priceSourcePill(q.source),
          if (q.approved) ...[
            const SizedBox(width: 6),
            const MasterStatusPill('Approved', tone: PillTone.green),
          ],
        ]),
        subtitle:
            'Supplier: ${_supplierName(q.supplierId)} · UOM: Per ${q.unit.toUpperCase()} · SKU ID: ${q.skuId.isEmpty ? '—' : q.skuId}',
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ViniiColors.grayTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(q.emoji, style: const TextStyle(fontSize: 24)),
        ),
        actions: [
          MasterButton(
              label: 'Edit Quote',
              icon: Icons.tune,
              onPressed: () => showSupplierPriceForm(context, _store,
                  existing: q,
                  suppliers: _suppliers,
                  materials: _materials,
                  menuItemNames: _menuItemNames)),
          MasterButton(
              label: 'Edit Price',
              icon: Icons.edit_outlined,
              onPressed: () => showEditQuotedPrice(context, _store, q)),
          MasterButton(
              label: q.approved ? 'Approved' : 'Approve Price',
              kind: MasterButtonKind.primary,
              onPressed: () => approveQuoteWithConfirm(context, _store, q,
                  supplierName: _supplierName(q.supplierId),
                  material: _material(q.materialId))),
        ],
      ),
      MasterTabStrip(
          tabs: _tabs,
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i)),
      const SizedBox(height: 24),
      switch (_tab) {
        0 => _overview(q),
        1 => _alternativeBids(q),
        _ => _qualityAudit(q),
      },
    ]);
  }

  String _price(SupplierPriceQuote q, double v) =>
      '${formatInr(v, decimals: 0)}/${q.unit}';

  // ---------------------------------------------------- Overview & Trends
  Widget _overview(SupplierPriceQuote q) {
    final s = _supplierOf(q.supplierId);
    final m = _material(q.materialId);
    final left =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterSection(
        title: 'Sourcing Contract Parameters',
        child: MasterGrid(columns: 2, minItemWidth: 200, children: [
          MasterKeyValue(
              'Lead Time',
              m == null
                  ? '—'
                  : '${m.leadTimeDays} day${m.leadTimeDays == 1 ? '' : 's'}'),
          MasterKeyValue('Payment Terms',
              s == null || s.paymentTerms.isEmpty ? '—' : s.paymentTerms),
          MasterKeyValue('Priority', q.priority),
          MasterKeyValue('Costing Status',
              q.approved ? 'Approved costing price' : 'Awaiting approval'),
        ]),
      ),
      const SizedBox(height: 20),
      MasterSection(
        title: 'Recipe & Menu Traceability Map',
        child: _traceability(q, m),
      ),
      const SizedBox(height: 20),
      _trendCard(q),
    ]);
    return _split(left, _supplierSelection(q));
  }

  Widget _traceability(SupplierPriceQuote q, RawMaterial? m) {
    final names = q.linkedTo
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final delta = q.currentPrice - q.lastPrice;
    Widget row(String title, String caption) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MasterStyle.tableHeaderBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MasterStyle.cardBorder),
          ),
          child: Row(children: [
            Text(q.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(caption, style: MasterStyle.muted),
                  ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                  delta == 0
                      ? 'No cost change'
                      : '${delta > 0 ? '+' : '-'}${formatInr(delta.abs(), decimals: 0)}/${q.unit}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: priceChangeColor(q.changePct))),
              const SizedBox(height: 2),
              const Text('input cost', style: MasterStyle.muted),
            ]),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      m == null
          ? const Text(
              'Not linked to a raw material — approving this price will not change any costing. Use Edit Quote to link it.',
              style: MasterStyle.muted)
          : row('Raw material: ${m.name} (${m.code})',
              'Costing price ${formatInr(m.purchaseCostPerUnit)}/${m.unit} · stock ${invQty(m.stockQty, m.unit)}'),
      for (final n in names) ...[
        const SizedBox(height: 8),
        row(n, 'Uses ${q.ingredientName}'),
      ],
    ]);
  }

  Widget _trendCard(SupplierPriceQuote q) {
    final points = [q.lastPrice, q.currentPrice];
    return MasterSection(
      title: 'Price Trend',
      subtitle:
          'Last recorded price → current quote · ${_supplierName(q.supplierId)}',
      trailing: Text(priceChangeLabel(q.changePct),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: priceChangeColor(q.changePct))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
              painter: _TrendPainter(points, const ['Last', 'Current'])),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 24, runSpacing: 8, children: [
          MasterKeyValue('Last Price', _price(q, q.lastPrice)),
          MasterKeyValue('Current Price', _price(q, q.currentPrice)),
          MasterKeyValue('Lowest (Wk)', _price(q, q.lowestWeek)),
        ]),
        const SizedBox(height: 8),
        const Text(
            'Only the last and current quoted prices are stored; each price edit moves the current price to "last".',
            style: MasterStyle.muted),
      ]),
    );
  }

  Widget _supplierSelection(SupplierPriceQuote q) {
    final options = [q, ..._alternatives(q)];
    return MasterSection(
      title: 'Active Supplier Selection',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final o in options) ...[
          _SupplierOption(
            name: _supplierName(o.supplierId) +
                (o.id == q.id ? ' (This quote)' : ''),
            caption:
                'Rate: ${_price(o, o.currentPrice)} · Rating: ${_supplierOf(o.supplierId)?.rating ?? '—'}★',
            selected: o.approved,
            onTap: () => _choose(o),
          ),
          const SizedBox(height: 12),
        ],
        const MasterBanner(
          tone: PillTone.blue,
          icon: 'ℹ️',
          message:
              'Selecting a supplier approves its quote: the price becomes the costing price of the linked raw material and the supplier becomes its preferred supplier.',
        ),
      ]),
    );
  }

  void _choose(SupplierPriceQuote o) {
    if (o.approved) {
      showMasterNotice(context,
          '${_supplierName(o.supplierId)} is already the approved quote');
      return;
    }
    approveQuoteWithConfirm(context, _store, o,
        supplierName: _supplierName(o.supplierId),
        material: _material(o.materialId));
  }

  // ----------------------------------------------------- Alternative Bids
  Widget _alternativeBids(SupplierPriceQuote q) {
    final bids = _alternatives(q);
    final best = bids.isEmpty ? null : bids.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (best != null && best.currentPrice < q.currentPrice) ...[
        MasterBanner(
          tone: PillTone.green,
          icon: '💡',
          message:
              '${_supplierName(best.supplierId)} quotes ${_price(best, best.currentPrice)}, '
              '${formatInr(q.currentPrice - best.currentPrice, decimals: 0)}/${q.unit} below this quote.',
        ),
        const SizedBox(height: 20),
      ],
      MasterSection(
        title: 'Alternative Bids',
        subtitle:
            'Other supplier quotes for the same raw material or ingredient · this quote: ${_supplierName(q.supplierId)} at ${_price(q, q.currentPrice)}',
        child: bids.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'No other supplier has quoted for this ingredient. Add a price quote for another supplier to compare.',
                    style: MasterStyle.muted))
            : MasterTable(
                minWidth: 820,
                columns: const [
                  MasterColumn('Supplier', flex: 18),
                  MasterColumn('Bid Rate', flex: 10),
                  MasterColumn('vs This Quote', flex: 10),
                  MasterColumn('Source', flex: 11),
                  MasterColumn('Rating', flex: 8),
                  MasterColumn('Action', flex: 14),
                ],
                selectedRows: {
                  for (var i = 0; i < bids.length; i++)
                    if (bids[i].approved) i
                },
                rows: [
                  for (final b in bids)
                    () {
                      final s = _supplierOf(b.supplierId);
                      final pct = q.currentPrice == 0
                          ? 0.0
                          : (b.currentPrice - q.currentPrice) /
                              q.currentPrice *
                              100;
                      return <Widget>[
                        MasterCellTitle(_supplierName(b.supplierId),
                            subtitle: s == null || s.city.isEmpty
                                ? null
                                : s.city),
                        MasterCellText(_price(b, b.currentPrice), bold: true),
                        MasterCellText(priceChangeLabel(pct),
                            bold: true, color: priceChangeColor(pct)),
                        priceSourcePill(b.source),
                        MasterCellText(s == null ? '—' : '${s.rating}★'),
                        MasterRowActions([if (!b.approved) 'Select', 'Detail'],
                            onTap: (a) {
                          if (a == 'Select') {
                            _choose(b);
                          } else {
                            widget.onOpenQuote?.call(b.id);
                          }
                        }),
                      ];
                    }(),
                ],
              ),
      ),
    ]);
  }

  // -------------------------------------------------------- Quality Audit
  Widget _qualityAudit(SupplierPriceQuote q) {
    final s = _supplierOf(q.supplierId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterGrid(columns: 3, children: [
        MasterStatCard(
            label: 'Supplier Rating',
            value: s == null ? '—' : '${s.rating}★',
            caption: 'No audits recorded'),
      ]),
      const SizedBox(height: 20),
      MasterSection(
        title: 'Inbound Quality Audits',
        subtitle: '${q.ingredientName} · ${_supplierName(q.supplierId)}',
        trailing: MasterButton(
            label: 'Log Audit',
            icon: Icons.add,
            onPressed: () => showMasterNotice(context,
                'Quality audits cannot be recorded yet in this version.')),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
              'No audits recorded. Quality audits are not stored in this version.',
              style: MasterStyle.muted),
        ),
      ),
    ]);
  }

  Widget _split(Widget left, Widget right) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 980
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 692, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 420, child: right),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 20), right]),
      );
}

// ===========================================================================
// Shared supplier-price helpers (also used by MasterSuppliersScreen).
// ===========================================================================

/// "+7.8%" / "0.0%" / "-2.1%".
String priceChangeLabel(double pct) =>
    '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

/// Price rises are bad for food cost (red), drops are good (green).
Color priceChangeColor(double pct) => pct > 0.05
    ? ViniiColors.redSolid
    : pct < -0.05
        ? ViniiColors.greenSolid
        : ViniiColors.textSecondaryLight;

Widget priceSourcePill(PriceSource s) => MasterStatusPill(s.label,
    tone: switch (s) {
      PriceSource.merchantEntered => PillTone.green,
      PriceSource.observed => PillTone.blue,
      PriceSource.imported => PillTone.purple,
      PriceSource.aiInferred => PillTone.amber,
      PriceSource.estimated => PillTone.gray,
    });

const quotePriorities = ['High', 'Medium', 'Low'];

/// Confirms, then approves [q] — its price becomes the costing price of
/// the linked raw material.
Future<void> approveQuoteWithConfirm(
    BuildContext context, DriftInventoryStore store, SupplierPriceQuote q,
    {required String supplierName, RawMaterial? material}) async {
  final price = '${formatInr(q.currentPrice)}/${q.unit}';
  final ok = await confirmMasterAction(context,
      title: 'Approve $price from $supplierName?',
      message: material == null
          ? 'This quote is not linked to a raw material, so no costing price changes. It will only be marked as approved.'
          : '$price becomes the costing price of ${material.name} '
              '(currently ${formatInr(material.purchaseCostPerUnit)}/${material.unit}) '
              'and $supplierName becomes its preferred supplier. Recipe costs using ${material.name} update immediately.',
      confirmLabel: 'Approve',
      destructive: false);
  if (!ok || !context.mounted) return;
  await runMasterAction(context, () => store.approveSupplierPrice(q.id),
      success: material == null
          ? 'Approved ${q.ingredientName} at $price'
          : '${material.name} now costs $price');
}

/// Records a new quoted price (the old current price becomes "last").
Future<void> showEditQuotedPrice(BuildContext context,
    DriftInventoryStore store, SupplierPriceQuote q) async {
  final ctrl = TextEditingController(text: q.currentPrice.toString());
  final form = GlobalKey<FormState>();
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => InvFormDialog(
      title: 'Edit Price · ${q.ingredientName}',
      formKey: form,
      width: 420,
      saveLabel: 'Save Price',
      onSave: () {
        if (!(form.currentState?.validate() ?? false)) return;
        Navigator.pop(ctx, invParse(ctrl.text));
      },
      children: [
        InvKvRow('Current price', '${formatInr(q.currentPrice)}/${q.unit}'),
        const SizedBox(height: 10),
        InvFormText(
            label: 'New price (₹ per ${q.unit}) *',
            controller: ctrl,
            number: true,
            validator: invNumberValidator(required: true)),
        const SizedBox(height: 10),
        const Text(
            'The current price moves to "Last Price". The quote goes back to awaiting approval.',
            style: MasterStyle.muted),
      ],
    ),
  );
  // The controller is left to GC: disposing it here would race the dialog's
  // exit animation, which still renders the field.
  if (value == null || !context.mounted) return;
  await runMasterAction(context, () => store.updateQuotedPrice(q.id, value),
      success: '${q.ingredientName}: ${formatInr(value)}/${q.unit} saved');
}

/// Add (existing == null) or edit a supplier price quote. [suppliers] may
/// include archived ones: only active suppliers are offered, and an
/// archived supplier already on the quote is shown by name. With
/// [menuItemNames] the "Linked Menu Items" field is a menu-item picker.
Future<void> showSupplierPriceForm(
  BuildContext context,
  DriftInventoryStore store, {
  SupplierPriceQuote? existing,
  required List<InventorySupplier> suppliers,
  required List<RawMaterial> materials,
  List<String>? menuItemNames,
}) async {
  if (!suppliers.any((s) => s.active)) {
    showMasterError(context, 'Add a supplier first (Suppliers tab).');
    return;
  }
  // An archived material linked to this quote is still named in the form.
  final linkedId = existing?.materialId;
  RawMaterial? archivedMaterial;
  if (linkedId != null && !materials.any((m) => m.id == linkedId)) {
    try {
      archivedMaterial = await store.getMaterial(linkedId);
    } catch (_) {
      archivedMaterial = null;
    }
    if (!context.mounted) return;
  }
  final result = await showDialog<SupplierPriceQuote>(
    context: context,
    builder: (_) => _QuoteFormDialog(
        existing: existing,
        suppliers: suppliers,
        materials: materials,
        archivedMaterial: archivedMaterial,
        menuItemNames: menuItemNames),
  );
  if (result == null || !context.mounted) return;
  await runMasterAction(context, () => store.upsertSupplierPrice(result),
      success: existing == null
          ? 'Added price quote for ${result.ingredientName}'
          : 'Saved ${result.ingredientName}');
}

class _QuoteFormDialog extends StatefulWidget {
  const _QuoteFormDialog({
    required this.existing,
    required this.suppliers,
    required this.materials,
    this.archivedMaterial,
    this.menuItemNames,
  });
  final SupplierPriceQuote? existing;

  /// All suppliers; only active ones are offered.
  final List<InventorySupplier> suppliers;
  final List<RawMaterial> materials;

  /// The quote's linked material when it is no longer in [materials].
  final RawMaterial? archivedMaterial;

  /// Menu item names for the "Linked Menu Items" picker; null keeps the
  /// comma-separated text field.
  final List<String>? menuItemNames;

  @override
  State<_QuoteFormDialog> createState() => _QuoteFormDialogState();
}

class _QuoteFormDialogState extends State<_QuoteFormDialog> {
  final _form = GlobalKey<FormState>();
  late final SupplierPriceQuote? e = widget.existing;
  late final _name = TextEditingController(text: e?.ingredientName ?? '');
  late final _current =
      TextEditingController(text: e == null ? '' : '${e!.currentPrice}');
  late final _last =
      TextEditingController(text: e == null ? '' : '${e!.lastPrice}');
  late final _sku = TextEditingController(text: e?.skuId ?? '');
  late final _linked = TextEditingController(text: e?.linkedTo ?? '');
  late final _emoji = TextEditingController(text: e?.emoji ?? '📦');
  late String _materialId = e?.materialId ?? '';
  late final List<InventorySupplier> _active = [
    for (final s in widget.suppliers)
      if (s.active) s
  ];
  late String _supplierId = e?.supplierId ?? _active.first.id;
  late PriceSource _source = e?.source ?? PriceSource.merchantEntered;
  late String _priority = e?.priority ?? 'Medium';

  /// Unit used when the quote is not linked to a raw material. A linked
  /// quote always uses the material's own unit (costing depends on it).
  late String _unit = () {
    final u = (e?.unit ?? '').trim();
    return u.isEmpty ? invUnits.first : u;
  }();

  /// Chosen menu items (picker mode).
  late final Set<String> _linkedItems = {
    for (final n in (e?.linkedTo ?? '').split(','))
      if (n.trim().isNotEmpty) n.trim()
  };

  static const _label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ViniiColors.textPrimaryLight);

  @override
  void dispose() {
    for (final c in [_name, _current, _last, _sku, _linked, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  RawMaterial? get _linkedMaterial {
    if (_materialId.isEmpty) return null;
    return widget.materials.where((x) => x.id == _materialId).firstOrNull ??
        (widget.archivedMaterial?.id == _materialId
            ? widget.archivedMaterial
            : null);
  }

  void _pickMaterial(String? id) {
    setState(() => _materialId = id ?? '');
    final m = widget.materials.where((x) => x.id == id).firstOrNull;
    if (m == null) return;
    if (_name.text.trim().isEmpty) _name.text = m.name;
    setState(() => _unit = m.unit);
    if (_emoji.text.trim().isEmpty || _emoji.text == '📦') {
      _emoji.text = m.emoji;
    }
    if (_last.text.trim().isEmpty) {
      _last.text = m.purchaseCostPerUnit.toString();
    }
  }

  Future<void> _pickLinkedItems() async {
    final names = {...?widget.menuItemNames, ..._linkedItems}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final picked = await showMasterMultiSelect(context,
        title: 'Menu items using this ingredient',
        options: names,
        selected: _linkedItems,
        emptyText: 'No menu items yet — add dishes in Master → Menu Items.');
    if (picked == null || !mounted) return;
    setState(() {
      _linkedItems
        ..clear()
        ..addAll(picked);
    });
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final current = invParse(_current.text)!;
    final last = invParse(_last.text) ?? current;
    final lowestBase = e?.lowestWeek ?? last;
    final lowest = [current, last, lowestBase].reduce((a, b) => a < b ? a : b);
    final priceChanged = e != null && e!.currentPrice != current;
    final material = _linkedMaterial;
    final names = widget.menuItemNames;
    Navigator.pop(
      context,
      SupplierPriceQuote(
        id: e?.id ?? 'sp-${DateTime.now().millisecondsSinceEpoch}',
        ingredientName: _name.text.trim(),
        emoji: _emoji.text.trim().isEmpty ? '📦' : _emoji.text.trim(),
        linkedTo: names == null
            ? _linked.text.trim()
            : [
                // Keep the menu's order, then any older names not in it.
                for (final n in names)
                  if (_linkedItems.contains(n)) n,
                for (final n in _linkedItems)
                  if (!names.contains(n)) n,
              ].join(', '),
        supplierId: _supplierId,
        unit: material?.unit ?? _unit,
        lastPrice: last,
        currentPrice: current,
        lowestWeek: lowest,
        source: _source,
        priority: _priority,
        skuId: _sku.text.trim(),
        materialId: _materialId.isEmpty ? null : _materialId,
        approved: (e?.approved ?? false) && !priceChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = <(String, String)>[
      for (final s in _active)
        (s.id, s.caption.isEmpty ? s.name : '${s.name} · ${s.caption}'),
      // The quote's supplier stays selectable after it was archived.
      if (!_active.any((s) => s.id == _supplierId))
        (_supplierId, supplierLabel(widget.suppliers, _supplierId)),
    ];
    final material = _linkedMaterial;
    final archived = widget.archivedMaterial;
    final units = {...invUnits, if (_unit.isNotEmpty) _unit}.toList();
    return InvFormDialog(
      title: e == null ? 'Add Price Quote' : 'Edit ${e!.ingredientName}',
      formKey: _form,
      onSave: _save,
      children: [
        InvFormRow([
          InvFormDropdown<String>(
              label: 'Link to Raw Material',
              value: _materialId,
              items: [
                ('', 'Not linked'),
                for (final m in widget.materials)
                  (m.id, '${m.name} · ${m.code}'),
                if (_materialId.isNotEmpty &&
                    !widget.materials.any((m) => m.id == _materialId))
                  (
                    _materialId,
                    archived != null && archived.id == _materialId
                        ? '${archived.name} (archived)'
                        : 'Removed material'
                  ),
              ],
              onChanged: _pickMaterial),
          InvFormDropdown<String>(
              label: 'Supplier *',
              value: _supplierId,
              items: suppliers,
              onChanged: (v) => setState(() => _supplierId = v ?? _supplierId)),
        ]),
        InvFormRow([
          InvFormText(
              label: 'Ingredient Name *',
              controller: _name,
              hint: 'e.g. Fresh Paneer Block',
              validator: invRequired),
          material == null
              ? InvFormDropdown<String>(
                  key: const ValueKey('unit-free'),
                  label: 'Unit *',
                  value: _unit,
                  items: [for (final u in units) (u, u)],
                  onChanged: (v) => setState(() => _unit = v ?? _unit))
              : InvFormDropdown<String>(
                  // Locked to the material's unit: costing depends on it.
                  key: ValueKey('unit-${material.id}'),
                  label: 'Unit (from ${material.name})',
                  value: material.unit,
                  items: [(material.unit, material.unit)],
                  enabled: false,
                  onChanged: (_) {}),
        ]),
        InvFormRow([
          InvFormText(
              label: 'Current Price (₹) *',
              controller: _current,
              number: true,
              validator: invNumberValidator(required: true)),
          InvFormText(
              label: 'Last Price (₹)',
              controller: _last,
              number: true,
              hint: 'Same as current',
              validator: invNumberValidator()),
        ]),
        InvFormRow([
          InvFormDropdown<PriceSource>(
              label: 'Source',
              value: _source,
              items: [for (final s in PriceSource.values) (s, s.label)],
              onChanged: (v) => setState(() => _source = v ?? _source)),
          InvFormDropdown<String>(
              label: 'Priority',
              value: _priority,
              items: [
                for (final p in {...quotePriorities, _priority}) (p, p)
              ],
              onChanged: (v) => setState(() => _priority = v ?? _priority)),
        ]),
        InvFormRow([
          InvFormText(label: 'Supplier SKU', controller: _sku),
          InvFormText(label: 'Emoji', controller: _emoji),
        ]),
        if (widget.menuItemNames == null)
          InvFormText(
              label: 'Linked Menu Items',
              controller: _linked,
              hint: 'Comma separated, e.g. Paneer Tikka, Palak Paneer')
        else
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Linked Menu Items', style: _label),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickLinkedItems,
                  child: InputDecorator(
                    isEmpty: _linkedItems.isEmpty,
                    decoration: invInputDecoration(
                            hint: 'Choose the dishes that use this ingredient')
                        .copyWith(
                            suffixIcon:
                                const Icon(Icons.arrow_drop_down, size: 20)),
                    child: Text(_linkedItems.join(', '),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ]),
        if (e != null && e!.approved) ...[
          const SizedBox(height: 10),
          const Text(
              'Changing the current price clears the approval; approve it again to update costing.',
              style: MasterStyle.muted),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------- private UI

class _SupplierOption extends StatelessWidget {
  const _SupplierOption(
      {required this.name,
      required this.caption,
      required this.selected,
      required this.onTap});
  final String name;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ViniiColors.lightGreenTint : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? ViniiColors.greenSolid
                      : MasterStyle.cardBorder),
            ),
            child: Row(children: [
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected
                      ? ViniiColors.greenSolid
                      : ViniiColors.textMutedLight),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: MasterStyle.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(caption, style: MasterStyle.muted),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

/// Minimal line chart: gridlines, point labels, price line and dots.
class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.labels);
  final List<double> points;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const left = 44.0, bottom = 20.0, top = 8.0, right = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    var lo = points.reduce((a, b) => a < b ? a : b);
    var hi = points.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) == 0 ? (hi == 0 ? 1.0 : hi * 0.05) : (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;

    final grid = Paint()
      ..color = MasterStyle.cardBorder
      ..strokeWidth = 1;
    void label(String text, Offset at, {bool alignRight = false}) {
      final tp = TextPainter(
          text: TextSpan(
              text: text,
              style: const TextStyle(
                  fontSize: 10, color: ViniiColors.textMutedLight)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset(alignRight ? at.dx - tp.width : at.dx - tp.width / 2,
              at.dy - tp.height / 2));
    }

    for (var i = 0; i <= 3; i++) {
      final y = top + h * i / 3;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      final v = hi - (hi - lo) * i / 3;
      label('₹${v.round()}', Offset(left - 6, y), alignRight: true);
    }

    Offset at(int i) => Offset(left + w * i / (points.length - 1),
        top + h * (1 - (points[i] - lo) / (hi - lo)));

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(at(points.length - 1).dx, top + h)
      ..lineTo(at(0).dx, top + h)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = ViniiColors.blueSolid.withValues(alpha: 0.08));
    canvas.drawPath(
        path,
        Paint()
          ..color = ViniiColors.blueSolid
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      canvas.drawCircle(at(i), last ? 4.5 : 3,
          Paint()..color = last ? ViniiColors.redSolid : ViniiColors.blueSolid);
      label(i < labels.length ? labels[i] : '${i + 1}',
          Offset(at(i).dx, size.height - bottom / 2));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points.join() != points.join();
}
