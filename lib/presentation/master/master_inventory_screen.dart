import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_raw_material_detail.dart';
import 'master_ui.dart';

/// Master → Raw Material Master (Figma 385:56009).
///
/// Lists raw materials live from the common [DriftInventoryStore] with
/// search and filters. Selecting a row drives the "Material Linkage" panel
/// (linked recipes — when [master] is given —, stock snapshot, purchase
/// ordering); the material name opens [MasterRawMaterialDetail] in place.
class MasterInventoryScreen extends StatefulWidget {
  const MasterInventoryScreen(
      {super.key, required this.inventory, this.master, this.currentUserName});
  final DriftInventoryStore inventory;

  /// Optional: enables the linked-recipes part of the linkage panel.
  final DriftMasterStore? master;

  /// The signed-in person, recorded as "Created by" on purchase orders
  /// raised from this screen. Null or empty leaves it blank.
  final String? currentUserName;

  @override
  State<MasterInventoryScreen> createState() => _MasterInventoryScreenState();
}

const _all = 'All';

const _csvHeaders = [
  'id',
  'code',
  'name',
  'category',
  'unit',
  'stock_qty',
  'reorder_level',
  'max_capacity',
  'purchase_cost',
  'preferred_supplier_id',
  'hsn',
  'lead_time_days',
];

class _MasterInventoryScreenState extends State<MasterInventoryScreen> {
  String _query = '';
  String _category = _all;
  String _supplier = _all;
  String _unit = _all;
  String _status = _all;
  String? _selectedId;
  String? _openId;

  final _subs = <StreamSubscription<Object?>>[];
  List<RawMaterial>? _materials;

  /// Every supplier, archived included (pickers filter to active ones).
  List<InventorySupplier> _suppliers = const [];
  List<Recipe> _recipes = const [];

  /// Dish id → current name, for recipes linked to menu items.
  Map<String, String> _dishNames = const {};

