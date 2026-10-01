import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../domain/inventory.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_raw_material_detail.dart';
import 'master_supplier_price_detail.dart';
import 'master_ui.dart';

/// Master → Supplier Price Integration (Figma 385:57715) plus supplier
/// management.
///
/// Price quotes, suppliers and raw materials are read live from the common
/// [DriftInventoryStore]. "Detail" (or the ingredient name) opens
/// [MasterSupplierPriceDetail] in place.
class MasterSuppliersScreen extends StatefulWidget {
  const MasterSuppliersScreen({super.key, required this.inventory, this.master});
  final DriftInventoryStore inventory;

  /// Optional: supplies the menu items offered as "Linked Menu Items" in
  /// the price-quote form (a free-text field without it).
  final DriftMasterStore? master;

  @override
  State<MasterSuppliersScreen> createState() => _MasterSuppliersScreenState();
}

const _all = 'All';
const _pageSize = 25;

const _priceHeaders = [
  'id',
  'ingredient_name',
  'material_id',
  'supplier_id',
  'unit',
  'last_price',
  'current_price',
  'lowest_week',
  'source',
  'priority',
  'sku_id',
];

const _supplierHeaders = [
  'id',
  'name',
  'legal_name',
  'category',
  'contact_person',
  'phone',
  'email',
  'gstin',
  'city',
  'rating',
  'payment_terms',
];

class _MasterSuppliersScreenState extends State<MasterSuppliersScreen> {
  int _view = 0; // 0 = price integration, 1 = suppliers
  String _query = '';
  String _supplier = _all;
  String _source = _all;
  String _priority = _all;
  int _page = 0;
  String _supplierQuery = '';
  String _supplierCategory = _all;
  String? _openId;

  final _subs = <StreamSubscription<Object?>>[];
  List<SupplierPriceQuote>? _quotes;

  /// Active suppliers (the Suppliers tab and pickers).
  List<InventorySupplier>? _suppliers;

  /// Every supplier, archived included — names on older price quotes.
  List<InventorySupplier> _allSuppliers = const [];
  List<RawMaterial> _materials = const [];

  /// Menu item names for the quote form's "Linked Menu Items" picker.
  List<String>? _menuItemNames;

