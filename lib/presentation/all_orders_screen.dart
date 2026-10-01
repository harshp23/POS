// Rebuilt from v1/POS-ALL-ORDERS-V3.png as a read view over the real
// orders (orders / order_lines / kitchen_tickets / payments), not the old
// editable summary table: amounts, statuses and customers come from the
// orders themselves and cannot be rewritten or deleted here. Corrections
// happen on the order (cancel / void / discount with a reason, recorded in
// its history). Export copies the rows in view as CSV to the clipboard.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/csv.dart';
import '../data/drift_all_orders_store.dart';
import '../data/drift_operations_store.dart';
import '../domain/operations.dart';
import 'operations/ops_order_dialogs.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

const _colOrder = 110.0;
const _colType = 100.0;
const _colSource = 80.0;
const _colCustomer = 150.0;
const _colItems = 70.0;
const _colAmount = 100.0;
const _colStatus = 150.0;
const _colPayment = 190.0;
const _colSync = 110.0;
const _colTime = 80.0;
const _colAction = 70.0;
const _tableWidth = _colOrder +
    _colType +
    _colSource +
    _colCustomer +
    _colItems +
    _colAmount +
    _colStatus +
    _colPayment +
    _colSync +
    _colTime +
    _colAction +
    32;

/// Lifecycle filter of the All Orders list.
enum _StatusFilter {
  all('All statuses'),
  open('Open'),
  held('Held'),
  awaitingPayment('Awaiting payment'),
  pendingVerification('Pending verification'),
  completed('Completed'),
  cancelled('Cancelled'),
  syncReview('Sync needs review');

  const _StatusFilter(this.label);
  final String label;
}

/// The order's status as All Orders shows it.
(String, Color) orderStatusOf(OpsOrder o) => switch (o.status) {
      OpsOrderStatus.cancelled => ('Cancelled', ViniiColors.redSolid),
      OpsOrderStatus.settled => ('Completed', ViniiColors.graySolid),
      OpsOrderStatus.billed => o.payment != null
          ? ('Pending verification', ViniiColors.amberSolid)
          : ('Billed', ViniiColors.purpleSolid),
      OpsOrderStatus.open => switch (o.kitchenState) {
          OpsKitchenState.notSent => ('Held', Colors.orange),
          OpsKitchenState.queued => ('New', ViniiColors.blueSolid),
          OpsKitchenState.preparing => ('Preparing', ViniiColors.amberSolid),
          OpsKitchenState.ready => ('Ready', ViniiColors.greenSolid),
          OpsKitchenState.served => ('Served', ViniiColors.blueSolid),
        },
    };

