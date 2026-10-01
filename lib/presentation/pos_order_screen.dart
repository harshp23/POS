// Rebuilt 1:1 from v1/POS-MAIN-DEFAULT.png and v1/POS-MAIN-V3.png
// (light/dark pair) — see Q02 in docs/DECISIONS-AND-QUESTIONS.txt.
//
// The POS order screen works on the same orders / KOT / payments / tables
// rows as Operations, through DriftOperationsStore:
//  * Opening a table that already has an open order loads that order —
//    new items are added to it and only they go to the kitchen.
//  * "Send KOT" saves the order (or the new items) and sends them to the
//    kitchen; a dine-in table becomes occupied by the order.
//  * "Save & Hold" saves without a KOT. Held orders are listed on the POS
//    home panel / Takeaway queue and resume here ([resumeOrderId]).
//  * "Proceed to Pay" sends anything unsent to the kitchen, then opens the
//    cash Payment screen for the order.
//  * People see the order's number (OpsOrder.number): the server's
//    "ORD-248" once synced, else this device's own key. The id is only
//    used to look the order up.

import 'dart:async';

import 'package:flutter/material.dart';

import '../application/kitchen_service.dart';
import '../application/order_service.dart';
import '../application/payment_service.dart';
import '../data/app_database.dart';
import '../data/drift_all_orders_store.dart';
import '../data/drift_menu_store.dart';
import '../data/drift_operations_store.dart';
import '../data/drift_table_store.dart';
import '../domain/menu.dart';
import '../domain/operations.dart';
import '../domain/restaurant_table.dart';
import 'operations/ops_order_dialogs.dart';
import 'operations/ops_pickers.dart';
import 'payment_screen.dart';
import 'vinii_theme.dart';

class PosOrderScreen extends StatefulWidget {
  const PosOrderScreen(
      {super.key,
      this.orderService,
      this.kitchenService,
      this.paymentService,
      required this.locationId,
      this.allOrdersStore,
      this.tableStore,
      this.menuStore,
      this.table,
      this.opsStore,
      this.resumeOrderId,
      this.channel,
      this.canTakePayments = true});

  /// Legacy POS services. The order flow now runs through [opsStore] (the
  /// same order lifecycle Operations uses); these are accepted so existing
  /// callers keep compiling, and are not used.
  final OrderService? orderService;
  final KitchenService? kitchenService;
  final PaymentService? paymentService;
  final DriftAllOrdersStore? allOrdersStore;
  final DriftTableStore? tableStore;
  final DriftMenuStore? menuStore;
  final String locationId;

  /// Arrived here from a Tables / Dine In card — dine-in at this table. If
  /// the table has an open order, that order is loaded.
  final RestaurantTable? table;

  /// The Operations store. When null it is built on the database of the
  /// table / All Orders / menu store passed in.
  final DriftOperationsStore? opsStore;

  /// Resume this order (a held order, or any open order).
  final String? resumeOrderId;

  /// Start a new order of this channel (e.g. delivery from the Delivery
  /// screen). Defaults to dine-in with a [table], else takeaway.
  final OpsChannel? channel;

  /// The signed-in role may collect money (cashier, owners, managers).
  /// Captains and waiters take orders only: the payment actions are hidden
  /// and the server refuses them as well.
  final bool canTakePayments;

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  final _cart = <String, int>{}; // itemId -> quantity (not saved yet)
  final Map<String, MenuItem> _knownItems = {};
  final Map<String, String> _categoryNames = {};
  String _categoryId = 'all';
  String _searchQuery = '';
  late OpsChannel _channel;
  String? _tableId;
  List<OpsTable> _tables = const [];
  bool _saving = false;
  Stream<List<MenuCategory>>? _categoriesStream;
  Stream<List<MenuItem>>? _itemsStream;
  DriftOperationsStore? _ops;
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<OpsOrder?>? _orderSub;

  /// The saved order this screen is adding to (null = new order).
  String? _orderId;
  OpsOrder? _order;
  bool _resolving = true;

