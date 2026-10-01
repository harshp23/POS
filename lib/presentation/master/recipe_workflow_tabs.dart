import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// Tabs 1-6 of the Recipes lifecycle (Figma "recipe-core-workflow",
/// screens 1-6). Every value shown is read live from the database through
/// [RecipeData]; ingredient costs come from the linked raw material's
/// current costing price, so approving a supplier price changes recipe
/// costs immediately.

// ---------------------------------------------------------------------------
// Shared recipe context + helpers (also used by recipe_lifecycle_tabs.dart)
// ---------------------------------------------------------------------------

/// Minimum gross margin a recipe should reach at its target price.
const recipeMarginThresholdPct = 60.0;

/// Everything a recipe tab needs: the stores, the live lists and the
/// recipe currently selected in the Recipes screen (null when there are no
/// recipes yet).
class RecipeData {
  const RecipeData({
    required this.master,
    required this.inventory,
    required this.recipes,
    required this.recipe,
    required this.materials,
    required this.quotes,
    required this.suppliers,
    required this.dishes,
    this.staffNames = const [],
  });

  final DriftMasterStore master;
  final DriftInventoryStore inventory;
  final List<Recipe> recipes;
  final Recipe? recipe;
  final Map<String, RawMaterial> materials;
  final List<SupplierPriceQuote> quotes;

  /// Suppliers for naming quotes — pass every supplier, archived included,
  /// so an archived one still reads "Name (archived)".
  final List<InventorySupplier> suppliers;
  final List<MasterDishItem> dishes;

  /// Staff names offered in the Staff Training picker; empty keeps the
  /// free-text field.
  final List<String> staffNames;

  RawMaterial? materialFor(RecipeLine l) =>
      l.materialId == null ? null : materials[l.materialId];

  /// Unit price used for costing a line (material price or fallback).
  double unitCostFor(RecipeLine l) =>
      materialFor(l)?.purchaseCostPerUnit ?? l.fallbackUnitCost;

  double lineCost(RecipeLine l) => l.costWith(materialFor(l));

  double ingredientCost(Recipe r) => r.ingredientCost(materials);
  double totalCost(Recipe r) => r.totalCost(materials);
  double marginPct(Recipe r) => r.marginPct(materials);

  /// Supplier name ("(archived)" when archived, "Unknown supplier" when
  /// the record is gone, "—" when none is set).
  String supplierName(String id) => supplierLabel(suppliers, id, none: '—');

  InventorySupplier? supplier(String id) {
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  MasterDishItem? dish(String? id) {
    if (id == null) return null;
    for (final d in dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Dish id → current name.
  Map<String, String> get dishNames => {for (final d in dishes) d.id: d.name};

  /// The current name of [r]'s linked dish ('' when not linked).
  String dishName(Recipe r) => r.linkedDishName(dishNames);

  /// Menu categories (from the dishes) plus those already on recipes.
  List<String> get categoryOptions => {
        for (final d in dishes)
          if (d.category.trim().isNotEmpty) d.category.trim(),
        for (final r in recipes)
          if (r.category.trim().isNotEmpty) r.category.trim(),
      }.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<SupplierPriceQuote> quotesFor(String? materialId) => materialId == null
      ? const []
      : [
          for (final q in quotes)
            if (q.materialId == materialId) q
        ];
}

/// Shown by tabs 2-10 when no recipe exists yet.
class RecipeNoSelection extends StatelessWidget {
  const RecipeNoSelection({super.key});

  @override
  Widget build(BuildContext context) => const MasterPage(children: [
        MasterCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Text('📖', style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
              Text('No recipe selected', style: MasterStyle.sectionTitle),
              SizedBox(height: 4),
              Text(
                  'Create a recipe from the Overview tab to start its lifecycle.',
                  textAlign: TextAlign.center,
                  style: MasterStyle.muted),
            ]),
          ),
        ),
      ]);
}

/// Labelled text field with a controller + validator, styled like
/// [MasterTextField].
class RecipeField extends StatelessWidget {
  const RecipeField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.maxLines = 1,
    this.validator,
    this.number = false,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final bool number;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              validator: validator,
              onChanged: onChanged,
              maxLines: maxLines,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              style: const TextStyle(fontSize: 13),
              decoration: recipeInputDecoration(hint: hint, suffix: suffix),
            ),
          ]);
}

InputDecoration recipeInputDecoration({String? hint, String? suffix}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c));
  return InputDecoration(
    isDense: true,
    hintText: hint,
    suffixText: suffix,
    hintStyle: const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: b(MasterStyle.cardBorder),
    enabledBorder: b(MasterStyle.cardBorder),
    errorBorder: b(ViniiColors.redSolid),
  );
}

/// Labelled dropdown styled like [RecipeField].
class RecipeDropdown<T> extends StatelessWidget {
  const RecipeDropdown({
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
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  /// False shows the value read-only (e.g. a unit locked to a material).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = items.where((i) => i.value == value).firstOrNull;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            items: items,
            onChanged: enabled ? onChanged : null,
            disabledHint: enabled ? null : selected?.child,
            validator: validator,
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textPrimaryLight),
            decoration: recipeInputDecoration(),
          ),
        ]);
  }
}

/// Recipe category picker: menu categories plus those already on recipes.
/// [value] is the category name ('' = none); a value not in the list (from
/// older data) stays selectable.
Widget recipeCategoryDropdown(
    {Key? key,
    required RecipeData data,
    required String value,
    required ValueChanged<String> onChanged}) {
  final current = value.trim();
  final options = {
    ...data.categoryOptions,
    if (current.isNotEmpty) current,
  };
  return RecipeDropdown<String>(
    key: key,
    label: 'Category',
    value: current,
    items: [
      const DropdownMenuItem(value: '', child: Text('No category')),
      for (final c in options)
        DropdownMenuItem(
            value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
    ],
    onChanged: (v) => onChanged(v ?? ''),
  );
}

String? recipeRequired(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Validator for a number ≥ 0 (or > 0 with [positive]).
FormFieldValidator<String> recipeNumber(
        {bool required = true, bool positive = false, double? max}) =>
    (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return required ? 'Required' : null;
      final n = double.tryParse(t);
      if (n == null) return 'Enter a number';
      if (positive && n <= 0) return 'Must be greater than 0';
      if (n < 0) return 'Must be 0 or more';
      if (max != null && n > max) return 'Must be at most ${recipeQty(max)}';
      return null;
    };

double recipeParse(String s) => double.tryParse(s.trim()) ?? 0;

String recipeQty(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

String recipeToday() => DateTime.now().toIso8601String().substring(0, 10);

String recipePct(double v) => '${v.toStringAsFixed(1)}%';

/// "v1.4" → "v1.5"; anything unparseable gets ".1" appended.
String bumpRecipeVersion(String v) {
  final m = RegExp(r'^v?(\d+)(?:\.(\d+))?$').firstMatch(v.trim());
  if (m == null) return '${v.trim()}.1';
  final minor = int.parse(m.group(2) ?? '0') + 1;
  return 'v${m.group(1)}.$minor';
}

/// Copy of [r] with a new linked menu item (copyWith cannot clear it).
Recipe recipeWithLink(Recipe r, String? dishId, String dishName) => Recipe(
      id: r.id,
      code: r.code,
      name: r.name,
      version: r.version,
      linkedMenuItemId: dishId,
      linkedMenuItemName: dishId == null ? '' : dishName,
      category: r.category,
      portion: r.portion,
      targetPrice: r.targetPrice,
      laborCost: r.laborCost,
      packagingCost: r.packagingCost,
      trialResult: r.trialResult,
      trainingDone: r.trainingDone,
      trainingTotal: r.trainingTotal,
      status: r.status,
      prepMethod: r.prepMethod,
      allergens: r.allergens,
      activeChannels: r.activeChannels,
      lines: r.lines,
    );

/// Saves [r] through the master store, showing errors as a snackbar.
Future<bool> saveRecipeRecord(BuildContext context, RecipeData data, Recipe r,
        {String? success}) =>
    runMasterAction(context, () => data.master.saveRecipe(r), success: success);

PillTone recipeStatusTone(String s) => switch (s) {
      'Active' || 'Approved' => PillTone.green,
      'Needs Attention' || 'Rejected' => PillTone.red,
      'In Trial' => PillTone.blue,
      _ => PillTone.amber,
    };

PillTone recipeTrialTone(String r) {
  final t = r.toLowerCase();
  if (t.startsWith('pass')) return PillTone.green;
  if (t.contains('fail')) return PillTone.red;
  if (t.startsWith('pending')) return PillTone.gray;
  return PillTone.amber;
}

// ---------------------------------------------------------------------------
// Shared layout helpers
// ---------------------------------------------------------------------------

/// Figma 692 / 420 main + side column split; stacks on narrow widths.
class _Split extends StatelessWidget {
  const _Split({required this.main, required this.side});
  final Widget main;
  final Widget side;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 900
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 692, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 420, child: side),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              main,
              const SizedBox(height: 24),
              side,
            ]));
}

