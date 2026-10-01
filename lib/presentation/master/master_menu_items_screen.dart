import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../data/spicy_bistro_seeder.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'add_edit_menu_item_modal.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

// ===========================================================================
// Shared menu-list building blocks (also used by MasterProductsOnlineScreen)
// ===========================================================================

/// The filter dropdowns shown above the menu list. Option lists are built
/// from the live dish values.
enum MenuFilter {
  category('Category'),
  subCategory('Sub-category'),
  kitchen('Kitchen'),
  cuisine('Cuisine'),
  diet('Diet'),
  availability('Availability'),
  channel('Channel'),
  status('Status');

  const MenuFilter(this.label);
  final String label;

  Iterable<String> valuesOf(MasterDishItem d) => switch (this) {
        MenuFilter.category => [d.category],
        MenuFilter.subCategory => [dishText(d, DishDetail.subSection)],
        MenuFilter.kitchen => [d.kitchenStation],
        MenuFilter.cuisine => [dishText(d, DishDetail.cuisine)],
        MenuFilter.diet => [dietLabel(d)],
        MenuFilter.availability => [d.availability],
        MenuFilter.channel => d.channels,
        MenuFilter.status => [d.status],
      };
}

class MenuItemFilters {
  final selected = <MenuFilter, String>{};
  String query = '';

  bool get isActive => selected.isNotEmpty || query.trim().isNotEmpty;

  void reset() {
    selected.clear();
    query = '';
  }

  List<String> options(MenuFilter f, List<MasterDishItem> dishes) {
    final s = <String>{
      for (final d in dishes)
        for (final v in f.valuesOf(d))
          if (v.trim().isNotEmpty) v.trim(),
    };
    final current = selected[f];
    if (current != null) s.add(current);
    return s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool matches(MasterDishItem d) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        d.name,
        d.sku,
        d.category,
        d.hsn,
        dishText(d, DishDetail.shortName),
        dishText(d, DishDetail.displayName),
        dishText(d, DishDetail.internalCode),
        dishText(d, DishDetail.barcode),
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    for (final e in selected.entries) {
      if (!e.key.valuesOf(d).map((v) => v.trim()).contains(e.value)) {
        return false;
      }
    }
    return true;
  }

  List<MasterDishItem> apply(List<MasterDishItem> dishes) =>
      dishes.where(matches).toList();
}

