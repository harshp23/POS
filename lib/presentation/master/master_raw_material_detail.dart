import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// Master → Raw Material Detail (Figma 385:56242). Opened in place from
/// [MasterInventoryScreen]. Reads the material, its stock movements,
/// supplier quotes and purchase orders live from the common
/// [DriftInventoryStore]; linked recipes come from [master] when given.
class MasterRawMaterialDetail extends StatefulWidget {
  const MasterRawMaterialDetail({
    super.key,
    required this.inventory,
    required this.materialId,
    required this.onBack,
    this.master,
    this.currentUserName,
  });
  final DriftInventoryStore inventory;
  final String materialId;
  final VoidCallback onBack;
  final DriftMasterStore? master;

  /// The signed-in person, recorded as "Created by" on purchase orders
  /// raised from this screen. Null or empty leaves it blank.
  final String? currentUserName;

  @override
  State<MasterRawMaterialDetail> createState() =>
      _MasterRawMaterialDetailState();
}

const _tabs = [
  'Overview',
  'Stock',
  'Suppliers',
  'Recipes',
  'Purchase History',
  'History'
];

class _MasterRawMaterialDetailState extends State<MasterRawMaterialDetail> {
  int _tab = 0;
  final _subs = <StreamSubscription<Object?>>[];
  List<RawMaterial>? _materials;