/// Two form fields side by side (stacked when very narrow).
class _FieldPair extends StatelessWidget {
  const _FieldPair(this.left, this.right);
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 480
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: left),
              const SizedBox(width: 20),
              Expanded(child: right),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              left,
              const SizedBox(height: 20),
              right,
            ]));
}

/// "Label ........ value" summary row.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.valueColor, this.size = 13});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: size,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold
                        ? ViniiColors.textPrimaryLight
                        : ViniiColors.textSecondaryLight)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: size,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor ?? ViniiColors.textPrimaryLight)),
        ]),
      );
}

/// Two fields side by side inside a dialog (no LayoutBuilder, which
/// AlertDialog's intrinsic sizing does not support).
class _DialogPair extends StatelessWidget {
  const _DialogPair(this.left, this.right);
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ]);
}

Widget _dialogShell(BuildContext context,
        {required String title,
        required GlobalKey<FormState> formKey,
        required List<Widget> children,
        required VoidCallback onSave,
        String saveLabel = 'Save'}) =>
    AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    children[i],
                  ],
                ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            onPressed: onSave,
            child: Text(saveLabel)),
      ],
    );

// ---------------------------------------------------------------------------
// Tab 1 — Overview (Screen 1 - Recipes Hub)
// ---------------------------------------------------------------------------

/// CSV columns for recipe import/export (one row per BOM line).
const recipeCsvHeaders = [
  'recipe_id',
  'code',
  'name',
  'category',
  'portion',
  'target_price',
  'labor_cost',
  'packaging_cost',
  'status',
  'line_material_id',
  'line_name',
  'line_qty',
  'line_unit',
  'line_wastage_pct',
  'line_fallback_unit_cost',
];

const recipeStatuses = [
  'Draft',
  'In Trial',
  'Needs Attention',
  'Approved',
  'Active',
  'Rejected',
];

class RecipeOverviewTab extends StatefulWidget {
  const RecipeOverviewTab(
      {super.key, required this.data, required this.onOpenRecipe});

  final RecipeData data;

  /// Opens lifecycle tab [tab] for recipe [recipeId] (row tap → Draft = 1).
  final void Function(int tab, String recipeId) onOpenRecipe;

  @override
  State<RecipeOverviewTab> createState() => _RecipeOverviewTabState();
}

class _RecipeOverviewTabState extends State<RecipeOverviewTab> {
  String _query = '';
  String _status = 'All';
  String _trial = 'All';
  String _category = 'All';

  RecipeData get _d => widget.data;

  List<Recipe> _filtered() {
    final q = _query.trim().toLowerCase();
    final dishNames = _d.dishNames;
    return _d.recipes.where((r) {
      if (q.isNotEmpty &&
          !r.name.toLowerCase().contains(q) &&
          !r.linkedDishName(dishNames).toLowerCase().contains(q) &&
          !r.code.toLowerCase().contains(q)) {
        return false;
      }
      if (_status != 'All' && r.status != _status) return false;
      if (_trial != 'All' && r.trialResult != _trial) return false;
      if (_category != 'All' && r.category != _category) return false;
      return true;
    }).toList();
  }

  Future<void> _newRecipe() async {
    final created = await showDialog<Recipe>(
        context: context, builder: (_) => _NewRecipeDialog(data: _d));
    if (created == null || !mounted) return;
    final ok = await saveRecipeRecord(context, _d, created,
        success: 'Recipe "${created.name}" created as Draft');
    if (ok) widget.onOpenRecipe(1, created.id);
  }

  Future<void> _delete(Recipe r) async {
    final ok = await confirmMasterAction(context,
        title: 'Delete recipe?',
        message:
            'Delete "${r.name}" (${r.code}) and its ${r.lines.length} ingredient lines? This cannot be undone.');
    if (!ok || !mounted) return;
    await runMasterAction(context, () => _d.master.deleteRecipe(r.id),
        success: 'Deleted ${r.name}');
  }

  Future<void> _export(List<Recipe> rows) async {
    await exportCsv(context,
        fileName: 'recipes-${recipeToday()}.csv',
        headers: recipeCsvHeaders,
        rows: [
          for (final r in rows)
            for (final l
                in r.lines.isEmpty ? const <RecipeLine?>[null] : r.lines)
              [
                r.id,
                r.code,
                r.name,
                r.category,
                r.portion,
                r.targetPrice,
                r.laborCost,
                r.packagingCost,
                r.status,
                l?.materialId ?? '',
                l?.name ?? '',
                l == null ? '' : l.qty,
                l?.unit ?? '',
                l == null ? '' : l.wastagePct,
                l == null ? '' : l.fallbackUnitCost,
              ],
        ]);
  }