/// Row of the eight live filter dropdowns plus Reset.
class MenuFilterControls extends StatelessWidget {
  const MenuFilterControls({
    super.key,
    required this.filters,
    required this.dishes,
    required this.onChanged,
    this.trailing = const [],
  });
  final MenuItemFilters filters;
  final List<MasterDishItem> dishes;
  final VoidCallback onChanged;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in MenuFilter.values)
          _dropdown(f, filters.options(f, dishes), isDark),
        if (filters.isActive)
          TextButton(
            onPressed: () {
              filters.selected.clear();
              onChanged();
            },
            child: const Text('Reset', style: TextStyle(fontSize: 11)),
          ),
        ...trailing,
      ],
    );
  }

  Widget _dropdown(MenuFilter f, List<String> options, bool isDark) {
    final value = filters.selected[f] ?? 'All';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: filters.selected.containsKey(f)
            ? ViniiColors.successPillBg
            : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA)),
        border:
            Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (v) {
            if (v == null || v == 'All') {
              filters.selected.remove(f);
            } else {
              filters.selected[f] = v;
            }
            onChanged();
          },
          items: [
            for (final o in ['All', ...options])
              DropdownMenuItem(value: o, child: Text('${f.label}: $o')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- CSV

const menuCsvHeaders = [
  'id',
  'name',
  'category',
  'selling_price',
  'food_cost',
  'availability',
  'channels',
  'kitchen_station',
  'status',
  'sku',
  'hsn',
  'diet',
  'image_url',
];

List<Object?> menuCsvRow(MasterDishItem d) => [
      d.id,
      d.name,
      d.category,
      d.sellingPrice.toStringAsFixed(2),
      d.foodCost.toStringAsFixed(2),
      d.availability,
      d.channels.join(', '),
      d.kitchenStation,
      d.status,
      d.sku,
      d.hsn,
      dietLabel(d).toLowerCase(),
      d.imageUrl,
    ];

String _today() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

Future<void> exportMenuItems(
    BuildContext context, List<MasterDishItem> dishes) async {
  if (dishes.isEmpty) {
    showMasterNotice(context, 'Nothing to export — no items match the filters');
    return;
  }
  await exportCsv(context,
      fileName: 'menu-items-${_today()}.csv',
      headers: menuCsvHeaders,
      rows: dishes.map(menuCsvRow));
}

/// Imports menu items from CSV. Rows match an existing item by id, then
/// sku, then name (case-insensitive); unmatched rows are added.
Future<void> importMenuItems(BuildContext context, DriftMasterStore store,
    List<MasterDishItem> existing) async {
  final records = await pickCsv(context);
  if (records == null || !context.mounted) return;
  final summary = ImportSummary();
  final byId = {for (final d in existing) d.id: d};

  MasterDishItem? match(CsvRecord r) {
    final id = r('id');
    if (id.isNotEmpty && byId.containsKey(id)) return byId[id];
    final sku = r('sku').toLowerCase();
    if (sku.isNotEmpty) {
      for (final d in byId.values) {
        if (d.sku.toLowerCase() == sku) return d;
      }
    }
    final name = r('name').toLowerCase();
    if (name.isNotEmpty) {
      for (final d in byId.values) {
        if (d.name.toLowerCase() == name) return d;
      }
    }
    return null;
  }

  var seq = 0;
  for (final r in records) {
    String? err(String msg) {
      summary.errors.add('Line ${r.line}: $msg');
      return null;
    }

    final base = match(r);
    final price = r.number('selling_price');
    if (r.has('selling_price') && (price == null || price < 0)) {
      err('selling_price "${r('selling_price')}" is not a valid amount');
      continue;
    }
    final cost = r.number('food_cost');
    if (r.has('food_cost') && (cost == null || cost < 0)) {
      err('food_cost "${r('food_cost')}" is not a valid amount');
      continue;
    }
    String? diet;
    if (r.has('diet')) {
      final raw = r('diet').toLowerCase().replaceAll(RegExp(r'[\s_]'), '-');
      diet = switch (raw) {
        'veg' || 'vegetarian' => 'veg',
        'non-veg' || 'nonveg' || 'non-vegetarian' => 'non-veg',
        'egg' || 'eggetarian' => 'egg',
        _ => null,
      };
      if (diet == null) {
        err('diet "${r('diet')}" must be veg, non-veg or egg');
        continue;
      }
    }
    if (base == null) {
      if (!r.has('name')) {
        err('name is required for new items');
        continue;
      }
      if (price == null) {
        err('selling_price is required for new items');
        continue;
      }
      if (!r.has('category')) {
        err('category is required for new items');
        continue;
      }
    }
    final channels = r.has('channels')
        ? r('channels')
            .split(RegExp(r'[,;|]'))
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList()
        : null;
    final d = base == null
        ? MasterDishItem(
            id: r(
                'id', 'dish-${DateTime.now().millisecondsSinceEpoch}-${seq++}'),
            name: r('name'),
            category: r('category'),
            sellingPrice: price!,
            foodCost: cost ?? 0,
            marginPercent: 0,
            availability: r('availability', 'In Stock'),
            channels: channels ?? const ['POS'],
            kitchenStation: r('kitchen_station'),
            status: r('status', 'Active'),
            sku: r('sku'),
            hsn: r('hsn'),
            imageUrl: r('image_url'),
            isVeg: (diet ?? 'veg') == 'veg',
            isNonVeg: diet == 'non-veg',
            isEgg: diet == 'egg',
          )
        : base.copyWith(
            name: r.has('name') ? r('name') : null,
            category: r.has('category') ? r('category') : null,
            sellingPrice: price,
            foodCost: cost,
            availability: r.has('availability') ? r('availability') : null,
            channels: channels,
            kitchenStation:
                r.has('kitchen_station') ? r('kitchen_station') : null,
            status: r.has('status') ? r('status') : null,
            sku: r.has('sku') ? r('sku') : null,
            hsn: r.has('hsn') ? r('hsn') : null,
            imageUrl: r.has('image_url') ? r('image_url') : null,
            isVeg: diet == null ? null : diet == 'veg',
            isNonVeg: diet == null ? null : diet == 'non-veg',
            isEgg: diet == null ? null : diet == 'egg',
          );
    try {
      await store.upsertDish(d);
      byId[d.id] = d;
      if (base == null) {
        summary.added++;
      } else {
        summary.updated++;
      }
    } catch (e) {
      err(masterErrorMessage(e,
          fallback:
              '"${d.name}" could not be saved. Check the row and try again.'));
    }
  }
  if (context.mounted) showImportSummary(context, summary);
}

// ---------------------------------------------------------------- bulk

Future<void> setMenuItemsAvailable(BuildContext context, DriftMasterStore store,
    List<MasterDishItem> dishes, bool available) async {
  if (dishes.isEmpty) return;
  await runMasterAction(context,
      () => store.setDishesAvailable(dishes.map((d) => d.id), available),
      success:
          '${dishes.length} item${dishes.length == 1 ? '' : 's'} marked ${available ? 'available' : 'unavailable'}');
}

/// Bulk Edit dialog. Returns true if the selected items were deleted.
Future<bool> showMenuBulkEditDialog(BuildContext context,
    DriftMasterStore store, List<MasterDishItem> dishes) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _BulkEditDialog(store: store, dishes: dishes),
  );
  return r ?? false;
}