  /// Every supplier, archived included (pickers filter to active ones).
  List<InventorySupplier> _suppliers = const [];
  List<SupplierPriceQuote> _quotes = const [];
  List<PurchaseOrder> _orders = const [];
  List<StockMovement> _movements = const [];
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
          .listen((v) => setState(() => _suppliers = v)))
      ..add(_store
          .watchSupplierPrices()
          .listen((v) => setState(() => _quotes = v)))
      ..add(_store
          .watchPurchaseOrders()
          .listen((v) => setState(() => _orders = v)))
      ..add(_store
          .watchMovements(widget.materialId)
          .listen((v) => setState(() => _movements = v)));
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

  InventorySupplier? _supplier(String id) =>
      _suppliers.where((s) => s.id == id).firstOrNull;

  String _supplierName(String id) => supplierLabel(_suppliers, id);

  Map<String, RawMaterial> get _materialMap =>
      {for (final x in _materials ?? const <RawMaterial>[]) x.id: x};

  @override
  Widget build(BuildContext context) {
    final materials = _materials;
    if (materials == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final m = materials.where((x) => x.id == widget.materialId).firstOrNull;
    if (m == null) {
      return MasterPage(children: [
        MasterBackLink(label: 'Back to Raw Materials', onTap: widget.onBack),
        const MasterBanner(
            tone: PillTone.gray,
            message:
                'This raw material no longer exists or has been archived.'),
      ]);
    }
    return MasterPage(children: [
      MasterBackLink(label: 'Back to Raw Materials', onTap: widget.onBack),
      MasterPageHeader(
        title: m.name,
        titleTrailing: stockStatusPill(m.status),
        subtitle: 'Item Code: ${m.code} · HSN: ${m.hsn.isEmpty ? '—' : m.hsn}',
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ViniiColors.grayTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
        ),
        actions: [
          MasterButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: () => showRawMaterialForm(context, _store,
                  existing: m, materials: materials, suppliers: _suppliers)),
          MasterButton(
              label: 'Archive',
              kind: MasterButtonKind.dangerOutline,
              onPressed: () => _archive(m)),
          MasterButton(
              label: 'Adjust Stock',
              onPressed: () => showAdjustStockDialog(context, _store, m)),
          MasterButton(
              label: 'Order Raw Material',
              kind: MasterButtonKind.primary,
              onPressed: () => _order(m)),
        ],
      ),
      MasterTabStrip(
          tabs: _tabs,
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i)),
      const SizedBox(height: 24),
      switch (_tab) {
        0 => _overview(m),
        1 => _stock(m),
        2 => _suppliersTab(m),
        3 => _recipesTab(m),
        4 => _purchaseHistory(m),
        _ => _history(m),
      },
    ]);
  }

  Future<void> _archive(RawMaterial m) async {
    final ok = await confirmMasterAction(context,
        title: 'Archive ${m.name}?',
        message:
            'The material is hidden from inventory lists. Its stock movements and purchase history are kept.',
        confirmLabel: 'Archive');
    if (!ok || !mounted) return;
    final done = await runMasterAction(
        context, () => _store.archiveMaterial(m.id),
        success: 'Archived ${m.name}');
    if (done) widget.onBack();
  }

  void _order(RawMaterial m) => createPurchaseOrderFor(
      context, _store, m, _suppliers,
      createdBy: widget.currentUserName ?? '');

  List<RecipeUse> _uses(RawMaterial m) =>
      recipeUsesFor(m.id, _recipes, _materialMap);

  // ---------------------------------------------------------------- Overview
  Widget _overview(RawMaterial m) {
    final receipts =
        _movements.where((x) => x.qtyDelta > 0 && x.unitCost != null).where(
              (x) => x.reason == 'GRN Receipt',
            );
    final qty = receipts.fold<double>(0, (s, x) => s + x.qtyDelta);
    final avg = qty == 0
        ? null
        : receipts.fold<double>(0, (s, x) => s + x.qtyDelta * x.unitCost!) /
            qty;
    return _split(
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MasterSection(
          title: 'Basic Information',
          child: MasterGrid(columns: 2, minItemWidth: 200, children: [
            _BoxedValue('Category', m.category),
            _BoxedValue('Storage Unit', _unitLabel(m.unit)),
            _BoxedValue('Current Cost / unit',
                '${formatInr(m.purchaseCostPerUnit)} / ${m.unit}'),
            _BoxedValue(
                'Average Purchase Price',
                avg == null
                    ? (m.lastPurchasePrice == null
                        ? 'No goods received yet'
                        : '${formatInr(m.lastPurchasePrice!)} / ${m.unit}')
                    : '${formatInr(avg)} / ${m.unit}'),
          ]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Recipe & Menu Relations',
          trailing: _affectedPill(m),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _recipeTable(m, withGroup: false),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => setState(() => _tab = 3),
                child: const Text('View Recipe Configurations →',
                    style: MasterStyle.link),
              ),
            ),
          ]),
        ),
      ]),
      _stockMetrics(m),
    );
  }

  Widget _affectedPill(RawMaterial m) {
    final n = _uses(m).length;
    return MasterStatusPill('$n Recipe${n == 1 ? '' : 's'} Affected',
        tone: n == 0 ? PillTone.gray : PillTone.blue);
  }

  Widget _stockMetrics(RawMaterial m) => MasterSection(
        title: 'Stock Metrics',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InvKvRow('Current Inventory', invQty(m.stockQty, m.unit), bold: true),
          InvKvRow('Safety Reorder Level', invQty(m.reorderLevel, m.unit)),
          InvKvRow('Maximum Capacity', invQty(m.maxCapacity, m.unit)),
          const Divider(height: 20, color: MasterStyle.cardBorder),
          InvKvRow('Preferred Supplier', _supplierName(m.preferredSupplierId)),
          const SizedBox(height: 12),
          MasterProgress(
            value: m.maxCapacity == 0 ? 0 : m.stockQty / m.maxCapacity,
            label: 'Capacity used',
            color: _statusColor(m.status),
          ),
        ]),
      );

  Widget _recipeTable(RawMaterial m, {required bool withGroup}) {
    if (widget.master == null) {
      return const _EmptyNote(
          'Recipe linkage is not available on this screen.');
    }
    final uses = _uses(m);
    if (uses.isEmpty) {
      return const _EmptyNote(
          'No recipes consume this material yet. Link it from a recipe BOM to see cost contribution here.');
    }
    return MasterTable(
      minWidth: withGroup ? 760 : 540,
      columns: [
        const MasterColumn('Recipe', flex: 17),
        if (withGroup) const MasterColumn('Menu Item', flex: 14),
        const MasterColumn('Qty / Portion', flex: 12),
        const MasterColumn('Cost Contribution', flex: 15),
        const MasterColumn('% of Recipe', flex: 10),
        if (withGroup) const MasterColumn('Impact', flex: 9),
      ],
      rows: [
        for (final u in uses)
          [
            MasterCellTitle(u.recipe.name, subtitle: u.recipe.status),
            if (withGroup)
              MasterCellText(() {
                final dish = u.recipe.linkedDishName(_dishNames);
                return dish.isEmpty ? '—' : dish;
              }()),
            MasterCellText(invQty(u.line.grossQty, u.line.unit, digits: 3)),
            MasterCellText(formatInr(u.cost)),
            MasterCellText('${u.pct.toStringAsFixed(1)}%'),
            if (withGroup) MasterStatusPill(u.impact),
          ],
      ],
    );
  }

  // ------------------------------------------------------------------- Stock
  Widget _stock(RawMaterial m) {
    final below = m.stockQty < m.reorderLevel;
    final cover = m.reorderLevel == 0 ? 1.0 : m.stockQty / m.reorderLevel;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterGrid(children: [
        MasterStatCard(
            label: 'Current Inventory',
            value: invQty(m.stockQty, m.unit),
            valueColor: _statusColor(m.status),
            caption: m.status.label,
            captionColor: _statusColor(m.status)),
        MasterStatCard(
            label: 'Safety Reorder Level',
            value: invQty(m.reorderLevel, m.unit),
            caption: '${(cover * 100).round()}% of reorder level on hand'),
        MasterStatCard(
            label: 'Maximum Capacity',
            value: invQty(m.maxCapacity, m.unit),
            caption:
                '${invQty((m.maxCapacity - m.stockQty).clamp(0, double.infinity).toDouble(), m.unit)} free'),
        MasterStatCard(
            label: 'Stock Value',
            value: formatInr(m.stockQty * m.purchaseCostPerUnit),
            caption: 'at ${formatInr(m.purchaseCostPerUnit)} / ${m.unit}'),
      ]),
      const SizedBox(height: 20),
      MasterSection(
        title: 'Stock Level',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MasterProgress(
              value: m.maxCapacity == 0 ? 0 : m.stockQty / m.maxCapacity,
              label:
                  '${invQty(m.stockQty, m.unit)} of ${invQty(m.maxCapacity, m.unit)} capacity',
              color: _statusColor(m.status)),
          const SizedBox(height: 16),
          InvKvRow('Next Order Suggested', invQty(m.suggestedOrderQty, m.unit)),
          InvKvRow('Supplier Lead Time',
              '${m.leadTimeDays} day${m.leadTimeDays == 1 ? '' : 's'}'),
          const SizedBox(height: 12),
          if (below)
            MasterBanner(
              tone: PillTone.amber,
              icon: '⚠️',
              message:
                  'Stock is below the safety reorder level. Order at least ${invQty(m.suggestedOrderQty, m.unit)} to get back to the reorder level.',
              trailing: MasterButton(
                  label: 'Order Raw Material',
                  kind: MasterButtonKind.primary,
                  onPressed: () => _order(m)),
            )
          else
            const MasterBanner(
                tone: PillTone.green,
                icon: '✅',
                message: 'Stock is above the safety reorder level.'),
        ]),
      ),
      const SizedBox(height: 20),
      MasterSection(
        title: 'Stock Movements',
        subtitle: 'Every change to stock on hand, newest first',
        trailing: MasterButton(
            label: 'Adjust Stock',
            icon: Icons.tune,
            onPressed: () => showAdjustStockDialog(context, _store, m)),
        child: StockMovementTable(
            movements: _movements, unit: m.unit, emptyText: _noMovements),
      ),
    ]);
  }

  static const _noMovements =
      'No stock movements recorded yet. Adjustments and goods receipts appear here.';

  // --------------------------------------------------------------- Suppliers
  Widget _suppliersTab(RawMaterial m) {
    final s = _supplier(m.preferredSupplierId);
    final quotes = _quotes.where((q) => q.materialId == m.id).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterSection(
        title: 'Preferred Supplier',
        trailing: s == null
            ? null
            : s.active
                ? const MasterStatusPill('Preferred', tone: PillTone.green)
                : const MasterStatusPill('Archived', tone: PillTone.gray),
        child: s == null
            ? _EmptyNote(m.preferredSupplierId.isEmpty
                ? 'No preferred supplier is set. Use Edit to choose one, or approve a supplier price quote for this material.'
                : 'The preferred supplier record is missing. Use Edit to choose another one.')
            : MasterGrid(columns: 4, minItemWidth: 180, children: [
                MasterKeyValue('Supplier', s.displayName),
                MasterKeyValue('Legal Name', s.legalName),
                MasterKeyValue('Category', _dash(s.category)),
                MasterKeyValue('Contact Person', _dash(s.contactPerson)),
                MasterKeyValue('Phone', _dash(s.phone)),
                MasterKeyValue('GSTIN', _dash(s.gstin)),
                MasterKeyValue('City', _dash(s.city)),
                MasterKeyValue('Rating', '${s.rating}★'),
                MasterKeyValue('Payment Terms', _dash(s.paymentTerms)),
                MasterKeyValue('Lead Time',
                    '${m.leadTimeDays} day${m.leadTimeDays == 1 ? '' : 's'}'),
                MasterKeyValue(
                    'Last Purchase Price',
                    m.lastPurchasePrice == null
                        ? '—'
                        : '${formatInr(m.lastPurchasePrice!)} / ${m.unit}'),
              ]),
      ),
      const SizedBox(height: 20),
      MasterSection(
        title: 'Supplier Price Quotes',
        subtitle: 'Supplier price integration entries linked to this material',
        child: quotes.isEmpty
            ? const _EmptyNote(
                'No supplier price quotes are linked to this material yet. Add one in Master → Suppliers.')
            : MasterTable(
                minWidth: 820,
                columns: const [
                  MasterColumn('Quoted Item', flex: 16),
                  MasterColumn('Supplier', flex: 14),
                  MasterColumn('Last Price', flex: 9),
                  MasterColumn('Current Price', flex: 9),
                  MasterColumn('Lowest (Wk)', flex: 9),
                  MasterColumn('Source', flex: 12),
                  MasterColumn('Status', flex: 10),
                ],
                rows: [
                  for (final q in quotes)
                    [
                      MasterCellTitle(q.ingredientName,
                          subtitle: q.skuId.isEmpty ? null : 'SKU ${q.skuId}'),
                      MasterCellText(_supplierName(q.supplierId)),
                      MasterCellText(
                          '${formatInr(q.lastPrice, decimals: 0)}/${q.unit}'),
                      MasterCellText(
                          '${formatInr(q.currentPrice, decimals: 0)}/${q.unit}',
                          bold: true),
                      MasterCellText(
                          '${formatInr(q.lowestWeek, decimals: 0)}/${q.unit}'),
                      MasterStatusPill(q.source.label, tone: PillTone.blue),
                      q.approved
                          ? const MasterStatusPill('Approved',
                              tone: PillTone.green)
                          : const MasterStatusPill('Pending'),
                    ],
                ],
              ),
      ),
    ]);
  }

  // ----------------------------------------------------------------- Recipes
  Widget _recipesTab(RawMaterial m) => MasterSection(
        title: 'Linked Recipes',
        trailing: _affectedPill(m),
        child: _recipeTable(m, withGroup: true),
      );

  // -------------------------------------------------------- Purchase History
  List<(PurchaseOrder, PurchaseOrderLine)> _poLines(RawMaterial m) => [
        for (final po in _orders)
          for (final l in po.lines)
            if (l.materialId == m.id ||
                (l.materialId == null && l.code.isNotEmpty && l.code == m.code))
              (po, l),
      ];

  Widget _purchaseHistory(RawMaterial m) {
    final lines = _poLines(m);
    return MasterSection(
      title: 'Purchase History',
      subtitle: 'Purchase orders containing ${m.name}',
      trailing: MasterButton(
          label: 'Order Raw Material',
          kind: MasterButtonKind.primary,
          onPressed: () => _order(m)),
      child: lines.isEmpty
          ? const _EmptyNote('No purchase orders contain this material yet.')
          : MasterTable(
              minWidth: 860,
              columns: const [
                MasterColumn('PO Number', flex: 9),
                MasterColumn('Supplier', flex: 15),
                MasterColumn('Order Date', flex: 10),
                MasterColumn('Ordered', flex: 8),
                MasterColumn('Received', flex: 8),
                MasterColumn('Unit Cost', flex: 9),
                MasterColumn('Line Total', flex: 10),
                MasterColumn('Status', flex: 12),
              ],
              rows: [
                for (final (po, l) in lines)
                  [
                    MasterCellText(po.number, bold: true),
                    MasterCellText(_supplierName(po.supplierId)),
                    MasterCellText(po.orderDate),
                    MasterCellText(invQty(l.orderedQty, l.unit)),
                    MasterCellText(invQty(l.receivedQty, l.unit)),
                    MasterCellText('${formatInr(l.unitCost)}/${l.unit}'),
                    MasterCellText(formatInr(l.total), bold: true),
                    MasterStatusPill(po.status.label),
                  ],
              ],
            ),
    );
  }

  // ----------------------------------------------------------------- History
  Widget _history(RawMaterial m) {
    final events = _movements;
    return MasterSection(
      title: 'Activity History',
      subtitle: 'Stock movements recorded for ${m.name}',
      child: events.isEmpty
          ? const _EmptyNote(_noMovements)
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < events.length; i++)
                _TimelineRow(
                    when: formatShortDate(events[i].createdAt),
                    title:
                        '${_signedQty(events[i].qtyDelta, m.unit)} · ${events[i].reason}',
                    detail: [
                      _time(events[i].createdAt),
                      if (events[i].reference.isNotEmpty)
                        'Ref: ${events[i].reference}',
                      if (events[i].unitCost != null)
                        '${formatInr(events[i].unitCost!)}/${m.unit}',
                    ].join(' · '),
                    positive: events[i].qtyDelta >= 0,
                    last: i == events.length - 1),
            ]),
    );
  }

  Widget _split(Widget left, Widget right) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 980
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 652, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 420, child: right),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 20), right]),
      );
}