  final _customer = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _channel = widget.channel ??
        (widget.table != null ? OpsChannel.dineIn : OpsChannel.takeaway);
    _initStreams();
    final AppDatabase? db = widget.opsStore?.db ??
        widget.tableStore?.db ??
        widget.allOrdersStore?.db ??
        widget.menuStore?.db;
    _ops = widget.opsStore ?? (db == null ? null : DriftOperationsStore(db));
    final ops = _ops;
    if (ops == null) {
      _resolving = false;
      return;
    }
    _subs.add(ops.watchTables().listen((t) {
      if (mounted) setState(() => _tables = t);
    }));
    unawaited(_resolveStart(ops));
  }

  /// Loads the order to resume, or the open order of the table opened.
  Future<void> _resolveStart(DriftOperationsStore ops) async {
    // Leave initState first — _bind calls setState.
    await Future<void>.value();
    if (!mounted) return;
    try {
      final resume = widget.resumeOrderId;
      if (resume != null) {
        _bind(resume);
        return;
      }
      final t = widget.table;
      if (t != null) {
        final table = await ops.getTable(t.id) ??
            (await ops.getTables())
                .where((x) => x.label == t.label)
                .firstOrNull;
        if (!mounted) return;
        if (table != null) {
          setState(() => _tableId = table.id);
          final current = table.currentOrderId;
          if (current != null) {
            final o = await ops.getOrder(current);
            if (o != null && o.isActive && mounted) {
              _bind(current);
              return;
            }
          }
        }
      }
    } finally {
      if (mounted && _orderId == null) setState(() => _resolving = false);
    }
  }

  void _bind(String orderId) {
    final ops = _ops;
    if (ops == null) return;
    _orderSub?.cancel();
    setState(() {
      _orderId = orderId;
      _resolving = true;
    });
    _orderSub = ops.watchOrder(orderId).listen((o) {
      if (!mounted) return;
      setState(() {
        _order = o;
        _resolving = false;
        if (o != null) {
          _channel = o.channel;
          if (o.tableLabel != null) {
            _tableId =
                _tables.where((t) => t.label == o.tableLabel).firstOrNull?.id ??
                    _tableId;
          }
          if (_customer.text.isEmpty) _customer.text = o.customerName;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant PosOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuStore != widget.menuStore) {
      _initStreams();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _orderSub?.cancel();
    _customer.dispose();
    _address.dispose();
    super.dispose();
  }

  void _initStreams() {
    _categoriesStream =
        widget.menuStore?.watchCategories() ?? Stream.value(const []);
    _itemsStream = widget.menuStore?.watchItems() ?? Stream.value(const []);
  }

  bool get _isExisting => _orderId != null;

  /// The order is open for new items (not billed / paid / cancelled).
  bool get _canAddItems =>
      !_isExisting || _order?.status == OpsOrderStatus.open;

  OpsTable? get _table => _tables.where((t) => t.id == _tableId).firstOrNull;

  /// Totals of the saved order plus the unsaved items, with the order's
  /// discount and GST % (5% for a new order — the stored default).
  OpsOrder get _preview {
    final o = _order;
    final lines = <String, OpsOrderLine>{
      for (final l in o?.lines ?? const <OpsOrderLine>[]) l.itemId: l
    };
    for (final l in _cartLines()) {
      final prev = lines[l.itemId];
      lines[l.itemId] = prev == null
          ? l
          : prev.copyWith(quantity: prev.quantity + l.quantity);
    }
    return OpsOrder(
        id: o?.id ?? 'NEW',
        channel: _channel,
        status: OpsOrderStatus.open,
        createdAt: o?.createdAt ?? DateTime.now(),
        lines: lines.values.toList(),
        discountPct: o?.discountPct ?? 0,
        taxPct: o?.taxPct ?? 5);
  }

  void _addItem(MenuItem item) {
    if (!item.available) return;
    if (!_canAddItems) {
      final o = _order;
      _warn(o == null
          ? 'This order takes no new items.'
          : '${o.number} is ${o.status.label.toLowerCase()} — it takes no '
              'new items.');
      return;
    }
    _knownItems[item.id] = item;
    setState(() => _cart.update(item.id, (q) => q + 1, ifAbsent: () => 1));
  }

  void _removeItem(MenuItem item) => setState(() {
        final q = _cart[item.id];
        if (q == null) return;
        if (q <= 1) {
          _cart.remove(item.id);
        } else {
          _cart[item.id] = q - 1;
        }
      });

  /// Cart lines for the items the menu still has. An item that is not
  /// loaded from the menu is never saved (it would have no name or
  /// price) — see [_unknownCartItems].
  List<OpsOrderLine> _cartLines() => [
        for (final e in _cart.entries)
          if (_knownItems[e.key] case final item?)
            OpsOrderLine(
                itemId: e.key,
                name: item.name,
                unitMinor: item.priceMinor,
                quantity: e.value,
                station:
                    stationForDish(_categoryNames[item.categoryId] ?? '', ''),
                isVeg: item.isVeg),
      ];

  /// Items in the cart that are not on the loaded menu (removed from the
  /// menu since they were added).
  int get _unknownCartItems =>
      _cart.keys.where((k) => !_knownItems.containsKey(k)).length;

  /// The order's number for messages ("ORD-248"), never its database id.
  /// An order saved a moment ago has no server number yet, so its device
  /// key is its number until sync.
  String _numberOf(String id) {
    final loaded = _order;
    if (loaded != null && loaded.id == id) return loaded.number;
    return orderNumberLabel(id, null);
  }

  void _warn(String message, {Color color = Colors.orange}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3)));
  }

  /// Checks what a new order needs before it can be saved.
  String? _newOrderProblem() {
    if (_cart.isEmpty) {
      return 'Warning: No items added. Please add items to the order before saving.';
    }
    if (_channel == OpsChannel.dineIn && _tableId == null) {
      return 'Warning: Please select a table for Dine In orders.';
    }
    if (_channel == OpsChannel.delivery &&
        (_customer.text.trim().isEmpty || _address.text.trim().isEmpty)) {
      return 'Warning: Enter the customer name and delivery address.';
    }
    return null;
  }

  /// Saves the cart: a new order, or new items on the loaded order. With
  /// [sendToKitchen] the items go to the kitchen (and a held order gets
  /// its first KOT). Returns the order id, or null when nothing was saved.
  Future<String?> _save({required bool sendToKitchen}) async {
    final ops = _ops;
    if (ops == null) {
      _warn('No order store is connected to this screen.',
          color: ViniiColors.redSolid);
      return null;
    }
    if (_unknownCartItems > 0) {
      _warn(
          'Some items in this order are no longer on the menu — remove them '
          'and add them again from the menu.',
          color: ViniiColors.redSolid);
      return null;
    }
    setState(() => _saving = true);
    try {
      final lines = _cartLines();
      String id;
      if (_orderId == null) {
        id = await ops
            .placeOrder(
                channel: _channel,
                lines: lines,
                tableId: _channel == OpsChannel.dineIn ? _tableId : null,
                guests: widget.table?.guestCount,
                source: 'POS',
                customerName: _customer.text.trim(),
                sendToKitchen: sendToKitchen)
            // A local-database write should never take long; if the
            // platform's storage backend is stuck (e.g. a web build whose
            // WASM/OPFS worker never resolves — see docs/JOURNAL.md), a
            // silent infinite "Saving..." spinner is worse than a clear
            // failure the user can retry.
            .timeout(const Duration(seconds: 8));
        if (_channel == OpsChannel.delivery) {
          final now = DateTime.now();
          await ops.upsertDelivery(OpsDelivery(
              id: await ops.nextDeliveryId(),
              orderId: id,
              merchant: 'Restaurant',
              status: DeliveryStatus.unassigned,
              createdAt: now,
              updatedAt: now,
              customerName: _customer.text.trim(),
              address: _address.text.trim()));
        }
      } else {
        id = _orderId!;
        final o = _order ?? await ops.getOrder(id);
        if (lines.isNotEmpty) {
          await ops
              .addLines(id, lines, sendToKitchen: sendToKitchen)
              .timeout(const Duration(seconds: 8));
        } else if (sendToKitchen && o != null && !o.sentToKitchen) {
          await ops.sendKot(id).timeout(const Duration(seconds: 8));
        }
        if (_customer.text.trim() != (o?.customerName ?? '')) {
          await ops.setCustomerName(id, _customer.text);
        }
      }
      if (!mounted) return id;
      setState(_cart.clear);
      if (_orderId == null) _bind(id);
      return id;
    } catch (e) {
      if (mounted) {
        _warn(
            e is TimeoutException
                ? 'Saving is taking too long — the local database may be unavailable. Please try again.'
                : 'Could not save the order: ${friendlyError(e)}',
            color: ViniiColors.redSolid);
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendKot() async {
    if (_orderId == null) {
      final problem = _newOrderProblem();
      if (problem != null) return _warn(problem);
    } else if (_cart.isEmpty && (_order?.sentToKitchen ?? true)) {
      return _warn('Add items to send a new KOT.');
    }
    final id = await _save(sendToKitchen: true);
    if (id == null || !mounted) return;
    final number = _numberOf(id);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KOT for $number sent to kitchen.')));
  }

  Future<void> _saveAndHold() async {
    if (_orderId != null && (_order?.sentToKitchen ?? false)) {
      return _warn('${_order!.number} is already in the kitchen — use Send '
          'KOT for new items.');
    }
    if (_orderId == null) {
      final problem = _newOrderProblem();
      if (problem != null) return _warn(problem);
    } else if (_cart.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final id = await _save(sendToKitchen: false);
    if (id == null || !mounted) return;
    final number = _numberOf(id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text('Order $number saved on hold'
          '${_table != null && _channel == OpsChannel.dineIn ? ' for ${_table!.label}' : ''} '
          '— resume it from Held orders.'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _proceedToPay() async {
    String? id = _orderId;
    if (_orderId == null) {
      final problem = _newOrderProblem();
      if (problem != null) return _warn(problem);
    }
    final o = _order;
    if (_cart.isNotEmpty || (o != null && !o.sentToKitchen)) {
      id = await _save(sendToKitchen: true);
    }
    if (id == null || !mounted) return;
    final ops = _ops!;
    final completed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaymentScreen(ops: ops, orderId: id!)));
    if (completed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _changeSavedQty(OpsOrderLine l, int qty) async {
    final ops = _ops;
    final o = _order;
    if (ops == null || o == null) return;
    String reason = '';
    if (qty < l.quantity && o.sentToKitchen) {
      final r = await showReasonDialog(context,
          title: qty <= 0 ? 'Void ${l.name}?' : 'Reduce ${l.name}?',
          message: '${l.name} was already sent to the kitchen. This change is '
              'recorded in the order history.',
          confirm: qty <= 0 ? 'Void Item' : 'Reduce',
          suggestions: const ['Guest changed mind', 'Wrong item']);
      if (r == null || !mounted) return;
      reason = r;
    }
    try {
      await ops.setLineQuantity(o.id, l.itemId, qty, reason: reason);
    } catch (e) {
      if (mounted) _warn(friendlyError(e), color: ViniiColors.redSolid);
    }
  }

  Future<void> _cancelOrder() async {
    final ops = _ops;
    final o = _order;
    if (ops == null || o == null) return;
    final reason = await showReasonDialog(context,
        title: 'Cancel ${o.number}?',
        message: 'The order is cancelled'
            '${o.sentToKitchen ? ' and the kitchen sees it as "Order cancelled"' : ''}'
            '${o.tableLabel != null ? '; ${o.tableLabel} is released for cleaning' : ''}. '
            'This is recorded in the order history.',
        confirm: 'Cancel Order',
        suggestions: const ['Guest left', 'Duplicate order']);
    if (reason == null || !mounted) return;
    try {
      await ops.cancelOrder(o.id, reason: reason);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
          .showSnackBar(SnackBar(content: Text('${o.number} cancelled.')));
    } catch (e) {
      if (mounted) _warn(friendlyError(e), color: ViniiColors.redSolid);
    }
  }

  String get _title {
    final o = _order;
    if (o != null) {
      return '${o.number} — ${o.displayName}'
          '${o.isHeld ? ' (held)' : ''}';
    }
    final label = _table?.label ?? widget.table?.label;
    return label != null && _channel == OpsChannel.dineIn
        ? '$label — New Order'
        : 'New ${_channel == OpsChannel.dineIn ? '' : '${_channel.label} '}Order';
  }

  /// Tables a new dine-in order may take: available ones, plus the table
  /// already chosen.
  List<OpsTable> get _pickableTables => [
        for (final t in _tables)
          if ((t.status == OpsTableStatus.available &&
                  t.currentOrderId == null) ||
              t.id == _tableId)
            t
      ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MenuCategory>>(
      stream: _categoriesStream,
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        for (final c in categories) {
          _categoryNames[c.id] = c.name;
        }
        return StreamBuilder<List<MenuItem>>(
          stream: _itemsStream,
          builder: (context, itemSnapshot) {
            final allItems = itemSnapshot.data ?? [];
            for (final i in allItems) {
              _knownItems[i.id] = i;
            }

            final itemsCountPerCategory = <String, int>{};
            for (final item in allItems) {
              itemsCountPerCategory[item.categoryId] =
                  (itemsCountPerCategory[item.categoryId] ?? 0) + 1;
            }

            final categoriesWithCounts = categories
                .map((c) =>
                    c.copyWith(itemCount: itemsCountPerCategory[c.id] ?? 0))
                .toList();

            final effectiveCategoryId = (_categoryId == 'all' ||
                    categories.any((c) => c.id == _categoryId))
                ? _categoryId
                : 'all';

            final selectedCategoryName = effectiveCategoryId == 'all'
                ? 'All Items'
                : (categories
                        .where((c) => c.id == effectiveCategoryId)
                        .map((c) => c.name)
                        .firstOrNull ??
                    'Category');

            final filteredItems = allItems.where((i) {
              final matchesCategory = effectiveCategoryId == 'all' ||
                  i.categoryId == effectiveCategoryId;
              final matchesSearch = _searchQuery.isEmpty ||
                  i.name.toLowerCase().contains(_searchQuery);
              return matchesCategory && matchesSearch;
            }).toList();

            final preview = _preview;
            final fixedChannel = _isExisting || widget.table != null;
            return Scaffold(
              appBar: AppBar(title: Text(_title), actions: [
                if (_order != null)
                  TextButton.icon(
                      onPressed: () => showBillPreview(context,
                          ops: _ops!,
                          orderId: _order!.id,
                          actorName: _ops!.actorName),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('View Bill')),
                if (_order != null &&
                    _order!.status == OpsOrderStatus.open &&
                    _order!.payment == null)
                  TextButton.icon(
                      onPressed: _saving ? null : _cancelOrder,
                      style: TextButton.styleFrom(
                          foregroundColor: ViniiColors.redSolid),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Order')),
              ]),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CategorySidebar(
                    categories: categoriesWithCounts,
                    totalItemsCount: allItems.length,
                    selected: effectiveCategoryId,
                    onSelect: (id) => setState(() => _categoryId = id),
                  ),
                  Expanded(
                    flex: 3,
                    child: _ItemGrid(
                      categoryName: selectedCategoryName,
                      items: filteredItems,
                      hasCategories: categories.isNotEmpty,
                      searchQuery: _searchQuery,
                      onSearchChanged: (q) =>
                          setState(() => _searchQuery = q.trim().toLowerCase()),
                      onTap: _addItem,
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: _OrderPanel(
                      fixedTableLabel: widget.table != null || _isExisting
                          ? (_order?.tableLabel ??
                              _table?.label ??
                              widget.table?.label)
                          : null,
                      guestCount: widget.table?.guestCount ?? _order?.guests,
                      selectedTableId: _tableId,
                      pickableTables: _pickableTables,
                      onTableChanged: (id) => setState(() => _tableId = id),
                      channel: _channel,
                      onChannelChanged: fixedChannel
                          ? null
                          : (c) => setState(() => _channel = c),
                      customer: _customer,
                      address: _address,
                      order: _order,
                      resolving: _resolving && _isExisting,
                      onSavedQty: _changeSavedQty,
                      cart: _cart,
                      knownItems: _knownItems,
                      preview: preview,
                      onRemove: _removeItem,
                      onAdd: _addItem,
                      saving: _saving,
                      canAddItems: _canAddItems,
                      canTakePayments: widget.canTakePayments,
                      onProceedToPay: _saving ? null : _proceedToPay,
                      onSendKot: _sendKot,
                      onSaveHold: _saveAndHold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel(
      {required this.fixedTableLabel,
      required this.guestCount,
      required this.selectedTableId,
      required this.pickableTables,
      required this.onTableChanged,
      required this.channel,
      required this.onChannelChanged,
      required this.customer,
      required this.address,
      required this.order,
      required this.resolving,
      required this.onSavedQty,
      required this.cart,
      required this.knownItems,
      required this.preview,
      required this.onRemove,
      required this.onAdd,
      required this.saving,
      required this.canAddItems,
      required this.canTakePayments,
      required this.onProceedToPay,
      required this.onSendKot,
      required this.onSaveHold});

  final String? fixedTableLabel;
  final int? guestCount;
  final String? selectedTableId;
  final List<OpsTable> pickableTables;
  final ValueChanged<String?> onTableChanged;
  final OpsChannel channel;
  final ValueChanged<OpsChannel>? onChannelChanged;
  final TextEditingController customer, address;

  /// The saved order being added to, null for a new order.
  final OpsOrder? order;
  final bool resolving;
  final Future<void> Function(OpsOrderLine line, int qty) onSavedQty;
  final Map<String, int> cart;
  final Map<String, MenuItem> knownItems;

  /// Saved + unsaved items with the order's discount and tax.
  final OpsOrder preview;
  final void Function(MenuItem) onRemove, onAdd;
  final bool saving;
  final bool canAddItems;
  final bool canTakePayments;
  final VoidCallback? onProceedToPay;
  final VoidCallback onSendKot, onSaveHold;

  String _pct(double p) =>
      p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final o = order;
    final paymentRecorded = o?.payment != null;
    final hasSaved = o != null && o.lines.isNotEmpty;
    final canPay = !saving &&
        !paymentRecorded &&
        (cart.isNotEmpty || hasSaved) &&
        (o == null || o.isActive);
    final canSend = !saving &&
        canAddItems &&
        (cart.isNotEmpty || (o != null && o.isHeld && o.lines.isNotEmpty));
    final holdAllowed = !saving && (o == null || o.isHeld);
    return DecoratedBox(
      decoration: BoxDecoration(
          border:
              Border(left: BorderSide(color: Theme.of(context).dividerColor))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o == null ? 'Current Order' : 'Order ${o.number}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (c, label) in const [
              (OpsChannel.dineIn, 'Dine In'),
              (OpsChannel.takeaway, 'Takeaway'),
              (OpsChannel.delivery, 'Delivery'),
            ])
              _OrderTypePill(
                  label: label,
                  selected: channel == c,
                  onTap: onChannelChanged == null
                      ? null
                      : () => onChannelChanged!(c)),
          ]),
          if (channel == OpsChannel.dineIn) ...[
            const SizedBox(height: 8),
            if (fixedTableLabel != null)
              Text(
                  '$fixedTableLabel${guestCount != null ? '  ·  $guestCount Guests' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600))
            else if (pickableTables.isEmpty)
              const Text('No available tables right now',
                  style: TextStyle(fontSize: 12, color: Colors.orange))
            else
              DropdownButtonFormField<String>(
                initialValue: selectedTableId,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Table',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                hint:
                    const Text('Choose table', style: TextStyle(fontSize: 13)),
                items: [
                  for (final t in pickableTables)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.label} (${t.seats} seats · ${t.floor})',
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: onTableChanged,
              ),
          ] else ...[
            const SizedBox(height: 8),
            TextField(
              controller: customer,
              decoration: InputDecoration(
                  isDense: true,
                  labelText: channel == OpsChannel.delivery
                      ? 'Customer name'
                      : 'Customer name (optional)',
                  border: const OutlineInputBorder()),
            ),
            if (channel == OpsChannel.delivery && o == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: address,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Delivery address',
                    border: OutlineInputBorder()),
              ),
            ],
          ],
          if (o != null) ...[
            const SizedBox(height: 8),
            Text(
                '${o.kitchenState.label} · ${o.paymentLabel}'
                '${o.billNo != null ? ' · Bill #${o.billNo}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (!o.isActive || o.status == OpsOrderStatus.billed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    switch (o.status) {
                      OpsOrderStatus.billed => paymentRecorded
                          ? 'Payment recorded — pending verification.'
                          : 'Bill generated — items are locked.',
                      OpsOrderStatus.settled =>
                        'This order is paid and closed.',
                      OpsOrderStatus.cancelled => 'This order was cancelled.',
                      OpsOrderStatus.open => '',
                    },
                    style: const TextStyle(
                        fontSize: 12,
                        color: ViniiColors.amberSolid,
                        fontWeight: FontWeight.w600)),
              ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: resolving
                ? const Center(child: CircularProgressIndicator())
                : (cart.isEmpty && !hasSaved)
                    ? const Center(
                        child: Text('No items yet — tap a menu item to add it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)))
                    : ListView(
                        children: [
                          if (hasSaved) ...[
                            Text(
                                o.sentToKitchen
                                    ? 'SENT TO KITCHEN'
                                    : 'SAVED (NOT SENT)',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    letterSpacing: 1)),
                            for (final l in o.lines)
                              _SavedLineTile(
                                  line: l,
                                  editable: o.status == OpsOrderStatus.open &&
                                      !saving,
                                  onChange: (q) => onSavedQty(l, q)),
                            const SizedBox(height: 8),
                          ],
                          if (cart.isNotEmpty && hasSaved)
                            const Text('NEW ITEMS',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    letterSpacing: 1)),
                          for (final entry in cart.entries)
                            _OrderLineTile(
                              item: knownItems[entry.key] ??
                                  MenuItem(
                                    id: entry.key,
                                    categoryId: '',
                                    name: 'No longer on the menu — remove it',
                                    priceMinor: 0,
                                    isVeg: true,
                                  ),
                              quantity: entry.value,
                              onAdd: onAdd,
                              onRemove: onRemove,
                            ),
                        ],
                      ),
          ),
          const Divider(),
          _TotalsRow(label: 'Subtotal', valueMinor: preview.subtotalMinor),
          if (preview.discountMinor > 0)
            _TotalsRow(
                label: 'Discount (${_pct(preview.discountPct)}%)',
                valueMinor: -preview.discountMinor),
          _TotalsRow(
              label: 'Tax (GST ${_pct(preview.taxPct)}%)',
              valueMinor: preview.taxMinor),
          const Divider(),
          _TotalsRow(
              label: 'TOTAL', valueMinor: preview.grandTotalMinor, bold: true),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  key: const Key('pos-proceed-to-pay'),
                  onPressed:
                      canPay && canTakePayments ? onProceedToPay : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: ViniiColors.brandGreen),
                  child: Text(
                      canTakePayments
                          ? 'Proceed to Pay'
                          : 'Payment is taken by the cashier',
                      style: const TextStyle(color: Colors.black)))),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: canSend ? onSendKot : null,
                  child: Text(saving ? 'Saving…' : 'Send KOT'))),
          const SizedBox(height: 8),
          Center(
              child: Tooltip(
            message: holdAllowed
                ? 'Save without sending to the kitchen'
                : 'Already in the kitchen — use Send KOT',
            child: TextButton(
                onPressed: holdAllowed ? onSaveHold : null,
                child: const Text('Save & Hold')),
          )),
        ]),
      ),
    );
  }
}

class _SavedLineTile extends StatelessWidget {
  const _SavedLineTile(
      {required this.line, required this.editable, required this.onChange});
  final OpsOrderLine line;
  final bool editable;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87))),
          IconButton(
              iconSize: 18,
              tooltip: 'Reduce / void',
              icon: const Icon(Icons.remove),
              onPressed: editable ? () => onChange(line.quantity - 1) : null),
          Text('${line.quantity}'),
          IconButton(
              iconSize: 18,
              tooltip: 'Add one more',
              icon: const Icon(Icons.add),
              onPressed: editable ? () => onChange(line.quantity + 1) : null),
          SizedBox(
              width: 56,
              child: Text(
                  '₹${(line.totalMinor / 100).toStringAsFixed(line.totalMinor % 100 == 0 ? 0 : 2)}',
                  textAlign: TextAlign.right)),
        ]),
      );
}

