import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/drift_operations_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/inventory.dart' show formatInr;
import '../../domain/operations.dart';
import '../master/master_file_io.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'ops_order_dialogs.dart';

const _border = Color(0xFFE5E7EB);
const _chipGray = Color(0xFFF3F4F6);
const _selGreenBg = Color(0xFFF0FDF4);
const _selGreenText = Color(0xFF16A34A);
const _vegGreen = Color(0xFF16A34A);
const _nonVegRed = Color(0xFFDC2626);

String _inr(int minor) =>
    formatInr(minor / 100, decimals: minor % 100 == 0 ? 0 : 2);

String _inr0(int minor) => formatInr(minor / 100, decimals: 0);

String _tableChipLabel(String label) {
  final m = RegExp(r'^T(\d+)$').firstMatch(label.trim());
  return m == null ? label : 'Table ${m.group(1)}';
}

String _channelLabel(OpsChannel c) => switch (c) {
      OpsChannel.dineIn => 'Dine-in',
      OpsChannel.takeaway => 'Takeaway',
      OpsChannel.delivery => 'Delivery',
    };

enum _PayMethod { cash, card, upi, split }

extension on _PayMethod {
  String get label => switch (this) {
        _PayMethod.cash => 'Cash',
        _PayMethod.card => 'Card',
        _PayMethod.upi => 'UPI (Google Pay)',
        _PayMethod.split => 'Split',
      };
  String get key => switch (this) {
        _PayMethod.cash => 'cash',
        _PayMethod.card => 'card',
        _PayMethod.upi => 'upi',
        _PayMethod.split => 'split',
      };
}

class _SettledInfo {
  const _SettledInfo(
      {required this.orderId,
      required this.orderNumber,
      required this.billNo,
      required this.totalMinor,
      required this.method,
      required this.pendingVerification,
      this.changeMinor});

  /// For lookups only — people see [orderNumber].
  final String orderId;

  /// "ORD-248" — the order number shown on screen.
  final String orderNumber;
  final int? billNo;
  final int totalMinor;
  final String method;

  /// Card / UPI / split recorded — the order stays open for payment until
  /// an authorised user verifies it.
  final bool pendingVerification;
  final int? changeMinor;
}

/// Operations → POS Billing. Left: menu (search / barcode / categories /
/// item grid). Right: the bill for an open order (live from the POS
/// tables) or a new bill kept locally until it is printed or settled.
///
/// Payments: cash (the default) settles the bill. Card / UPI / split are
/// recorded as "pending verification" — the device cannot confirm them —
/// and only a user allowed to verify payments ([canVerifyPayments]) can
/// settle them with "Verify Payment".
class OpsPosBillingScreen extends StatefulWidget {
  const OpsPosBillingScreen(
      {super.key,
      required this.ops,
      this.master,
      this.focusOrderId,
      this.onOpenBilling,
      this.canVerifyPayments = false,
      this.canTakePayments = true,
      this.canPlaceOrders = true});
  final DriftOperationsStore ops;
  final DriftMasterStore? master;
  final String? focusOrderId;
  final ValueChanged<String>? onOpenBilling;

  /// The signed-in role may verify card / UPI payments (owner, restaurant
  /// admin, branch manager). False hides the Verify action.
  final bool canVerifyPayments;

  /// The role may settle bills (cashier, owner, admin, branch manager).
  final bool canTakePayments;

  /// The role may start bills and add items (not the kitchen).
  final bool canPlaceOrders;

  @override
  State<OpsPosBillingScreen> createState() => _OpsPosBillingScreenState();
}

