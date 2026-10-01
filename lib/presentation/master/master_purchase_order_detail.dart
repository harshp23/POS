import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_inventory_store.dart';
import '../../domain/inventory.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// CSV columns shared by the PO list export/import and the single-PO
/// export: one row per PO line.
const purchaseOrderCsvHeaders = <String>[
  'po_number',
  'supplier_id',
  'order_date',
  'expected_delivery',
  'status',
  'tax_pct',
  'material_id',
  'material_name',
  'code',
  'unit',
  'unit_cost',
  'ordered_qty',
  'received_qty',
];

/// One CSV row per line of each order in [orders].
List<List<Object?>> purchaseOrderCsvRows(Iterable<PurchaseOrder> orders) => [
      for (final o in orders)
        if (o.lines.isEmpty)
          [
            o.number,
            o.supplierId,
            o.orderDate,
            o.expectedDelivery,
            o.status.label,
            o.taxPct,
            '',
            '',
            '',
            '',
            '',
            '',
            '',
          ]
        else
          for (final l in o.lines)
            [
              o.number,
              o.supplierId,
              o.orderDate,
              o.expectedDelivery,
              o.status.label,
              o.taxPct,
              l.materialId ?? '',
              l.materialName,
              l.code,
              l.unit,
              l.unitCost,
              l.orderedQty,
              l.receivedQty,
            ],
    ];

/// "2026-09-27" for export file names.
String purchaseOrderFileDate() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// True once any stock has been received or rejected against [po] — it can
/// then no longer be edited or deleted.
bool purchaseOrderHasReceipts(PurchaseOrder po) =>
    po.lines.any((l) => l.receivedQty > 0 || l.rejectedQty > 0);

/// Master → Purchase Orders → PO detail (Figma "purchase-order-detail"
/// 385:57608): header with Approve / Cancel PO / Receive Stock, supplier
/// information, delivery address, raw-material line items with totals, and
/// the approval timeline derived from the PO status. Reads the order live
/// from [inventory], so edits and goods receipts show immediately.
class MasterPurchaseOrderDetail extends StatefulWidget {
  const MasterPurchaseOrderDetail({
    super.key,
    required this.inventory,
    required this.poNumber,
    required this.onBack,
    required this.onReceiveStock,
    required this.onEdit,
  });

  final DriftInventoryStore inventory;
  final String poNumber;
  final VoidCallback onBack;
  final VoidCallback onReceiveStock;
  final ValueChanged<PurchaseOrder> onEdit;

  @override
  State<MasterPurchaseOrderDetail> createState() =>
      _MasterPurchaseOrderDetailState();
}

class _MasterPurchaseOrderDetailState extends State<MasterPurchaseOrderDetail> {
  StreamSubscription<List<PurchaseOrder>>? _poSub;
  StreamSubscription<List<InventorySupplier>>? _supplierSub;
  PurchaseOrder? _order;
  bool _loaded = false;
  List<InventorySupplier> _suppliers = const [];