class _BulkEditDialog extends StatefulWidget {
  const _BulkEditDialog({required this.store, required this.dishes});
  final DriftMasterStore store;
  final List<MasterDishItem> dishes;

  @override
  State<_BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<_BulkEditDialog> {
  static const _noChange = 'No change';
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String _status = _noChange;
  String _availability = _noChange;
  String _mode = '₹';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Iterable<String> get _ids => widget.dishes.map((d) => d.id);

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (_status == _noChange && _availability == _noChange && amount == 0) {
      showMasterError(context, 'Choose at least one change to apply.');
      return;
    }
    setState(() => _busy = true);
    final n = widget.dishes.length;
    final ok = await runMasterAction(context, () async {
      if (_status != _noChange) {
        await widget.store.setDishesStatus(_ids, _status);
      }
      if (_availability != _noChange) {
        await widget.store
            .setDishesAvailable(_ids, _availability == 'Available');
      }
      if (amount != 0) {
        await widget.store.adjustDishPrices(_ids,
            delta: _mode == '₹' ? amount : 0, pct: _mode == '%' ? amount : 0);
      }
    }, success: 'Updated $n item${n == 1 ? '' : 's'}');
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, false);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await deleteMenuItems(context, widget.store, widget.dishes);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco([String? hint]) => InputDecoration(
          isDense: true,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        );
    Widget dropdown(String label, String value, List<String> options,
            ValueChanged<String> onChanged) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: MasterStyle.label),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            key: ValueKey('$label|$value'),
            initialValue: value,
            isDense: true,
            decoration: deco(),
            style: const TextStyle(fontSize: 13, color: Colors.black),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(o))
            ],
            onChanged: (v) => setState(() => onChanged(v!)),
          ),
        ]);
    final n = widget.dishes.length;
    return AlertDialog(
      title: Text('Bulk edit $n item${n == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.dishes.take(4).map((d) => d.name).join(', ') +
                    (n > 4 ? ' and ${n - 4} more' : ''),
                style: MasterStyle.muted,
              ),
              const SizedBox(height: 16),
              dropdown(
                  'Set status',
                  _status,
                  [_noChange, 'Active', 'Draft', 'Inactive'],
                  (v) => _status = v),
              const SizedBox(height: 12),
              dropdown(
                  'Set availability',
                  _availability,
                  [_noChange, 'Available', 'Unavailable'],
                  (v) => _availability = v),
              const SizedBox(height: 12),
              const Text('Adjust selling price', style: MasterStyle.label),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '₹', label: Text('₹')),
                    ButtonSegment(value: '%', label: Text('%')),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    style: const TextStyle(fontSize: 13),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: deco(_mode == '₹'
                        ? 'e.g. 20 or -10 (rupees)'
                        : 'e.g. 5 or -10 (percent)'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final x = double.tryParse(t);
                      if (x == null) return 'Enter a number';
                      if (_mode == '%' && x <= -100) {
                        return 'Must be greater than -100%';
                      }
                      return null;
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline,
              size: 18, color: ViniiColors.redSolid),
          label: const Text('Delete selected',
              style: TextStyle(color: ViniiColors.redSolid)),
        ),
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ViniiColors.brandGreen,
              foregroundColor: Colors.black),
          onPressed: _busy ? null : _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Green "N selected" bar with the bulk actions.