class _OpsPosBillingScreenState extends State<OpsPosBillingScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _subs = <StreamSubscription<Object?>>[];

  List<OpsOrder> _orders = const [];
  List<OpsTable> _tables = const [];
  List<MasterDishItem> _dishes = const [];
  bool _ordersLoaded = false;
  bool _dishesLoaded = false;

  /// Order numbers seen on this screen (id → "ORD-248"), so a bill that
  /// has left the open list is still named by its number, never its id.
  final _numbers = <String, String>{};
  final _lookedUp = <String>{};

  String _query = '';
  String _category = 'All';

  /// Open order shown in the bill panel; null = new bill.
  String? _orderId;

  /// Order just created by this screen, waiting for the stream to show it.
  String? _pendingOrderId;

  // New-bill state (kept locally until the first Print / Settle).
  OpsChannel _newChannel = OpsChannel.dineIn;
  String? _newTableId;
  List<OpsOrderLine> _newLines = [];
  double _newDiscountPct = 0;
  String _newDiscountReason = '';

  /// Cash by default: the only tender the device can confirm by itself.
  _PayMethod _method = _PayMethod.cash;
  _SettledInfo? _settled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orderId = widget.focusOrderId;
    _subs.add(widget.ops.watchOrders(openOnly: true).listen((o) {
      if (!mounted) return;
      setState(() {
        _orders = o;
        _ordersLoaded = true;
        for (final x in o) {
          _numbers[x.id] = x.number;
        }
        if (_pendingOrderId != null && o.any((x) => x.id == _pendingOrderId)) {
          _pendingOrderId = null;
        }
      });
    }));
    _subs.add(widget.ops.watchTables().listen((t) {
      if (mounted) setState(() => _tables = t);
    }));
    final master = widget.master;
    if (master != null) {
      _subs.add(master.watchDishes().listen((d) {
        if (mounted) {
          setState(() {
            _dishes = d;
            _dishesLoaded = true;
          });
        }
      }));
    }
  }

  @override
  void didUpdateWidget(covariant OpsPosBillingScreen old) {
    super.didUpdateWidget(old);
    if (widget.focusOrderId != old.focusOrderId &&
        widget.focusOrderId != null) {
      setState(() {
        _orderId = widget.focusOrderId;
        _settled = null;
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Derived data
  // -------------------------------------------------------------------

  List<MasterDishItem> get _sellable => _dishes
      .where((d) => d.status == 'Active' && d.availability != 'Unavailable')
      .toList();

  List<String> get _categories {
    final set = <String>{};
    for (final d in _sellable) {
      if (d.category.trim().isNotEmpty) set.add(d.category.trim());
    }
    return set.toList()..sort();
  }

  String _barcodeOf(MasterDishItem d) =>
      (d.details['barcode'] ?? '').toString().trim();

  List<MasterDishItem> get _visibleDishes {
    final q = _query.trim().toLowerCase();
    return _sellable.where((d) {
      if (_category != 'All' && d.category.trim() != _category) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.sku.toLowerCase().contains(q) ||
          _barcodeOf(d).toLowerCase().contains(q);
    }).toList();
  }

  OpsOrder? get _order {
    final id = _orderId;
    if (id == null) return null;
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// The order number people read ("ORD-248") for the order [id]. An
  /// order no longer in the open list is looked up once; until then a
  /// short reference is shown (never a database id).
  String _numberOf(String id) {
    final known = _numbers[id];
    if (known != null) return known;
    if (_ordersLoaded) _lookUpNumber(id);
    return orderNumberLabel(id, null);
  }

  void _lookUpNumber(String id) {
    if (!_lookedUp.add(id)) return;
    widget.ops.getOrder(id).then((o) {
      if (o != null && mounted) setState(() => _numbers[id] = o.number);
    }, onError: (Object _) {});
  }

  /// A transient order used only for the new-bill totals (same getters).
  OpsOrder get _draft => OpsOrder(
      id: 'NEW',
      channel: _newChannel,
      status: OpsOrderStatus.open,
      createdAt: DateTime.now(),
      lines: _newLines,
      discountPct: _newDiscountPct);

  OpsOrderLine _lineFor(MasterDishItem d, int qty) => OpsOrderLine(
      itemId: d.id,
      name: d.name,
      unitMinor: (d.sellingPrice * 100).round(),
      quantity: qty,
      station: stationForDish(d.category, d.kitchenStation),
      isVeg: d.isVeg);

  // -------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------

  void _resetToNew() => setState(() {
        _orderId = null;
        _pendingOrderId = null;
        _settled = null;
        _newLines = [];
        _newDiscountPct = 0;
        _newDiscountReason = '';
        _newTableId = null;
        _newChannel = OpsChannel.dineIn;
        _method = _PayMethod.cash;
      });

  Future<void> _addDish(MasterDishItem d) async {
    if (!widget.canPlaceOrders) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Your role reviews bills; it cannot add items.')));
      return;
    }
    if (_settled != null) {
      _resetToNew();
    }
    final order = _order;
    if (_orderId != null && order != null) {
      await runMasterAction(
          context, () => widget.ops.addLines(order.id, [_lineFor(d, 1)]),
          success: '${d.name} added to ${order.number} — sent to kitchen');
      return;
    }
    if (_orderId != null) return; // still loading
    setState(() {
      final i = _newLines.indexWhere((l) => l.itemId == d.id);
      if (i >= 0) {
        _newLines = [..._newLines]..[i] =
            _newLines[i].copyWith(quantity: _newLines[i].quantity + 1);
      } else {
        _newLines = [..._newLines, _lineFor(d, 1)];
      }
    });
  }

  Future<void> _onSearchSubmitted(String raw) async {
    final code = raw.trim().toLowerCase();
    if (code.isEmpty) return;
    MasterDishItem? hit;
    for (final d in _sellable) {
      if (_barcodeOf(d).toLowerCase() == code ||
          (d.sku.isNotEmpty && d.sku.toLowerCase() == code)) {
        hit = d;
        break;
      }
    }
    if (hit == null) {
      showMasterNotice(context,
          'No active item has barcode / SKU "${raw.trim()}". Tap an item to add it.');
      _searchFocus.requestFocus();
      return;
    }
    _search.clear();
    setState(() => _query = '');
    await _addDish(hit);
    if (mounted) _searchFocus.requestFocus();
  }

  void _onBarcodePressed() {
    _searchFocus.requestFocus();
    _search.selection =
        TextSelection(baseOffset: 0, extentOffset: _search.text.length);
    showMasterNotice(
        context,
        'Barcode scanners type into the search box — scan now; '
        'an exact barcode / SKU match is added on Enter.');
  }

  Future<void> _changeQty(OpsOrderLine l, int qty) async {
    final order = _order;
    final existing = _orderId != null && order != null;
    // Reducing an item the kitchen already has is a void: it needs a
    // reason and goes into the order history.
    if (existing && order.sentToKitchen && qty < l.quantity) {
      final reason = await showReasonDialog(context,
          title: qty <= 0 ? 'Void ${l.name}?' : 'Reduce ${l.name}?',
          message: qty <= 0
              ? '${l.name} was already sent to the kitchen. Removing it is '
                  'recorded in the order history.'
              : '${l.name} was already sent to the kitchen. Reducing it '
                  '${l.quantity} → $qty is recorded in the order history.',
          confirm: qty <= 0 ? 'Void Item' : 'Reduce',
          suggestions: const [
            'Guest changed mind',
            'Wrong item',
            'Out of stock'
          ]);
      if (reason == null || !mounted) return;
      await runMasterAction(
          context,
          () => widget.ops
              .setLineQuantity(order.id, l.itemId, qty, reason: reason),
          success: qty <= 0 ? '${l.name} voided' : '${l.name} reduced');
      return;
    }
    if (qty <= 0) {
      final ok = await confirmMasterAction(context,
          title: 'Remove item?',
          message: 'Remove ${l.name} from this bill?',
          confirmLabel: 'Remove');
      if (!ok || !mounted) return;
    }
    if (existing) {
      await runMasterAction(
          context, () => widget.ops.setLineQuantity(order.id, l.itemId, qty),
          success: qty > l.quantity && order.sentToKitchen
              ? '+${qty - l.quantity} ${l.name} sent to kitchen'
              : null);
      return;
    }
    setState(() {
      if (qty <= 0) {
        _newLines = _newLines.where((x) => x.itemId != l.itemId).toList();
      } else {
        _newLines = [
          for (final x in _newLines)
            x.itemId == l.itemId ? x.copyWith(quantity: qty) : x
        ];
      }
    });
  }

  Future<void> _editDiscount() async {
    final order = _order;
    final current = order?.discountPct ?? _newDiscountPct;
    final r = await showDialog<(double, String)>(
        context: context, builder: (_) => _DiscountDialog(initial: current));
    if (r == null || !mounted) return;
    final (pct, reason) = r;
    if (order != null) {
      await runMasterAction(
          context, () => widget.ops.setDiscount(order.id, pct, reason: reason),
          success: 'Discount set to ${_pctText(pct)}%');
    } else {
      setState(() {
        _newDiscountPct = pct;
        _newDiscountReason = reason;
      });
    }
  }

  Future<void> _verify(OpsOrder o) async {
    final note = await showVerifyPaymentDialog(context, o);
    if (note == null || !mounted) return;
    final ok = await runMasterAction(
        context,
        () => widget.ops.verifyPayment(o.id, note: note),
        success: 'Payment for ${o.number} verified — bill settled');
    if (ok && mounted && _settled?.orderId == o.id) {
      setState(() => _settled = null);
    }
  }

  Future<void> _preview(String orderId) =>
      showBillPreview(context, ops: widget.ops, orderId: orderId);

  void _pickTable(OpsTable? t) {
    if (t == null) {
      setState(() => _newTableId = null);
      return;
    }
    final existingId = t.currentOrderId;
    final existing = existingId == null
        ? null
        : _orders.where((o) => o.id == existingId).firstOrNull;
    if (existing != null) {
      // The table already has an open order: switch to it and move any
      // items picked for the new bill onto it.
      final lines = _newLines;
      setState(() {
        _orderId = existing.id;
        _newLines = [];
        _newTableId = null;
      });
      if (lines.isNotEmpty) {
        final count = lines.fold<int>(0, (s, l) => s + l.quantity);
        runMasterAction(
            context, () => widget.ops.addLines(existing.id, lines),
            success: '$count ${count == 1 ? 'item' : 'items'} added to '
                '${existing.number} on ${t.label} — sent to kitchen');
      } else {
        showMasterNotice(context,
            '${t.label} already has open order ${existing.number} — opened it.');
      }
      return;
    }
    setState(() => _newTableId = t.id);
  }

  /// Creates the order for a new bill (sends it to the kitchen) and
  /// applies the locally stored discount. Returns the order id.
  Future<String> _createFromDraft() async {
    if (_newChannel == OpsChannel.dineIn && _newTableId == null) {
      throw ArgumentError('Pick a table for dine-in.');
    }
    final id = await widget.ops.placeOrder(
        channel: _newChannel,
        lines: _newLines,
        tableId: _newChannel == OpsChannel.dineIn ? _newTableId : null,
        source: 'POS',
        sendToKitchen: true);
    if (_newDiscountPct > 0) {
      await widget.ops
          .setDiscount(id, _newDiscountPct, reason: _newDiscountReason);
    }
    return id;
  }

  /// Generates the bill number and shows the bill on screen. No receipt
  /// printer is connected — the preview says so; nothing is printed.
  Future<void> _printDraft() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? id;
    final ok = await runMasterAction(context, () async {
      id = _order?.id;
      if (id == null) {
        id = await _createFromDraft();
        if (mounted) {
          setState(() {
            _orderId = id;
            _pendingOrderId = id;
            _newLines = [];
            _newDiscountPct = 0;
            _newDiscountReason = '';
          });
        }
      }
      await widget.ops.generateBill(id!);
    });
    if (mounted) setState(() => _busy = false);
    if (ok && mounted && id != null) await _preview(id!);
  }

  Future<void> _settle(int totalMinor) async {
    if (_busy) return;
    // Collect the payment details first (nothing is written if cancelled).
    String method = _method.key;
    int? receivedMinor;
    int? change;
    if (_method == _PayMethod.cash) {
      final r = await showDialog<int>(
          context: context,
          builder: (_) => _CashDialog(totalMinor: totalMinor));
      if (r == null || !mounted) return;
      receivedMinor = r;
      change = r - totalMinor;
    } else if (_method == _PayMethod.split) {
      final s = await showDialog<String>(
          context: context,
          builder: (_) => _SplitDialog(totalMinor: totalMinor));
      if (s == null || !mounted) return;
      method = s;
    }
    setState(() => _busy = true);
    _SettledInfo? info;
    await runMasterAction(context, () async {
      var id = _order?.id;
      if (id == null) {
        id = await _createFromDraft();
        if (mounted) {
          setState(() {
            _orderId = id;
            _pendingOrderId = id;
            _newLines = [];
            _newDiscountPct = 0;
            _newDiscountReason = '';
          });
        }
      }
      final state = await widget.ops
          .settleOrder(id, method, receivedMinor: receivedMinor);
      final done = await widget.ops.getOrder(id);
      info = _SettledInfo(
          orderId: id,
          orderNumber:
              done?.number ?? _numbers[id] ?? orderNumberLabel(id, null),
          billNo: done?.billNo,
          totalMinor: done?.grandTotalMinor ?? totalMinor,
          method: method,
          pendingVerification: state == OrderPaymentState.pendingVerification,
          changeMinor: receivedMinor == null
              ? null
              : receivedMinor - (done?.grandTotalMinor ?? totalMinor));
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (info != null) {
        _settled = info;
        _pendingOrderId = null;
      }
    });
    if (info != null) {
      showMasterNotice(
          context,
          info!.pendingVerification
              ? 'Bill #${info!.billNo ?? '-'}: ${paymentMethodLabel(method)} '
                  'recorded — pending verification.'
              : 'Bill #${info!.billNo ?? '-'} settled${change != null && info!.changeMinor! > 0 ? ' — return change ${_inr(info!.changeMinor!)}' : ''}.');
    }
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000 && c.maxHeight.isFinite;
      if (wide) {
        final panelW = (c.maxWidth * 0.42).clamp(400.0, 540.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _menu(scroll: true)),
            const SizedBox(width: 20),
            SizedBox(width: panelW, child: _billPanel(scroll: true)),
          ]),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _menu(scroll: false),
          const SizedBox(height: 20),
          _billPanel(scroll: false),
        ]),
      );
    });
  }

  // ---- Left: menu ----------------------------------------------------

  Widget _menu({required bool scroll}) {
    final grid = _itemGrid(scroll: scroll);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _searchBox()),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Scan barcode',
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _onBarcodePressed,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.barcode_reader,
                    size: 22, color: ViniiColors.textPrimaryLight),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 22),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final cat in ['All', ..._categories])
          _CategoryChip(
              label: cat,
              selected: _category == cat,
              onTap: () => setState(() => _category = cat)),
      ]),
      const SizedBox(height: 16),
      if (scroll) Expanded(child: grid) else grid,
    ]);
  }

  Widget _searchBox() => Container(
        height: 42,
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search,
              size: 20, color: ViniiColors.textSecondaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: _onSearchSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                  fontSize: 14, color: ViniiColors.textPrimaryLight),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                hintText: 'Scan barcode or search food items...',
                hintStyle: TextStyle(
                    fontSize: 14, color: ViniiColors.textSecondaryLight),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              iconSize: 18,
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close,
                  color: ViniiColors.textSecondaryLight),
            ),
        ]),
      );

  Widget _itemGrid({required bool scroll}) {
    if (widget.master == null) {
      return const _EmptyNote(
          icon: Icons.restaurant_menu,
          text: 'Menu catalogue is not available on this device.');
    }
    if (!_dishesLoaded) {
      return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()));
    }
    final items = _visibleDishes;
    if (items.isEmpty) {
      return _EmptyNote(
          icon: Icons.search_off,
          text: _query.isNotEmpty
              ? 'No items match "$_query".'
              : 'No active items in this category.');
    }
    return LayoutBuilder(builder: (context, c) {
      const spacing = 12.0;
      final cols =
          ((c.maxWidth + spacing) / (146 + spacing)).floor().clamp(2, 8);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      final wrap = Wrap(spacing: spacing, runSpacing: spacing, children: [
        for (final d in items)
          SizedBox(
              width: w,
              height: 110,
              child: _ItemCard(dish: d, onTap: () => _addDish(d))),
      ]);
      return scroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16), child: wrap)
          : wrap;
    });
  }

  // ---- Right: bill ---------------------------------------------------

  Widget _billPanel({required bool scroll}) {
    final Widget body;
    if (_settled != null) {
      body = _successState(_settled!);
    } else if (_orderId != null && _order == null) {
      body = _missingOrder(scroll: scroll);
    } else {
      body = _billBody(scroll: scroll);
    }
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _openBillsBar(),
            const SizedBox(height: 10),
            if (scroll) Flexible(child: body) else body,
          ]),
    );
  }

  Widget _openBillsBar() {
    final open = _orders;
    return Row(children: [
      PopupMenuButton<String>(
        tooltip: 'Switch to an open bill',
        enabled: open.isNotEmpty,
        onSelected: (id) => setState(() {
          _orderId = id;
          _settled = null;
        }),
        itemBuilder: (_) => [
          for (final o in open)
            PopupMenuItem(
              value: o.id,
              child: SizedBox(
                width: 300,
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${o.tableLabel != null ? _tableChipLabel(o.tableLabel!) : _channelLabel(o.channel)} · ${o.number}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: o.id == _orderId
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                  if (o.status == OpsOrderStatus.billed)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: o.payment != null
                            ? const MasterStatusPill('Pending verification',
                                tone: PillTone.amber)
                            : const MasterStatusPill('Billed',
                                tone: PillTone.purple)),
                  Text(_inr0(o.grandTotalMinor),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: _chipGray, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined,
                size: 15, color: ViniiColors.textSecondaryLight),
            const SizedBox(width: 6),
            Text(_ordersLoaded ? 'Open bills (${open.length})' : 'Open bills',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: ViniiColors.textSecondaryLight),
          ]),
        ),
      ),
      const Spacer(),
      if (_orderId != null || _settled != null)
        TextButton.icon(
          onPressed: _resetToNew,
          style: TextButton.styleFrom(
              foregroundColor: ViniiColors.textPrimaryLight,
              visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Bill',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
    ]);
  }

  Widget _missingOrder({required bool scroll}) {
    if (!_ordersLoaded || _pendingOrderId == _orderId) {
      return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.receipt_long_outlined,
            size: 36, color: ViniiColors.textMutedLight),
        const SizedBox(height: 10),
        Text('${_numberOf(_orderId!)} is no longer open',
            style: MasterStyle.sectionTitle, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text(
            'It was settled or cancelled. Pick another open bill or '
            'start a new one.',
            style: MasterStyle.muted,
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        MasterButton(
            label: 'New Bill',
            kind: MasterButtonKind.primary,
            icon: Icons.add,
            onPressed: _resetToNew),
      ]),
    );
  }

  Widget _billBody({required bool scroll}) {
    final order = _order;
    final bill = order ?? _draft;
    final editable = order == null || order.status == OpsOrderStatus.open;
    final lines = bill.lines;

    final linesWidget = lines.isEmpty
        ? const _EmptyNote(
            icon: Icons.shopping_basket_outlined,
            text: 'No items yet — tap an item or scan a barcode to add it '
                'to the bill.')
        : ListView.builder(
            shrinkWrap: true,
            physics: scroll ? null : const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            itemBuilder: (_, i) => _LineRow(
                line: lines[i],
                enabled: editable && !_busy,
                onMinus: () => _changeQty(lines[i], lines[i].quantity - 1),
                onPlus: () => _changeQty(lines[i], lines[i].quantity + 1)),
          );

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          order != null ? _existingHeader(order) : _newHeader(),
          const SizedBox(height: 12),
          if (order != null &&
              order.status == OpsOrderStatus.billed &&
              order.payment == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: MasterBanner(
                  message: 'Bill generated — items are locked. Settle to '
                      'close it.',
                  tone: PillTone.purple),
            ),
          if (scroll) Flexible(child: linesWidget) else linesWidget,
          const SizedBox(height: 40),
          _totals(bill, editable),
          const SizedBox(height: 18),
          if (order?.payment != null)
            _recordedPayment(order!)
          else ...[
            const Text('PAYMENT METHOD',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: ViniiColors.textSecondaryLight)),
            const SizedBox(height: 10),
            Row(children: [
              for (final m in _PayMethod.values) ...[
                if (m != _PayMethod.cash) const SizedBox(width: 8),
                Expanded(
                    child: _PayButton(
                        label: m.label,
                        selected: _method == m,
                        onTap: () => setState(() => _method = m))),
              ],
            ]),
            if (_method != _PayMethod.cash) ...[
              const SizedBox(height: 8),
              const Text(
                  'Card / UPI / split are recorded as pending verification — '
                  'the bill closes once a manager verifies the payment.',
                  style:
                      TextStyle(fontSize: 11.5, color: ViniiColors.amberSolid)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _BigButton(
                  label:
                      order?.billNo == null ? 'Print Draft Bill' : 'View Bill',
                  primary: false,
                  onTap: lines.isEmpty || _busy ? null : _printDraft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigButton(
                  label: !widget.canTakePayments
                      ? 'Payment is taken by the cashier'
                      : _method == _PayMethod.cash
                          ? 'Settle & Close (${_inr0(bill.grandTotalMinor)})'
                          : 'Record Payment (${_inr0(bill.grandTotalMinor)})',
                  primary: true,
                  onTap: lines.isEmpty || _busy || !widget.canTakePayments
                      ? null
                      : () => _settle(bill.grandTotalMinor),
                ),
              ),
            ]),
          ],
        ]);
  }

  /// A card / UPI / split payment already recorded on this bill.
  Widget _recordedPayment(OpsOrder o) {
    final p = o.payment!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterBanner(
          message: '${paymentMethodLabel(p.method)} ${_inr(p.amountMinor)} '
              'recorded ${formatClock(p.recordedAt)} — pending verification. '
              '${widget.canVerifyPayments ? 'Verify it once the money has '
                  'arrived.' : 'A manager must verify it before the bill '
                  'closes.'}',
          tone: PillTone.amber),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _BigButton(
              label: 'View Bill',
              primary: false,
              onTap: _busy ? null : () => _preview(o.id)),
        ),
        if (widget.canVerifyPayments) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _BigButton(
                label: 'Verify Payment',
                primary: true,
                onTap: _busy ? null : () => _verify(o)),
          ),
        ],
      ]),
    ]);
  }

  Widget _existingHeader(OpsOrder o) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bill #${o.billNo ?? 'pending'}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 2),
          Text(
              'Waiter: ${o.serverName.isEmpty ? '—' : o.serverName}  ·  ${o.number}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: ViniiColors.textSecondaryLight)),
        ]),
      ),
      if (o.tableLabel != null) ...[
        _HeaderChip(label: _tableChipLabel(o.tableLabel!), green: true),
        const SizedBox(width: 8),
      ],
      _HeaderChip(label: _channelLabel(o.channel)),
    ]);
  }

  Widget _newHeader() {
    final pickable = _tables
        .where((t) =>
            t.status == OpsTableStatus.available ||
            t.status == OpsTableStatus.occupied)
        .toList();
    OpsTable? selected;
    for (final t in pickable) {
      if (t.id == _newTableId) selected = t;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New Bill',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            SizedBox(height: 2),
            Text('Bill no. is assigned when printed or settled',
                style: TextStyle(
                    fontSize: 12, color: ViniiColors.textSecondaryLight)),
          ]),
        ),
        if (selected != null) ...[
          _HeaderChip(label: _tableChipLabel(selected.label), green: true),
          const SizedBox(width: 8),
        ],
        _HeaderChip(label: _channelLabel(_newChannel)),
      ]),
      const SizedBox(height: 12),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in OpsChannel.values)
              _CategoryChip(
                  label: _channelLabel(c),
                  selected: _newChannel == c,
                  onTap: () => setState(() => _newChannel = c)),
            if (_newChannel == OpsChannel.dineIn)
              Container(
                height: 32,
                // Fixed width: a long "T2 · Occupied (ORD-…)" option must
                // not stretch the picker across the row.
                width: 240,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: selected == null
                            ? ViniiColors.amberSolid
                            : _border),
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected?.id,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('Pick table',
                        style: TextStyle(
                            fontSize: 13, color: ViniiColors.amberSolid)),
                    style: const TextStyle(
                        fontSize: 13, color: ViniiColors.textPrimaryLight),
                    items: [
                      for (final t in pickable)
                        DropdownMenuItem(
                            value: t.id,
                            child: Text(
                                '${t.label} · ${t.status.label}${t.currentOrderId != null ? ' (${_numberOf(t.currentOrderId!)})' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) => _pickTable(
                        pickable.where((t) => t.id == id).firstOrNull),
                  ),
                ),
              ),
          ]),
    ]);
  }

  Widget _totals(OpsOrder bill, bool editable) {
    const labelStyle =
        TextStyle(fontSize: 13, color: ViniiColors.textSecondaryLight);
    const valueStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ViniiColors.textPrimaryLight);
    Widget row(Widget l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: l),
            Text(v, style: valueStyle),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row(const Text('Subtotal', style: labelStyle), _inr0(bill.subtotalMinor)),
      InkWell(
        onTap: editable && !_busy ? _editDiscount : null,
        borderRadius: BorderRadius.circular(4),
        child: row(
            Row(children: [
              Flexible(
                child: Text('Discount (${_pctText(bill.discountPct)}% Applied)',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ViniiColors.textPrimaryLight)),
              ),
              if (editable) ...[
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined,
                    size: 13, color: ViniiColors.textMutedLight),
              ],
            ]),
            '-${_inr0(bill.discountMinor)}'),
      ),
      row(Text('GST (${_pctText(bill.taxPct)}%)', style: labelStyle),
          _inr0(bill.taxMinor)),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: _border)),
      Row(children: [
        const Expanded(
          child: Text('Grand Total',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
        ),
        Text(_inr0(bill.grandTotalMinor),
            style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: ViniiColors.textPrimaryLight)),
      ]),
    ]);
  }

  Widget _successState(_SettledInfo s) {
    // "Cash", "UPI", "Split: Cash ₹120 + UPI ₹80" — never the stored key.
    final methodText = paymentMethodLabel(s.method);
    final pending = s.pendingVerification;
    final live = _orders.where((o) => o.id == s.orderId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: pending ? ViniiColors.amberTint : _selGreenBg,
              shape: BoxShape.circle),
          child: Icon(
              pending ? Icons.hourglass_top_rounded : Icons.check_rounded,
              size: 36,
              color: pending ? ViniiColors.amberSolid : _selGreenText),
        ),
        const SizedBox(height: 16),
        Text(
            pending
                ? 'Bill #${s.billNo ?? '-'} · payment pending verification'
                : 'Bill #${s.billNo ?? '-'} settled',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textPrimaryLight)),
        const SizedBox(height: 6),
        Text('${s.orderNumber} · ${_inr(s.totalMinor)} · $methodText',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textSecondaryLight)),
        if (pending) ...[
          const SizedBox(height: 10),
          Text(
              widget.canVerifyPayments
                  ? 'Recorded, not confirmed. Verify it once the money has '
                      'arrived.'
                  : 'Recorded, not confirmed. A manager must verify it before '
                      'the bill is closed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.amberSolid)),
        ],
        if (s.changeMinor != null && s.changeMinor! > 0) ...[
          const SizedBox(height: 10),
          Text('Change to return: ${_inr(s.changeMinor!)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _selGreenText)),
        ],
        const SizedBox(height: 22),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: _BigButton(
                    label: 'View Bill',
                    primary: false,
                    onTap: () => _preview(s.orderId)),
              ),
              if (pending && widget.canVerifyPayments && live != null)
                SizedBox(
                  width: 170,
                  child: _BigButton(
                      label: 'Verify Payment',
                      primary: false,
                      onTap: () => _verify(live)),
                ),
              SizedBox(
                width: 150,
                child: _BigButton(
                    label: 'New Bill', primary: true, onTap: _resetToNew),
              ),
            ]),
      ]),
    );
  }
}