String _dash(String s) => s.isEmpty ? '—' : s;

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _signedQty(double v, String unit) =>
    '${v >= 0 ? '+' : '-'}${invQty(v.abs(), unit)}';

String _unitLabel(String unit) => switch (unit) {
      'kg' => 'kg (Kilogram)',
      'g' => 'g (Gram)',
      'L' => 'L (Litre)',
      'ml' => 'ml (Millilitre)',
      'pcs' => 'pcs (Pieces)',
      _ => unit,
    };

Color _statusColor(StockStatus s) => switch (s) {
      StockStatus.inStock => ViniiColors.greenSolid,
      StockStatus.lowStock => ViniiColors.amberSolid,
      StockStatus.criticalLow || StockStatus.outOfStock => ViniiColors.redSolid,
    };

// ===========================================================================
// Shared inventory helpers — used by the Raw Materials list, this detail
// screen and the Suppliers screens. Every write goes through the common
// DriftInventoryStore (stock only via adjustStock / postGoodsReceipt).
// ===========================================================================

/// "12.5 kg".
String invQty(double v, String unit, {int digits = 1}) =>
    '${v.toStringAsFixed(digits)} $unit';

/// Status pill with the stock-specific tones (critical is red, not amber).
Widget stockStatusPill(StockStatus s) => MasterStatusPill(s.label,
    tone: switch (s) {
      StockStatus.inStock => PillTone.green,
      StockStatus.lowStock => PillTone.amber,
      StockStatus.criticalLow || StockStatus.outOfStock => PillTone.red,
    });