  Future<void> _import() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    // Group rows by recipe_id (or code when no id is given), keeping order.
    final groups = <String, List<CsvRecord>>{};
    for (final rec in records) {
      final key = rec('recipe_id').isNotEmpty
          ? 'id:${rec('recipe_id')}'
          : 'code:${rec('code').toUpperCase()}';
      if (key == 'code:') {
        summary.errors.add('Line ${rec.line}: recipe_id or code is required');
        continue;
      }
      groups.putIfAbsent(key, () => []).add(rec);
    }
    final toSave = <Recipe>[];
    final seenCodes = <String>{};
    for (final rows in groups.values) {
      final head = rows.first;
      final errors = <String>[];
      final name = head('name');
      final code = head('code');
      if (name.isEmpty) errors.add('Line ${head.line}: name is required');
      if (code.isEmpty) errors.add('Line ${head.line}: code is required');
      // Blank → null (keep existing / 0); invalid → error + null.
      double? nonNeg(CsvRecord r, String h) {
        if (!r.has(h)) return null;
        final v = r.number(h);
        if (v == null || v < 0) {
          errors.add('Line ${r.line}: $h must be a number ≥ 0');
          return null;
        }
        return v;
      }

      final target = nonNeg(head, 'target_price');
      final labour = nonNeg(head, 'labor_cost');
      final packaging = nonNeg(head, 'packaging_cost');
      final status = head('status');
      if (status.isNotEmpty && !recipeStatuses.contains(status)) {
        errors.add(
            'Line ${head.line}: status must be one of ${recipeStatuses.join(', ')}');
      }
      final lines = <RecipeLine>[];
      for (final r in rows) {
        if (!r.has('line_name') && !r.has('line_material_id')) continue;
        final matId = r('line_material_id');
        final mat = matId.isEmpty ? null : _d.materials[matId];
        if (matId.isNotEmpty && mat == null) {
          errors.add('Line ${r.line}: unknown raw material id "$matId"');
          continue;
        }
        final qty = r.number('line_qty');
        if (qty == null || qty <= 0) {
          errors.add('Line ${r.line}: line_qty must be greater than 0');
          continue;
        }
        final waste = nonNeg(r, 'line_wastage_pct') ?? 0;
        final fallback = nonNeg(r, 'line_fallback_unit_cost') ?? 0;
        final unit = r('line_unit', mat?.unit ?? '');
        if (unit.isEmpty) {
          errors.add('Line ${r.line}: line_unit is required');
          continue;
        }
        lines.add(RecipeLine(
            materialId: mat?.id,
            name: r('line_name', mat?.name ?? ''),
            qty: qty,
            unit: unit,
            wastagePct: waste,
            fallbackUnitCost: fallback));
      }
      if (seenCodes.contains(code.toUpperCase())) {
        errors.add('Line ${head.line}: code $code appears for two recipes');
      }
      if (errors.isNotEmpty) {
        summary.errors.addAll(errors);
        continue;
      }
      seenCodes.add(code.toUpperCase());
      final id = head('recipe_id');
      Recipe? existing;
      for (final r in _d.recipes) {
        if ((id.isNotEmpty && r.id == id) ||
            (id.isEmpty && r.code.toUpperCase() == code.toUpperCase())) {
          existing = r;
        }
      }
      // A code already used by a different recipe would create a duplicate.
      final selfId = existing?.id ?? id;
      final clash = _d.recipes.any(
          (r) => r.code.toUpperCase() == code.toUpperCase() && r.id != selfId);
      if (clash) {
        summary.errors.add(
            'Line ${head.line}: code $code already belongs to another recipe');
        continue;
      }
      final base = existing ??
          Recipe(
              id: id.isNotEmpty
                  ? id
                  : 'rcp-${DateTime.now().microsecondsSinceEpoch}-${toSave.length}',
              code: code,
              name: name);
      toSave.add(base.copyWith(
        code: code,
        name: name,
        category: head('category', base.category),
        portion: head('portion', base.portion),
        targetPrice: target,
        laborCost: labour,
        packagingCost: packaging,
        status: status.isEmpty ? base.status : status,
        lines: lines,
      ));
      if (existing == null) {
        summary.added++;
      } else {
        summary.updated++;
      }
    }
    await runMasterAction(context, () async {
      for (final r in toSave) {
        await _d.master.saveRecipe(r);
      }
    });
    if (mounted) showImportSummary(context, summary);
  }

  @override
  Widget build(BuildContext context) {
    final all = _d.recipes;
    final rows = _filtered();
    final activeFilters =
        [_status, _trial, _category].where((f) => f != 'All').length +
            (_query.trim().isEmpty ? 0 : 1);
    List<String> opts(Iterable<String> v) => [
          'All',
          ...{
            for (final s in v)
              if (s.isNotEmpty) s
          }
        ];

    return MasterPage(children: [
      MasterPageHeader(
        title: 'Recipe Master Index',
        subtitle:
            'Monitor trial results, training completions, and direct food costs across every recipe',
        actions: [
          MasterButton(
              label: 'Import', icon: Icons.upload_outlined, onPressed: _import),
          MasterButton(
              label: 'Export',
              icon: Icons.download_outlined,
              onPressed: rows.isEmpty ? null : () => _export(rows)),
          MasterButton(
              label: 'New Recipe',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: _newRecipe),
        ],
      ),
      MasterFilterBar(children: [
        MasterSearchField(
            hint: 'Search recipes, menu items, codes...',
            width: 300,
            onChanged: (v) => setState(() => _query = v)),
        MasterFilterButton(
            label: 'Status: $_status',
            options: opts(all.map((r) => r.status)),
            onSelected: (v) => setState(() => _status = v)),
        MasterFilterButton(
            label: 'Trial: $_trial',
            options: opts(all.map((r) => r.trialResult)),
            onSelected: (v) => setState(() => _trial = v)),
        MasterFilterButton(
            label: 'Category: $_category',
            options: opts(all.map((r) => r.category)),
            onSelected: (v) => setState(() => _category = v)),
        Text('Active filters: $activeFilters Selected',
            style: MasterStyle.muted),
      ]),
      const SizedBox(height: 24),
      MasterTable(
        minWidth: 1140,
        columns: const [
          MasterColumn('Recipe', flex: 232),
          MasterColumn('Linked Menu Item', flex: 180),
          MasterColumn('Food Cost', flex: 110),
          MasterColumn('Target Price', flex: 110),
          MasterColumn('Trial Result', flex: 130),
          MasterColumn('Training Comp.', flex: 150),
          MasterColumn('Status', flex: 120),
          MasterColumn('Actions', flex: 100),
        ],
        onRowTap: (i) => widget.onOpenRecipe(1, rows[i].id),
        rows: [
          for (final r in rows)
            [
              MasterCellTitle(r.name, subtitle: '${r.code} · ${r.version}'),
              MasterCellText(() {
                final dish = _d.dishName(r);
                return dish.isEmpty ? 'Not linked' : dish;
              }()),
              MasterCellText(formatInr(_d.totalCost(r)), bold: true),
              MasterCellText(formatInr(r.targetPrice)),
              MasterStatusPill(r.trialResult,
                  tone: recipeTrialTone(r.trialResult)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    r.trainingTotal == 0
                        ? '-'
                        : '${(r.trainingDone / r.trainingTotal * 100).round()}%',
                    style:
                        MasterStyle.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('(${r.trainingDone}/${r.trainingTotal} Staff)',
                      overflow: TextOverflow.ellipsis,
                      style: MasterStyle.muted),
                ),
              ]),
              MasterStatusPill(r.status, tone: recipeStatusTone(r.status)),
              MasterRowActions(const ['Open', 'Delete'], onTap: (a) {
                if (a == 'Delete') {
                  _delete(r);
                } else {
                  widget.onOpenRecipe(1, r.id);
                }
              }),
            ],
        ],
        footer: Text(
            all.isEmpty
                ? 'No recipes yet — use New Recipe or Import to add one'
                : rows.isEmpty
                    ? 'No recipes match the current filters'
                    : 'Showing ${rows.length} of ${all.length} recipes',
            style: MasterStyle.muted),
      ),
    ]);
  }
}

class _NewRecipeDialog extends StatefulWidget {
  const _NewRecipeDialog({required this.data});
  final RecipeData data;

  @override
  State<_NewRecipeDialog> createState() => _NewRecipeDialogState();
}

class _NewRecipeDialogState extends State<_NewRecipeDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController();
  late final _code = TextEditingController(text: _nextCode());
  final _category = TextEditingController();
  final _portion = TextEditingController();
  final _target = TextEditingController();
  String? _dishId;

  String _nextCode() {
    final codes = {for (final r in widget.data.recipes) r.code.toUpperCase()};
    var n = widget.data.recipes.length + 1;
    while (codes.contains('RCP-${n.toString().padLeft(3, '0')}')) {
      n++;
    }
    return 'RCP-${n.toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _category, _portion, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final dish = widget.data.dish(_dishId);
    Navigator.pop(
        context,
        Recipe(
          id: 'rcp-${DateTime.now().millisecondsSinceEpoch}',
          code: _code.text.trim(),
          name: _name.text.trim(),
          category: _category.text.trim(),
          portion: _portion.text.trim(),
          linkedMenuItemId: dish?.id,
          linkedMenuItemName: dish?.name ?? '',
          targetPrice: recipeParse(_target.text),
          status: 'Draft',
        ));
  }

  @override
  Widget build(BuildContext context) => _dialogShell(context,
          title: 'New Recipe',
          formKey: _form,
          onSave: _save,
          saveLabel: 'Create Draft',
          children: [
            RecipeField(
                label: 'Recipe Name *',
                controller: _name,
                validator: recipeRequired),
            _DialogPair(
              RecipeField(
                  label: 'Recipe Code *',
                  controller: _code,
                  validator: (v) {
                    final e = recipeRequired(v);
                    if (e != null) return e;
                    final c = v!.trim().toUpperCase();
                    return widget.data.recipes
                            .any((r) => r.code.toUpperCase() == c)
                        ? 'Code already used'
                        : null;
                  }),
              recipeCategoryDropdown(
                  key: ValueKey('new-cat-${_category.text.trim()}'),
                  data: widget.data,
                  value: _category.text,
                  onChanged: (v) => setState(() => _category.text = v)),
            ),
            _DialogPair(
              RecipeField(
                  label: 'Portion / Serving Size',
                  controller: _portion,
                  hint: 'e.g. Bowl (350g)'),
              RecipeField(
                  label: 'Target Selling Price *',
                  controller: _target,
                  number: true,
                  suffix: '₹',
                  validator: recipeNumber()),
            ),
            RecipeDropdown<String?>(
              label: 'Linked Menu Item',
              value: _dishId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Not linked')),
                for (final d in widget.data.dishes)
                  DropdownMenuItem(
                      value: d.id,
                      child: Text('${d.name} · ${formatInr(d.sellingPrice)}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _dishId = v;
                final d = widget.data.dish(v);
                if (d != null && _target.text.trim().isEmpty) {
                  _target.text = d.sellingPrice.toStringAsFixed(2);
                }
                if (d != null && _category.text.trim().isEmpty) {
                  _category.text = d.category;
                }
              }),
            ),
          ]);
}

