import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../vinii_theme.dart';
import 'add_edit_menu_item_modal.dart';
import 'master_file_io.dart';
import 'master_menu_items_screen.dart';
import 'master_ui.dart';

class MasterProductsOnlineScreen extends StatefulWidget {
  const MasterProductsOnlineScreen(
      {super.key, required this.store, this.allowDemoSeed = true, this.ops});

  final DriftMasterStore store;

  /// Fill an empty menu with sample dishes — local demo mode only. With a
  /// backend the restaurant's real menu comes from its server.
  final bool allowDemoSeed;

  /// Optional: supplies the kitchen stations (Operations → KDS) offered as
  /// "Kitchen Station" / "KDS Group" in the item editor.
  final DriftOperationsStore? ops;

  @override
  State<MasterProductsOnlineScreen> createState() =>
      _MasterProductsOnlineScreenState();
}

class _MasterProductsOnlineScreenState extends State<MasterProductsOnlineScreen>
    with MenuDataMixin {
  String _activeSubTab =
      'Item Master'; // 'Dashboard', 'Channel Price', 'Item Master'
  final _filters = MenuItemFilters();
  final _search = TextEditingController();

  // Channel Price editing: key = '<dishId>|base' or '<dishId>|<channel>'.
  final _priceCtrls = <String, TextEditingController>{};
  final _dirty = <String>{};
  final _savingRows = <String>{};

  @override
  DriftMasterStore get menuStore => widget.store;

  bool _didAutoSeed = false;

  Future<void> _seedSampleDishes() async {
    for (final d in MasterCatalogData.sampleDishes) {
      await widget.store.upsertDish(d);
    }
  }

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
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<MasterDishItem> get _all => dishes ?? const [];

  @override
  void onDishesChanged(List<MasterDishItem> items) {
    if (widget.allowDemoSeed && items.isEmpty && !_didAutoSeed) {
      _didAutoSeed = true;
      _seedSampleDishes();
    }
    // Refresh untouched price cells with the latest saved values.
    final byId = {for (final d in items) d.id: d};
    for (final e in _priceCtrls.entries) {
      if (_dirty.contains(e.key)) continue;
      final parts = e.key.split('|');
      final d = byId[parts.first];
      if (d == null) continue;
      final text = _savedPriceText(d, parts.sublist(1).join('|'));
      if (e.value.text != text) e.value.text = text;
    }
  }

  // ------------------------------------------------------------ channel price

  /// Online channels shown as price-override columns (POS uses base price).
  List<String> get _priceChannels {
    final s = <String>{
      for (final d in _all)
        for (final c in d.channels)
          if (c.trim().isNotEmpty && c.trim().toUpperCase() != 'POS') c.trim()
    };
    return s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Map<String, Object?> _channelPrices(MasterDishItem d) {
    final v = d.details[DishDetail.channelPrices];
    return v is Map ? v.cast<String, Object?>() : const {};
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _savedPriceText(MasterDishItem d, String channel) {
    if (channel == 'base') return _fmt(d.sellingPrice);
    final v = _channelPrices(d)[channel];
    if (v is num) return _fmt(v.toDouble());
    return '';
  }

  TextEditingController _priceCtrl(MasterDishItem d, String channel) =>
      _priceCtrls.putIfAbsent('${d.id}|$channel',
          () => TextEditingController(text: _savedPriceText(d, channel)));

  bool _rowDirty(MasterDishItem d) =>
      _dirty.any((k) => k.startsWith('${d.id}|'));

  String? _priceError(String text, {required bool required}) {
    final t = text.trim();
    if (t.isEmpty) return required ? 'Required' : null;
    final v = double.tryParse(t);
    if (v == null) return 'Not a number';
    if (v < 0) return 'Must be ≥ 0';
    return null;
  }

  /// Validates and builds the updated dish for a row, or returns an error.
  (MasterDishItem?, String?) _buildRow(MasterDishItem d) {
    final base = _priceCtrl(d, 'base').text;
    final baseErr = _priceError(base, required: true);
    if (baseErr != null) return (null, '${d.name}: base price $baseErr');
    final prices = <String, Object?>{..._channelPrices(d)};
    for (final ch in _priceChannels) {
      final key = '${d.id}|$ch';
      if (!_priceCtrls.containsKey(key)) continue;
      final t = _priceCtrls[key]!.text.trim();
      final err = _priceError(t, required: false);
      if (err != null) return (null, '${d.name}: $ch price $err');
      if (t.isEmpty) {
        prices.remove(ch);
      } else {
        prices[ch] = double.parse(t);
      }
    }
    final details = <String, Object?>{...d.details};
    if (prices.isEmpty) {
      details.remove(DishDetail.channelPrices);
    } else {
      details[DishDetail.channelPrices] = prices;
    }
    return (
      d.copyWith(sellingPrice: double.parse(base.trim()), details: details),
      null
    );
  }

  Future<void> _saveRows(List<MasterDishItem> rows) async {
    final updates = <MasterDishItem>[];
    for (final d in rows) {
      final (u, err) = _buildRow(d);
      if (err != null) {
        showMasterError(context, err);
        return;
      }
      updates.add(u!);
    }
    if (updates.isEmpty) return;
    setState(() => _savingRows.addAll(updates.map((d) => d.id)));
    final ok = await runMasterAction(context, () async {
      for (final u in updates) {
        await widget.store.upsertDish(u);
      }
    },
        success: updates.length == 1
            ? 'Prices saved for ${updates.first.name}'
            : 'Prices saved for ${updates.length} items');
    if (!mounted) return;
    setState(() {
      _savingRows.removeAll(updates.map((d) => d.id));
      if (ok) {
        for (final u in updates) {
          _dirty.removeWhere((k) => k.startsWith('${u.id}|'));
        }
      }
    });
  }

  void _discardRow(MasterDishItem d) {
    setState(() {
      for (final k in _dirty.where((k) => k.startsWith('${d.id}|')).toList()) {
        final ch = k.split('|').sublist(1).join('|');
        _priceCtrls[k]?.text = _savedPriceText(d, ch);
        _dirty.remove(k);
      }
    });
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) =>
      withKitchenStations(_buildBody(context));

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final filtered = _filters.apply(_all);

    return Column(
      children: [
        // Sub Navigation Header Bar (Dashboard, Channel Price, Item Master)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              _buildSubNavTab('Dashboard', _activeSubTab == 'Dashboard'),
              _buildSubNavTab(
                  'Channel Price', _activeSubTab == 'Channel Price'),
              _buildSubNavTab('Item Master', _activeSubTab == 'Item Master'),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(isDark, filtered),
                const SizedBox(height: 20),
                if (dishes == null)
                  menuLoadingOrError()
                else if (_activeSubTab == 'Dashboard')
                  _dashboard()
                else ...[
                  _filterCard(cardBg, borderColor, isDark),
                  const SizedBox(height: 20),
                  if (filtered.isEmpty)
                    MenuEmptyState(
                      hasItems: _all.isNotEmpty,
                      onAdd: _openAdd,
                      onReset: () => setState(() {
                        _filters.reset();
                        _search.clear();
                      }),
                    )
                  else if (_activeSubTab == 'Channel Price')
                    _channelPriceTable(filtered, cardBg, borderColor, isDark)
                  else ...[
                    MenuItemsDataTable(
                      store: widget.store,
                      dishes: filtered,
                      allDishes: _all,
                      selected: selectedIds,
                      media: media,
                      nameColor: const Color(0xFF175CD3),
                      onSelectionChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (selectedIds.isNotEmpty)
                      MenuBulkBar(
                        store: widget.store,
                        selected: selectedDishes,
                        editLabel: 'Edit selected',
                        onClear: () => setState(selectedIds.clear),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAdd() => openMenuItemEditor(context,
          store: widget.store,
          allDishes: _all,
          kitchenStations: kitchenStationNames)
      .then((_) => refreshMenuData());

  Widget _header(bool isDark, List<MasterDishItem> filtered) {
    final dirtyRows = _all.where(_rowDirty).toList();
    return Row(
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
                switch (_activeSubTab) {
                  'Dashboard' => 'Catalogue health across channels at a glance',
                  'Channel Price' =>
                    'Set the base price and per-channel prices for every item',
                  _ =>
                    'Manage dishes, pricing, availability, recipes and item information from one place',
                },
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_activeSubTab == 'Channel Price' && dirtyRows.isNotEmpty) ...[
          TextButton(
            onPressed: () {
              for (final d in dirtyRows) {
                _discardRow(d);
              }
            },
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _saveRows(dirtyRows),
            style: ElevatedButton.styleFrom(
              backgroundColor: ViniiColors.brandGreen,
              foregroundColor: Colors.black,
            ),
            child: Text('Save all (${dirtyRows.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
        ],
        OutlinedButton(
          onPressed: dishes == null
              ? null
              : () => importMenuItems(context, widget.store, _all),
          child: const Text('Import'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: dishes == null
              ? null
              : () => exportMenuItems(
                  context, _activeSubTab == 'Dashboard' ? _all : filtered),
          child: const Text('Export'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _openAdd,
          icon: const Icon(Icons.add, size: 16, color: Colors.black),
          label: const Text('Add Item',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ViniiColors.brandGreen,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _filterCard(Color cardBg, Color borderColor, bool isDark) {
    return Container(
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
              fillColor:
                  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          MenuFilterControls(
            filters: _filters,
            dishes: _all,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ dashboard

  Widget _dashboard() {
    final all = _all;
    if (all.isEmpty) {
      return MenuEmptyState(hasItems: false, onAdd: _openAdd);
    }
    final active = all.where((d) => d.status == 'Active').length;
    final unavailable =
        all.where((d) => d.availability == 'Unavailable').toList();
    final priced = all.where((d) => d.sellingPrice > 0).toList();
    final avgMargin = priced.isEmpty
        ? 0.0
        : priced.map((d) => d.marginPercent).reduce((a, b) => a + b) /
            priced.length;
    final channelCounts = <String, int>{};
    for (final d in all) {
      for (final c in d.channels) {
        if (c.trim().isEmpty) continue;
        channelCounts[c.trim()] = (channelCounts[c.trim()] ?? 0) + 1;
      }
    }
    final channels = channelCounts.keys.toList()
      ..sort((a, b) => channelCounts[b]!.compareTo(channelCounts[a]!));
    final byCategory = <String, List<MasterDishItem>>{};
    for (final d in all) {
      byCategory.putIfAbsent(d.category, () => []).add(d);
    }
    final categories = byCategory.keys.toList()..sort();

    final attention = <(MasterDishItem, String)>[
      for (final d in all)
        if (d.sellingPrice <= 0)
          (d, 'No selling price')
        else if (d.sellingPrice > 0 && d.marginPercent < 50)
          (d, 'Low margin ${d.marginPercent.toStringAsFixed(0)}%')
        else if (d.channels.isEmpty)
          (d, 'Not exposed on any channel')
        else if (d.imageUrl.isEmpty && dishText(d, DishDetail.mediaId).isEmpty)
          (d, 'No image'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MasterGrid(children: [
          MasterStatCard(
              label: 'Total items',
              value: '${all.length}',
              caption: '${byCategory.length} categories'),
          MasterStatCard(
              label: 'Active items',
              value: '$active',
              valueColor: ViniiColors.emeraldText,
              caption: '${all.length - active} draft / inactive'),
          MasterStatCard(
              label: 'Unavailable now',
              value: '${unavailable.length}',
              valueColor: unavailable.isEmpty
                  ? ViniiColors.textPrimaryLight
                  : ViniiColors.redSolid,
              caption: 'Hidden from ordering'),
          MasterStatCard(
              label: 'Average margin',
              value: '${avgMargin.toStringAsFixed(1)}%',
              caption: 'Across ${priced.length} priced items'),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final coverage = MasterSection(
            title: 'Channel coverage',
            subtitle: 'Items exposed on each sales channel',
            child: Column(children: [
              if (channels.isEmpty)
                const Text('No channels assigned yet.',
                    style: MasterStyle.muted),
              for (final ch in channels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MasterProgress(
                    label: '$ch · ${channelCounts[ch]} of ${all.length}',
                    value: channelCounts[ch]! / all.length,
                  ),
                ),
            ]),
          );
          final cats = MasterSection(
            title: 'Categories',
            subtitle: 'Item count and average price',
            child: Column(children: [
              for (final cat in categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                        child: Text(cat.isEmpty ? '(none)' : cat,
                            style: MasterStyle.body)),
                    Text('${byCategory[cat]!.length} items',
                        style: MasterStyle.muted),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 90,
                      child: Text(
                        formatRupees(byCategory[cat]!
                                .map((d) => d.sellingPrice)
                                .reduce((a, b) => a + b) /
                            byCategory[cat]!.length),
                        textAlign: TextAlign.right,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
            ]),
          );
          if (c.maxWidth < 900) {
            return Column(
                children: [coverage, const SizedBox(height: 16), cats]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: coverage),
            const SizedBox(width: 16),
            Expanded(child: cats),
          ]);
        }),
        const SizedBox(height: 16),
        MasterSection(
          title: 'Needs attention',
          subtitle: attention.isEmpty
              ? 'Every item is priced, exposed and has an image'
              : '${attention.length} items to review',
          child: Column(children: [
            for (final (d, reason) in attention.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(d.name,
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  MasterStatusPill(reason, tone: PillTone.amber),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => openMenuItemEditor(context,
                            store: widget.store,
                            allDishes: _all,
                            dish: d,
                            kitchenStations: kitchenStationNames)
                        .then((_) => refreshMenuData()),
                    child: const Text('Fix'),
                  ),
                ]),
              ),
            if (attention.length > 12)
              Text('…and ${attention.length - 12} more',
                  style: MasterStyle.muted),
          ]),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ price table

  Widget _channelPriceTable(
      List<MasterDishItem> rows, Color cardBg, Color borderColor, bool isDark) {
    final channels = _priceChannels;
    const head = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'POS bills at the base price. Leave a channel price empty to use the base price on that channel. Cells are disabled for channels the item is not exposed on.',
          style: MasterStyle.muted,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF252525) : const Color(0xFFF9FAFB),
              ),
              horizontalMargin: 16,
              columnSpacing: 18,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              columns: [
                const DataColumn(label: Text('Item', style: head)),
                const DataColumn(label: Text('Food Cost', style: head)),
                const DataColumn(label: Text('Base Price ₹', style: head)),
                for (final ch in channels)
                  DataColumn(label: Text('$ch ₹', style: head)),
                const DataColumn(label: Text('Margin', style: head)),
                const DataColumn(label: Text('', style: head)),
              ],
              rows: [
                for (final d in rows) _priceRow(d, channels),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _priceRow(MasterDishItem d, List<String> channels) {
    final dirty = _rowDirty(d);
    final saving = _savingRows.contains(d.id);
    final base = double.tryParse(_priceCtrl(d, 'base').text.trim());
    final margin =
        base == null || base <= 0 ? null : (base - d.foodCost) / base * 100;
    return DataRow(
      color: dirty ? WidgetStateProperty.all(const Color(0xFFFFFBEB)) : null,
      cells: [
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(d.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF175CD3))),
              Text(d.category,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        )),
        DataCell(Text(formatRupees(d.foodCost),
            style: const TextStyle(fontSize: 12))),
        DataCell(_priceField(d, 'base', required: true)),
        for (final ch in channels)
          DataCell(d.channels.contains(ch)
              ? _priceField(d, ch, required: false)
              : Text('—', style: TextStyle(color: Colors.grey[400]))),
        DataCell(Text(margin == null ? '—' : '${margin.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: ViniiColors.emeraldText,
                fontWeight: FontWeight.bold,
                fontSize: 12))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          if (dirty && !saving)
            IconButton(
              tooltip: 'Discard changes',
              icon: const Icon(Icons.undo, size: 16),
              onPressed: () => _discardRow(d),
            ),
          saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: dirty ? () => _saveRows([d]) : null,
                  child: const Text('Save'),
                ),
        ])),
      ],
    );
  }

  Widget _priceField(MasterDishItem d, String channel,
      {required bool required}) {
    final ctrl = _priceCtrl(d, channel);
    final key = '${d.id}|$channel';
    final err = _priceError(ctrl.text, required: required);
    return SizedBox(
      width: 96,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => _dirty.add(key)),
        onSubmitted: (_) => _saveRows([d]),
        decoration: InputDecoration(
          isDense: true,
          hintText: required ? '0' : 'Base',
          errorText: err,
          errorStyle: const TextStyle(fontSize: 9, height: 0.8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: MasterStyle.cardBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: MasterStyle.cardBorder)),
        ),
      ),
    );
  }

  Widget _buildSubNavTab(String title, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _activeSubTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? ViniiColors.emeraldText : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? ViniiColors.emeraldText : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