  DriftInventoryStore get _store => widget.inventory;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
          _store.watchMaterials().listen((v) => setState(() => _materials = v)))
      ..add(_store
          .watchAllSuppliers()
          .listen((v) => setState(() => _suppliers = v)));
    final master = widget.master;
    if (master != null) {
      _subs
        ..add(master
            .watchRecipes()
            .listen((v) => setState(() => _recipes = v)))
        ..add(master.watchDishes().listen((v) => setState(
            () => _dishNames = {for (final d in v) d.id: d.name})));
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

  Map<String, RawMaterial> get _materialMap =>
      {for (final m in _materials ?? const <RawMaterial>[]) m.id: m};

  List<RawMaterial> _filtered(List<RawMaterial> all) {
    final q = _query.trim().toLowerCase();
    return all.where((m) {
      if (q.isNotEmpty &&
          !m.name.toLowerCase().contains(q) &&
          !m.code.toLowerCase().contains(q)) {
        return false;
      }
      if (_category != _all && m.category != _category) return false;
      if (_supplier != _all &&
          _supplierName(m.preferredSupplierId) != _supplier) {
        return false;
      }
      if (_unit != _all && m.unit != _unit) return false;
      if (_status != _all && m.status.label != _status) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openId;
    if (openId != null) {
      return MasterRawMaterialDetail(
          inventory: _store,
          master: widget.master,
          materialId: openId,
          currentUserName: widget.currentUserName,
          onBack: () => setState(() => _openId = null));
    }
    final all = _materials;
    final rows = all == null ? const <RawMaterial>[] : _filtered(all);
    final selected = all == null || all.isEmpty
        ? null
        : all.where((m) => m.id == _selectedId).firstOrNull ??
            all.firstWhere(
                (m) =>
                    m.status == StockStatus.criticalLow ||
                    m.status == StockStatus.outOfStock,
                orElse: () => all.first);
    final critical = (all ?? const <RawMaterial>[])
        .where((m) =>
            m.status == StockStatus.criticalLow ||
            m.status == StockStatus.outOfStock)
        .toList();

    return MasterPage(children: [
      MasterPageHeader(
        title: 'Raw Materials Master',
        subtitle:
            'Inventory items mapped across kitchen dishes and food cost configurations',
        actions: [
          MasterButton(
              label: 'Audit Log',
              icon: Icons.history,
              onPressed: all == null
                  ? null
                  : () => showStockAuditLog(context, _store, all,
                      materialId: selected?.id)),
          MasterButton(
              label: 'Import CSV', icon: Icons.upload_file, onPressed: _import),
          MasterButton(
              label: 'Export CSV',
              icon: Icons.download,
              onPressed: () => _export(rows)),
          MasterButton(
              label: '+ Add Raw Material',
              kind: MasterButtonKind.primary,
              onPressed: () => showRawMaterialForm(context, _store,
                  materials: all ?? const [], suppliers: _suppliers)),
        ],
      ),
      _filterBar(all ?? const []),
      const SizedBox(height: 24),
      if (all == null)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else
        _materialsTable(rows, all, selected),
      if (selected != null) ...[
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final uses = recipeUsesFor(selected.id, _recipes, _materialMap);
          final linkage = _LinkagePanel(
            material: selected,
            supplierName: _supplierName(selected.preferredSupplierId),
            uses: widget.master == null ? null : uses,
            dishNames: _dishNames,
          );
          final ordering = _PurchaseOrderingPanel(
            material: selected,
            supplierName: _supplierName(selected.preferredSupplierId),
            linkedCount: uses.length,
            onViewSupplier: () => showSupplierInfo(
                context, _supplierOf(selected.preferredSupplierId)),
            onCreatePo: () => _createPo(selected),
          );
          if (c.maxWidth >= 980) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 692, child: linkage),
              const SizedBox(width: 24),
              Expanded(flex: 420, child: ordering),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [linkage, const SizedBox(height: 24), ordering]);
        }),
      ],
      for (final m in critical) ...[
        const SizedBox(height: 24),
        _criticalBanner(m),
      ],
    ]);
  }

  Widget _filterBar(List<RawMaterial> all) {
    final categories = {for (final m in all) m.category}.toList()..sort();
    final suppliers = {
      for (final m in all) _supplierName(m.preferredSupplierId)
    }.toList()
      ..sort();
    final units = {for (final m in all) m.unit}.toList()..sort();
    final statuses = [
      for (final s in StockStatus.values)
        if (all.any((m) => m.status == s)) s.label
    ];
    return MasterFilterBar(children: [
      MasterSearchField(
          hint: 'Search materials by name or code...',
          width: 417,
          onChanged: (v) => setState(() => _query = v)),
      MasterFilterButton(
          label: 'Category: $_category',
          options: [_all, ...categories],
          onSelected: (v) => setState(() => _category = v)),
      MasterFilterButton(
          label: 'Supplier: $_supplier',
          options: [_all, ...suppliers],
          onSelected: (v) => setState(() => _supplier = v)),
      MasterFilterButton(
          label: 'Unit: $_unit',
          options: [_all, ...units],
          onSelected: (v) => setState(() => _unit = v)),
      MasterFilterButton(
          label: 'Stock Status: $_status',
          options: [_all, ...statuses],
          onSelected: (v) => setState(() => _status = v)),
    ]);
  }

  Widget _materialsTable(
      List<RawMaterial> rows, List<RawMaterial> all, RawMaterial? selected) {
    final selectedIndex = rows.indexWhere((m) => m.id == selected?.id);
    return MasterTable(
      minWidth: 1100,
      columns: const [
        MasterColumn('Material', flex: 17),
        MasterColumn('Category', flex: 10),
        MasterColumn('Stock', flex: 8),
        MasterColumn('Unit', flex: 6),
        MasterColumn('Purchase Cost', flex: 11),
        MasterColumn('Supplier', flex: 15),
        MasterColumn('Reorder Level', flex: 10),
        MasterColumn('Status', flex: 11),
        MasterColumn('Actions', flex: 17),
      ],
      selectedRows: {if (selectedIndex >= 0) selectedIndex},
      onRowTap: (i) => setState(() => _selectedId = rows[i].id),
      rows: [
        for (final m in rows)
          [
            InkWell(
              onTap: () => setState(() {
                _selectedId = m.id;
                _openId = m.id;
              }),
              child: MasterCellTitle(m.name,
                  subtitle: m.code, isLink: true, emoji: m.emoji),
            ),
            MasterCellText(m.category),
            MasterCellText(invQty(m.stockQty, m.unit)),
            MasterCellText(m.unit),
            MasterCellText('${formatInr(m.purchaseCostPerUnit)}/${m.unit}'),
            MasterCellText(_supplierName(m.preferredSupplierId)),
            MasterCellText(invQty(m.reorderLevel, m.unit)),
            stockStatusPill(m.status),
            MasterRowActions(
                const ['View Linkage', 'Edit', 'Adjust', 'Archive'],
                onTap: (a) {
              switch (a) {
                case 'Edit':
                  showRawMaterialForm(context, _store,
                      existing: m, materials: all, suppliers: _suppliers);
                case 'Adjust':
                  showAdjustStockDialog(context, _store, m);
                case 'Archive':
                  _archive(m);
                default:
                  setState(() => _selectedId = m.id);
              }
            }),
          ],
      ],
      footer: rows.isEmpty
          ? Text(
              all.isEmpty
                  ? 'No raw materials yet. Use "+ Add Raw Material" or Import CSV.'
                  : 'No raw materials match these filters.',
              style: MasterStyle.muted)
          : Text('Showing ${rows.length} of ${all.length} materials',
              style: MasterStyle.muted),
    );
  }

  Future<void> _archive(RawMaterial m) async {
    final ok = await confirmMasterAction(context,
        title: 'Archive ${m.name}?',
        message:
            'The material is hidden from inventory lists. Its stock movements and purchase history are kept.',
        confirmLabel: 'Archive');
    if (!ok || !mounted) return;
    await runMasterAction(context, () => _store.archiveMaterial(m.id),
        success: 'Archived ${m.name}');
  }

  Widget _criticalBanner(RawMaterial m) {
    final uses = recipeUsesFor(m.id, _recipes, _materialMap);
    final names = {for (final u in uses) u.recipe.name}.toList();
    final list = names.length <= 1
        ? names.join()
        : '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}';
    final linkText = widget.master == null
        ? ''
        : names.isEmpty
            ? ' It is not linked to any recipe yet.'
            : ' This ingredient is linked to ${names.length} recipe${names.length == 1 ? '' : 's'}, including $list.';
    return MasterBanner(
      tone: PillTone.red,
      icon: '⚠️',
      message:
          'Critical Alert: ${m.name} is ${m.status == StockStatus.outOfStock ? 'out of stock' : 'running low'} '
          '(${invQty(m.stockQty, m.unit)} on hand, reorder at ${invQty(m.reorderLevel, m.unit)}).$linkText '
          'Click "Create PO" to replenish stock now.',
      trailing: MasterButton(
          label: 'Create PO',
          kind: MasterButtonKind.danger,
          onPressed: () => _createPo(m)),
    );
  }

  void _createPo(RawMaterial m) => createPurchaseOrderFor(
      context, _store, m, _suppliers,
      createdBy: widget.currentUserName ?? '');

  // -------------------------------------------------------------- CSV

  void _export(List<RawMaterial> rows) {
    final d = DateTime.now();
    final stamp =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    exportCsv(context,
        fileName: 'raw-materials-$stamp.csv',
        headers: _csvHeaders,
        rows: [
          for (final m in rows)
            [
              m.id,
              m.code,
              m.name,
              m.category,
              m.unit,
              m.stockQty,
              m.reorderLevel,
              m.maxCapacity,
              m.purchaseCostPerUnit,
              m.preferredSupplierId,
              m.hsn,
              m.leadTimeDays,
            ],
        ]);
  }

  Future<void> _import() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    await runMasterAction(context, () async {
      final existing = await _store.getMaterials();
      final supplierIds = {for (final s in await _store.getSuppliers()) s.id};
      final byId = {for (final m in existing) m.id: m};
      final byCode = {for (final m in existing) m.code.toLowerCase(): m};
      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        try {
          await _importRow(r, i, byId, byCode, supplierIds, summary);
        } on _RowError catch (e) {
          summary.errors.add('Line ${r.line}: ${e.message}');
        }
      }
    });
    if (mounted) showImportSummary(context, summary);
  }

  Future<void> _importRow(
    CsvRecord r,
    int index,
    Map<String, RawMaterial> byId,
    Map<String, RawMaterial> byCode,
    Set<String> supplierIds,
    ImportSummary summary,
  ) async {
    double? num(String h) {
      if (!r.has(h)) return null;
      final v = r.number(h);
      if (v == null) throw _RowError('$h "${r(h)}" is not a number');
      if (v < 0) throw _RowError('$h cannot be negative');
      return v;
    }

    final id = r('id');
    final code = r('code');
    final match =
        byId[id] ?? (code.isEmpty ? null : byCode[code.toLowerCase()]);
    final name = r('name', match?.name ?? '');
    if (name.isEmpty) throw _RowError('name is required');
    final category = r('category', match?.category ?? '');
    if (category.isEmpty) throw _RowError('category is required');
    final supplierId =
        r('preferred_supplier_id', match?.preferredSupplierId ?? '');
    if (supplierId.isNotEmpty && !supplierIds.contains(supplierId)) {
      throw _RowError('unknown preferred_supplier_id "$supplierId"');
    }
    final stock = num('stock_qty');
    final reorder = num('reorder_level') ?? match?.reorderLevel ?? 0;
    final lead = num('lead_time_days');
    final newCode = code.isNotEmpty
        ? code
        : match?.code ?? await _store.nextMaterialCode(category);
    final clash = byCode[newCode.toLowerCase()];
    if (clash != null && clash.id != match?.id) {
      throw _RowError('code $newCode already belongs to ${clash.name}');
    }
    final material = RawMaterial(
      id: match?.id ??
          (id.isNotEmpty
              ? id
              : 'rm-${DateTime.now().millisecondsSinceEpoch}-$index'),
      code: newCode,
      name: name,
      category: category,
      unit: r('unit', match?.unit ?? 'kg'),
      stockQty: match == null ? (stock ?? 0) : match.stockQty,
      reorderLevel: reorder,
      maxCapacity: num('max_capacity') ?? match?.maxCapacity ?? 0,
      purchaseCostPerUnit:
          num('purchase_cost') ?? match?.purchaseCostPerUnit ?? 0,
      preferredSupplierId: supplierId,
      status: stockStatusFor(match?.stockQty ?? stock ?? 0, reorder),
      hsn: r('hsn', match?.hsn ?? ''),
      emoji: match?.emoji ?? '📦',
      leadTimeDays: lead?.round() ?? match?.leadTimeDays ?? 2,
      lastPurchasePrice: match?.lastPurchasePrice,
    );
    await _store.upsertMaterial(material);
    if (match != null) {
      if (stock != null && (stock - match.stockQty).abs() > 1e-9) {
        await _store.adjustStock(match.id, stock - match.stockQty,
            reason: 'CSV Import', reference: 'Line ${r.line}');
      }
      summary.updated++;
    } else {
      summary.added++;
    }
    byId[material.id] = material;
    byCode[material.code.toLowerCase()] = material;
  }
}

