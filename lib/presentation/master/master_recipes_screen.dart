import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_inventory_store.dart';
import '../../data/drift_master_store.dart';
import '../../data/master_catalog.dart';
import '../../data/staff_repository.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_ui.dart';
import 'recipe_lifecycle_tabs.dart';
import 'recipe_workflow_tabs.dart';

/// Master → Recipes: the 10-tab recipe lifecycle (Figma
/// "recipe-core-workflow"). The tab strip + recipe selector sit directly
/// under the shell's top bar; the selected tab's page scrolls below it.
/// Recipes, raw materials, supplier prices, suppliers and menu items are
/// all read live from the database, so e.g. approving a supplier price
/// changes every recipe cost immediately.
class MasterRecipesScreen extends StatefulWidget {
  const MasterRecipesScreen(
      {super.key, required this.master, required this.inventory, this.staff});

  final DriftMasterStore master;
  final DriftInventoryStore inventory;

  /// Optional: the staff list offered in the Staff Training "Staff Member"
  /// picker (a free-text field without it).
  final StaffRepository? staff;

  @override
  State<MasterRecipesScreen> createState() => _MasterRecipesScreenState();
}

class _MasterRecipesScreenState extends State<MasterRecipesScreen> {
  static const _tabs = [
    'Overview',
    'Recipe Draft',
    'Ingredients',
    'Cost Calculation',
    'Supplier Prices',
    'Trials & Training',
    'Staff Training',
    'Feedback & Approval',
    'Menu Activation',
    'Cost Impact',
  ];

  int _tab = 0;
  String? _selectedId;

  List<Recipe>? _recipes;
  List<RawMaterial>? _materialList;
  Map<String, RawMaterial> _materials = const {};
  List<SupplierPriceQuote> _quotes = const [];
  List<InventorySupplier> _suppliers = const [];
  List<MasterDishItem> _dishes = const [];
  List<String> _staffNames = const [];
  Object? _error;
  final _subs = <StreamSubscription<Object?>>[];

  Future<void> _loadStaff() async {
    final repo = widget.staff;
    if (repo == null) return;
    try {
      final people = await repo.employees();
      const gone = {'inactive', 'terminated', 'resigned', 'exited', 'left'};
      final names = {
        for (final p in people)
          if (p.fullName.trim().isNotEmpty &&
              !gone.contains(p.status.trim().toLowerCase()))
            p.fullName.trim()
      }.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() => _staffNames = names);
    } catch (_) {
      // No staff list (offline / no permission): keep the free-text field.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStaff();
    void onError(Object e) {
      if (mounted) setState(() => _error = e);
    }

    _subs.addAll([
      widget.master
          .watchRecipes()
          .listen((v) => setState(() => _recipes = v), onError: onError),
      widget.inventory.watchMaterials().listen(
          (v) => setState(() {
                _materialList = v;
                _materials = {for (final m in v) m.id: m};
              }),
          onError: onError),
      widget.inventory
          .watchSupplierPrices()
          .listen((v) => setState(() => _quotes = v), onError: onError),
      // Archived suppliers included, so older quotes still name them.
      widget.inventory
          .watchAllSuppliers()
          .listen((v) => setState(() => _suppliers = v), onError: onError),
      widget.master
          .watchDishes()
          .listen((v) => setState(() => _dishes = v), onError: onError),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Recipe? get _selected {
    final list = _recipes ?? const <Recipe>[];
    if (list.isEmpty) return null;
    for (final r in list) {
      if (r.id == _selectedId) return r;
    }
    return list.first;
  }

  void _open(int i) => setState(() => _tab = i);

  void _openRecipe(int tab, String recipeId) => setState(() {
        _selectedId = recipeId;
        _tab = tab;
      });

  Widget _selector() {
    final list = _recipes ?? const <Recipe>[];
    final sel = _selected;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sel?.id,
          isExpanded: true,
          hint: const Text('No recipes yet', style: MasterStyle.muted),
          style: const TextStyle(
              fontSize: 13, color: ViniiColors.textPrimaryLight),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: ViniiColors.textSecondaryLight),
          items: [
            for (final r in list)
              DropdownMenuItem(
                  value: r.id,
                  child: Text('${r.name} · ${r.code}',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged:
              list.isEmpty ? null : (v) => setState(() => _selectedId = v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _recipes == null || _materialList == null;
    final strip = MasterTabStrip(tabs: _tabs, selected: _tab, onSelect: _open);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 760) {
            return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: strip),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(width: 260, child: _selector()),
              ),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: _selector()),
                strip,
              ]);
        }),
      ),
      Expanded(child: _body(loading)),
    ]);
  }

  Widget _body(bool loading) {
    if (_error != null && loading) {
      return const Center(
          child: Text(
              'Could not load recipes. Please open this screen again, or restart the app if it keeps happening.',
              textAlign: TextAlign.center,
              style: MasterStyle.muted));
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    final sel = _selected;
    final data = RecipeData(
      master: widget.master,
      inventory: widget.inventory,
      recipes: _recipes!,
      recipe: sel,
      materials: _materials,
      quotes: _quotes,
      suppliers: _suppliers,
      dishes: _dishes,
      staffNames: _staffNames,
    );
    // Recipe-bound tabs are keyed by recipe id so their local form state
    // resets when another recipe is selected.
    final k = sel?.id ?? '-';
    return IndexedStack(index: _tab, children: [
      RecipeOverviewTab(data: data, onOpenRecipe: _openRecipe),
      RecipeDraftTab(key: ValueKey('draft-$k'), data: data),
      RecipeIngredientsTab(data: data),
      RecipeCostCalculationTab(data: data),
      RecipeSupplierPricesTab(key: ValueKey('prices-$k'), data: data),
      RecipeTrialsTab(key: ValueKey('trials-$k'), data: data),
      RecipeStaffTrainingTab(key: ValueKey('training-$k'), data: data),
      RecipeFeedbackApprovalTab(data: data),
      RecipeMenuActivationTab(key: ValueKey('activation-$k'), data: data),
      RecipeCostImpactTab(key: ValueKey('impact-$k'), data: data),
    ]);
  }
}