  DriftInventoryStore get _store => widget.inventory;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_store
          .watchSupplierPrices()
          .listen((v) => setState(() => _quotes = v)))
      ..add(_store.watchAllSuppliers().listen((v) => setState(() {
            _allSuppliers = v;
            _suppliers = [
              for (final s in v)
                if (s.active) s
            ];
          })))
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

  List<InventorySupplier> get _supplierList => _suppliers ?? const [];

  String _supplierName(String id) => supplierLabel(_allSuppliers, id);

  RawMaterial? _material(String? id) =>
      id == null ? null : _materials.where((m) => m.id == id).firstOrNull;

  List<SupplierPriceQuote> _filtered(List<SupplierPriceQuote> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      final supplier = _supplierName(p.supplierId);
      if (q.isNotEmpty &&
          !p.ingredientName.toLowerCase().contains(q) &&
          !p.linkedTo.toLowerCase().contains(q) &&
          !p.skuId.toLowerCase().contains(q) &&
          !supplier.toLowerCase().contains(q)) {
        return false;
      }
      if (_supplier != _all && supplier != _supplier) return false;
      if (_source != _all && p.source.label != _source) return false;
      if (_priority != _all && p.priority != _priority) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openId;
    if (openId != null) {
      return MasterSupplierPriceDetail(
          inventory: _store,
          quoteId: openId,
          master: widget.master,
          onOpenQuote: (id) => setState(() => _openId = id),
          onBack: () => setState(() => _openId = null));
    }
    final loading = _quotes == null || _suppliers == null;
    return MasterPage(children: [
      MasterPageHeader(
        title: _view == 0 ? 'Supplier Price Integration' : 'Suppliers',
        subtitle: _view == 0
            ? 'Review integrated ingredient catalog prices, observe price anomalies, and assign preferred sourcing'
            : 'Manage the suppliers used for price quotes and purchase orders',
        actions: _view == 0
            ? [
                MasterButton(
                    label: 'Import CSV',
                    icon: Icons.upload_file,
                    onPressed: _importPrices),
                MasterButton(
                    label: 'Export CSV',
                    icon: Icons.download,
                    onPressed: () =>
                        _exportPrices(_filtered(_quotes ?? const []))),
                MasterButton(
                    label: '+ Add Price Quote',
                    kind: MasterButtonKind.primary,
                    onPressed: () => showSupplierPriceForm(context, _store,
                        suppliers: _allSuppliers,
                        materials: _materials,
                        menuItemNames: _menuItemNames)),
              ]
            : [
                MasterButton(
                    label: 'Import CSV',
                    icon: Icons.upload_file,
                    onPressed: _importSuppliers),
                MasterButton(
                    label: 'Export CSV',
                    icon: Icons.download,
                    onPressed: () =>
                        _exportSuppliers(_filteredSuppliers(_supplierList))),
                MasterButton(
                    label: '+ Add Supplier',
                    kind: MasterButtonKind.primary,
                    onPressed: () => _editSupplier(null)),
              ],
      ),
      MasterTabStrip(tabs: [
        'Price Integration (${_quotes?.length ?? 0})',
        'Suppliers (${_suppliers?.length ?? 0})',
      ], selected: _view, onSelect: (i) => setState(() => _view = i)),
      const SizedBox(height: 20),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_view == 0)
        ..._pricesView(_quotes!)
      else
        ..._suppliersView(_supplierList),
    ]);
  }

  // ------------------------------------------------------ price quotes

  List<Widget> _pricesView(List<SupplierPriceQuote> all) {
    final rows = _filtered(all);
    final pages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final visible = rows.skip(start).take(_pageSize).toList();
    final suppliers =
        {for (final p in all) _supplierName(p.supplierId)}.toList()..sort();
    final sources = [
      for (final s in PriceSource.values)
        if (all.any((p) => p.source == s)) s.label
    ];
    final priorities = {for (final p in all) p.priority}.toList()
      ..sort((a, b) {
        int rank(String p) {
          final i = quotePriorities.indexOf(p);
          return i < 0 ? 99 : i;
        }

        return rank(a).compareTo(rank(b));
      });
    return [
      MasterFilterBar(children: [
        MasterSearchField(
            hint: 'Search ingredients, SKUs or suppliers...',
            onChanged: (v) => setState(() {
                  _query = v;
                  _page = 0;
                })),
        MasterFilterButton(
            label: _supplier == _all ? 'Supplier' : _supplier,
            options: [_all, ...suppliers],
            onSelected: (v) => setState(() {
                  _supplier = v;
                  _page = 0;
                })),
        MasterFilterButton(
            label: _source == _all ? 'Source' : _source,
            options: [_all, ...sources],
            onSelected: (v) => setState(() {
                  _source = v;
                  _page = 0;
                })),
        MasterFilterButton(
            label: _priority == _all ? 'Priority' : _priority,
            options: [_all, ...priorities],
            onSelected: (v) => setState(() {
                  _priority = v;
                  _page = 0;
                })),
      ]),
      const SizedBox(height: 24),
      MasterTable(
        minWidth: 1100,
        columns: const [
          MasterColumn('Ingredient Name', flex: 176),
          MasterColumn('Supplier', flex: 110),
          MasterColumn('Last Price', flex: 90),
          MasterColumn('Current Price', flex: 90),
          MasterColumn('Lowest (Wk)', flex: 90),
          MasterColumn('Change', flex: 80),
          MasterColumn('Source', flex: 120),
          MasterColumn('Priority', flex: 90),
          MasterColumn('Action', flex: 170),
        ],
        rows: [
          for (final p in visible)
            [
              InkWell(
                onTap: () => setState(() => _openId = p.id),
                child: MasterCellTitle(p.ingredientName,
                    emoji: p.emoji, subtitle: _linkedCaption(p)),
              ),
              MasterCellText(_supplierName(p.supplierId)),
              MasterCellText(_price(p.lastPrice, p.unit)),
              MasterCellText(_price(p.currentPrice, p.unit), bold: true),
              MasterCellText(_price(p.lowestWeek, p.unit)),
              MasterCellText(priceChangeLabel(p.changePct),
                  bold: true, color: priceChangeColor(p.changePct)),
              priceSourcePill(p.source),
              _priorityPill(p.priority),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (p.approved) ...[
                  const MasterStatusPill('Approved', tone: PillTone.green),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: MasterRowActions(
                      ['Detail', if (!p.approved) 'Approve', 'Edit', 'Delete'],
                      onTap: (a) => _priceAction(a, p)),
                ),
              ]),
            ],
        ],
        footer: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Text(
                rows.isEmpty
                    ? (all.isEmpty
                        ? 'No price quotes yet. Use "+ Add Price Quote" or Import CSV.'
                        : 'No price entries match these filters.')
                    : 'Showing ${start + 1}–${start + visible.length} of ${rows.length} entries'
                        '${rows.length == all.length ? '' : ' (filtered from ${all.length})'}',
                style: MasterStyle.muted),
            _Pagination(
                page: page,
                pages: pages,
                onPage: (p) => setState(() => _page = p)),
          ],
        ),
      ),
    ];
  }

  String _linkedCaption(SupplierPriceQuote p) {
    final m = _material(p.materialId);
    if (m != null) return 'Raw material: ${m.name}';
    if (p.linkedTo.isNotEmpty) return 'Linked to: ${p.linkedTo}';
    return 'Not linked to a raw material';
  }

  Future<void> _priceAction(String action, SupplierPriceQuote p) async {
    switch (action) {
      case 'Detail':
        setState(() => _openId = p.id);
      case 'Approve':
        await approveQuoteWithConfirm(context, _store, p,
            supplierName: _supplierName(p.supplierId),
            material: _material(p.materialId));
      case 'Edit':
        await showSupplierPriceForm(context, _store,
            existing: p,
            suppliers: _allSuppliers,
            materials: _materials,
            menuItemNames: _menuItemNames);
      case 'Delete':
        final ok = await confirmMasterAction(context,
            title: 'Delete price quote?',
            message:
                '${p.ingredientName} from ${_supplierName(p.supplierId)} will be removed. Raw material costing prices already approved are not changed.');
        if (!ok || !mounted) return;
        await runMasterAction(context, () => _store.deleteSupplierPrice(p.id),
            success: 'Deleted ${p.ingredientName} quote');
    }
  }

  void _exportPrices(List<SupplierPriceQuote> rows) {
    exportCsv(context,
        fileName: 'supplier-prices-${_stamp()}.csv',
        headers: _priceHeaders,
        rows: [
          for (final p in rows)
            [
              p.id,
              p.ingredientName,
              p.materialId ?? '',
              p.supplierId,
              p.unit,
              p.lastPrice,
              p.currentPrice,
              p.lowestWeek,
              p.source.label,
              p.priority,
              p.skuId,
            ],
        ]);
  }

  Future<void> _importPrices() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    await runMasterAction(context, () async {
      final existing = await _store.getSupplierPrices();
      final supplierIds = {for (final s in await _store.getSuppliers()) s.id};
      final materials = {for (final m in await _store.getMaterials()) m.id: m};
      final byId = {for (final q in existing) q.id: q};
      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        try {
          final quote = _priceFromRow(r, i, byId, supplierIds, materials);
          final isNew = !byId.containsKey(quote.id);
          await _store.upsertSupplierPrice(quote);
          byId[quote.id] = quote;
          isNew ? summary.added++ : summary.updated++;
        } on _RowError catch (e) {
          summary.errors.add('Line ${r.line}: ${e.message}');
        }
      }
    });
    if (mounted) showImportSummary(context, summary);
  }

  SupplierPriceQuote _priceFromRow(
    CsvRecord r,
    int index,
    Map<String, SupplierPriceQuote> byId,
    Set<String> supplierIds,
    Map<String, RawMaterial> materials,
  ) {
    double? num(String h) {
      if (!r.has(h)) return null;
      final v = r.number(h);
      if (v == null) throw _RowError('$h "${r(h)}" is not a number');
      if (v < 0) throw _RowError('$h cannot be negative');
      return v;
    }

    final id = r('id');
    var match = byId[id];
    final supplierId = r('supplier_id', match?.supplierId ?? '');
    final sku = r('sku_id');
    if (match == null && sku.isNotEmpty) {
      match = byId.values
          .where((q) => q.skuId == sku && q.supplierId == supplierId)
          .firstOrNull;
    }
    final name = r('ingredient_name', match?.ingredientName ?? '');
    if (name.isEmpty) throw _RowError('ingredient_name is required');
    if (supplierId.isEmpty) throw _RowError('supplier_id is required');
    if (!supplierIds.contains(supplierId)) {
      throw _RowError('unknown supplier_id "$supplierId"');
    }
    final materialId = r('material_id', match?.materialId ?? '');
    final material = materialId.isEmpty ? null : materials[materialId];
    if (materialId.isNotEmpty && material == null) {
      throw _RowError('unknown material_id "$materialId"');
    }
    final current = num('current_price') ?? match?.currentPrice;
    if (current == null) throw _RowError('current_price is required');
    final last = num('last_price') ?? match?.lastPrice ?? current;
    final lowest = num('lowest_week') ??
        match?.lowestWeek ??
        (last < current ? last : current);
    final unit = r('unit', match?.unit ?? material?.unit ?? '');
    if (unit.isEmpty) throw _RowError('unit is required');
    final sourceLabel = r('source');
    final source = sourceLabel.isEmpty
        ? (match?.source ?? PriceSource.imported)
        : PriceSource.values
                .where(
                    (s) => s.label.toLowerCase() == sourceLabel.toLowerCase())
                .firstOrNull ??
            (throw _RowError('unknown source "$sourceLabel"'));
    final priority = r('priority', match?.priority ?? 'Medium');
    return SupplierPriceQuote(
      id: match?.id ??
          (id.isNotEmpty
              ? id
              : 'sp-${DateTime.now().millisecondsSinceEpoch}-$index'),
      ingredientName: name,
      emoji: match?.emoji ?? material?.emoji ?? '📦',
      linkedTo: match?.linkedTo ?? '',
      supplierId: supplierId,
      unit: unit,
      lastPrice: last,
      currentPrice: current,
      lowestWeek: lowest,
      source: source,
      priority: priority,
      skuId: sku.isEmpty ? (match?.skuId ?? '') : sku,
      materialId: materialId.isEmpty ? null : materialId,
      approved: (match?.approved ?? false) && match!.currentPrice == current,
    );
  }

  // ---------------------------------------------------------- suppliers

  List<InventorySupplier> _filteredSuppliers(List<InventorySupplier> all) {
    final q = _supplierQuery.trim().toLowerCase();
    return all.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.id.toLowerCase().contains(q) &&
          !s.city.toLowerCase().contains(q) &&
          !s.contactPerson.toLowerCase().contains(q) &&
          !s.gstin.toLowerCase().contains(q)) {
        return false;
      }
      if (_supplierCategory != _all && s.category != _supplierCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Widget> _suppliersView(List<InventorySupplier> all) {
    final rows = _filteredSuppliers(all);
    final categories = {
      for (final s in all)
        if (s.category.isNotEmpty) s.category
    }.toList()
      ..sort();
    final quoteCounts = <String, int>{};
    for (final q in _quotes ?? const <SupplierPriceQuote>[]) {
      quoteCounts[q.supplierId] = (quoteCounts[q.supplierId] ?? 0) + 1;
    }
    return [
      MasterFilterBar(children: [
        MasterSearchField(
            hint: 'Search suppliers by name, city, contact or GSTIN...',
            onChanged: (v) => setState(() => _supplierQuery = v)),
        MasterFilterButton(
            label: _supplierCategory == _all
                ? 'Category'
                : 'Category: $_supplierCategory',
            options: [_all, ...categories],
            onSelected: (v) => setState(() => _supplierCategory = v)),
      ]),
      const SizedBox(height: 24),
      MasterTable(
        minWidth: 1100,
        columns: const [
          MasterColumn('Supplier', flex: 18),
          MasterColumn('Category', flex: 11),
          MasterColumn('Contact', flex: 14),
          MasterColumn('City', flex: 10),
          MasterColumn('GSTIN', flex: 14),
          MasterColumn('Rating', flex: 7),
          MasterColumn('Payment Terms', flex: 11),
          MasterColumn('Quotes', flex: 7),
          MasterColumn('Actions', flex: 12),
        ],
        rows: [
          for (final s in rows)
            [
              MasterCellTitle(s.name,
                  subtitle: s.legalName.isNotEmpty && s.legalName != s.name
                      ? s.legalName
                      : (s.email.isEmpty ? null : s.email)),
              MasterCellText(_dash(s.category)),
              MasterCellTitle(_dash(s.contactPerson),
                  subtitle: s.phone.isEmpty ? null : s.phone),
              MasterCellText(_dash(s.city)),
              MasterCellText(_dash(s.gstin)),
              MasterCellText('${s.rating}★'),
              MasterCellText(_dash(s.paymentTerms)),
              MasterCellText('${quoteCounts[s.id] ?? 0}'),
              MasterRowActions(const ['Edit', 'Archive'], onTap: (a) {
                if (a == 'Edit') {
                  _editSupplier(s);
                } else {
                  _archiveSupplier(s);
                }
              }),
            ],
        ],
        footer: Text(
            rows.isEmpty
                ? (all.isEmpty
                    ? 'No suppliers yet. Use "+ Add Supplier" or Import CSV.'
                    : 'No suppliers match these filters.')
                : 'Showing ${rows.length} of ${all.length} suppliers',
            style: MasterStyle.muted),
      ),
    ];
  }

  Future<void> _editSupplier(InventorySupplier? existing) async {
    final id = existing?.id ?? await _store.nextSupplierId();
    if (!mounted) return;
    final result = await showDialog<InventorySupplier>(
      context: context,
      builder: (_) => _SupplierFormDialog(
          id: id,
          existing: existing,
          others: _supplierList,
          categories: {
            for (final s in _allSuppliers)
              if (s.category.trim().isNotEmpty) s.category.trim()
          }.toList()
            ..sort()),
    );
    if (result == null || !mounted) return;
    await runMasterAction(context, () => _store.upsertSupplier(result),
        success: existing == null
            ? 'Added ${result.name}'
            : 'Saved ${result.name}');
  }

  Future<void> _archiveSupplier(InventorySupplier s) async {
    final quotes = (_quotes ?? const <SupplierPriceQuote>[])
        .where((q) => q.supplierId == s.id)
        .length;
    final ok = await confirmMasterAction(context,
        title: 'Archive ${s.name}?',
        message:
            'The supplier is hidden from supplier lists and dropdowns. Purchase orders and $quotes price quote${quotes == 1 ? '' : 's'} keep their history.',
        confirmLabel: 'Archive');
    if (!ok || !mounted) return;
    await runMasterAction(context, () => _store.archiveSupplier(s.id),
        success: 'Archived ${s.name}');
  }

  void _exportSuppliers(List<InventorySupplier> rows) {
    exportCsv(context,
        fileName: 'suppliers-${_stamp()}.csv',
        headers: _supplierHeaders,
        rows: [
          for (final s in rows)
            [
              s.id,
              s.name,
              s.legalName,
              s.category,
              s.contactPerson,
              s.phone,
              s.email,
              s.gstin,
              s.city,
              s.rating,
              s.paymentTerms,
            ],
        ]);
  }

  Future<void> _importSuppliers() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    await runMasterAction(context, () async {
      final existing = await _store.getSuppliers();
      final byId = {for (final s in existing) s.id: s};
      final byName = {for (final s in existing) s.name.toLowerCase(): s};
      for (final r in records) {
        try {
          final name = r('name');
          final match = byId[r('id')] ??
              (name.isEmpty ? null : byName[name.toLowerCase()]);
          final finalName = name.isEmpty ? (match?.name ?? '') : name;
          if (finalName.isEmpty) throw _RowError('name is required');
          final rating = r.has('rating') ? r.number('rating') : match?.rating;
          if (r.has('rating') && rating == null) {
            throw _RowError('rating "${r('rating')}" is not a number');
          }
          if (rating != null && (rating < 0 || rating > 5)) {
            throw _RowError('rating must be between 0 and 5');
          }
          final email = r('email', match?.email ?? '');
          if (email.isNotEmpty && !_emailOk(email)) {
            throw _RowError('email "$email" is not valid');
          }
          final id = match?.id ??
              (r('id').isNotEmpty ? r('id') : await _store.nextSupplierId());
          final s = InventorySupplier(
            id: id,
            name: finalName,
            legalName: r('legal_name', match?.legalName ?? finalName),
            category: r('category', match?.category ?? ''),
            contactPerson: r('contact_person', match?.contactPerson ?? ''),
            phone: r('phone', match?.phone ?? ''),
            email: email,
            gstin: r('gstin', match?.gstin ?? '').toUpperCase(),
            city: r('city', match?.city ?? ''),
            rating: rating ?? 0,
            paymentTerms:
                r('payment_terms', match?.paymentTerms ?? 'Net 15 Days'),
          );
          await _store.upsertSupplier(s);
          byId[s.id] = s;
          byName[s.name.toLowerCase()] = s;
          match == null ? summary.added++ : summary.updated++;
        } on _RowError catch (e) {
          summary.errors.add('Line ${r.line}: ${e.message}');
        }
      }
    });
    if (mounted) showImportSummary(context, summary);
  }
}

