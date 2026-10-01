// Rebuilt from v1/POS-DINE-IN-V3.png. The board shows every table with its
// real state: the floor status (available / reserved / cleaning) layered
// with where its current order is — waiting for the kitchen, preparing,
// ready, served, or payment pending once the bill is generated
// (deriveDineInBoardStatus in domain/operations.dart). "Order List" lists
// the open dine-in orders themselves.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/drift_operations_store.dart';
import '../data/drift_table_store.dart';
import '../data/local_dine_in_catalog.dart';
import '../domain/dine_in_status.dart';
import '../domain/operations.dart';
import 'operations/ops_pickers.dart';
import 'vinii_theme.dart';

class DineInScreen extends StatefulWidget {
  const DineInScreen(
      {super.key,
      this.tableStore,
      required this.onOpenOrder,
      required this.onStartOrder,
      this.ops,
      this.canTakePayments = true});

  final DriftTableStore? tableStore;

  /// Order data for the board. Built on [tableStore]'s database when null.
  final DriftOperationsStore? ops;

  /// Table has an order (or seated guests) — open it in the order screen,
  /// which loads the table's open order.
  final void Function(DineInTable table) onOpenOrder;

  /// Free / reserved table — start a new order there.
  final void Function(DineInTable table) onStartOrder;