  @override
  void initState() {
    super.initState();
    _poSub = widget.inventory.watchPurchaseOrders().listen((orders) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _order = orders.where((o) => o.number == widget.poNumber).firstOrNull;
      });
    });
    // Archived suppliers included: an old order still names its supplier.
    _supplierSub = widget.inventory.watchAllSuppliers().listen((s) {
      if (mounted) setState(() => _suppliers = s);
    });
  }

  @override
  void dispose() {
    _poSub?.cancel();
    _supplierSub?.cancel();
    super.dispose();
  }

  static bool _canReceive(PurchaseOrder o) => const {
        PurchaseOrderStatus.pending,
        PurchaseOrderStatus.approved,
        PurchaseOrderStatus.partiallyReceived,
      }.contains(o.status);

  static bool _canCancel(PurchaseOrder o) =>
      o.status != PurchaseOrderStatus.received &&
      o.status != PurchaseOrderStatus.cancelled;

  Future<void> _approve(PurchaseOrder o) async {
    await runMasterAction(
        context,
        () => widget.inventory
            .setPurchaseOrderStatus(o.number, PurchaseOrderStatus.approved),
        success: '${o.number} approved');
  }

  Future<void> _submit(PurchaseOrder o) async {
    await runMasterAction(
        context,
        () => widget.inventory
            .setPurchaseOrderStatus(o.number, PurchaseOrderStatus.pending),
        success: '${o.number} submitted for approval');
  }

  Future<void> _cancel(PurchaseOrder o) async {
    if (!_canCancel(o)) {
      showMasterNotice(context,
          '${o.number} is ${o.status.label.toLowerCase()} and can no longer be cancelled');
      return;
    }
    final ok = await confirmMasterAction(context,
        title: 'Cancel ${o.number}?',
        message: purchaseOrderHasReceipts(o)
            ? 'Stock already received stays in inventory; the remaining quantity will no longer be expected.'
            : 'No stock will be received against this purchase order.',
        confirmLabel: 'Cancel PO');
    if (!ok || !mounted) return;
    await runMasterAction(
        context,
        () => widget.inventory
            .setPurchaseOrderStatus(o.number, PurchaseOrderStatus.cancelled),
        success: '${o.number} cancelled');
  }

  void _edit(PurchaseOrder o) {
    if (purchaseOrderHasReceipts(o)) {
      showMasterNotice(context,
          '${o.number} has already received stock and can no longer be edited');
      return;
    }
    widget.onEdit(o);
  }

  void _receive(PurchaseOrder o) {
    if (_canReceive(o)) {
      widget.onReceiveStock();
    } else {
      showMasterNotice(
          context,
          o.status == PurchaseOrderStatus.draft
              ? '${o.number} is a draft — submit it before receiving stock'
              : '${o.number} is ${o.status.label.toLowerCase()} — nothing left to receive');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return MasterPage(children: [
        MasterBackLink(label: 'Back to Purchase Orders', onTap: widget.onBack),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: _loaded
                ? Text('${widget.poNumber} no longer exists.',
                    style: MasterStyle.muted)
                : const CircularProgressIndicator(),
          ),
        ),
      ]);
    }
    final supplier =
        _suppliers.where((s) => s.id == order.supplierId).firstOrNull;
    Widget dimmed(bool enabled, Widget child) =>
        enabled ? child : Opacity(opacity: 0.5, child: child);
    return MasterPage(children: [
      MasterBackLink(label: 'Back to Purchase Orders', onTap: widget.onBack),
      MasterPageHeader(
        title: order.number,
        titleTrailing: MasterStatusPill(order.status.label),
        subtitle: 'Ordered on ${order.orderDate} · Created by '
            '${order.createdBy.trim().isEmpty ? '—' : order.createdBy}',
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ViniiColors.grayTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MasterStyle.cardBorder),
          ),
          child: const Icon(Icons.description_outlined,
              size: 24, color: ViniiColors.textSecondaryLight),
        ),
        actions: [
          MasterButton(
            label: 'Export CSV',
            icon: Icons.download_outlined,
            onPressed: () => exportCsv(context,
                fileName:
                    'purchase-order-${order.number}-${purchaseOrderFileDate()}.csv',
                headers: purchaseOrderCsvHeaders,
                rows: purchaseOrderCsvRows([order])),
          ),
          dimmed(
            !purchaseOrderHasReceipts(order),
            MasterButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: () => _edit(order),
            ),
          ),
          if (order.status == PurchaseOrderStatus.draft)
            MasterButton(
              label: 'Submit for Approval',
              onPressed: () => _submit(order),
            ),
          if (order.status == PurchaseOrderStatus.pending)
            MasterButton(
              label: 'Approve',
              icon: Icons.check,
              onPressed: () => _approve(order),
            ),
          dimmed(
            _canCancel(order),
            MasterButton(
              label: 'Cancel PO',
              kind: MasterButtonKind.dangerOutline,
              onPressed: () => _cancel(order),
            ),
          ),
          dimmed(
            _canReceive(order),
            MasterButton(
              label: 'Receive Stock',
              kind: MasterButtonKind.primary,
              onPressed: () => _receive(order),
            ),
          ),
        ],
      ),
      LayoutBuilder(builder: (context, c) {
        final left =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SupplierCard(order: order, supplier: supplier),
          const SizedBox(height: 24),
          _LineItemsCard(order: order),
        ]);
        final right = _TimelineCard(order: order);
        if (c.maxWidth < 860) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 24), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 692, child: left),
          const SizedBox(width: 24),
          Expanded(flex: 380, child: right),
        ]);
      }),
    ]);
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.order, required this.supplier});
  final PurchaseOrder order;
  final InventorySupplier? supplier;

  @override
  Widget build(BuildContext context) {
    Widget block(String label, String value, String caption) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: MasterStyle.label),
              const SizedBox(height: 4),
              Text(value, style: MasterStyle.value),
              const SizedBox(height: 4),
              Text(caption, style: MasterStyle.muted),
            ]);
    final s = supplier;
    final details = s == null
        ? const <String>[]
        : [
            if (s.city.isNotEmpty) s.city,
            if (s.gstin.isNotEmpty) 'GSTIN: ${s.gstin}',
            if (s.contactPerson.isNotEmpty) s.contactPerson,
            if (s.phone.isNotEmpty) s.phone,
          ];
    return MasterSection(
      title: 'Supplier Information',
      child: MasterGrid(columns: 2, spacing: 32, minItemWidth: 240, children: [
        s == null
            ? block('Supplier Name', 'Unknown supplier',
                'This supplier record is missing')
            : block(
                'Supplier Name',
                s.active ? s.legalName : '${s.legalName} (archived)',
                details.isEmpty ? 'No contact details saved' : details.join(' · ')),
        block(
            'Delivery Address',
            order.deliveryAddress.isEmpty ? '—' : order.deliveryAddress,
            [
              order.deliveryCity,
              'Expected ${order.expectedDelivery}',
            ].where((e) => e.isNotEmpty).join(' · ')),
      ]),
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  const _LineItemsCard({required this.order});
  final PurchaseOrder order;

  static String _qty(double q, String unit) {
    final s = q == q.roundToDouble() ? q.toStringAsFixed(0) : '$q';
    return '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    Widget totalRow(String label, String value, {bool strong = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: strong
                        ? MasterStyle.value
                        : MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600))),
            Text(value,
                style: strong
                    ? MasterStyle.value
                    : MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
          ]),
        );
    return MasterSection(
      title: 'Line Items (Raw Materials)',
      child: MasterTable(
        minWidth: 600,
        columns: const [
          MasterColumn('Raw Material', flex: 232),
          MasterColumn('Unit Cost', flex: 110),
          MasterColumn('Ordered', flex: 100),
          MasterColumn('Received', flex: 120),
          MasterColumn('Total', flex: 120),
        ],
        rows: [
          for (final l in order.lines)
            [
              MasterCellTitle(l.materialName,
                  subtitle: l.code.isEmpty ? null : l.code),
              MasterCellText(formatInr(l.unitCost)),
              MasterCellText(_qty(l.orderedQty, l.unit)),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MasterCellText(_qty(l.receivedQty, l.unit),
                        color: l.receivedQty + l.rejectedQty >= l.orderedQty
                            ? ViniiColors.greenSolid
                            : null),
                    if (l.rejectedQty > 0)
                      Text('${_qty(l.rejectedQty, l.unit)} rejected',
                          overflow: TextOverflow.ellipsis,
                          style: MasterStyle.muted
                              .copyWith(color: ViniiColors.redSolid)),
                  ]),
              MasterCellText(formatInr(l.total), bold: true),
            ],
        ],
        footer: Column(children: [
          if (order.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('This order has no line items.',
                  style: MasterStyle.muted),
            ),
          totalRow('Subtotal', formatInr(order.subtotal),
              strong: order.taxPct == 0),
          if (order.taxPct > 0) ...[
            totalRow('Tax (${_pct(order.taxPct)}%)', formatInr(order.tax)),
            totalRow('Total', formatInr(order.total), strong: true),
          ],
          if (order.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Notes: ${order.notes}', style: MasterStyle.muted),
              ),
            ),
        ]),
      ),
    );
  }
}

