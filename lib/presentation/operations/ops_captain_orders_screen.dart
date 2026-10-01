import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../data/staff_repository.dart' show StaffRepository;
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_pickers.dart';

/// Operations → Captain Order. A captain picks dishes from the Master
/// menu into a running ticket for a table picked on the floor plan, then
/// "Send to Kitchen (KOT)" places the order in the POS tables (joining
/// the table's open order if it has one) and creates the KOT.
class OpsCaptainOrdersScreen extends StatefulWidget {
  const OpsCaptainOrdersScreen(
      {super.key,
      required this.ops,
      this.master,
      this.focusOrderId,
      this.onOpenBilling,
      this.staff});
  final DriftOperationsStore ops;
  final DriftMasterStore? master;
  final String? focusOrderId;
  final ValueChanged<String>? onOpenBilling;

  /// The restaurant's staff: the captain / server is picked from its
  /// active people. Null (no staff list) → typed, with the names already
  /// used on tables and orders suggested.
  final StaffRepository? staff;

  @override
  State<OpsCaptainOrdersScreen> createState() => _OpsCaptainOrdersScreenState();
}

const _lime = ViniiColors.brandGreen;
const _border = MasterStyle.cardBorder;
const _pageBg = Color(0xFFF8F9FA);
const _panelGrey = Color(0xFFF3F4F6);
const _dark = Color(0xFF111827);
const _emerald = Color(0xFF10B981);
const _orange = Color(0xFFF59E0B);
const _violet = Color(0xFF8B5CF6);
const _muted = Color(0xFF9CA3AF);

String _money(int minor) => formatInr(minor / 100, decimals: 0);

/// "MAIN COURSE" → "Main Course" (Master stores some categories in caps).
String _titleCase(String s) => s != s.toUpperCase()
    ? s
    : s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
int _priceMinor(MasterDishItem d) => (d.sellingPrice * 100).round();
bool _isVeg(MasterDishItem d) => d.isVeg && !d.isNonVeg;

/// Preferred order for the category chips; others follow alphabetically.
const _categoryOrder = [
  'starters',
  'main course',
  'breads',
  'rice',
  'beverages',
  'desserts'
];

class _CartLine {
  _CartLine(this.dish, this.qty);
  final MasterDishItem dish;
  int qty;
}

class _OpsCaptainOrdersScreenState extends State<OpsCaptainOrdersScreen> {
  late final DriftMasterStore _master =
      widget.master ?? DriftMasterStore(widget.ops.db);
  late final Stream<List<MasterDishItem>> _dishes$ = _master.watchDishes();
  late final Stream<List<OpsTable>> _tables$ = widget.ops.watchTables();
  late final Stream<List<OpsOrder>> _orders$ =
      widget.ops.watchOrders(openOnly: true);

  Timer? _ticker;
  DateTime _now = DateTime.now();

  String _query = '';
  bool _vegOnly = false;
  String? _category;
  bool _categoryInit = false;

  String? _floor;
  String? _tableId;
  int _guests = 2;
  final _cart = <String, _CartLine>{};
  final _notes = TextEditingController();
  final _captain = TextEditingController();