/// One recipe BOM line that consumes a given raw material.
class RecipeUse {
  const RecipeUse(
      {required this.recipe,
      required this.line,
      required this.cost,
      required this.pct});
  final Recipe recipe;
  final RecipeLine line;

  /// Cost of this material per portion of [recipe].
  final double cost;

  /// Share of the recipe's total cost, 0–100.
  final double pct;

  String get impact => pct >= 30
      ? 'High'
      : pct >= 10
          ? 'Medium'
          : 'Low';
}

/// Recipes whose BOM lines reference [materialId], priced from [materials].
List<RecipeUse> recipeUsesFor(String materialId, List<Recipe> recipes,
    Map<String, RawMaterial> materials) {
  final out = <RecipeUse>[];
  for (final r in recipes) {
    final total = r.totalCost(materials);
    for (final l in r.lines) {
      if (l.materialId != materialId) continue;
      final cost = l.costWith(materials[materialId]);
      out.add(RecipeUse(
          recipe: r,
          line: l,
          cost: cost,
          pct: total <= 0 ? 0 : cost / total * 100));
    }
  }
  return out;
}

/// Label/value row used in side panels.
class InvKvRow extends StatelessWidget {
  const InvKvRow(this.label, this.value, {super.key, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textSecondaryLight))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: bold ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
          ),
        ]),
      );
}

/// Table of stock movements (date, change, reason, reference, unit cost).
class StockMovementTable extends StatelessWidget {
  const StockMovementTable(
      {super.key,
      required this.movements,
      required this.unit,
      required this.emptyText,
      this.materialNames});
  final List<StockMovement> movements;
  final String unit;
  final String emptyText;

  /// When given, a Material column is shown (all-materials audit log).
  final Map<String, (String, String)>? materialNames;

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) return _EmptyNote(emptyText);
    final names = materialNames;
    return MasterTable(
      minWidth: names == null ? 640 : 760,
      columns: [
        const MasterColumn('Date', flex: 12),
        if (names != null) const MasterColumn('Material', flex: 14),
        const MasterColumn('Change', flex: 10),
        const MasterColumn('Reason', flex: 13),
        const MasterColumn('Reference', flex: 14),
        const MasterColumn('Unit Cost', flex: 9, alignEnd: true),
      ],
      rows: [
        for (final mv in movements)
          () {
            final u = names?[mv.materialId]?.$2 ?? unit;
            return <Widget>[
              MasterCellTitle(formatShortDate(mv.createdAt),
                  subtitle: _time(mv.createdAt)),
              if (names != null)
                MasterCellText(names[mv.materialId]?.$1 ?? 'Removed material',
                    bold: true),
              MasterCellText(_signedQty(mv.qtyDelta, u),
                  bold: true,
                  color: mv.qtyDelta >= 0
                      ? ViniiColors.greenSolid
                      : ViniiColors.redSolid),
              MasterCellText(mv.reason),
              MasterCellText(mv.reference.isEmpty ? '—' : mv.reference),
              MasterCellText(
                  mv.unitCost == null ? '—' : formatInr(mv.unitCost!)),
            ];
          }(),
      ],
    );
  }
}