class MenuBulkBar extends StatelessWidget {
  const MenuBulkBar({
    super.key,
    required this.store,
    required this.selected,
    required this.onClear,
    this.editLabel = 'Bulk Edit',
  });
  final DriftMasterStore store;
  final List<MasterDishItem> selected;
  final VoidCallback onClear;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final names = selected.take(2).map((d) => d.name).join(' and ');
    final more = selected.length > 2 ? ' and ${selected.length - 2} more' : '';
    final anyAvailable = selected.any((d) => d.availability != 'Unavailable');
    final anyUnavailable = selected.any((d) => d.availability == 'Unavailable');
    final btn = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ViniiColors.successPillBg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ViniiColors.brandGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '✓ ${selected.length} selected',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$names$more ${selected.length == 1 ? 'is' : 'are'} ready for bulk actions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onClear,
            style: btn,
            child: const Text('Deselect All', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          if (anyAvailable)
            OutlinedButton(
              onPressed: () =>
                  setMenuItemsAvailable(context, store, selected, false),
              style: btn,
              child: const Text('Mark Unavailable',
                  style: TextStyle(fontSize: 11)),
            ),
          if (anyAvailable && anyUnavailable) const SizedBox(width: 8),
          if (anyUnavailable)
            OutlinedButton(
              onPressed: () =>
                  setMenuItemsAvailable(context, store, selected, true),
              style: btn,
              child:
                  const Text('Mark Available', style: TextStyle(fontSize: 11)),
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final deleted =
                  await showMenuBulkEditDialog(context, store, selected);
              if (deleted) onClear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ViniiColors.brandGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            child: Text(editLabel),
          ),
        ],
      ),
    );
  }
}

/// Overflow menu for one dish (card / row).
class MenuItemOverflow extends StatelessWidget {
  const MenuItemOverflow({
    super.key,
    required this.store,
    required this.dish,
    required this.allDishes,
    this.media = const {},
    this.onDeleted,
  });
  final DriftMasterStore store;
  final MasterDishItem dish;
  final List<MasterDishItem> allDishes;
  final Map<String, MediaAssetRecord> media;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final unavailable = dish.availability == 'Unavailable';
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_vert, size: 16),
      padding: EdgeInsets.zero,
      onSelected: (v) async {
        switch (v) {
          case 'view':
            await showMenuItemDetails(context,
                store: store, dish: dish, allDishes: allDishes, media: media);
          case 'edit':
            await openMenuItemEditor(context,
                store: store, allDishes: allDishes, dish: dish);
          case 'toggle':
            await setMenuItemsAvailable(context, store, [dish], unavailable);
          case 'delete':
            if (await deleteMenuItems(context, store, [dish])) {
              onDeleted?.call();
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: Text('View details')),
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
            value: 'toggle',
            child: Text(unavailable ? 'Mark available' : 'Mark unavailable')),
        const PopupMenuItem(
            value: 'delete',
            child:
                Text('Delete', style: TextStyle(color: ViniiColors.redSolid))),
      ],
    );
  }
}