  /// Active staff names for the captain / server picker (loaded once).
  late final Future<List<String>> _staffNames;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final me = widget.ops.actorName.trim();
    _staffNames = loadStaffNames(widget.staff, include: [me]);
    // The signed-in person takes the order unless they pick someone else.
    _captain.text = me;
    _ticker = Timer.periodic(const Duration(seconds: 20),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    _captain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MasterDishItem>>(
      stream: _dishes$,
      builder: (context, dSnap) => StreamBuilder<List<OpsTable>>(
        stream: _tables$,
        builder: (context, tSnap) => StreamBuilder<List<OpsOrder>>(
          stream: _orders$,
          builder: (context, oSnap) {
            final dishes = (dSnap.data ?? const <MasterDishItem>[])
                .where((d) =>
                    d.status == 'Active' && d.availability != 'Unavailable')
                .toList();
            final tables = tSnap.data ?? const <OpsTable>[];
            final orders = {
              for (final o in oSnap.data ?? const <OpsOrder>[]) o.id: o
            };
            // Drop cart lines whose dish disappeared from the menu.
            final ids = {for (final d in dishes) d.id};
            _cart.removeWhere((k, _) => dSnap.hasData && !ids.contains(k));

            return LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 1000;
              final menu = _menuColumn(dishes, dSnap.hasData);
              final side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _floorPlan(tables),
                  const SizedBox(height: 16),
                  _ticket(tables, orders),
                ],
              );
              final header = _header();
              if (narrow) {
                return ColoredBox(
                  color: _pageBg,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [menu, const SizedBox(height: 20), side],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ColoredBox(
                color: _pageBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 24, 8, 24),
                              child: menu,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: c.maxWidth >= 1150 ? 480 : 420,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                              child: side,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
          },
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Captain Order',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: ViniiColors.textPrimaryLight)),
            SizedBox(height: 4),
            Text('Efficient order taking & table management',
                style: TextStyle(fontSize: 14, color: Color(0xFF3A3A40))),
          ],
        ),
      );

  // -------------------------------------------------------------------------
  // Menu
  // -------------------------------------------------------------------------

  List<String> _categories(List<MasterDishItem> dishes) {
    final cats = {for (final d in dishes) d.category}.toList();
    int rank(String c) {
      final i = _categoryOrder.indexOf(c.toLowerCase());
      return i < 0 ? 99 : i;
    }

    cats.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.compareTo(b);
    });
    return cats;
  }

  Widget _menuColumn(List<MasterDishItem> dishes, bool loaded) {
    final cats = _categories(dishes);
    if (!_categoryInit && loaded) {
      _categoryInit = true;
      _category =
          cats.where((c) => c.toLowerCase() == 'main course').firstOrNull;
    }
    if (_category != null && !cats.contains(_category)) _category = null;
    final q = _query.toLowerCase();
    final shown = dishes
        .where((d) =>
            (!_vegOnly || _isVeg(d)) &&
            (_category == null || d.category == _category) &&
            (q.isEmpty ||
                d.name.toLowerCase().contains(q) ||
                d.category.toLowerCase().contains(q)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Icon(Icons.circle_outlined,
                    size: 16, color: Color(0xFF3A3A40)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search for dishes, starters, drinks...',
                      hintStyle:
                          TextStyle(fontSize: 14, color: Color(0xFF3A3A40)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _vegOnly = !_vegOnly),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: _vegOnly ? _emerald : Colors.white,
                        border: Border.all(color: _emerald, width: 1.3),
                        borderRadius: BorderRadius.circular(2)),
                    child: _vegOnly
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  const Text('Veg Only',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ViniiColors.textPrimaryLight)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in cats)
            _Chip(
              label: _titleCase(c),
              selected: c == _category,
              onTap: () =>
                  setState(() => _category = _category == c ? null : c),
            ),
        ]),
        const SizedBox(height: 20),
        if (!loaded)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                  dishes.isEmpty
                      ? 'No active dishes in the Master menu.'
                      : 'No dishes match your filters.',
                  style: MasterStyle.muted),
            ),
          )
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 16.0;
            final cols = (c.maxWidth / 200).floor().clamp(1, 4);
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final d in shown)
                SizedBox(
                  width: w,
                  child: _DishCard(
                    dish: d,
                    inCart: _cart[d.id]?.qty ?? 0,
                    onAdd: () => _add(d),
                  ),
                ),
            ]);
          }),
      ],
    );
  }

  void _add(MasterDishItem d) {
    setState(() {
      final l = _cart[d.id];
      if (l == null) {
        _cart[d.id] = _CartLine(d, 1);
      } else {
        l.qty++;
      }
    });
  }

  // -------------------------------------------------------------------------
  // Floor plan
  // -------------------------------------------------------------------------

  List<String> _floorsOf(List<OpsTable> tables) {
    final used = tables.map((t) => t.floor).toSet();
    return [
      ...DriftOperationsStore.defaultFloors.where(used.contains),
      ...used.where((f) => !DriftOperationsStore.defaultFloors.contains(f)),
    ];
  }

  Widget _floorPlan(List<OpsTable> tables) {
    final floors = _floorsOf(tables);
    if (_floor == null || !floors.contains(_floor)) {
      final sel = tables.where((t) => t.id == _tableId).firstOrNull;
      _floor = sel?.floor ?? (floors.isEmpty ? null : floors.first);
    }
    final onFloor = tables.where((t) => t.floor == _floor).toList();
    int count(bool Function(OpsTable) f) => onFloor.where(f).length;

    return Container(
      decoration: BoxDecoration(
        color: _panelGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Floor Plan',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.textPrimaryLight)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _border)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            for (final f in floors)
                              Material(
                                color: f == _floor ? _lime : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => setState(() => _floor = f),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 5),
                                    child: Text(f,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: f == _floor
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: f == _floor
                                                ? ViniiColors.textPrimaryLight
                                                : const Color(0xFF3A3A40))),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                    'Select a table to view its status and current order context.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF3A3A40))),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 420),
            child: onFloor.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No tables on this floor.',
                        textAlign: TextAlign.center, style: MasterStyle.muted),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(builder: (context, c) {
                      const gap = 12.0;
                      final cols = (c.maxWidth / 100).floor().clamp(2, 4);
                      final w = (c.maxWidth - gap * (cols - 1)) / cols;
                      return Wrap(spacing: gap, runSpacing: gap, children: [
                        for (final t in onFloor)
                          SizedBox(
                            width: w,
                            child: _TableTile(
                              table: t,
                              now: _now,
                              selected: t.id == _tableId,
                              onTap: () => _selectTable(t),
                            ),
                          ),
                      ]);
                    }),
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border))),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Wrap(spacing: 18, runSpacing: 6, children: [
              _legend(_emerald,
                  'Available: ${count((t) => t.status == OpsTableStatus.available)}'),
              _legend(_dark,
                  'Occupied: ${count((t) => t.status == OpsTableStatus.occupied)}'),
              _legend(_orange,
                  'Reserved: ${count((t) => t.status == OpsTableStatus.reserved)}'),
              _legend(_violet,
                  'Billing: ${count((t) => t.status == OpsTableStatus.billing)}'),
              if (count((t) => t.status == OpsTableStatus.cleaning) > 0)
                _legend(_muted,
                    'Cleaning: ${count((t) => t.status == OpsTableStatus.cleaning)}'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A3A40))),
        ],
      );

  void _selectTable(OpsTable t) {
    setState(() {
      if (_tableId == t.id) {
        _tableId = null;
        return;
      }
      _tableId = t.id;
      _guests = t.guests ?? (t.seats < 2 ? t.seats : 2);
      if (t.serverName.isNotEmpty) _captain.text = t.serverName;
    });
  }

  // -------------------------------------------------------------------------
  // Running ticket
  // -------------------------------------------------------------------------

  Widget _ticket(List<OpsTable> tables, Map<String, OpsOrder> orders) {
    final table = tables.where((t) => t.id == _tableId).firstOrNull;
    final order =
        table?.currentOrderId == null ? null : orders[table!.currentOrderId];
    final lines = _cart.values.toList();
    final itemCount = lines.fold<int>(0, (s, l) => s + l.qty);
    final subtotal =
        lines.fold<int>(0, (s, l) => s + _priceMinor(l.dish) * l.qty);
    final seated = table != null &&
        (table.status == OpsTableStatus.occupied ||
            table.status == OpsTableStatus.billing);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  table == null
                      ? 'Order Ticket'
                      : 'Order Ticket · ${table.label}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ViniiColors.textPrimaryLight)),
            ),
            if (lines.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final yes = await confirmMasterAction(context,
                      title: 'Clear ticket?',
                      message:
                          'Remove all $itemCount items from the ticket? Nothing has been sent to the kitchen yet.',
                      confirmLabel: 'Clear');
                  if (yes && mounted) setState(_cart.clear);
                },
                child: const Text('Clear',
                    style: TextStyle(color: ViniiColors.redSolid)),
              ),
          ]),
          const SizedBox(height: 10),
          if (table == null)
            _hint('Select a table on the floor plan to take its order.')
          else ...[
            Row(children: [
              Expanded(
                child: Text(
                    '${table.status.label} · ${table.seats} seats${table.seatedAt != null ? ' · ${table.elapsedMinutes(_now)}m' : ''}',
                    style: MasterStyle.muted.copyWith(fontSize: 12.5)),
              ),
              if (!seated) ...[
                const Text('Guests',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF3A3A40))),
                const SizedBox(width: 8),
                _QtyStepper(
                  value: _guests,
                  onMinus: _guests > 1 ? () => setState(() => _guests--) : null,
                  onPlus: () => setState(() => _guests++),
                ),
              ] else
                Text('${table.guests ?? '—'} guests',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
            if (!seated && _guests > table.seats)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${table.label} seats ${table.seats} — reduce guests or pick a bigger table.',
                    style: const TextStyle(
                        fontSize: 11.5, color: ViniiColors.redSolid)),
              ),
            if (order != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _panelGrey, borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        'Running order ${order.number} · ${order.itemCount} items · ${_money(order.grandTotalMinor)}${order.billNo != null ? ' · Bill #${order.billNo}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF3A3A40))),
                  ),
                  const SizedBox(width: 8),
                  _smallButton('Open Bill', () => _openBill(order.id)),
                ]),
              ),
            ],
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          if (lines.isEmpty)
            _hint('Tap + on a dish to add it to the ticket.')
          else
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  _VegBox(veg: _isVeg(l.dish)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.dish.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(_money(_priceMinor(l.dish)),
                            style: MasterStyle.muted),
                      ],
                    ),
                  ),
                  _QtyStepper(
                    value: l.qty,
                    onMinus: () => setState(() {
                      if (--l.qty <= 0) _cart.remove(l.dish.id);
                    }),
                    onPlus: () => setState(() => l.qty++),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(_money(_priceMinor(l.dish) * l.qty),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              // Picked from the staff list (+ "Other…"); without one,
              // typed with the names already used here suggested.
              child: PersonPickerField(
                controller: _captain,
                namesFuture: _staffNames,
                suggestions: distinctNames([
                  for (final t in tables) t.serverName,
                  for (final o in orders.values) o.serverName,
                  widget.ops.actorName,
                ]),
                // Labelled: the field starts filled with the signed-in
                // person, so a hint alone would not say what it is.
                decoration: _decoration('Captain / server').copyWith(
                    labelText: 'Captain / server',
                    labelStyle:
                        const TextStyle(fontSize: 12.5, color: _muted)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _notes,
                style: const TextStyle(fontSize: 13),
                decoration: _decoration('Kitchen notes (e.g. less spicy)'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Text('$itemCount items',
                style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A40))),
            const Spacer(),
            const Text('Subtotal  ',
                style: TextStyle(fontSize: 13, color: Color(0xFF3A3A40))),
            Text(_money(subtotal),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: ViniiColors.textPrimaryLight,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              onPressed: _sending ? null : () => _sendKot(table, lines),
              icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
              label: const Text('Send to Kitchen (KOT)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: ViniiColors.textPrimaryLight,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              onPressed: () {
                if (table == null) {
                  showMasterError(context, 'Select a table first.');
                } else if (order == null) {
                  showMasterError(context,
                      '${table.label} has no open order yet — send a KOT first.');
                } else {
                  _openBill(order.id);
                }
              },
              child: const Text('Open Bill',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(s, style: MasterStyle.muted.copyWith(fontSize: 12.5)),
      );

  Widget _smallButton(String label, VoidCallback onTap) => SizedBox(
        height: 30,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: ViniiColors.textPrimaryLight,
              side: const BorderSide(color: _border),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4))),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  void _openBill(String orderId) {
    final cb = widget.onOpenBilling;
    if (cb == null) {
      showMasterNotice(context, 'POS Billing is not available here.');
    } else {
      cb(orderId);
    }
  }

  Future<void> _sendKot(OpsTable? table, List<_CartLine> lines) async {
    if (table == null) {
      showMasterError(context, 'Select a table on the floor plan first.');
      return;
    }
    if (lines.isEmpty) {
      showMasterError(context, 'Add at least one dish to the ticket.');
      return;
    }
    if (table.status == OpsTableStatus.cleaning) {
      showMasterError(context,
          '${table.label} is being cleaned — mark it available in Dine In first.');
      return;
    }
    final seated = table.status == OpsTableStatus.occupied ||
        table.status == OpsTableStatus.billing;
    if (!seated && _guests > table.seats) {
      showMasterError(context, '${table.label} seats only ${table.seats}.');
      return;
    }
    setState(() => _sending = true);
    final sent = [for (final l in lines) (l.dish.name, l.qty)];
    String? orderId;
    final ok = await runMasterAction(context, () async {
      orderId = await widget.ops.placeOrder(
        channel: OpsChannel.dineIn,
        tableId: table.id,
        guests: seated ? null : _guests,
        serverName: _captain.text.trim(),
        source: 'Captain',
        notes: _notes.text.trim(),
        lines: [
          for (final l in lines)
            OpsOrderLine(
              itemId: l.dish.id,
              name: l.dish.name,
              unitMinor: _priceMinor(l.dish),
              quantity: l.qty,
              station: stationForDish(l.dish.category, l.dish.kitchenStation),
              isVeg: _isVeg(l.dish),
            ),
        ],
      );
    });
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _cart.clear();
        _notes.clear();
      }
    });
    if (!ok || orderId == null) return;
    final id = orderId!;
    // The order number people read ("ORD-248"); the id is only for
    // opening the bill.
    var number = orderNumberLabel(id, null);
    try {
      final placed = await widget.ops.getOrder(id);
      if (placed != null) number = placed.number;
    } catch (_) {
      // Keep the short reference — the order itself was placed.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: ViniiColors.greenSolid),
        title: const Text('KOT sent to kitchen'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${table.label} · $number',
                  style: MasterStyle.value, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              for (final (name, q) in sent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${q}x $name', style: MasterStyle.body),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openBill(id);
              },
              child: const Text('Open Bill')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: ViniiColors.textPrimaryLight),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: _muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border)),
    );

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _lime : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6.5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? _lime : _border)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? ViniiColors.textPrimaryLight
                        : const Color(0xFF3A3A40))),
          ),
        ),
      );
}