// ----------------------------------------------------------- form widgets

InputDecoration invInputDecoration({String? hint, String? suffix}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      suffixText: suffix,
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

/// Labelled text input bound to a controller, in the Master form style.
class InvFormText extends StatelessWidget {
  const InvFormText({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.validator,
    this.onChanged,
    this.number = false,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool number;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _fieldLabel),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              validator: validator,
              onChanged: onChanged,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              style: const TextStyle(fontSize: 13),
              decoration: invInputDecoration(hint: hint, suffix: suffix),
            ),
          ]);
}

/// Labelled dropdown in the Master form style.
class InvFormDropdown<T> extends StatelessWidget {
  const InvFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  /// False shows the value read-only (e.g. a unit locked to a material).
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _fieldLabel),
            const SizedBox(height: 6),
            DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              validator: validator,
              style: const TextStyle(
                  fontSize: 13, color: ViniiColors.textPrimaryLight),
              decoration: invInputDecoration(),
              items: [
                for (final (v, text) in items)
                  DropdownMenuItem<T>(
                      value: v,
                      child: Text(text, overflow: TextOverflow.ellipsis)),
              ],
              disabledHint: enabled
                  ? null
                  : Text(
                      items
                          .where((i) => i.$1 == value)
                          .map((i) => i.$2)
                          .join(),
                      overflow: TextOverflow.ellipsis),
              onChanged: enabled ? onChanged : null,
            ),
          ]);
}

/// Two fields side by side on wide dialogs, stacked on narrow ones.
class InvFormRow extends StatelessWidget {
  const InvFormRow(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 420) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    children[i],
                  ],
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: children[i]),
            ],
          ]);
        }),
      );
}

/// Parses a form number ("₹1,240.50" → 1240.5); null when blank/invalid.
double? invParse(String s) {
  final raw = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return raw.isEmpty ? null : double.tryParse(raw);
}

/// Validator: optional (or required) number ≥ 0.
FormFieldValidator<String> invNumberValidator(
        {bool required = false, bool positive = false}) =>
    (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return required ? 'Required' : null;
      final n = invParse(t);
      if (n == null) return 'Enter a number';
      if (n < 0) return 'Must be 0 or more';
      if (positive && n == 0) return 'Must be more than 0';
      return null;
    };

String? invRequired(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

/// Standard form dialog shell: title, scrollable body, Cancel / Save.
class InvFormDialog extends StatelessWidget {
  const InvFormDialog({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Save',
    this.width = 560,
  });
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;
  final double width;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: MasterStyle.sectionTitle),
        content: SizedBox(
          width: width,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children),
            ),
          ),
        ),
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              label: saveLabel,
              kind: MasterButtonKind.primary,
              onPressed: onSave),
        ],
      );
}

// ------------------------------------------------------- material form

const invUnits = masterUnits;

/// Add (existing == null) or edit a raw material, saved via upsertMaterial.
/// [suppliers] may include archived ones: only active suppliers are
/// offered, and an archived preferred supplier is shown by name.
Future<void> showRawMaterialForm(
  BuildContext context,
  DriftInventoryStore store, {
  RawMaterial? existing,
  required List<RawMaterial> materials,
  required List<InventorySupplier> suppliers,
}) async {
  final result = await showDialog<RawMaterial>(
    context: context,
    builder: (_) => _MaterialFormDialog(
        store: store,
        existing: existing,
        materials: materials,
        suppliers: suppliers),
  );
  if (result == null || !context.mounted) return;
  await runMasterAction(context, () => store.upsertMaterial(result),
      success: existing == null
          ? 'Added ${result.name} (${result.code})'
          : 'Saved ${result.name}');
}

class _MaterialFormDialog extends StatefulWidget {
  const _MaterialFormDialog(
      {required this.store,
      required this.existing,
      required this.materials,
      required this.suppliers});
  final DriftInventoryStore store;
  final RawMaterial? existing;
  final List<RawMaterial> materials;
  final List<InventorySupplier> suppliers;