class _RowError implements Exception {
  _RowError(this.message);
  final String message;
}

String _dash(String s) => s.isEmpty ? '—' : s;

String _stamp() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

bool _emailOk(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);

String _price(double v, String unit) => '${formatInr(v, decimals: 0)}/$unit';

Widget _priorityPill(String p) => MasterStatusPill(p,
    tone: switch (p) {
      'High' => PillTone.red,
      'Medium' => PillTone.amber,
      _ => PillTone.gray,
    });

/// Payment terms offered in the supplier form (a custom value already on a
/// supplier is kept as an extra option).
const supplierPaymentTerms = [
  'Advance',
  'Cash on Delivery',
  'Net 7 Days',
  'Net 15 Days',
  'Net 30 Days',
  'Net 45 Days',
];

/// Add / edit supplier form.
class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog(
      {required this.id,
      required this.existing,
      required this.others,
      this.categories = const []});
  final String id;
  final InventorySupplier? existing;
  final List<InventorySupplier> others;

  /// Supplier categories already in use, offered in the Category dropdown.
  final List<String> categories;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  /// Category dropdown value that reveals the new-category field.
  static const _newCategory = '__new_category__';

  final _form = GlobalKey<FormState>();
  late final InventorySupplier? e = widget.existing;
  late final _name = TextEditingController(text: e?.name ?? '');
  late final _legal = TextEditingController(text: e?.legalName ?? '');
  late final _category = TextEditingController(text: e?.category ?? '');
  late final _contact = TextEditingController(text: e?.contactPerson ?? '');
  late final _phone = TextEditingController(text: e?.phone ?? '');
  late final _email = TextEditingController(text: e?.email ?? '');
  late final _gstin = TextEditingController(text: e?.gstin ?? '');
  late final _city = TextEditingController(text: e?.city ?? '');
  late final _rating =
      TextEditingController(text: e == null ? '' : '${e!.rating}');
  late String _terms = () {
    final t = (e?.paymentTerms ?? '').trim();
    return t.isEmpty ? 'Net 15 Days' : t;
  }();

  late final List<String> _categories = {
    ...widget.categories,
    if ((e?.category ?? '').trim().isNotEmpty) e!.category.trim(),
  }.toList()
    ..sort();

  /// '' (no category), an existing category, or [_newCategory].
  late String _categoryChoice = (e?.category ?? '').trim().isNotEmpty
      ? e!.category.trim()
      : (widget.categories.isEmpty && e == null ? _newCategory : '');

  List<TextEditingController> get _all => [
        _name,
        _legal,
        _category,
        _contact,
        _phone,
        _email,
        _gstin,
        _city,
        _rating,
      ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      InventorySupplier(
        id: widget.id,
        name: name,
        legalName: _legal.text.trim().isEmpty ? name : _legal.text.trim(),
        category: _category.text.trim(),
        contactPerson: _contact.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        gstin: _gstin.text.trim().toUpperCase(),
        city: _city.text.trim(),
        rating: invParse(_rating.text) ?? 0,
        paymentTerms: _terms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InvFormDialog(
        title: e == null ? 'Add Supplier' : 'Edit ${e!.name}',
        formKey: _form,
        onSave: _save,
        children: [
          InvFormRow([
            InvFormText(
                label: 'Supplier Name *',
                controller: _name,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Required';
                  final dup = widget.others.any((s) =>
                      s.id != widget.id &&
                      s.name.toLowerCase() == t.toLowerCase());
                  return dup ? 'A supplier with this name exists' : null;
                }),
            InvFormText(label: 'Legal Name', controller: _legal),
          ]),
          InvFormRow([
            Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InvFormDropdown<String>(
                      label: 'Category',
                      value: _categoryChoice,
                      items: [
                        ('', 'No category'),
                        for (final c in _categories) (c, c),
                        (_newCategory, '+ Add new category…'),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _categoryChoice = v;
                          _category.text = v == _newCategory ? '' : v;
                        });
                      }),
                  if (_categoryChoice == _newCategory) ...[
                    const SizedBox(height: 10),
                    InvFormText(
                        label: 'New Category Name',
                        controller: _category,
                        hint: 'e.g. Dairy',
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Enter a name, or pick one above';
                          return _categories.any(
                                  (c) => c.toLowerCase() == t.toLowerCase())
                              ? 'Already in the list — pick it above'
                              : null;
                        }),
                  ],
                ]),
            InvFormText(label: 'City', controller: _city),
          ]),
          InvFormRow([
            InvFormText(label: 'Contact Person', controller: _contact),
            InvFormText(
                label: 'Phone',
                controller: _phone,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[0-9+\-\s()]{6,20}$').hasMatch(t)
                      ? null
                      : 'Enter a valid phone number';
                }),
          ]),
          InvFormRow([
            InvFormText(
                label: 'Email',
                controller: _email,
                validator: (v) {
                  final t = (v ?? '').trim();
                  return t.isEmpty || _emailOk(t)
                      ? null
                      : 'Enter a valid email';
                }),
            InvFormText(
                label: 'GSTIN',
                controller: _gstin,
                hint: '15 characters',
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[0-9A-Za-z]{15}$').hasMatch(t)
                      ? null
                      : 'GSTIN must be 15 letters/digits';
                }),
          ]),
          InvFormRow([
            InvFormText(
                label: 'Rating (0–5)',
                controller: _rating,
                number: true,
                validator: (v) {
                  final base = invNumberValidator()(v);
                  if (base != null) return base;
                  final n = invParse(v ?? '');
                  return n != null && n > 5 ? 'Must be 5 or less' : null;
                }),
            InvFormDropdown<String>(
                label: 'Payment Terms',
                value: _terms,
                items: [
                  for (final t in {...supplierPaymentTerms, _terms}) (t, t),
                ],
                onChanged: (v) => setState(() => _terms = v ?? _terms)),
          ]),
        ],
      );
}

/// Previous / page number / next pagination control.
class _Pagination extends StatelessWidget {
  const _Pagination(
      {required this.page, required this.pages, required this.onPage});
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    Widget box(Widget child, {bool active = false, VoidCallback? onTap}) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 32),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? ViniiColors.textPrimaryLight : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? ViniiColors.textPrimaryLight
                      : MasterStyle.cardBorder),
            ),
            child: child,
          ),
        );
    final canPrev = page > 0;
    final canNext = page < pages - 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      box(
          Icon(Icons.chevron_left,
              size: 18,
              color: canPrev
                  ? ViniiColors.textPrimaryLight
                  : ViniiColors.textMutedLight),
          onTap: canPrev ? () => onPage(page - 1) : null),
      const SizedBox(width: 6),
      box(
          Text('${page + 1} / $pages',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          active: true),
      const SizedBox(width: 6),
      box(
          Icon(Icons.chevron_right,
              size: 18,
              color: canNext
                  ? ViniiColors.textPrimaryLight
                  : ViniiColors.textMutedLight),
          onTap: canNext ? () => onPage(page + 1) : null),
    ]);
  }
}