/// Where the order stands with the Proviyaa server.
(String, Color) syncStatusOf(OpsOrder o) {
  if (o.syncNeedsReview) return ('Needs review', ViniiColors.redSolid);
  return switch (o.syncStatus) {
    'synchronized' => ('Synced', ViniiColors.greenSolid),
    'needsReview' => ('Needs review', ViniiColors.redSolid),
    _ => ('Not uploaded', ViniiColors.graySolid),
  };
}

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen(
      {super.key, this.ordersStore, this.ops, this.onOpenOrder});

  /// Kept for existing callers: its database is used when [ops] is null.
  final DriftAllOrdersStore? ordersStore;
  final DriftOperationsStore? ops;

  /// Opens an active order in the POS order screen.
  final ValueChanged<String>? onOpenOrder;

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  String _channel = 'All';
  _StatusFilter _status = _StatusFilter.all;
  bool _todayOnly = true;
  String _query = '';
  DriftOperationsStore? _ops;
  StreamSubscription<List<OpsOrder>>? _sub;
  List<OpsOrder>? _orders;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final db = widget.ops?.db ?? widget.ordersStore?.db;
    _ops = widget.ops ?? (db == null ? null : DriftOperationsStore(db));
    _sub = _ops?.watchOrders().listen(
        (o) => mounted ? setState(() => _orders = o) : null,
        onError: (Object e) => mounted ? setState(() => _error = e) : null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _today(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _statusMatch(OpsOrder o) => switch (_status) {
        _StatusFilter.all => true,
        _StatusFilter.open => o.isActive,
        _StatusFilter.held => o.isHeld,
        _StatusFilter.awaitingPayment =>
          o.isActive && o.paymentState == OrderPaymentState.unpaid,
        _StatusFilter.pendingVerification =>
          o.paymentState == OrderPaymentState.pendingVerification,
        _StatusFilter.completed => o.status == OpsOrderStatus.settled,
        _StatusFilter.cancelled => o.status == OpsOrderStatus.cancelled,
        _StatusFilter.syncReview => syncStatusOf(o).$1 == 'Needs review',
      };

  bool _queryMatch(OpsOrder o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      o.id,
      o.number,
      o.customerName,
      o.tableLabel ?? '',
      o.source,
      if (o.billNo != null) '${o.billNo}',
      for (final l in o.lines) l.name,
    ].join(' ').toLowerCase().contains(q);
  }

  String _time(DateTime d) =>
      _today(d) ? formatClock(d) : '${d.day}/${d.month} ${formatClock(d)}';

  Future<void> _export(List<OpsOrder> rows) async {
    final csv = Csv.encode([
      'Order',
      'Bill no',
      'Type',
      'Source',
      'Table / customer',
      'Items',
      'Subtotal (INR)',
      'Discount (INR)',
      'GST (INR)',
      'Total (INR)',
      'Status',
      'Payment',
      'Sync',
      'Placed',
    ], [
      for (final o in rows)
        [
          o.number,
          o.billNo ?? '',
          o.channel.label,
          o.source,
          o.displayName,
          o.lines.map((l) => '${l.quantity}x ${l.name}').join('; '),
          (o.subtotalMinor / 100).toStringAsFixed(2),
          (o.discountMinor / 100).toStringAsFixed(2),
          (o.taxMinor / 100).toStringAsFixed(2),
          (o.grandTotalMinor / 100).toStringAsFixed(2),
          orderStatusOf(o).$1,
          o.paymentLabel,
          syncStatusOf(o).$1,
          o.createdAt.toIso8601String(),
        ],
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Copied ${rows.length} order${rows.length == 1 ? '' : 's'} '
                  'as CSV — paste into a spreadsheet.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ops = _ops;
    if (ops == null) {
      return const Center(
          child: Text('All Orders — no order store is connected.',
              style: TextStyle(color: ViniiColors.textMutedLight)));
    }
    if (_error != null) {
      return Center(
          child: Text('Could not load orders: ${friendlyError(_error!)}'));
    }
    final all = _orders;
    final scoped = [
      for (final o in all ?? const <OpsOrder>[])
        if (!_todayOnly || _today(o.createdAt) || o.isActive) o
    ];
    final channels = <String, bool Function(OpsOrder)>{
      'All': (_) => true,
      for (final c in OpsChannel.values) c.label: (o) => o.channel == c,
    };
    final visible = [
      for (final o in scoped)
        if (channels[_channel]!(o) && _statusMatch(o) && _queryMatch(o)) o
    ];

    return Container(
      color: ViniiColors.lightPageBg,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('All Orders',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${scoped.length} order${scoped.length == 1 ? '' : 's'} '
                          '${_todayOnly ? 'today (and still open)' : 'on this device'}',
                          style: const TextStyle(
                              color: ViniiColors.textMutedLight, fontSize: 13)),
                    ]),
                Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 38,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search order, customer, item',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                      DropdownButton<_StatusFilter>(
                        value: _status,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final s in _StatusFilter.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (s) =>
                            setState(() => _status = s ?? _StatusFilter.all),
                      ),
                      FilterChip(
                          label: const Text('Today'),
                          selected: _todayOnly,
                          onSelected: (v) => setState(() => _todayOnly = v)),
                      OutlinedButton.icon(
                        onPressed:
                            visible.isEmpty ? null : () => _export(visible),
                        icon:
                            const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Export CSV'),
                      ),
                    ]),
              ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in channels.entries)
                ChoiceChip(
                  label: Text('${e.key}  ${scoped.where(e.value).length}'),
                  selected: _channel == e.key,
                  selectedColor: ViniiColors.brandGreen,
                  labelStyle: TextStyle(
                      color: _channel == e.key ? Colors.black : null,
                      fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _channel = e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: all == null
                ? const Center(child: CircularProgressIndicator())
                : scoped.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                                _todayOnly
                                    ? 'No orders today yet'
                                    : 'No orders on this device yet',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            const Text(
                              'Orders taken in the POS or Operations appear here automatically.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: constraints.maxWidth < _tableWidth
                                ? _tableWidth
                                : constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: ViniiColors.lightBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: ViniiColors.lightBorder)),
                              child: Column(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: ViniiColors.lightBorder))),
                                  child: const Row(children: [
                                    SizedBox(
                                        width: _colOrder,
                                        child: _HeaderLabel('ORDER')),
                                    SizedBox(
                                        width: _colType,
                                        child: _HeaderLabel('TYPE')),
                                    SizedBox(
                                        width: _colSource,
                                        child: _HeaderLabel('SOURCE')),
                                    SizedBox(
                                        width: _colCustomer,
                                        child: _HeaderLabel('TABLE/CUSTOMER')),
                                    SizedBox(
                                        width: _colItems,
                                        child: _HeaderLabel('ITEMS')),
                                    SizedBox(
                                        width: _colAmount,
                                        child: _HeaderLabel('AMOUNT')),
                                    SizedBox(
                                        width: _colStatus,
                                        child: _HeaderLabel('STATUS')),
                                    SizedBox(
                                        width: _colPayment,
                                        child: _HeaderLabel('PAYMENT')),
                                    SizedBox(
                                        width: _colSync,
                                        child: _HeaderLabel('SYNC')),
                                    SizedBox(
                                        width: _colTime,
                                        child: _HeaderLabel('TIME')),
                                    SizedBox(
                                        width: _colAction,
                                        child: _HeaderLabel('')),
                                  ]),
                                ),
                                Expanded(
                                  child: visible.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'No orders match these filters.',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        )
                                      : ListView.separated(
                                          itemCount: visible.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                                  height: 1,
                                                  color:
                                                      ViniiColors.lightBorder),
                                          itemBuilder: (context, i) =>
                                              _OrderRow(
                                            order: visible[i],
                                            time: _time(visible[i].createdAt),
                                            onView: () =>
                                                showOrderDetailsDialog(context,
                                                    ops: ops,
                                                    orderId: visible[i].id,
                                                    onOpenOrder:
                                                        widget.onOpenOrder),
                                          ),
                                        ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ViniiColors.textMutedLight,
          letterSpacing: 0.4));
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(
      {required this.order, required this.time, required this.onView});

  final OpsOrder order;
  final String time;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final (status, statusColor) = orderStatusOf(o);
    final (sync, syncColor) = syncStatusOf(o);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(
              width: _colOrder,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.number,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ViniiColors.emeraldText,
                            fontWeight: FontWeight.w600)),
                    if (o.billNo != null)
                      Text('Bill #${o.billNo}',
                          style: const TextStyle(
                              fontSize: 11, color: ViniiColors.textMutedLight)),
                  ])),
          SizedBox(
              width: _colType,
              child: _Pill(o.channel.label, ViniiColors.graySolid)),
          SizedBox(
              width: _colSource,
              child: Text(o.source,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))),
          SizedBox(
              width: _colCustomer,
              child: Text(o.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))),
          SizedBox(
              width: _colItems,
              child: Text('${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: ViniiColors.textMutedLight))),
          SizedBox(
              width: _colAmount,
              child: Text('₹${(o.grandTotalMinor / 100).toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700))),
          SizedBox(width: _colStatus, child: _Pill(status, statusColor)),
          SizedBox(
              width: _colPayment,
              child: Text(o.paymentLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: switch (o.paymentState) {
                        OrderPaymentState.paid => ViniiColors.greenSolid,
                        OrderPaymentState.pendingVerification =>
                          ViniiColors.amberSolid,
                        OrderPaymentState.unpaid =>
                          ViniiColors.textSecondaryLight,
                      }))),
          SizedBox(width: _colSync, child: _Pill(sync, syncColor)),
          SizedBox(
              width: _colTime,
              child: Text(time,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: ViniiColors.textMutedLight))),
          SizedBox(
            width: _colAction,
            child: TextButton(onPressed: onView, child: const Text('View')),
          ),
        ]));
  }
}