String _pctText(double p) =>
    p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);

// ---------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? ViniiColors.brandGreen : _border)),
            child: Align(
                widthFactor: 1,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.black
                            : ViniiColors.textPrimaryLight))),
          ),
        ),
      );
}

class _VegMark extends StatelessWidget {
  const _VegMark({required this.veg});
  final bool veg;

  @override
  Widget build(BuildContext context) {
    final c = veg ? _vegGreen : _nonVegRed;
    return Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.2),
          borderRadius: BorderRadius.circular(2)),
      child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.dish, required this.onTap});
  final MasterDishItem dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _VegMark(veg: dish.isVeg && !dish.isNonVeg)),
                  const Spacer(),
                  Text(dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ViniiColors.textPrimaryLight)),
                  const SizedBox(height: 6),
                  Text(formatInr(dish.sellingPrice, decimals: 0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                  const Spacer(),
                ]),
          ),
        ),
      );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, this.green = false});
  final String label;
  final bool green;

  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: green ? _selGreenBg : _chipGray,
            border:
                Border.all(color: green ? ViniiColors.brandGreen : _chipGray),
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: green ? _selGreenText : ViniiColors.textPrimaryLight)),
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow(
      {required this.line,
      required this.enabled,
      required this.onMinus,
      required this.onPlus});
  final OpsOrderLine line;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget step(String s, VoidCallback onTap) => Material(
          color: _chipGray,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: enabled ? onTap : null,
            child: SizedBox(
                width: 22,
                height: 22,
                child: Center(
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? ViniiColors.textPrimaryLight
                                : ViniiColors.textMutedLight)))),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 2),
            Text('${_inr(line.unitMinor)} each',
                style: const TextStyle(
                    fontSize: 11, color: ViniiColors.textSecondaryLight)),
          ]),
        ),
        const SizedBox(width: 8),
        step('-', onMinus),
        SizedBox(
          width: 26,
          child: Text('${line.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
        ),
        step('+', onPlus),
        SizedBox(
          width: 100,
          child: Text(_inr(line.totalMinor),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
        ),
      ]),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _selGreenBg : _chipGray,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? ViniiColors.brandGreen : _chipGray)),
            // Scales a long label ("UPI (Google Pay)") down to fit a
            // narrow button instead of cutting it off.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _selGreenText
                          : ViniiColors.textPrimaryLight)),
            ),
          ),
        ),
      );
}