class _RowError implements Exception {
  _RowError(this.message);
  final String message;
}

/// Bordered sub-card with a heading row and an optional count pill.
class _SubCard extends StatelessWidget {
  const _SubCard({required this.title, this.pill, required this.child});
  final String title;
  final Widget? pill;
  final Widget child;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight))),
            if (pill != null) pill!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _LinkagePanel extends StatelessWidget {
  const _LinkagePanel(
      {required this.material,
      required this.supplierName,
      required this.uses,
      this.dishNames = const {}});
  final RawMaterial material;
  final String supplierName;

  /// Null when recipe data is not available on this screen.
  final List<RecipeUse>? uses;

  /// Dish id → current name.
  final Map<String, String> dishNames;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final links = uses;
    Widget note(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t, style: MasterStyle.muted),
        );
    final menuItems = links == null
        ? const <RecipeUse>[]
        : links
            .where((u) => u.recipe.linkedDishName(dishNames).isNotEmpty)
            .toList();
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Material Linkage', style: MasterStyle.sectionTitle),
          const SizedBox(width: 10),
          Flexible(
              child: Text('· ${m.name}',
                  overflow: TextOverflow.ellipsis, style: MasterStyle.muted)),
        ]),
        const SizedBox(height: 16),
        _SubCard(
          title: 'Linked Recipes',
          pill: links == null
              ? null
              : MasterStatusPill('${links.length} linked',
                  tone: links.isEmpty ? PillTone.gray : PillTone.green),
          child: links == null
              ? note('Recipe linkage is not available on this screen.')
              : links.isEmpty
                  ? note('No recipes are linked to this material yet.')
                  : MasterTable(
                      minWidth: 520,
                      columns: const [
                        MasterColumn('Recipe', flex: 24),
                        MasterColumn('Qty / Portion', flex: 10),
                        MasterColumn('Cost Contribution', flex: 12),
                        MasterColumn('% of Recipe', flex: 10),
                      ],
                      rows: [
                        for (final u in links)
                          [
                            MasterCellText(u.recipe.name, bold: true),
                            MasterCellText(invQty(u.line.grossQty, u.line.unit,
                                digits: 3)),
                            MasterCellText(formatInr(u.cost)),
                            MasterCellText('${u.pct.toStringAsFixed(1)}%'),
                          ],
                      ],
                    ),
        ),
        const SizedBox(height: 16),
        _SubCard(
          title: 'Inventory Snapshot',
          pill: stockStatusPill(m.status),
          child: Column(children: [
            InvKvRow('Current Inventory', invQty(m.stockQty, m.unit),
                bold: true),
            InvKvRow('Safety Reorder Level', invQty(m.reorderLevel, m.unit)),
            InvKvRow('Maximum Capacity', invQty(m.maxCapacity, m.unit)),
            InvKvRow('Preferred Supplier', supplierName),
          ]),
        ),
        const SizedBox(height: 16),
        _SubCard(
          title: 'Affected Items',
          pill: links == null
              ? null
              : MasterStatusPill(
                  '${menuItems.length} menu item${menuItems.length == 1 ? '' : 's'}',
                  tone: PillTone.blue),
          child: links == null
              ? note('Recipe linkage is not available on this screen.')
              : menuItems.isEmpty
                  ? note('No menu items use this material through a recipe.')
                  : MasterTable(
                      minWidth: 520,
                      columns: const [
                        MasterColumn('Menu Item', flex: 35),
                        MasterColumn('Menu Group', flex: 12),
                        MasterColumn('Impact', flex: 10),
                      ],
                      rows: [
                        for (final u in menuItems)
                          [
                            MasterCellText(u.recipe.linkedDishName(dishNames),
                                bold: true),
                            MasterCellText(u.recipe.category.isEmpty
                                ? '—'
                                : u.recipe.category),
                            MasterStatusPill(u.impact),
                          ],
                      ],
                    ),
        ),
      ]),
    );
  }
}