/// Selectable table of dishes with View / Edit / more actions per row.
class MenuItemsDataTable extends StatelessWidget {
  const MenuItemsDataTable({
    super.key,
    required this.store,
    required this.dishes,
    required this.allDishes,
    required this.selected,
    required this.onSelectionChanged,
    this.onChanged,
    this.media = const {},
    this.nameColor,
  });
  final DriftMasterStore store;
  final List<MasterDishItem> dishes;
  final List<MasterDishItem> allDishes;
  final Set<String> selected;
  final VoidCallback onSelectionChanged;

  /// Called after a row was edited, so the screen can re-read at once.
  final VoidCallback? onChanged;
  final Map<String, MediaAssetRecord> media;
  final Color? nameColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const head = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF252525) : const Color(0xFFF9FAFB),
          ),
          horizontalMargin: 16,
          columnSpacing: 22,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          onSelectAll: (v) {
            if (v == true) {
              selected.addAll(dishes.map((d) => d.id));
            } else {
              selected.removeAll(dishes.map((d) => d.id));
            }
            onSelectionChanged();
          },
          columns: const [
            DataColumn(label: Text('Item', style: head)),
            DataColumn(label: Text('Category', style: head)),
            DataColumn(
                label: Text('Selling Price', style: head), numeric: true),
            DataColumn(label: Text('Food Cost', style: head), numeric: true),
            DataColumn(label: Text('Margin', style: head), numeric: true),
            DataColumn(label: Text('Availability', style: head)),
            DataColumn(label: Text('Channels', style: head)),
            DataColumn(label: Text('Kitchen', style: head)),
            DataColumn(label: Text('Status', style: head)),
            DataColumn(label: Text('Action', style: head)),
          ],
          rows: [
            for (final dish in dishes)
              DataRow(
                selected: selected.contains(dish.id),
                onSelectChanged: (val) {
                  if (val == true) {
                    selected.add(dish.id);
                  } else {
                    selected.remove(dish.id);
                  }
                  onSelectionChanged();
                },
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: MenuItemImage(
                              dish: dish,
                              media: media,
                              width: 32,
                              height: 32,
                              iconSize: 16),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dish.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: nameColor)),
                              Text(
                                  dish.sku.isEmpty
                                      ? dietLabel(dish)
                                      : 'SKU: ${dish.sku}',
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => showMenuItemDetails(context,
                        store: store,
                        dish: dish,
                        allDishes: allDishes,
                        media: media),
                  ),
                  DataCell(Text(dish.category,
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(formatRupees(dish.sellingPrice),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
                  DataCell(Text(formatRupees(dish.foodCost),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${dish.marginPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: ViniiColors.emeraldText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12))),
                  DataCell(Text(dish.availability,
                      style: TextStyle(
                          fontSize: 12,
                          color: dish.availability == 'Unavailable'
                              ? ViniiColors.redSolid
                              : null))),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(dish.channels.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(dish.kitchenStation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                  )),
                  DataCell(MasterStatusPill(dish.status)),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'View',
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      onPressed: () => showMenuItemDetails(context,
                          store: store,
                          dish: dish,
                          allDishes: allDishes,
                          media: media),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => openMenuItemEditor(context,
                              store: store, allDishes: allDishes, dish: dish)
                          .then((_) => onChanged?.call()),
                    ),
                    MenuItemOverflow(
                      store: store,
                      dish: dish,
                      allDishes: allDishes,
                      media: media,
                      onDeleted: () {
                        selected.remove(dish.id);
                        onSelectionChanged();
                      },
                    ),
                  ])),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Watches dishes + media from the store and exposes them to a State.