  @override
  State<_MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<_MaterialFormDialog> {
  final _form = GlobalKey<FormState>();
  late final RawMaterial? e = widget.existing;
  late final _name = TextEditingController(text: e?.name ?? '');
  late final _code = TextEditingController(text: e?.code ?? '');
  late final _category = TextEditingController(text: e?.category ?? '');
  late final _stock = TextEditingController(text: e == null ? '0' : '');
  late final _reorder =
      TextEditingController(text: e == null ? '' : _n(e!.reorderLevel));
  late final _max =
      TextEditingController(text: e == null ? '' : _n(e!.maxCapacity));
  late final _cost =
      TextEditingController(text: e == null ? '' : _n(e!.purchaseCostPerUnit));
  late final _hsn = TextEditingController(text: e?.hsn ?? '');
  late final _lead = TextEditingController(text: '${e?.leadTimeDays ?? 2}');
  late final _emoji = TextEditingController(text: e?.emoji ?? '📦');
  late String _unit = e?.unit ?? 'kg';
  late String _supplierId = e?.preferredSupplierId ?? '';
  bool _codeTouched = false;

  /// Value of the category dropdown item that reveals the new-name field.
  static const _newCategory = '__new_category__';

  /// Selected existing category, or [_newCategory]. The chosen / typed name
  /// itself lives in [_category].
  late String _categoryChoice;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  List<String> get _categories => {
        for (final m in widget.materials)
          if (m.category.trim().isNotEmpty) m.category,
        if (e != null && e!.category.trim().isNotEmpty) e!.category,
      }.toList()
        ..sort();

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _category,
      _stock,
      _reorder,
      _max,
      _cost,
      _hsn,
      _lead,
      _emoji
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autoCode() async {
    if (e != null || _codeTouched) return;
    final cat = _category.text.trim();
    if (cat.isEmpty) return;
    final code = await widget.store.nextMaterialCode(cat);
    if (!mounted || _codeTouched || _category.text.trim() != cat) return;
    setState(() => _code.text = code);
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final stock = e?.stockQty ?? (invParse(_stock.text) ?? 0);
    final reorder = invParse(_reorder.text) ?? 0;
    Navigator.pop(
      context,
      RawMaterial(
        id: e?.id ?? 'rm-${DateTime.now().millisecondsSinceEpoch}',
        code: _code.text.trim(),
        name: _name.text.trim(),
        category: _category.text.trim(),
        unit: _unit,
        stockQty: stock,
        reorderLevel: reorder,
        maxCapacity: invParse(_max.text) ?? 0,
        purchaseCostPerUnit: invParse(_cost.text) ?? 0,
        preferredSupplierId: _supplierId,
        status: stockStatusFor(stock, reorder),
        hsn: _hsn.text.trim(),
        emoji: _emoji.text.trim().isEmpty ? '📦' : _emoji.text.trim(),
        leadTimeDays: (invParse(_lead.text) ?? 0).round(),
        lastPurchasePrice: e?.lastPurchasePrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = {...invUnits, _unit}.toList();
    final active = [
      for (final s in widget.suppliers)
        if (s.active) s
    ];
    final supplierItems = <(String, String)>[
      ('', 'None'),
      for (final s in active) (s.id, s.name),
      // An archived (or missing) preferred supplier stays selectable by name.
      if (_supplierId.isNotEmpty && !active.any((s) => s.id == _supplierId))
        (_supplierId, supplierLabel(widget.suppliers, _supplierId)),
    ];
    final categories = _categories;
    return InvFormDialog(
      title: e == null ? 'Add Raw Material' : 'Edit ${e!.name}',
      formKey: _form,
      onSave: _save,
      children: [
        InvFormRow([
          InvFormText(
              label: 'Material Name *',
              controller: _name,
              hint: 'e.g. Paneer',
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Required';
                final dup = widget.materials.any((m) =>
                    m.id != e?.id && m.name.toLowerCase() == t.toLowerCase());
                return dup ? 'A material with this name exists' : null;
              }),
          InvFormText(label: 'Emoji', controller: _emoji, hint: '📦'),
        ]),
        InvFormRow([
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                InvFormDropdown<String>(
                    label: 'Category *',
                    value: _categoryChoice,
                    items: [
                      for (final c in categories) (c, c),
                      (_newCategory, '+ Add new category…'),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _categoryChoice = v;
                        if (v == _newCategory) {
                          _category.clear();
                        } else {
                          _category.text = v;
                        }
                      });
                      _autoCode();
                    }),
                if (_categoryChoice == _newCategory) ...[
                  const SizedBox(height: 10),
                  InvFormText(
                      label: 'New Category Name *',
                      controller: _category,
                      hint: 'e.g. Grains',
                      onChanged: (_) => _autoCode(),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Required';
                        return categories
                                .any((c) => c.toLowerCase() == t.toLowerCase())
                            ? 'Already in the list — pick it above'
                            : null;
                      }),
                ],
              ]),
          InvFormText(
              label: 'Item Code *',
              controller: _code,
              hint: 'Auto from category',
              onChanged: (_) => _codeTouched = true,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Required';
                final dup = widget.materials.any((m) =>
                    m.id != e?.id && m.code.toLowerCase() == t.toLowerCase());
                return dup ? 'Code already used' : null;
              }),
        ]),
        InvFormRow([
          InvFormDropdown<String>(
              label: 'Unit *',
              value: _unit,
              items: [for (final u in units) (u, u)],
              onChanged: (v) => setState(() => _unit = v ?? _unit)),
          if (e == null)
            InvFormText(
                label: 'Opening Stock',
                controller: _stock,
                number: true,
                suffix: _unit,
                validator: invNumberValidator())
          else
            InvKvRow('Stock on hand', invQty(e!.stockQty, e!.unit), bold: true),
        ]),
        InvFormRow([
          InvFormText(
              label: 'Reorder Level *',
              controller: _reorder,
              number: true,
              suffix: _unit,
              validator: invNumberValidator(required: true)),
          InvFormText(
              label: 'Max Capacity *',
              controller: _max,
              number: true,
              suffix: _unit,
              validator: invNumberValidator(required: true)),
        ]),
        InvFormRow([
          InvFormText(
              label: 'Purchase Cost / unit (₹) *',
              controller: _cost,
              number: true,
              validator: invNumberValidator(required: true)),
          InvFormDropdown<String>(
              label: 'Preferred Supplier',
              value: _supplierId,
              items: supplierItems,
              onChanged: (v) => setState(() => _supplierId = v ?? '')),
        ]),
        InvFormRow([
          InvFormText(label: 'HSN Code', controller: _hsn, hint: 'e.g. 0406'),
          InvFormText(
              label: 'Lead Time (days)',
              controller: _lead,
              number: true,
              validator: invNumberValidator()),
        ]),
        if (e == null)
          const Text(
              'Opening stock is recorded as an "Opening Stock" movement. After saving, stock only changes through Adjust Stock or goods receipts.',
              style: MasterStyle.muted),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final existing = e;
    final categories = _categories;
    if (existing != null && existing.category.trim().isNotEmpty) {
      _categoryChoice = existing.category;
    } else if (existing == null && categories.isNotEmpty) {
      _categoryChoice = categories.first;
      _category.text = categories.first;
      _autoCode();
    } else {
      _categoryChoice = _newCategory;
    }
  }
}