class _PurchaseOrderingPanel extends StatelessWidget {
  const _PurchaseOrderingPanel(
      {required this.material,
      required this.supplierName,
      required this.linkedCount,
      required this.onViewSupplier,
      required this.onCreatePo});
  final RawMaterial material;
  final String supplierName;
  final int linkedCount;
  final VoidCallback onViewSupplier;
  final VoidCallback onCreatePo;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final below = m.stockQty < m.reorderLevel;
    final lastPrice = m.lastPurchasePrice;
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Purchase Ordering', style: MasterStyle.sectionTitle),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: MasterStyle.tableHeaderBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MasterStyle.cardBorder),
          ),
          child: Column(children: [
            InvKvRow('Preferred Supplier', supplierName),
            InvKvRow(
                'Last Purchase Price',
                lastPrice == null
                    ? 'No receipts yet'
                    : '${formatInr(lastPrice)} / ${m.unit}'),
            InvKvRow('Lead Time',
                '${m.leadTimeDays} day${m.leadTimeDays == 1 ? '' : 's'}'),
            InvKvRow(
                'Next Order Suggested', invQty(m.suggestedOrderQty, m.unit)),
          ]),
        ),
        const SizedBox(height: 16),
        if (below)
          MasterBanner(
            tone: PillTone.amber,
            icon: '⚠️',
            message: linkedCount == 0
                ? 'Current stock is below the safety reorder level. Replenish now to avoid kitchen delays.'
                : 'Current stock is below the safety reorder level. Replenishing now will cover $linkedCount linked recipe${linkedCount == 1 ? '' : 's'} and avoid kitchen delays.',
          )
        else
          const MasterBanner(
            tone: PillTone.green,
            icon: '✅',
            message:
                'Stock is above the safety reorder level. No purchase order is needed right now.',
          ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          MasterButton(label: 'View Supplier', onPressed: onViewSupplier),
          MasterButton(
              label: 'Create Purchase Order',
              kind: MasterButtonKind.primary,
              onPressed: onCreatePo),
        ]),
      ]),
    );
  }
}