  /// The signed-in role may collect money (cashier, owners, managers).
  /// Captains and waiters take orders only: the payment actions are hidden
  /// and the server refuses them as well.
  final bool canTakePayments;

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

enum _BoardView { tableView, orderList }

/// One table on the board.
class _BoardTable {
  const _BoardTable(this.table, this.order, this.status);
  final OpsTable table;
  final OpsOrder? order;
  final DineInBoardStatus status;
}

Color _statusColor(DineInBoardStatus s) => switch (s) {
      DineInBoardStatus.available => ViniiColors.greenSolid,
      DineInBoardStatus.reserved => ViniiColors.blueSolid,
      DineInBoardStatus.seated => ViniiColors.graySolid,
      DineInBoardStatus.waitingKot => ViniiColors.amberSolid,
      DineInBoardStatus.preparing => ViniiColors.amberSolid,
      DineInBoardStatus.ready => ViniiColors.greenSolid,
      DineInBoardStatus.served => ViniiColors.blueSolid,
      DineInBoardStatus.paymentPending => ViniiColors.purpleSolid,
      DineInBoardStatus.cleaning => ViniiColors.graySolid,
    };

String _rupees(int minor) => '₹${(minor / 100).toStringAsFixed(0)}';

class _DineInScreenState extends State<DineInScreen> {
  _BoardView _view = _BoardView.tableView;
  DriftOperationsStore? _ops;
  final _subs = <StreamSubscription<Object?>>[];
  List<OpsTable> _tables = const [];
  Map<String, OpsOrder> _orders = const {};
  List<OpsOrder> _openDineIn = const [];
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _connect();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant DineInScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableStore != widget.tableStore ||
        oldWidget.ops != widget.ops) {
      _connect();
    }
  }

  void _connect() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final db = widget.ops?.db ?? widget.tableStore?.db;
    _ops = widget.ops ?? (db == null ? null : DriftOperationsStore(db));
    final ops = _ops;
    if (ops == null) return;
    _subs
      ..add(ops.watchTables().listen((t) {
        if (mounted) setState(() => _tables = t);
      }))
      ..add(ops.watchOrders(openOnly: true).listen((o) {
        if (!mounted) return;
        setState(() {
          _orders = {for (final x in o) x.id: x};
          _openDineIn = [
            for (final x in o.reversed)
              if (x.channel == OpsChannel.dineIn) x
          ];
        });
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker?.cancel();
    super.dispose();
  }

  List<_BoardTable> get _board => [
        for (final t in _tables)
          () {
            final o =
                t.currentOrderId == null ? null : _orders[t.currentOrderId];
            return _BoardTable(t, o, deriveDineInBoardStatus(t.status, o));
          }(),
      ];

  /// The value the app's order callbacks take.
  DineInTable _callbackTable(OpsTable t, OpsOrder? o, DineInBoardStatus s) =>
      DineInTable(
          label: t.label,
          status: switch (s) {
            DineInBoardStatus.available ||
            DineInBoardStatus.reserved ||
            DineInBoardStatus.cleaning =>
              DineInTableStatus.available,
            DineInBoardStatus.seated ||
            DineInBoardStatus.waitingKot =>
              DineInTableStatus.waitingKot,
            DineInBoardStatus.preparing => DineInTableStatus.preparing,
            DineInBoardStatus.ready ||
            DineInBoardStatus.served =>
              DineInTableStatus.ready,
            DineInBoardStatus.paymentPending =>
              DineInTableStatus.paymentPending,
          },
          seats: t.seats,
          guestCount: t.guests ?? o?.guests,
          elapsedMinutes: t.elapsedMinutes(_now),
          orderTotalMinor: o?.grandTotalMinor);

  Future<void> _markAvailable(OpsTable t) async {
    final ops = _ops;
    if (ops == null) return;
    try {
      await ops.setTableStatus(t.id, OpsTableStatus.available);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.label} is available')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: ViniiColors.redSolid,
          content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    int count(bool Function(DineInBoardStatus) f) =>
        board.where((b) => f(b.status)).length;
    final active = count((s) =>
        s != DineInBoardStatus.available &&
        s != DineInBoardStatus.reserved &&
        s != DineInBoardStatus.cleaning);

    return Container(
        color: ViniiColors.lightPageBg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dine In Orders',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        _SummaryChip(
                            label: 'Active $active',
                            color: ViniiColors.graySolid),
                        for (final s in const [
                          DineInBoardStatus.waitingKot,
                          DineInBoardStatus.preparing,
                          DineInBoardStatus.ready,
                          DineInBoardStatus.paymentPending,
                          DineInBoardStatus.reserved,
                          DineInBoardStatus.cleaning,
                        ])
                          _SummaryChip(
                              label: '${s.label} ${count((x) => x == s)}',
                              color: _statusColor(s)),
                      ]),
                    ]),
              ),
              _ViewToggle(
                  value: _view, onChanged: (v) => setState(() => _view = v)),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: _view == _BoardView.tableView
                  ? _tableView(board)
                  : _orderList(),
            ),
          ]),
        ));
  }

  Widget _tableView(List<_BoardTable> board) {
    if (board.isEmpty) {
      return const Center(
          child: Text('No tables found. Add tables in the Tables module.',
              style: TextStyle(color: ViniiColors.textMutedLight)));
    }
    return LayoutBuilder(
      builder: (context, gridConstraints) {
        if (gridConstraints.maxWidth <= 0 || gridConstraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 200,
              crossAxisSpacing: 20,
              mainAxisSpacing: 24),
          itemCount: board.length,
          itemBuilder: (context, i) {
            final b = board[i];
            final cb = _callbackTable(b.table, b.order, b.status);
            return TableOrderCard(
                board: b.status,
                table: b.table,
                order: b.order,
                now: _now,
                onOpen: () => widget.onOpenOrder(cb),
                onStart: () => widget.onStartOrder(cb),
                onMarkAvailable: () => _markAvailable(b.table),
                canTakePayments: widget.canTakePayments);
          },
        );
      },
    );
  }

  Widget _orderList() {
    final orders = _openDineIn;
    if (orders.isEmpty) {
      return const Center(
          child: Text(
              'No open dine-in orders. Start one from a table in Table View.',
              style: TextStyle(color: ViniiColors.textMutedLight)));
    }
    return Container(
      decoration: BoxDecoration(
          color: ViniiColors.lightBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ViniiColors.lightBorder)),
      child: ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: ViniiColors.lightBorder),
        itemBuilder: (context, i) {
          final o = orders[i];
          final table =
              _tables.where((t) => t.currentOrderId == o.id).firstOrNull;
          final status = deriveDineInBoardStatus(
              table?.status ?? OpsTableStatus.occupied, o);
          final mins = _now.difference(o.createdAt).inMinutes;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              SizedBox(
                  width: 70,
                  child: Text(o.tableLabel ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15))),
              Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${o.number}${o.customerName.isEmpty ? '' : ' · ${o.customerName}'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          o.lines
                              .map((l) => '${l.quantity}× ${l.name}')
                              .join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: ViniiColors.textMutedLight)),
                    ]),
              ),
              Expanded(flex: 2, child: StatusChip(status: status)),
              Expanded(
                  flex: 2,
                  child: Text(o.paymentLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: o.paymentState ==
                                  OrderPaymentState.pendingVerification
                              ? ViniiColors.amberSolid
                              : ViniiColors.textSecondaryLight))),
              SizedBox(
                  width: 70,
                  child: Text('$mins min',
                      style: const TextStyle(
                          fontSize: 12, color: ViniiColors.textMutedLight))),
              SizedBox(
                  width: 80,
                  child: Text(_rupees(o.grandTotalMinor),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: table == null
                    ? const Text('Table released',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: ViniiColors.textMutedLight))
                    : OutlinedButton(
                        onPressed: () => widget
                            .onOpenOrder(_callbackTable(table, o, status)),
                        child: Text(status == DineInBoardStatus.paymentPending
                            ? (widget.canTakePayments
                                ? 'Collect Payment'
                                : 'View Bill')
                            : 'Open Order')),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(label,
      style:
          TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600));
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});
  final _BoardView value;
  final ValueChanged<_BoardView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: ViniiColors.grayTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ViniiColors.lightBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ToggleSegment(
            label: 'Table View',
            selected: value == _BoardView.tableView,
            onTap: () => onChanged(_BoardView.tableView)),
        _ToggleSegment(
            label: 'Order List',
            selected: value == _BoardView.orderList,
            onTap: () => onChanged(_BoardView.orderList)),
      ]));
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: selected ? ViniiColors.lightBg : null,
              borderRadius: BorderRadius.circular(6),
              boxShadow: selected
                  ? [const BoxShadow(color: Color(0x14000000), blurRadius: 3)]
                  : null),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? ViniiColors.textPrimaryLight
                      : ViniiColors.textMutedLight)),
        ),
      ));
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final DineInBoardStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(status.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class TableOrderCard extends StatelessWidget {
  const TableOrderCard(
      {super.key,
      required this.board,
      required this.table,
      required this.order,
      required this.now,
      required this.onOpen,
      required this.onStart,
      required this.onMarkAvailable,
      this.canTakePayments = true});
  final DineInBoardStatus board;
  final OpsTable table;
  final OpsOrder? order;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onMarkAvailable;
  final bool canTakePayments;

  Color? get _borderColor => switch (board) {
        DineInBoardStatus.waitingKot ||
        DineInBoardStatus.preparing =>
          ViniiColors.amberSolid,
        DineInBoardStatus.paymentPending => ViniiColors.purpleSolid,
        DineInBoardStatus.ready => ViniiColors.greenSolid,
        _ => null,
      };

  bool get _hasGuests =>
      board != DineInBoardStatus.available &&
      board != DineInBoardStatus.reserved &&
      board != DineInBoardStatus.cleaning;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final mins = table.elapsedMinutes(now);
    return Container(
        decoration: BoxDecoration(
            color: ViniiColors.lightBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: _borderColor ?? ViniiColors.lightBorder,
                width: _borderColor != null ? 1.4 : 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(table.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_outline,
                  size: 14, color: ViniiColors.textMutedLight),
              Text(
                  _hasGuests && table.guests != null
                      ? ' ${table.guests} Guests'
                      : ' ${table.seats} seats',
                  style: const TextStyle(
                      fontSize: 12, color: ViniiColors.textMutedLight)),
            ]),
          ]),
          const SizedBox(height: 8),
          StatusChip(status: board),
          const SizedBox(height: 10),
          Expanded(child: _details(o, mins)),
          SizedBox(width: double.infinity, child: _actionButton()),
        ]));
  }

  Widget _details(OpsOrder? o, int? mins) {
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k,
                style: const TextStyle(
                    fontSize: 12, color: ViniiColors.textMutedLight)),
            Flexible(
              child: Text(v,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        );
    switch (board) {
      case DineInBoardStatus.available:
        return const SizedBox.shrink();
      case DineInBoardStatus.cleaning:
        return const Text('Guests have left — mark it available once cleaned.',
            style: TextStyle(fontSize: 12, color: ViniiColors.textMutedLight));
      case DineInBoardStatus.reserved:
        final name = table.reservedByName;
        final at = table.reservedAt;
        return Text(
            [
              if (name != null && name.isNotEmpty) name,
              if (at != null) formatClock(at),
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ViniiColors.blueSolid));
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          kv('Elapsed', mins == null ? '—' : '$mins min'),
          kv('Order Total',
              o == null ? 'No order yet' : _rupees(o.grandTotalMinor)),
          if (o != null && o.status == OpsOrderStatus.billed)
            kv('Bill', o.billNo == null ? 'Generated' : '#${o.billNo}'),
        ]);
    }
  }

  Widget _actionButton() => switch (board) {
        DineInBoardStatus.available ||
        DineInBoardStatus.reserved =>
          FilledButton(
              onPressed: onStart,
              style:
                  FilledButton.styleFrom(
                      backgroundColor: ViniiColors.brandGreen,
                      foregroundColor: Colors.black),
              child: Text(
                  board == DineInBoardStatus.reserved
                      ? 'Seat & Start Order'
                      : 'Start Order',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        DineInBoardStatus.cleaning => OutlinedButton(
            onPressed: onMarkAvailable,
            style: OutlinedButton.styleFrom(
                foregroundColor: ViniiColors.greenSolid,
                side: const BorderSide(color: ViniiColors.greenSolid)),
            child: const Text('Mark Available',
                style: TextStyle(fontWeight: FontWeight.w700))),
        DineInBoardStatus.paymentPending => FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            child: Text(canTakePayments ? 'Collect Payment' : 'View Bill',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        DineInBoardStatus.seated => OutlinedButton(
            onPressed: onOpen,
            child: const Text('Take Order',
                style: TextStyle(fontWeight: FontWeight.w700))),
        _ => OutlinedButton(
            onPressed: onOpen,
            style: OutlinedButton.styleFrom(
                foregroundColor: _statusColor(board),
                side: BorderSide(color: _statusColor(board))),
            child: const Text('Open Order',
                style: TextStyle(fontWeight: FontWeight.w700))),
      };
}