class _BigButton extends StatelessWidget {
  const _BigButton(
      {required this.label, required this.primary, required this.onTap});
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary
        ? (disabled ? const Color(0xFFD9F7B8) : ViniiColors.brandGreen)
        : Colors.white;
    final fg = disabled
        ? ViniiColors.textMutedLight
        : (primary ? Colors.black : ViniiColors.textPrimaryLight);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: primary
                      ? (disabled
                          ? const Color(0xFFD9F7B8)
                          : ViniiColors.brandGreen)
                      : _border)),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: ViniiColors.textMutedLight),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: ViniiColors.textSecondaryLight)),
        ]),
      );
}

// ---------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------

final _moneyFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

int? _parseMinor(String s) {
  final v = double.tryParse(s.trim());
  return v == null ? null : (v * 100).round();
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial});
  final double initial;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final _c = TextEditingController(text: _pctText(widget.initial));
  final _reason = TextEditingController();
  String? _error;
  String? _reasonError;

  @override
  void dispose() {
    _c.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Every discount change is recorded in the order history with a reason.
  void _submit() {
    final v = double.tryParse(_c.text.trim());
    if (v == null || v < 0 || v > 100) {
      setState(() => _error = 'Enter a percentage between 0 and 100');
      return;
    }
    final reason = _reason.text.trim();
    if (v != widget.initial && reason.isEmpty) {
      setState(() => _reasonError = 'Enter a reason — it is kept in the '
          'order history');
      return;
    }
    Navigator.pop(context, (v, reason));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Discount'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _c,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_moneyFormatter],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                  labelText: 'Discount %', suffixText: '%', errorText: _error),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final p in const [0, 5, 10, 15, 20])
                ActionChip(
                    label: Text('$p%'),
                    onPressed: () => setState(() {
                          _c.text = '$p';
                          _error = null;
                        })),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_reasonError != null) setState(() => _reasonError = null);
              },
              decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. regular guest, manager approval',
                  errorText: _reasonError,
                  errorMaxLines: 2),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Apply')),
        ],
      );
}