// ----------------------------------------------------- adjust stock

const adjustReasons = [
  'Count Correction',
  'Wastage',
  'Spoilage',
  'Opening Stock',
  'Other'
];

/// Manual stock change through [DriftInventoryStore.adjustStock].
Future<void> showAdjustStockDialog(
    BuildContext context, DriftInventoryStore store, RawMaterial m) async {
  final result = await showDialog<(double, String, String)>(
      context: context, builder: (_) => _AdjustStockDialog(material: m));
  if (result == null || !context.mounted) return;
  final (delta, reason, reference) = result;
  await runMasterAction(
      context,
      () =>
          store.adjustStock(m.id, delta, reason: reason, reference: reference),
      success: '${m.name}: ${_signedQty(delta, m.unit)} ($reason)');
}

class _AdjustStockDialog extends StatefulWidget {
  const _AdjustStockDialog({required this.material});
  final RawMaterial material;

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _ref = TextEditingController();
  bool _add = true;
  String _reason = adjustReasons.first;

  @override
  void dispose() {
    _qty.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final q = invParse(_qty.text) ?? 0;
    final after = _add ? m.stockQty + q : m.stockQty - q;
    return InvFormDialog(
      title: 'Adjust Stock · ${m.name}',
      formKey: _form,
      width: 460,
      saveLabel: 'Save Adjustment',
      onSave: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        final v = invParse(_qty.text)!;
        Navigator.pop(context, (_add ? v : -v, _reason, _ref.text.trim()));
      },
      children: [
        InvKvRow('Current stock', invQty(m.stockQty, m.unit), bold: true),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true, label: Text('Add'), icon: Icon(Icons.add)),
            ButtonSegment(
                value: false, label: Text('Remove'), icon: Icon(Icons.remove)),
          ],
          selected: {_add},
          onSelectionChanged: (s) => setState(() => _add = s.first),
        ),
        const SizedBox(height: 14),
        InvFormText(
          label: 'Quantity *',
          controller: _qty,
          number: true,
          suffix: m.unit,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final base = invNumberValidator(required: true, positive: true)(v);
            if (base != null) return base;
            if (!_add && invParse(v!)! > m.stockQty) {
              return 'Only ${invQty(m.stockQty, m.unit)} on hand';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        InvFormDropdown<String>(
            label: 'Reason *',
            value: _reason,
            items: [for (final r in adjustReasons) (r, r)],
            onChanged: (v) => setState(() => _reason = v ?? _reason)),
        const SizedBox(height: 14),
        InvFormText(
            label: 'Reference',
            controller: _ref,
            hint: 'e.g. Stock count sheet #12'),
        const SizedBox(height: 14),
        InvKvRow(
            'Stock after adjustment', invQty(after < 0 ? 0 : after, m.unit),
            bold: true),
      ],
    );
  }
}

// -------------------------------------------------- create purchase order

/// Drafts a purchase order for [m] (suggested qty, preferred supplier) via
/// savePurchaseOrder and reports the new PO number. Only active suppliers
/// are offered; [createdBy] (the signed-in person) is recorded on the PO.
Future<void> createPurchaseOrderFor(BuildContext context,
    DriftInventoryStore store, RawMaterial m, List<InventorySupplier> suppliers,
    {String createdBy = ''}) async {
  final active = [
    for (final s in suppliers)
      if (s.active) s
  ];
  if (active.isEmpty) {
    showMasterError(
        context, 'Add a supplier first (Master → Suppliers → Suppliers).');
    return;
  }
  final result = await showDialog<(String, double, double)>(
      context: context,
      builder: (_) => _CreatePoDialog(material: m, suppliers: active));
  if (result == null || !context.mounted) return;
  final (supplierId, qty, cost) = result;
  var number = '';
  await runMasterAction(context, () async {
    number = await store.nextPoNumber();
    final now = DateTime.now();
    await store.savePurchaseOrder(PurchaseOrder(
      number: number,
      supplierId: supplierId,
      orderDate: formatShortDate(now),
      expectedDelivery:
          formatShortDate(now.add(Duration(days: m.leadTimeDays))),
      status: PurchaseOrderStatus.draft,
      createdBy: createdBy.trim(),
      notes: 'Raised from Raw Materials for ${m.name}',
      lines: [
        PurchaseOrderLine(
          materialId: m.id,
          materialName: m.name,
          code: m.code,
          unit: m.unit,
          unitCost: cost,
          orderedQty: qty,
        ),
      ],
    ));
  });
  if (number.isNotEmpty && context.mounted) {
    showMasterNotice(context,
        '$number created (Draft) · ${invQty(qty, m.unit)} of ${m.name}');
  }
}

class _CreatePoDialog extends StatefulWidget {
  const _CreatePoDialog({required this.material, required this.suppliers});
  final RawMaterial material;
  final List<InventorySupplier> suppliers;

  @override
  State<_CreatePoDialog> createState() => _CreatePoDialogState();
}