mixin MenuDataMixin<T extends StatefulWidget> on State<T> {
  DriftMasterStore get menuStore;
  StreamSubscription<List<MasterDishItem>>? _dishSub;
  StreamSubscription<List<MediaAssetRecord>>? _mediaSub;
  List<MasterDishItem>? dishes;
  Map<String, MediaAssetRecord> media = const {};
  Object? loadError;
  final selectedIds = <String>{};

  /// Active kitchen stations from Operations → KDS, offered by the item
  /// editor; null when the screen has no operations store.
  List<String>? kitchenStationNames;
  StreamSubscription<Object?>? _stationSub;

  /// Follows the kitchen stations configured in Operations → KDS.
  void startKitchenStations(DriftOperationsStore? ops) {
    if (ops == null) return;
    _stationSub = ops.watchKitchenStations().listen((stations) {
      if (!mounted) return;
      setState(() => kitchenStationNames = [
            for (final s in stations)
              if (s.active && s.name.trim().isNotEmpty) s.name.trim()
          ]);
    }, onError: (Object _) {});
  }

  /// Puts the kitchen stations where the item editor finds them.
  Widget withKitchenStations(Widget child) =>
      MenuKitchenStations(names: kitchenStationNames, child: child);

  void startMenuData() {
    _listenDishes();
    _mediaSub = menuStore.watchMedia().listen((items) {
      if (mounted) setState(() => media = {for (final m in items) m.id: m});
    }, onError: (Object _) {});
  }

  void onDishesChanged(List<MasterDishItem> items) {}

  void _listenDishes() {
    _dishSub?.cancel();
    _dishSub = menuStore.watchDishes().listen((items) {
      if (!mounted) return;
      setState(() {
        dishes = items;
        loadError = null;
        final ids = items.map((d) => d.id).toSet();
        selectedIds.removeWhere((id) => !ids.contains(id));
      });
      onDishesChanged(items);
    }, onError: (Object e) {
      // A failed stream would otherwise leave the list frozen: show the
      // error only while there is nothing to show, re-read once, and
      // listen again.
      debugPrint('menu items stream failed: $e');
      if (!mounted) return;
      if (dishes == null) setState(() => loadError = e);
      _dishSub?.cancel();
      _dishSub = null;
      refreshMenuData();
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _dishSub == null) _listenDishes();
      });
    });
  }

  /// Re-reads the dishes now — after the editor closes, so a save shows at
  /// once even if the database stream is late.
  Future<void> refreshMenuData() async {
    try {
      final fresh = await menuStore.getDishes();
      if (!mounted) return;
      setState(() {
        dishes = fresh;
        loadError = null;
      });
    } catch (e) {
      if (mounted && dishes == null) setState(() => loadError = e);
    }
  }

  void stopMenuData() {
    _dishSub?.cancel();
    _mediaSub?.cancel();
    _stationSub?.cancel();
  }

  List<MasterDishItem> get selectedDishes => [
        for (final d in dishes ?? const <MasterDishItem>[])
          if (selectedIds.contains(d.id)) d
      ];

  Widget menuLoadingOrError() => Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: loadError != null
              ? const Text(
                  'Could not load menu items. Please open this screen again, or restart the app if it keeps happening.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ViniiColors.redSolid))
              : const CircularProgressIndicator(),
        ),
      );
}

/// Empty-state card for the menu list.
class MenuEmptyState extends StatelessWidget {
  const MenuEmptyState(
      {super.key,
      required this.hasItems,
      required this.onAdd,
      this.onReset,
      this.onSeed});
  final bool hasItems;
  final VoidCallback onAdd;
  final VoidCallback? onReset;
  final VoidCallback? onSeed;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.restaurant_menu, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
                hasItems
                    ? 'No items match the current search and filters.'
                    : 'No menu items yet. Add your first dish or load the default catalog.',
                style: MasterStyle.muted),
            const SizedBox(height: 12),
            hasItems
                ? MasterButton(label: 'Reset filters', onPressed: onReset)
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      MasterButton(
                          label: 'Add Item',
                          icon: Icons.add,
                          kind: MasterButtonKind.primary,
                          onPressed: onAdd),
                      if (onSeed != null)
                        MasterButton(
                            label: 'Load Spicy Bistro Catalog',
                            icon: Icons.download,
                            kind: MasterButtonKind.outline,
                            onPressed: onSeed),
                    ],
                  ),
          ]),
        ),
      );
}