class _CashDialog extends StatefulWidget {
  const _CashDialog({required this.totalMinor});
  final int totalMinor;

  @override
  State<_CashDialog> createState() => _CashDialogState();
}

class _CashDialogState extends State<_CashDialog> {
  late final _c =
      TextEditingController(text: (widget.totalMinor / 100).ceil().toString());
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _parseMinor(_c.text);
    if (v == null || v < widget.totalMinor) {
      setState(() =>
          _error = 'Received must be at least ${_inr(widget.totalMinor)}');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final received = _parseMinor(_c.text);
    final change = received == null ? null : received - widget.totalMinor;
    return AlertDialog(
      title: const Text('Cash payment'),
      content: SizedBox(
        width: 340,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MasterKeyValue('Bill total', _inr(widget.totalMinor)),
              const SizedBox(height: 8),
              TextField(
                controller: _c,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyFormatter],
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                    labelText: 'Amount received',
                    prefixText: '₹ ',
                    errorText: _error),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(
                    child: Text('Change to return',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600))),
                Text(change == null || change < 0 ? '—' : _inr(change),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _selGreenText)),
              ]),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Settle')),
      ],
    );
  }
}

class _SplitDialog extends StatefulWidget {
  const _SplitDialog({required this.totalMinor});
  final int totalMinor;

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  static const _methods = ['cash', 'card', 'upi'];
  static const _labels = {'cash': 'Cash', 'card': 'Card', 'upi': 'UPI'};
  String _m1 = 'cash';
  String _m2 = 'upi';
  late final _a1 = TextEditingController(text: _fmt(widget.totalMinor ~/ 2));
  late final _a2 = TextEditingController(
      text: _fmt(widget.totalMinor - widget.totalMinor ~/ 2));
  String? _error;