class _VegBox extends StatelessWidget {
  const _VegBox({required this.veg, this.size = 14});
  final bool veg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
              color: veg ? const Color(0xFF34D399) : const Color(0xFFF87171),
              width: 1.4),
        ),
      );
}

class _DishCard extends StatelessWidget {
  const _DishCard(
      {required this.dish, required this.inCart, required this.onAdd});
  final MasterDishItem dish;
  final int inCart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final desc = dish.details['description'];
    final subtitle = desc is String && desc.trim().isNotEmpty
        ? desc.trim()
        : 'Classic Preparation';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inCart > 0 ? _lime : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _VegBox(veg: _isVeg(dish), size: 16),
            const Spacer(),
            Text(_money(_priceMinor(dish)),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
          ]),
          const SizedBox(height: 12),
          Text(dish.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _muted)),
            ),
            if (inCart > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('×$inCart',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.greenSolid)),
              ),
            Tooltip(
              message: 'Add ${dish.name}',
              child: Material(
                color: _lime,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onAdd,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.add, size: 18, color: Colors.black),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile(
      {required this.table,
      required this.now,
      required this.selected,
      required this.onTap});
  final OpsTable table;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = table;
    final occupied = t.status == OpsTableStatus.occupied;
    final (bg, border, fg, sub) = switch (t.status) {
      OpsTableStatus.occupied => (_dark, _dark, Colors.white, _muted),
      OpsTableStatus.reserved => (
          Colors.white,
          _orange,
          ViniiColors.textPrimaryLight,
          const Color(0xFF6B7280)
        ),
      OpsTableStatus.available => (
          Colors.white,
          _emerald,
          ViniiColors.textPrimaryLight,
          const Color(0xFF6B7280)
        ),
      OpsTableStatus.billing => (
          Colors.white,
          _violet,
          ViniiColors.textPrimaryLight,
          const Color(0xFF6B7280)
        ),
      OpsTableStatus.cleaning => (
          const Color(0xFFF9FAFB),
          const Color(0xFFD1D5DB),
          const Color(0xFF6B7280),
          _muted
        ),
    };
    final status = switch (t.status) {
      OpsTableStatus.billing => 'Billing',
      _ => t.status.label,
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 96,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: selected ? const Color(0xFF16A34A) : border,
                width: selected ? 2.5 : 1),
            boxShadow: selected
                ? const [
                    BoxShadow(
                        color: Color(0x3316A34A),
                        blurRadius: 8,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(t.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                ),
                Icon(Icons.people_outline, size: 14, color: sub),
                const SizedBox(width: 4),
                Text('${t.seats}', style: TextStyle(fontSize: 12, color: sub)),
              ]),
              const SizedBox(height: 6),
              if (occupied) ...[
                _iconLine(
                    Icons.people_outline, '${t.guests ?? '—'} guests', sub),
                const SizedBox(height: 4),
                _iconLine(
                    Icons.schedule,
                    t.seatedAt == null ? '—' : '${t.elapsedMinutes(now)}m',
                    sub),
              ] else
                Text(status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: sub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconLine(IconData i, String s, Color c) => Row(children: [
        Icon(i, size: 14, color: c),
        const SizedBox(width: 6),
        Flexible(
          child: Text(s,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c)),
        ),
      ]);
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper(
      {required this.value, required this.onMinus, required this.onPlus});
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? f) => InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(4)),
            child: Icon(i,
                size: 13,
                color: f == null ? _muted : ViniiColors.textPrimaryLight),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, onMinus),
      SizedBox(
        width: 28,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      btn(Icons.add, onPlus),
    ]);
  }
}