class _OrderTypePill extends StatelessWidget {
  const _OrderTypePill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: ViniiColors.brandGreen,
      labelStyle: TextStyle(color: selected ? Colors.black : null),
      onSelected: onTap == null ? null : (_) => onTap!());
}

class _OrderLineTile extends StatelessWidget {
  const _OrderLineTile(
      {required this.item,
      required this.quantity,
      required this.onAdd,
      required this.onRemove});
  final MenuItem item;
  final int quantity;
  final void Function(MenuItem) onAdd, onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child:
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(
            iconSize: 18,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onRemove(item)),
        Text('$quantity'),
        IconButton(
            iconSize: 18,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onAdd(item)),
        SizedBox(
            width: 56,
            child: Text(
                '₹${(item.priceMinor * quantity / 100).toStringAsFixed(item.priceMinor % 100 == 0 ? 0 : 2)}',
                textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow(
      {required this.label, required this.valueMinor, this.bold = false});
  final String label;
  final int valueMinor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style =
        TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    final v = valueMinor.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text('${valueMinor < 0 ? '-' : ''}₹${(v / 100).toStringAsFixed(2)}',
            style: style),
      ]),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.totalItemsCount,
    required this.selected,
    required this.onSelect,
  });
  final List<MenuCategory> categories;
  final int totalItemsCount;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 195,
      child: categories.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No categories in database',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'CATEGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _CategoryTile(
                  label: 'All Items',
                  count: totalItemsCount,
                  selected: selected == 'all',
                  onTap: () => onSelect('all'),
                ),
                for (final c in categories)
                  _CategoryTile(
                    label: c.name,
                    count: c.itemCount,
                    selected: selected == c.id,
                    onTap: () => onSelect(c.id),
                  ),
              ],
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: selected ? ViniiColors.greenTint : null,
          border: selected ? Border.all(color: ViniiColors.brandGreen) : null,
          borderRadius: BorderRadius.circular(8)),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(Icons.star_border,
              size: 18, color: selected ? ViniiColors.brandGreen : Colors.grey),
          title: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? ViniiColors.brandGreen : null)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? ViniiColors.brandGreen.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? ViniiColors.brandGreen : Colors.grey.shade700,
              ),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.categoryName,
    required this.items,
    required this.hasCategories,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onTap,
  });
  final String categoryName;
  final List<MenuItem> items;
  final bool hasCategories;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final void Function(MenuItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$categoryName  ·  ${items.length} items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          searchQuery.isNotEmpty
                              ? Icons.search_off
                              : (!hasCategories
                                  ? Icons.restaurant_menu
                                  : Icons.fastfood_outlined),
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No items matching "$searchQuery"'
                              : (!hasCategories
                                  ? 'No categories or items in database yet'
                                  : 'No items in this category'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Try searching with a different keyword.'
                              : 'Add categories and items in Menu Management to start taking orders.',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, gridConstraints) {
                      if (gridConstraints.maxWidth <= 0 ||
                          gridConstraints.maxHeight <= 0) {
                        return const SizedBox.shrink();
                      }
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 130,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _ItemCard(item: items[i], onTap: onTap),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final MenuItem item;
  final void Function(MenuItem) onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.available ? () => onTap(item) : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: item.available ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(10)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (item.isBestseller)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: ViniiColors.amberTint,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('Bestseller',
                      style: TextStyle(
                          fontSize: 10, color: ViniiColors.amberSolid))),
            const Spacer(),
            Row(children: [
              Icon(Icons.circle,
                  size: 8,
                  color: item.isVeg
                      ? ViniiColors.greenSolid
                      : ViniiColors.redSolid),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 2),
            Text(
                '₹${(item.priceMinor / 100).toStringAsFixed(item.priceMinor % 100 == 0 ? 0 : 2)}'),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.circle,
                  size: 6,
                  color: item.available
                      ? ViniiColors.greenSolid
                      : ViniiColors.redSolid),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(
                      item.available
                          ? 'Available'
                          : (item.unavailableReason ?? 'Unavailable'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: item.available
                              ? ViniiColors.greenSolid
                              : ViniiColors.redSolid))),
            ]),
          ]),
        ),
      ),
    );
  }
}