class _CreatePoDialogState extends State<_CreatePoDialog> {
  final _form = GlobalKey<FormState>();
  late final RawMaterial m = widget.material;
  late String _supplierId =
      widget.suppliers.any((s) => s.id == m.preferredSupplierId)
          ? m.preferredSupplierId
          : widget.suppliers.first.id;
  late final _qty = TextEditingController(text: () {
    var q = m.suggestedOrderQty;
    if (q <= 0) q = (m.maxCapacity - m.stockQty).clamp(0, double.infinity);
    if (q <= 0) q = m.reorderLevel;
    return q <= 0 ? '' : q.toStringAsFixed(q == q.roundToDouble() ? 0 : 2);
  }());
  late final _cost =
      TextEditingController(text: m.purchaseCostPerUnit.toString());

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (invParse(_qty.text) ?? 0) * (invParse(_cost.text) ?? 0);
    return InvFormDialog(
      title: 'Create Purchase Order · ${m.name}',
      formKey: _form,
      width: 480,
      saveLabel: 'Create Draft PO',
      onSave: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        Navigator.pop(context,
            (_supplierId, invParse(_qty.text)!, invParse(_cost.text)!));
      },
      children: [
        InvKvRow('Current stock', invQty(m.stockQty, m.unit)),
        InvKvRow('Suggested (to reorder level)',
            invQty(m.suggestedOrderQty, m.unit)),
        const SizedBox(height: 10),
        InvFormDropdown<String>(
            label: 'Supplier *',
            value: _supplierId,
            items: [
              for (final s in widget.suppliers)
                (s.id, s.caption.isEmpty ? s.name : '${s.name} · ${s.caption}')
            ],
            onChanged: (v) => setState(() => _supplierId = v ?? _supplierId)),
        const SizedBox(height: 14),
        InvFormRow([
          InvFormText(
              label: 'Order Quantity *',
              controller: _qty,
              number: true,
              suffix: m.unit,
              onChanged: (_) => setState(() {}),
              validator: invNumberValidator(required: true, positive: true)),
          InvFormText(
              label: 'Unit Cost (₹) *',
              controller: _cost,
              number: true,
              onChanged: (_) => setState(() {}),
              validator: invNumberValidator(required: true)),
        ]),
        InvKvRow('Line total (before tax)', formatInr(total), bold: true),
        const SizedBox(height: 6),
        const Text(
            'The PO is saved as a Draft in Purchase Orders. Stock is added only when goods are received against it.',
            style: MasterStyle.muted),
      ],
    );
  }
}

// ------------------------------------------------------ supplier + audit

/// Read-only supplier card dialog.
void showSupplierInfo(BuildContext context, InventorySupplier? s) {
  if (s == null) {
    showMasterNotice(context,
        'No preferred supplier is set for this material — use Edit to choose one.');
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(s.displayName, style: MasterStyle.sectionTitle),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InvKvRow('Legal Name', _dash(s.legalName)),
          InvKvRow('Category', _dash(s.category)),
          InvKvRow('Contact', _dash(s.contactPerson)),
          InvKvRow('Phone', _dash(s.phone)),
          InvKvRow('Email', _dash(s.email)),
          InvKvRow('GSTIN', _dash(s.gstin)),
          InvKvRow('City', _dash(s.city)),
          InvKvRow('Rating', '${s.rating}★'),
          InvKvRow('Payment Terms', _dash(s.paymentTerms)),
        ]),
      ),
      actions: [
        MasterButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

/// Stock movement audit log for one material, or all materials.
Future<void> showStockAuditLog(BuildContext context, DriftInventoryStore store,
    List<RawMaterial> materials,
    {String? materialId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AuditLogDialog(
        store: store, materials: materials, initialId: materialId),
  );
}

const _allMaterials = '__all__';

class _AuditLogDialog extends StatefulWidget {
  const _AuditLogDialog(
      {required this.store, required this.materials, this.initialId});
  final DriftInventoryStore store;
  final List<RawMaterial> materials;
  final String? initialId;

  @override
  State<_AuditLogDialog> createState() => _AuditLogDialogState();
}

class _AuditLogDialogState extends State<_AuditLogDialog> {
  late String _id = widget.initialId ?? _allMaterials;
  late Stream<List<StockMovement>> _stream = _streamFor(_id);

  Stream<List<StockMovement>> _streamFor(String id) {
    if (id != _allMaterials) return widget.store.watchMovements(id);
    // No store-wide movement stream: merge a one-off read of each material.
    return Stream.fromFuture(Future.wait([
      for (final m in widget.materials) widget.store.watchMovements(m.id).first
    ]).then((lists) => [for (final l in lists) ...l]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt))));
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      for (final m in widget.materials) m.id: (m.name, m.unit),
    };
    final selected = widget.materials.where((m) => m.id == _id).firstOrNull;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Stock Audit Log', style: MasterStyle.sectionTitle),
      content: SizedBox(
        width: 820,
        height: 520,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InvFormDropdown<String>(
            label: 'Material',
            value: _id,
            items: [
              (_allMaterials, 'All materials'),
              for (final m in widget.materials) (m.id, '${m.name} · ${m.code}'),
            ],
            onChanged: (v) => setState(() {
              _id = v ?? _allMaterials;
              _stream = _streamFor(_id);
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<StockMovement>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  child: StockMovementTable(
                    movements: snap.data!,
                    unit: selected?.unit ?? '',
                    materialNames: selected == null ? names : null,
                    emptyText: 'No stock movements recorded yet.',
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        MasterButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

// ----------------------------------------------------------- private UI

class _BoxedValue extends StatelessWidget {
  const _BoxedValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: MasterStyle.label),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: MasterStyle.tableHeaderBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MasterStyle.cardBorder),
              ),
              child: Text(value, style: MasterStyle.body),
            ),
          ]);
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: MasterStyle.muted),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(
      {required this.when,
      required this.title,
      required this.detail,
      required this.positive,
      required this.last});
  final String when;
  final String title;
  final String detail;
  final bool positive;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 96,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(when, style: MasterStyle.muted),
              )),
          Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color:
                      positive ? ViniiColors.greenSolid : ViniiColors.redSolid,
                  shape: BoxShape.circle),
            ),
            if (!last)
              Expanded(
                  child: Container(width: 2, color: MasterStyle.cardBorder)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detail, style: MasterStyle.muted),
                  ]),
            ),
          ),
        ]),
      );
}