// ---------------------------------------------------------------------------
// Tab 2 — Recipe Draft (Screen 2)
// ---------------------------------------------------------------------------

class RecipeDraftTab extends StatefulWidget {
  const RecipeDraftTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeDraftTab> createState() => _RecipeDraftTabState();
}

class _RecipeDraftTabState extends State<RecipeDraftTab> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _version = TextEditingController();
  final _category = TextEditingController();
  final _portion = TextEditingController();
  final _target = TextEditingController();
  final _labour = TextEditingController();
  final _packaging = TextEditingController();
  final _prep = TextEditingController();
  final _allergens = TextEditingController();
  String? _dishId;
  bool _dirty = false;
  int _formGen = 0;

  List<TextEditingController> get _all => [
        _name,
        _code,
        _version,
        _category,
        _portion,
        _target,
        _labour,
        _packaging,
        _prep,
        _allergens
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecipeDraftTab old) {
    super.didUpdateWidget(old);
    final r = widget.data.recipe;
    final o = old.data.recipe;
    if (r?.id != o?.id || (!_dirty && !identical(r, o))) _load();
  }

  void _load() {
    final r = widget.data.recipe;
    if (r == null) return;
    _name.text = r.name;
    _code.text = r.code;
    _version.text = r.version;
    _category.text = r.category;
    _portion.text = r.portion;
    _target.text = recipeQty(r.targetPrice);
    _labour.text = recipeQty(r.laborCost);
    _packaging.text = recipeQty(r.packagingCost);
    _prep.text = r.prepMethod;
    _allergens.text = r.allergens;
    _dishId = widget.data.dish(r.linkedMenuItemId)?.id;
    _dirty = false;
    _formGen++;
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed([_]) => setState(() => _dirty = true);

  Recipe _build(Recipe r, {String? status, String? trialResult}) {
    final dish = widget.data.dish(_dishId);
    return recipeWithLink(
        r.copyWith(
          name: _name.text.trim(),
          code: _code.text.trim(),
          version: _version.text.trim(),
          category: _category.text.trim(),
          portion: _portion.text.trim(),
          targetPrice: recipeParse(_target.text),
          laborCost: recipeParse(_labour.text),
          packagingCost: recipeParse(_packaging.text),
          prepMethod: _prep.text.trim(),
          allergens: _allergens.text.trim(),
          status: status,
          trialResult: trialResult,
        ),
        dish?.id,
        dish?.name ?? '');
  }

  Future<void> _save(Recipe r, {bool submit = false}) async {
    if (!_form.currentState!.validate()) return;
    if (submit && r.lines.isEmpty) {
      showMasterError(context,
          'Add at least one ingredient (Ingredients tab) before submitting for trial.');
      return;
    }
    final next = submit
        ? _build(r, status: 'In Trial', trialResult: 'Pending')
        : _build(r);
    final ok = await saveRecipeRecord(context, widget.data, next,
        success: submit
            ? '${next.name} submitted for kitchen trial'
            : 'Draft saved for ${next.name}');
    if (ok && mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data.recipe;
    if (r == null) return const RecipeNoSelection();
    final d = widget.data;
    // Live figures from the form values + current ingredient prices.
    final target = recipeParse(_target.text);
    final cost = d.ingredientCost(r) +
        recipeParse(_labour.text) +
        recipeParse(_packaging.text);
    final margin = target <= 0 ? 0.0 : (target - cost) / target * 100;
    final allowedPct = 100 - recipeMarginThresholdPct;
    final allowed = target * allowedPct / 100;
    final belowThreshold = margin < recipeMarginThresholdPct;
    String? codeClash(String? v) {
      final e = recipeRequired(v);
      if (e != null) return e;
      final c = v!.trim().toUpperCase();
      return d.recipes.any((x) => x.id != r.id && x.code.toUpperCase() == c)
          ? 'Code already used by another recipe'
          : null;
    }

    return MasterPage(children: [
      MasterCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: ViniiColors.blueTint,
        borderColor: const Color(0xFFBFDBFE),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
                'ℹ️ Real-time validation active. Target-price margin recommended above ${recipeMarginThresholdPct.toStringAsFixed(0)}%.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF))),
            Text(
                _dirty
                    ? 'Unsaved changes'
                    : 'Saved · ${r.status} · ${r.version}',
                style: MasterStyle.muted),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Form(
        key: _form,
        child: _Split(
          main: MasterSection(
            title: 'Basic Recipe Information',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecipeField(
                      label: 'Recipe Name *',
                      controller: _name,
                      validator: recipeRequired,
                      onChanged: _changed),
                  const SizedBox(height: 20),
                  _FieldPair(
                    RecipeField(
                        label: 'Recipe Code *',
                        controller: _code,
                        validator: codeClash,
                        onChanged: _changed),
                    RecipeField(
                        label: 'Version *',
                        controller: _version,
                        validator: recipeRequired,
                        onChanged: _changed),
                  ),
                  const SizedBox(height: 20),
                  _FieldPair(
                    RecipeDropdown<String?>(
                      key: ValueKey('dish-$_formGen'),
                      label: 'Linked Menu Item',
                      value: _dishId,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Not linked')),
                        for (final dish in d.dishes)
                          DropdownMenuItem(
                              value: dish.id,
                              child: Text(dish.name,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() {
                        _dishId = v;
                        _dirty = true;
                        // A new link fills an empty category from the dish.
                        final dish = d.dish(v);
                        if (dish != null && _category.text.trim().isEmpty) {
                          _category.text = dish.category;
                        }
                      }),
                    ),
                    recipeCategoryDropdown(
                        key: ValueKey('cat-$_formGen-${_category.text.trim()}'),
                        data: d,
                        value: _category.text,
                        onChanged: (v) => setState(() {
                              _category.text = v;
                              _dirty = true;
                            })),
                  ),
                  const SizedBox(height: 20),
                  _FieldPair(
                    RecipeField(
                        label: 'Serving Size / Portion',
                        controller: _portion,
                        onChanged: _changed),
                    RecipeField(
                        label: 'Target Selling Price *',
                        controller: _target,
                        number: true,
                        suffix: '₹',
                        validator: recipeNumber(),
                        onChanged: _changed),
                  ),
                  const SizedBox(height: 20),
                  _FieldPair(
                    RecipeField(
                        label: 'Labour Cost / Portion',
                        controller: _labour,
                        number: true,
                        suffix: '₹',
                        validator: recipeNumber(),
                        onChanged: _changed),
                    RecipeField(
                        label: 'Packaging Cost / Portion',
                        controller: _packaging,
                        number: true,
                        suffix: '₹',
                        validator: recipeNumber(),
                        onChanged: _changed),
                  ),
                  const SizedBox(height: 20),
                  RecipeField(
                      label: 'Preparation Method',
                      controller: _prep,
                      maxLines: 3,
                      onChanged: _changed),
                  const SizedBox(height: 20),
                  RecipeField(
                      label: 'Allergens',
                      controller: _allergens,
                      hint: 'e.g. Dairy (Cream, Butter, Paneer)',
                      onChanged: _changed),
                ]),
          ),
          side:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MasterSection(
              title: 'Pricing Target & Margins',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryRow('Target Selling Price', formatInr(target),
                        bold: true, size: 14),
                    _SummaryRow(
                        'Allowed Food Cost (${allowedPct.toStringAsFixed(0)}%)',
                        formatInr(allowed)),
                    const Divider(height: 20, color: MasterStyle.cardBorder),
                    _SummaryRow('Calculated Food Cost', formatInr(cost),
                        valueColor: cost > allowed
                            ? ViniiColors.redSolid
                            : ViniiColors.emeraldText),
                    _SummaryRow('Projected Gross Margin', recipePct(margin),
                        valueColor: belowThreshold
                            ? ViniiColors.redSolid
                            : ViniiColors.emeraldText),
                    const SizedBox(height: 12),
                    belowThreshold
                        ? MasterBanner(
                            icon: '⚠️',
                            tone: PillTone.amber,
                            message: r.lines.isEmpty
                                ? 'Validation Alert: no ingredients yet — add BOM lines in the Ingredients tab to compute food cost.'
                                : 'Validation Alert: Projected margin (${recipePct(margin)}) is below the master threshold of ${recipeMarginThresholdPct.toStringAsFixed(0)}%. Consider adjusting portions or the target price.')
                        : MasterBanner(
                            icon: '✅',
                            tone: PillTone.green,
                            message:
                                'Validation Passed: Projected margin (${recipePct(margin)}) meets the master threshold of ${recipeMarginThresholdPct.toStringAsFixed(0)}%.'),
                  ]),
            ),
            const SizedBox(height: 24),
            MasterCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MasterButton(
                        label: 'Save Draft',
                        kind: MasterButtonKind.primary,
                        onPressed: () => _save(r)),
                    const SizedBox(height: 12),
                    MasterButton(
                        label: 'Submit for Trial',
                        onPressed: () => _save(r, submit: true)),
                  ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — Ingredients (Screen 3 - Ingredient Standard)
// ---------------------------------------------------------------------------

class RecipeIngredientsTab extends StatelessWidget {
  const RecipeIngredientsTab({super.key, required this.data});
  final RecipeData data;

  Future<void> _saveLines(
      BuildContext context, Recipe r, List<RecipeLine> lines, String msg) {
    return saveRecipeRecord(context, data, r.copyWith(lines: lines),
        success: msg);
  }

  Future<void> _edit(BuildContext context, Recipe r, [int? index]) async {
    final line = await showDialog<RecipeLine>(
        context: context,
        builder: (_) => _LineDialog(
            data: data, line: index == null ? null : r.lines[index]));
    if (line == null || !context.mounted) return;
    final lines = [...r.lines];
    if (index == null) {
      lines.add(line);
    } else {
      lines[index] = line;
    }
    await _saveLines(context, r, lines,
        index == null ? 'Added ${line.name}' : 'Updated ${line.name}');
  }

  Future<void> _remove(BuildContext context, Recipe r, int index) async {
    final l = r.lines[index];
    final ok = await confirmMasterAction(context,
        title: 'Remove ingredient?',
        message: 'Remove ${l.name} from ${r.name}?',
        confirmLabel: 'Remove');
    if (!ok || !context.mounted) return;
    await _saveLines(
        context, r, [...r.lines]..removeAt(index), 'Removed ${l.name}');
  }

  Future<void> _toggleKey(
      BuildContext context, Recipe r, int index, bool v) async {
    final l = r.lines[index];
    final lines = [...r.lines];
    lines[index] = RecipeLine(
        materialId: l.materialId,
        name: l.name,
        qty: l.qty,
        unit: l.unit,
        wastagePct: l.wastagePct,
        fallbackUnitCost: l.fallbackUnitCost,
        isKey: v,
        substitute: l.substitute);
    await _saveLines(context, r, lines,
        v ? '${l.name} marked as key ingredient' : '${l.name} no longer key');
  }

  @override
  Widget build(BuildContext context) {
    final r = data.recipe;
    if (r == null) return const RecipeNoSelection();
    final noSub = [
      for (final l in r.lines)
        if (l.substitute.trim().isEmpty) l.name
    ];
    final unlinked = [
      for (final l in r.lines)
        if (data.materialFor(l) == null) l.name
    ];
    return MasterPage(children: [
      if (noSub.isNotEmpty) ...[
        MasterBanner(
            icon: '⚠️',
            tone: PillTone.amber,
            message:
                "Missing Standard Information: ${noSub.map((m) => "'$m'").join(', ')} ${noSub.length == 1 ? 'does' : 'do'} not have a linked standard substitute. Supply chain alerts will fire if the main item goes Out of Stock."),
        const SizedBox(height: 16),
      ],
      if (unlinked.isNotEmpty) ...[
        MasterBanner(
            icon: '🔗',
            tone: PillTone.red,
            message:
                "Not linked to inventory: ${unlinked.map((m) => "'$m'").join(', ')} ${unlinked.length == 1 ? 'is' : 'are'} costed from a manual fallback price and will not follow supplier price changes or deplete stock."),
        const SizedBox(height: 16),
      ],
      if (noSub.isNotEmpty || unlinked.isNotEmpty) const SizedBox(height: 8),
      MasterSection(
        title: 'Standard Raw Materials Linkage · ${r.name}',
        subtitle:
            'Define depletion quantities per portion, key tags, substitutes and wastage',
        trailing: MasterButton(
            label: 'Add Ingredient',
            icon: Icons.add,
            kind: MasterButtonKind.primary,
            onPressed: () => _edit(context, r)),
        child: MasterTable(
          minWidth: 1100,
          columns: const [
            MasterColumn('Ingredient', flex: 280),
            MasterColumn('Key Ingredient', flex: 110),
            MasterColumn('Qty / Portion', flex: 100),
            MasterColumn('Unit', flex: 60),
            MasterColumn('Substitute', flex: 160),
            MasterColumn('Waste %', flex: 80),
            MasterColumn('Allergen', flex: 90),
            MasterColumn('Cost', flex: 90),
            MasterColumn('Actions', flex: 120),
          ],
          rows: [
            for (var i = 0; i < r.lines.length; i++)
              () {
                final l = r.lines[i];
                final m = data.materialFor(l);
                return <Widget>[
                  MasterCellTitle(l.name,
                      emoji: m?.emoji,
                      subtitle: m != null
                          ? '${m.code} · ${formatInr(m.purchaseCostPerUnit)}/${m.unit}'
                          : 'Not linked · fallback ${formatInr(l.fallbackUnitCost)}/${l.unit}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 24,
                      child: FittedBox(
                        child: Switch(
                            value: l.isKey,
                            activeTrackColor: ViniiColors.brandGreen,
                            onChanged: (v) => _toggleKey(context, r, i, v)),
                      ),
                    ),
                  ),
                  MasterCellText(recipeQty(l.qty)),
                  MasterCellText(l.unit),
                  l.substitute.trim().isEmpty
                      ? const MasterCellText('⚠️ Missing',
                          color: ViniiColors.amberSolid, bold: true)
                      : MasterCellText(l.substitute),
                  MasterCellText('${l.wastagePct.toStringAsFixed(1)}%'),
                  MasterCellText(_lineAllergens(r, l, m)),
                  MasterCellText(formatInr(data.lineCost(l)), bold: true),
                  MasterRowActions(const ['Edit', 'Delete'], onTap: (a) {
                    if (a == 'Edit') {
                      _edit(context, r, i);
                    } else {
                      _remove(context, r, i);
                    }
                  }),
                ];
              }(),
          ],
          footer: Text(
              r.lines.isEmpty
                  ? 'No ingredients yet — use Add Ingredient to build the BOM'
                  : '${r.lines.length} ingredients · raw material cost ${formatInr(data.ingredientCost(r))} per portion',
              style: MasterStyle.muted),
        ),
      ),
    ]);
  }
}

/// Declared allergen groups of a recipe: "Dairy (Cream, Butter), Gluten"
/// → {Dairy: [Cream, Butter], Gluten: []}.
Map<String, List<String>> _allergenGroups(String text) {
  final parts = <String>[];
  final buf = StringBuffer();
  var depth = 0;
  for (final ch in text.split('')) {
    if (ch == '(') depth++;
    if (ch == ')' && depth > 0) depth--;
    if ((ch == ',' || ch == ';') && depth == 0) {
      parts.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  parts.add(buf.toString());
  final out = <String, List<String>>{};
  for (final p in parts) {
    final t = p.trim();
    if (t.isEmpty) continue;
    final open = t.indexOf('(');
    final group = (open < 0 ? t : t.substring(0, open)).trim();
    final members = open < 0
        ? const <String>[]
        : t
            .substring(open + 1)
            .replaceAll(')', '')
            .split(RegExp(r'[,;/]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (group.isNotEmpty) out[group] = members;
  }
  return out;
}

/// The recipe's declared allergens (Recipe Draft → Allergens) that this
/// ingredient carries, matched by name or material category; "—" when none.
String _lineAllergens(Recipe r, RecipeLine l, RawMaterial? m) {
  final haystack =
      '${l.name} ${m?.name ?? ''} ${m?.category ?? ''}'.toLowerCase();
  final hits = <String>[
    for (final g in _allergenGroups(r.allergens).entries)
      if ([g.key, ...g.value]
          .any((w) => w.length >= 3 && haystack.contains(w.toLowerCase())))
        g.key,
  ];
  return hits.isEmpty ? '—' : hits.join(', ');
}

class _LineDialog extends StatefulWidget {
  const _LineDialog({required this.data, this.line});
  final RecipeData data;
  final RecipeLine? line;

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  static const _freeText = '__free__';
  final _form = GlobalKey<FormState>();
  late String _source;
  late final _name = TextEditingController(text: widget.line?.name ?? '');
  late final _qty = TextEditingController(
      text: widget.line == null ? '' : recipeQty(widget.line!.qty));

  /// Unit of a free-text line. A line linked to a raw material always uses
  /// the material's own unit — its quantity and cost are in that unit.
  late String _unit = () {
    final u = (widget.line?.unit ?? '').trim();
    return u.isEmpty ? masterUnits.first : u;
  }();
  late final _waste =
      TextEditingController(text: recipeQty(widget.line?.wastagePct ?? 0));
  late final _fallback = TextEditingController(
      text: recipeQty(widget.line?.fallbackUnitCost ?? 0));

  /// Name of the standard substitute ('' = none).
  late String _substitute = (widget.line?.substitute ?? '').trim();
  late bool _key = widget.line?.isKey ?? false;

  @override
  void initState() {
    super.initState();
    final id = widget.line?.materialId;
    _source = id != null && widget.data.materials.containsKey(id)
        ? id
        : (widget.line == null && widget.data.materials.isNotEmpty
            ? widget.data.materials.keys.first
            : _freeText);
    if (widget.line == null) _applyMaterial();
  }

  void _applyMaterial() {
    final m = widget.data.materials[_source];
    if (m == null) return;
    _name.text = m.name;
    _unit = m.unit;
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _waste, _fallback]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final m = widget.data.materials[_source];
    Navigator.pop(
        context,
        RecipeLine(
          materialId: m?.id,
          name: _name.text.trim(),
          qty: recipeParse(_qty.text),
          unit: m?.unit ?? _unit,
          wastagePct: recipeParse(_waste.text),
          fallbackUnitCost: recipeParse(_fallback.text),
          isKey: _key,
          substitute: _substitute,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final mats = widget.data.materials.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final linked = _source != _freeText;
    final material = widget.data.materials[_source];
    final units = {...masterUnits, if (_unit.isNotEmpty) _unit};
    // Substitutes are other raw materials, by name (names can repeat after
    // an import, so they are de-duplicated).
    final subNames = <String>{
      for (final x in mats)
        if (x.id != _source) x.name
    };
    final isMaterialName = mats.any((x) => x.name == _substitute);
    return _dialogShell(context,
        title: widget.line == null ? 'Add Ingredient' : 'Edit Ingredient',
        formKey: _form,
        onSave: _save,
        children: [
          RecipeDropdown<String>(
            label: 'Raw Material',
            value: _source,
            items: [
              for (final m in mats)
                DropdownMenuItem(
                    value: m.id,
                    child: Text(
                        '${m.name} (${m.code}) · ${formatInr(m.purchaseCostPerUnit)}/${m.unit}',
                        overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(
                  value: _freeText,
                  child: Text('Free-text item (not in inventory)')),
            ],
            onChanged: (v) => setState(() {
              _source = v ?? _freeText;
              _applyMaterial();
            }),
          ),
          RecipeField(
              label: 'Ingredient Name *',
              controller: _name,
              validator: recipeRequired),
          _DialogPair(
            RecipeField(
                label: 'Quantity per Portion *',
                controller: _qty,
                number: true,
                hint: 'in the material unit, e.g. 0.15',
                validator: recipeNumber(positive: true)),
            material == null
                ? RecipeDropdown<String>(
                    key: const ValueKey('line-unit-free'),
                    label: 'Unit *',
                    value: _unit,
                    items: [
                      for (final u in units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? _unit))
                : RecipeDropdown<String>(
                    // Locked: the quantity is in the material's own unit.
                    key: ValueKey('line-unit-${material.id}'),
                    label: 'Unit (from raw material)',
                    value: material.unit,
                    items: [
                      DropdownMenuItem(
                          value: material.unit, child: Text(material.unit)),
                    ],
                    enabled: false,
                    onChanged: (_) {}),
          ),
          _DialogPair(
            RecipeField(
                label: 'Wastage %',
                controller: _waste,
                number: true,
                suffix: '%',
                validator: recipeNumber(max: 100)),
            RecipeField(
                label: linked
                    ? 'Fallback Unit Cost (unused while linked)'
                    : 'Unit Cost *',
                controller: _fallback,
                number: true,
                suffix: '₹',
                validator: recipeNumber()),
          ),
          RecipeDropdown<String>(
            key: ValueKey('substitute-$_source'),
            label: 'Standard Substitute',
            value: _substitute,
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('No substitute (used when out of stock)')),
              for (final n in subNames)
                DropdownMenuItem(
                    value: n, child: Text(n, overflow: TextOverflow.ellipsis)),
              if (_substitute.isNotEmpty && !subNames.contains(_substitute))
                DropdownMenuItem(
                    value: _substitute,
                    child: Text(
                        isMaterialName
                            ? _substitute
                            : '$_substitute (not in inventory)',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _substitute = v ?? ''),
          ),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _key,
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Key ingredient', style: MasterStyle.body),
              onChanged: (v) => setState(() => _key = v ?? false),
            ),
          ),
        ]);
  }
}

// ---------------------------------------------------------------------------
// Tab 4 — Cost Calculation (Screen 4)
// ---------------------------------------------------------------------------

class RecipeCostCalculationTab extends StatelessWidget {
  const RecipeCostCalculationTab({super.key, required this.data});
  final RecipeData data;

  @override
  Widget build(BuildContext context) {
    final r = data.recipe;
    if (r == null) return const RecipeNoSelection();
    final fallback = [
      for (final l in r.lines)
        if (data.materialFor(l) == null) l
    ];
    final raw = data.ingredientCost(r);
    final overhead = r.laborCost + r.packagingCost;
    final total = data.totalCost(r);
    final margin = data.marginPct(r);
    return MasterPage(children: [
      for (final l in fallback) ...[
        MasterBanner(
            icon: '🚨',
            tone: PillTone.red,
            message: l.materialId == null
                ? "Unverified Price: '${l.name}' is not linked to an inventory raw material, so it is costed at a manual fallback of ${formatInr(l.fallbackUnitCost)}/${l.unit}. Link it in the Ingredients tab to follow supplier prices."
                : "Stale Supplier Price: '${l.name}' points to a raw material that is archived or missing, so it is costed at the fallback of ${formatInr(l.fallbackUnitCost)}/${l.unit}."),
        const SizedBox(height: 16),
      ],
      if (fallback.isNotEmpty) const SizedBox(height: 8),
      _Split(
        main: MasterSection(
          title: 'Material & Overhead Cost Calculator',
          trailing: MasterButton(
              label: 'Recalculate',
              icon: Icons.refresh,
              onPressed: () => showMasterNotice(context,
                  'Recalculated from current inventory prices: ${formatInr(total)} per portion')),
          child: MasterTable(
            minWidth: 600,
            columns: const [
              MasterColumn('Item / Cost Category', flex: 150),
              MasterColumn('Net Qty', flex: 100),
              MasterColumn('Waste Adj.', flex: 100),
              MasterColumn('Base Cost', flex: 120),
              MasterColumn('Total Cost', flex: 100, alignEnd: true),
            ],
            rows: [
              for (final l in r.lines)
                [
                  MasterCellTitle(l.name,
                      subtitle: data.materialFor(l) == null
                          ? 'Fallback price'
                          : 'Inventory price'),
                  MasterCellText('${recipeQty(l.qty)} ${l.unit}'),
                  MasterCellText('${recipeQty(l.grossQty)} ${l.unit}'),
                  MasterCellText(
                      '${formatInr(data.unitCostFor(l))}/${data.materialFor(l)?.unit ?? l.unit}'),
                  MasterCellText(formatInr(data.lineCost(l)), bold: true),
                ],
              [
                const MasterCellTitle('Labour (per portion)'),
                const MasterCellText('1 portion'),
                const MasterCellText('-'),
                MasterCellText('${formatInr(r.laborCost)}/portion'),
                MasterCellText(formatInr(r.laborCost), bold: true),
              ],
              [
                const MasterCellTitle('Packaging (per portion)'),
                const MasterCellText('1 portion'),
                const MasterCellText('-'),
                MasterCellText('${formatInr(r.packagingCost)}/portion'),
                MasterCellText(formatInr(r.packagingCost), bold: true),
              ],
            ],
          ),
        ),
        side: MasterSection(
          title: 'Financial Summary',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: MasterStyle.tableHeaderBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MasterStyle.cardBorder)),
              child: Column(children: [
                _SummaryRow('Raw Ingredients', formatInr(raw)),
                _SummaryRow('Labour & Packaging', formatInr(overhead)),
                const Divider(height: 20, color: MasterStyle.cardBorder),
                _SummaryRow('Total Recipe Cost', formatInr(total),
                    bold: true, size: 15),
              ]),
            ),
            const SizedBox(height: 12),
            _SummaryRow('Gross profit margin', recipePct(margin),
                bold: true,
                size: 15,
                valueColor: margin < recipeMarginThresholdPct
                    ? ViniiColors.redSolid
                    : ViniiColors.emeraldText),
            Text('at target selling price ${formatInr(r.targetPrice)}',
                style: MasterStyle.muted),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Tab 5 — Supplier Prices (Screen 5 - Supplier Price)
// ---------------------------------------------------------------------------

class RecipeSupplierPricesTab extends StatefulWidget {
  const RecipeSupplierPricesTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeSupplierPricesTab> createState() =>
      _RecipeSupplierPricesTabState();
}

class _RecipeSupplierPricesTabState extends State<RecipeSupplierPricesTab> {
  String? _materialId;

  Future<void> _approve(SupplierPriceQuote q, RawMaterial m) async {
    await runMasterAction(
        context, () => widget.data.inventory.approveSupplierPrice(q.id),
        success:
            'Approved ${widget.data.supplierName(q.supplierId)} at ${formatInr(q.currentPrice)}/${q.unit} — ${m.name} costing updated');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final r = d.recipe;
    if (r == null) return const RecipeNoSelection();
    // BOM materials (deduplicated), key ingredients first.
    final lines = [...r.lines]
      ..sort((a, b) => (b.isKey ? 1 : 0) - (a.isKey ? 1 : 0));
    final mats = <RawMaterial>[];
    for (final l in lines) {
      final m = d.materialFor(l);
      if (m != null && !mats.any((x) => x.id == m.id)) mats.add(m);
    }
    final selected = mats.isEmpty
        ? null
        : mats.firstWhere((m) => m.id == _materialId, orElse: () => mats.first);
    final bids = d.quotesFor(selected?.id);
    final allQuotes = [
      for (final m in mats) ...d.quotesFor(m.id),
    ];
    // Recipe cost if [m] were priced at [price].
    double costAt(RawMaterial m, double price) {
      var total = r.laborCost + r.packagingCost;
      for (final l in r.lines) {
        total += l.materialId == m.id ? l.grossQty * price : d.lineCost(l);
      }
      return total;
    }

    final selectedLine = selected == null
        ? null
        : r.lines.firstWhere((l) => l.materialId == selected.id);
    return MasterPage(children: [
      const MasterPageHeader(
        title: 'Supplier Evaluation & Bidding',
        subtitle:
            'Compare supplier quotes for this recipe\'s ingredients and approve the costing price',
      ),
      if (selected == null)
        const MasterBanner(
            icon: 'ℹ️',
            tone: PillTone.blue,
            message:
                'No ingredient of this recipe is linked to an inventory raw material yet, so there are no supplier quotes to compare. Link materials in the Ingredients tab.')
      else ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in mats)
            ChoiceChip(
              label: Text(m.name, style: const TextStyle(fontSize: 12)),
              selected: m.id == selected.id,
              selectedColor: ViniiColors.brandGreen,
              onSelected: (_) => setState(() => _materialId = m.id),
            ),
        ]),
        const SizedBox(height: 16),
        MasterSection(
          title:
              '${selected.name}${selectedLine?.isKey == true ? ' · Key Ingredient' : ''}',
          subtitle:
              'Current costing price ${formatInr(selected.purchaseCostPerUnit)}/${selected.unit} from ${d.supplierName(selected.preferredSupplierId)} · recipe cost ${formatInr(d.totalCost(r))}',
          child: MasterTable(
            minWidth: 960,
            columns: const [
              MasterColumn('Supplier Name', flex: 300),
              MasterColumn('Last Price', flex: 110),
              MasterColumn('Current Price', flex: 120),
              MasterColumn('Change', flex: 90),
              MasterColumn('Recipe Cost if Used', flex: 140),
              MasterColumn('Status', flex: 110),
              MasterColumn('Select', flex: 110),
            ],
            rows: [
              for (final q in bids)
                () {
                  final inUse = q.approved &&
                      q.supplierId == selected.preferredSupplierId &&
                      (q.currentPrice - selected.purchaseCostPerUnit).abs() <
                          0.005;
                  final s = d.supplier(q.supplierId);
                  return <Widget>[
                    MasterCellTitle(d.supplierName(q.supplierId),
                        subtitle: [
                          if (s != null && s.city.isNotEmpty) s.city,
                          if (s != null && s.contactPerson.isNotEmpty)
                            s.contactPerson,
                          q.source.label,
                        ].join(' · ')),
                    MasterCellText('${formatInr(q.lastPrice)}/${q.unit}'),
                    MasterCellText('${formatInr(q.currentPrice)}/${q.unit}',
                        bold: true,
                        color: q.currentPrice < q.lastPrice
                            ? ViniiColors.emeraldText
                            : q.currentPrice > q.lastPrice
                                ? ViniiColors.redSolid
                                : null),
                    MasterCellText(
                        '${q.changePct >= 0 ? '+' : ''}${recipePct(q.changePct)}',
                        color: q.changePct > 0
                            ? ViniiColors.redSolid
                            : ViniiColors.emeraldText),
                    MasterCellText(formatInr(costAt(selected, q.currentPrice))),
                    MasterStatusPill(
                        inUse
                            ? 'In Use'
                            : q.approved
                                ? 'Approved'
                                : 'Pending',
                        tone: inUse || q.approved
                            ? PillTone.green
                            : PillTone.amber),
                    MasterButton(
                        label: inUse ? 'Selected' : 'Approve',
                        kind: inUse
                            ? MasterButtonKind.primary
                            : MasterButtonKind.outline,
                        onPressed: inUse ? null : () => _approve(q, selected)),
                  ];
                }(),
            ],
            footer: bids.isEmpty
                ? Text(
                    'No supplier quotes recorded for ${selected.name}. Add quotes in Master → Suppliers.',
                    style: MasterStyle.muted)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        MasterSection(
          title: 'Recipe Ingredient Price Index',
          subtitle: 'All supplier quotes linked to ${r.name} ingredients',
          child: MasterTable(
            minWidth: 960,
            columns: const [
              MasterColumn('Ingredient', flex: 220),
              MasterColumn('Supplier', flex: 170),
              MasterColumn('Last Price', flex: 110),
              MasterColumn('Current Price', flex: 110),
              MasterColumn('Change', flex: 90),
              MasterColumn('Lowest (Week)', flex: 110),
              MasterColumn('Source', flex: 130),
            ],
            rows: [
              for (final q in allQuotes)
                [
                  MasterCellTitle(q.ingredientName,
                      emoji: q.emoji,
                      subtitle: q.skuId.isEmpty ? null : q.skuId),
                  MasterCellText(d.supplierName(q.supplierId)),
                  MasterCellText('${formatInr(q.lastPrice)}/${q.unit}'),
                  MasterCellText('${formatInr(q.currentPrice)}/${q.unit}',
                      bold: true),
                  MasterCellText(
                      '${q.changePct >= 0 ? '+' : ''}${recipePct(q.changePct)}',
                      color: q.changePct > 0
                          ? ViniiColors.redSolid
                          : ViniiColors.emeraldText),
                  MasterCellText('${formatInr(q.lowestWeek)}/${q.unit}'),
                  MasterStatusPill(q.source.label, tone: PillTone.gray),
                ],
            ],
            footer: allQuotes.isEmpty
                ? const Text('No supplier quotes for these ingredients yet',
                    style: MasterStyle.muted)
                : null,
          ),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Tab 6 — Trials & Training (Screen 6 - Trial)
// ---------------------------------------------------------------------------

const recipeTrialResults = ['Pass', 'Needs Changes', 'Failed'];

class RecipeTrialsTab extends StatefulWidget {
  const RecipeTrialsTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeTrialsTab> createState() => _RecipeTrialsTabState();
}

class _RecipeTrialsTabState extends State<RecipeTrialsTab> {
  String _result = 'Pass';
  bool _bump = false;
  String? _lastUpload;

  Future<void> _saveTrial(Recipe r) async {
    final version = _bump ? bumpRecipeVersion(r.version) : r.version;
    final result = _result == 'Pass' ? 'Pass ($version)' : _result;
    final ok = await saveRecipeRecord(
        context, widget.data, r.copyWith(trialResult: result, version: version),
        success:
            'Trial logged for ${r.name}: $result${_bump ? ' · version bumped to $version' : ''}');
    if (ok && mounted) setState(() => _bump = false);
  }

  Future<void> _upload(Recipe r) async {
    final file = await pickMediaFile(context);
    if (file == null || !mounted) return;
    final ok = await runMasterAction(
        context,
        () => widget.data.master.addMedia(
            fileName: file.$1,
            bytes: file.$2,
            folder: 'Recipe Trials',
            usageLabel: 'Trial · ${r.name} ${r.version}'),
        success: 'Uploaded ${file.$1} to Media → Recipe Trials');
    if (ok && mounted) setState(() => _lastUpload = file.$1);
  }

  Future<void> _training(Recipe r, {int done = 0, int total = 0}) async {
    final nextTotal = (r.trainingTotal + total).clamp(0, 999);
    final nextDone = (r.trainingDone + done).clamp(0, nextTotal);
    if (done > 0 && r.trainingDone >= r.trainingTotal) {
      showMasterError(context,
          'All ${r.trainingTotal} enrolled staff are already certified. Increase the enrolled count first.');
      return;
    }
    await saveRecipeRecord(context, widget.data,
        r.copyWith(trainingDone: nextDone, trainingTotal: nextTotal),
        success: 'Training updated: $nextDone of $nextTotal staff certified');
  }

  Widget _stepper(
          String label, int value, VoidCallback? minus, VoidCallback? plus) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: MasterStyle.body)),
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Decrease',
              onPressed: minus,
              icon: const Icon(Icons.remove_circle_outline, size: 20)),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: MasterStyle.body.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Increase',
              onPressed: plus,
              icon: const Icon(Icons.add_circle_outline, size: 20)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.data.recipe;
    if (r == null) return const RecipeNoSelection();
    final pct = r.trainingTotal == 0 ? 0.0 : r.trainingDone / r.trainingTotal;
    return MasterPage(children: [
      const MasterPageHeader(
        title: 'Trial & Training Execution',
        subtitle:
            'Log the kitchen trial outcome, version the recipe, and track staff certification',
      ),
      _Split(
        main: MasterSection(
          title: 'Trial Log: ${r.name} ${r.version}',
          subtitle: 'Current result: ${r.trialResult} · status ${r.status}',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _FieldPair(
              RecipeDropdown<String>(
                label: 'Trial Result *',
                value: _result,
                items: [
                  for (final t in recipeTrialResults)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _result = v ?? 'Pass'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: _bump,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                        'Bump version to ${bumpRecipeVersion(r.version)}',
                        style: MasterStyle.body),
                    onChanged: (v) => setState(() => _bump = v ?? false),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
                _lastUpload == null
                    ? 'Trial photos/videos are stored in Master → Media (folder "Recipe Trials").'
                    : 'Last upload: $_lastUpload',
                style: MasterStyle.muted),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 8, children: [
              MasterButton(
                  label: 'Upload Media',
                  icon: Icons.photo_camera_outlined,
                  onPressed: () => _upload(r)),
              MasterButton(
                  label: 'Save Trial Log',
                  kind: MasterButtonKind.primary,
                  onPressed: () => _saveTrial(r)),
            ]),
          ]),
        ),
        side: MasterSection(
          title: 'Staff Training Checklist',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MasterProgress(
                value: pct,
                label:
                    '${r.trainingDone} of ${r.trainingTotal} staff certified'),
            const SizedBox(height: 12),
            _stepper(
                'Enrolled staff',
                r.trainingTotal,
                r.trainingTotal > 0 ? () => _training(r, total: -1) : null,
                () => _training(r, total: 1)),
            _stepper(
                'Certified staff',
                r.trainingDone,
                r.trainingDone > 0 ? () => _training(r, done: -1) : null,
                r.trainingDone < r.trainingTotal
                    ? () => _training(r, done: 1)
                    : null),
            const SizedBox(height: 8),
            MasterStatusPill(
                r.trainingTotal == 0
                    ? 'No staff enrolled'
                    : r.trainingDone >= r.trainingTotal
                        ? 'Training Complete'
                        : 'Training In Progress',
                tone: r.trainingTotal > 0 && r.trainingDone >= r.trainingTotal
                    ? PillTone.green
                    : PillTone.amber),
          ]),
        ),
      ),
    ]);
  }
}