// ===========================================================================
// Menu Catalog screen
// ===========================================================================

class MasterMenuItemsScreen extends StatefulWidget {
  const MasterMenuItemsScreen(
      {super.key, required this.store, this.allowDemoSeed = true, this.ops});

  final DriftMasterStore store;

  /// Fill an empty menu with sample dishes — local demo mode only. With a
  /// backend the restaurant's real menu comes from its server.
  final bool allowDemoSeed;

  /// Optional: supplies the kitchen stations (Operations → KDS) offered as
  /// "Kitchen Station" / "KDS Group" in the item editor.
  final DriftOperationsStore? ops;

  @override
  State<MasterMenuItemsScreen> createState() => _MasterMenuItemsScreenState();
}

class _MasterMenuItemsScreenState extends State<MasterMenuItemsScreen>
    with MenuDataMixin {
  String _viewMode = 'Grid'; // 'Grid' or 'List'
  final _filters = MenuItemFilters();
  final _search = TextEditingController();

  @override
  DriftMasterStore get menuStore => widget.store;

  @override
  void initState() {
    super.initState();
    startMenuData();
    startKitchenStations(widget.ops);
  }

  @override
  void dispose() {
    stopMenuData();
    _search.dispose();
    super.dispose();
  }

  List<MasterDishItem> get _all => dishes ?? const [];

  void _openAddEditModal([MasterDishItem? dish]) {
    openMenuItemEditor(context,
            store: widget.store,
            allDishes: _all,
            dish: dish,
            kitchenStations: kitchenStationNames)
        .then((_) => refreshMenuData());
  }

  void _view(MasterDishItem dish) => showMenuItemDetails(context,
      store: widget.store,
      dish: dish,
      allDishes: _all,
      media: media,
      kitchenStations: kitchenStationNames);

  bool _didAutoSeed = false;

  @override
  void onDishesChanged(List<MasterDishItem> items) {
    if (widget.allowDemoSeed && items.isEmpty && !_didAutoSeed) {
      _didAutoSeed = true;
      _seedSampleDishes();
    }
  }

  Future<void> _seedSampleDishes() async {
    for (final d in MasterCatalogData.sampleDishes) {
      await widget.store.upsertDish(d);
    }
    for (final d in SpicyBistroSeeder.masterDishes) {
      await widget.store.upsertDish(d);
    }
    final fresh = await widget.store.getDishes();
    if (mounted) {
      setState(() {
        dishes = fresh;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _filters.reset();
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) =>
      withKitchenStations(_buildBody(context));

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final filteredDishes = _filters.apply(_all);
    final allShownSelected = filteredDishes.isNotEmpty &&
        filteredDishes.every((d) => selectedIds.contains(d.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu Catalog',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage dishes, pricing, availability, recipes and item information from one place',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: dishes == null
                    ? null
                    : () => importMenuItems(context, widget.store, _all),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Import'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: dishes == null
                    ? null
                    : () => exportMenuItems(context, filteredDishes),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Export'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openAddEditModal(),
                icon: const Icon(Icons.add, size: 16, color: Colors.black),
                label: const Text('Add Item',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViniiColors.brandGreen,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Filter Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (val) => setState(() => _filters.query = val),
                  decoration: InputDecoration(
                    hintText: 'Filter by dish name, SKU, code or barcode...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF4F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                MenuFilterControls(
                  filters: _filters,
                  dishes: _all,
                  onChanged: () => setState(() {}),
                  trailing: [
                    const SizedBox(width: 8),
                    if (filteredDishes.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          if (allShownSelected) {
                            selectedIds
                                .removeAll(filteredDishes.map((d) => d.id));
                          } else {
                            selectedIds.addAll(filteredDishes.map((d) => d.id));
                          }
                        }),
                        child: Text(
                            allShownSelected
                                ? 'Deselect shown'
                                : 'Select all (${filteredDishes.length})',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildViewToggle('Grid', _viewMode == 'Grid'),
                          _buildViewToggle('List', _viewMode == 'List'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (selectedIds.isNotEmpty) ...[
            MenuBulkBar(
              store: widget.store,
              selected: selectedDishes,
              onClear: () => setState(selectedIds.clear),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          if (dishes == null)
            menuLoadingOrError()
          else if (filteredDishes.isEmpty)
            MenuEmptyState(
                hasItems: _all.isNotEmpty,
                onAdd: () => _openAddEditModal(),
                onReset: _resetFilters,
                // The demo catalog is for the local demo only, never a
                // live restaurant.
                onSeed: widget.allowDemoSeed ? _seedSampleDishes : null)
          else if (_viewMode == 'Grid')
            _buildGridView(filteredDishes, cardBg, borderColor, isDark)
          else
            MenuItemsDataTable(
              onChanged: refreshMenuData,
              store: widget.store,
              dishes: filteredDishes,
              allDishes: _all,
              selected: selectedIds,
              media: media,
              onSelectionChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }

  Widget _buildGridView(
    List<MasterDishItem> dishes,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dishes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 460,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) =>
              _card(dishes[index], cardBg, borderColor),
        );
      },
    );
  }

  Widget _card(MasterDishItem dish, Color cardBg, Color borderColor) {
    final isSelected = selectedIds.contains(dish.id);
    final unavailable = dish.availability == 'Unavailable';
    final costPct = dish.sellingPrice > 0
        ? (dish.foodCost / dish.sellingPrice * 100).toStringAsFixed(0)
        : '0';
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? ViniiColors.brandGreen : borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with badges
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: MenuItemImage(
                    dish: dish,
                    media: media,
                    height: 160,
                    width: double.infinity,
                    iconSize: 40),
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 140,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      dish.category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: ViniiColors.emeraldText,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    MasterStatusPill(dish.status),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Checkbox(
                        value: isSelected,
                        visualDensity: VisualDensity.compact,
                        activeColor: ViniiColors.emeraldText,
                        onChanged: (v) => setState(() => v == true
                            ? selectedIds.add(dish.id)
                            : selectedIds.remove(dish.id)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Content Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _priceRow('Selling Price', formatRupees(dish.sellingPrice),
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _priceRow(
                    'Food Cost',
                    '${formatRupees(dish.foodCost)} ($costPct%)',
                    const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                _priceRow(
                    'Margin',
                    '${dish.marginPercent.toStringAsFixed(0)}%',
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ViniiColors.emeraldText,
                    )),
                const Divider(height: 16),
                _buildMetaRow('Availability', dish.availability,
                    textColor: unavailable
                        ? ViniiColors.redSolid
                        : ViniiColors.emeraldText),
                _buildMetaRow('Channels', dish.channels.join(' · '),
                    textColor: const Color(0xFF2563EB)),
                _buildMetaRow('Kitchen', dish.kitchenStation),
                _buildMetaRow('Diet', dietLabel(dish)),
              ],
            ),
          ),
          const Spacer(),
          const Divider(height: 1),

          // Footer SKU & Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SKU: ${dish.sku.isEmpty ? '—' : dish.sku} · HSN: ${dish.hsn.isEmpty ? '—' : dish.hsn}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _footerLink('View', () => _view(dish)),
                const SizedBox(width: 8),
                _footerLink('Edit', () => _openAddEditModal(dish)),
                MenuItemOverflow(
                  store: widget.store,
                  dish: dish,
                  allDishes: _all,
                  media: media,
                  onDeleted: () => setState(() => selectedIds.remove(dish.id)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ViniiColors.emeraldText,
            ),
          ),
        ),
      );

  Widget _priceRow(String label, String value, TextStyle style) => Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          Text(value, style: style),
        ],
      );

  Widget _buildMetaRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(String mode, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ViniiColors.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