  static String _fmt(int minor) => minor % 100 == 0
      ? (minor ~/ 100).toString()
      : (minor / 100).toStringAsFixed(2);

  @override
  void dispose() {
    _a1.dispose();
    _a2.dispose();
    super.dispose();
  }

  void _submit() {
    final x = _parseMinor(_a1.text);
    final y = _parseMinor(_a2.text);
    if (_m1 == _m2) {
      setState(() => _error = 'Pick two different methods');
      return;
    }
    if (x == null || y == null || x <= 0 || y <= 0) {
      setState(() => _error = 'Both amounts must be more than ₹0');
      return;
    }
    if (x + y != widget.totalMinor) {
      setState(() => _error =
          'Amounts must add up to ${_inr(widget.totalMinor)} (now ${_inr(x + y)})');
      return;
    }
    Navigator.pop(context, 'split: $_m1 ${_inr(x)} + $_m2 ${_inr(y)}');
  }

  Widget _row(String method, ValueChanged<String> onMethod,
          TextEditingController c, ValueChanged<String> onAmount) =>
      Row(children: [
        SizedBox(
          width: 110,
          child: DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: [
              for (final m in _methods)
                DropdownMenuItem(value: m, child: Text(_labels[m]!)),
            ],
            onChanged: (v) => onMethod(v ?? method),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_moneyFormatter],
            onChanged: onAmount,
            decoration:
                const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Split payment'),
        content: SizedBox(
          width: 380,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MasterKeyValue('Bill total', _inr(widget.totalMinor)),
                const SizedBox(height: 8),
                _row(_m1, (v) => setState(() => _m1 = v), _a1, (v) {
                  final x = _parseMinor(v);
                  if (x != null && x <= widget.totalMinor) {
                    _a2.text = _fmt(widget.totalMinor - x);
                  }
                  setState(() => _error = null);
                }),
                const SizedBox(height: 12),
                _row(_m2, (v) => setState(() => _m2 = v), _a2, (v) {
                  final y = _parseMinor(v);
                  if (y != null && y <= widget.totalMinor) {
                    _a1.text = _fmt(widget.totalMinor - y);
                  }
                  setState(() => _error = null);
                }),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: ViniiColors.redSolid)),
                ],
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Settle')),
        ],
      );
}