String _pct(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _TimelineStep {
  const _TimelineStep(this.title, this.lines, {this.done = true});
  final String title;
  final List<String> lines;
  final bool done;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});
  final PurchaseOrder order;

  List<_TimelineStep> get _steps {
    final created = _TimelineStep('PO Draft Created', [
      'Created by ${order.createdBy.trim().isEmpty ? '—' : order.createdBy}',
      'Ordered on ${order.orderDate}',
    ]);
    final receivedQty =
        order.lines.fold<double>(0, (s, l) => s + l.receivedQty);
    final orderedQty = order.lines.fold<double>(0, (s, l) => s + l.orderedQty);
    final receivedValue =
        order.lines.fold<double>(0, (s, l) => s + l.receivedQty * l.unitCost);
    final hasReceipts = purchaseOrderHasReceipts(order);
    return switch (order.status) {
      PurchaseOrderStatus.draft => [
          created,
          const _TimelineStep('Submit for Approval',
              ['Draft not yet submitted', 'Pending Action'],
              done: false),
        ],
      PurchaseOrderStatus.pending => [
          created,
          const _TimelineStep('Submitted for Approval', ['Sent to manager']),
          const _TimelineStep('Awaiting Approval',
              ['Manager Review Required', 'Pending Action'],
              done: false),
        ],
      PurchaseOrderStatus.approved => [
          created,
          const _TimelineStep('Approved', ['Ready for delivery']),
          _TimelineStep('Awaiting Delivery',
              ['Expected ${order.expectedDelivery}', 'Pending Action'],
              done: false),
        ],
      PurchaseOrderStatus.partiallyReceived => [
          created,
          const _TimelineStep('Approved', ['Ready for delivery']),
          _TimelineStep('Partially Received', [
            '${_pct(receivedQty)} of ${_pct(orderedQty)} units received',
            '${formatInr(receivedValue)} added to stock',
          ]),
          const _TimelineStep('Balance Pending',
              ['Remaining quantity to be received', 'Pending Action'],
              done: false),
        ],
      PurchaseOrderStatus.received => [
          created,
          const _TimelineStep('Approved', ['Ready for delivery']),
          _TimelineStep('Stock Received', [
            'Goods receipt posted to inventory',
            '${formatInr(receivedValue)} received',
          ]),
        ],
      PurchaseOrderStatus.cancelled => [
          created,
          _TimelineStep('PO Cancelled', [
            hasReceipts
                ? '${formatInr(receivedValue)} received before cancelling'
                : 'No stock will be received',
          ]),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return MasterSection(
      title: 'Approval Timeline',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 16,
                child: Column(children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          steps[i].done ? ViniiColors.greenSolid : Colors.white,
                      border: Border.all(
                          width: 2,
                          color: steps[i].done
                              ? ViniiColors.greenSolid
                              : ViniiColors.amberSolid),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: MasterStyle.cardBorder),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(bottom: i < steps.length - 1 ? 16 : 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: MasterStyle.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        for (var j = 0; j < steps[i].lines.length; j++) ...[
                          const SizedBox(height: 2),
                          Text(steps[i].lines[j],
                              style: j == steps[i].lines.length - 1 &&
                                      !steps[i].done
                                  ? MasterStyle.muted.copyWith(
                                      color: ViniiColors.amberSolid,
                                      fontWeight: FontWeight.w600)
                                  : MasterStyle.muted),
                        ],
                      ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
