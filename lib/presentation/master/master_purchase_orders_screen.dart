import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/drift_inventory_store.dart';
import '../../domain/inventory.dart';
import '../../domain/vendor_account.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_purchase_order_detail.dart';
import 'master_receiving_grn.dart';
import 'master_ui.dart';

enum _PoView { list, detail, receiving }

/// Master → Purchase Orders hub (Figma "purchase-orders" 385:57282).
/// Hosts three in-place views: the PO list, a PO detail, and the Goods
/// Receipt Note used to receive stock against a PO. Everything is read
/// live from the common inventory store ([DriftInventoryStore]).
class MasterPurchaseOrdersScreen extends StatefulWidget {
  const MasterPurchaseOrdersScreen({
    super.key,
    required this.inventory,
    this.currentUserName,
    this.branches = const [],
  });

  final DriftInventoryStore inventory;

  /// The signed-in person, recorded as "Created by" on new orders. Null or
  /// empty leaves it blank (shown as "—").
  final String? currentUserName;

  /// The restaurant's branches, offered as delivery addresses in the form.
  final List<BranchLocation> branches;

  @override
  State<MasterPurchaseOrdersScreen> createState() =>
      _MasterPurchaseOrdersScreenState();
}

class _MasterPurchaseOrdersScreenState
    extends State<MasterPurchaseOrdersScreen> {
  static const _statusAll = 'All';
  static const _statusOpen = 'All Open';
  static const _supplierAll = 'All';

  _PoView _view = _PoView.list;
  String? _selected;

  String _query = '';
  String _status = _statusAll;
  String _supplier = _supplierAll;

  final _subs = <StreamSubscription<Object?>>[];
  List<PurchaseOrder> _orders = const [];

  /// Every supplier, archived included (for naming old orders).
  List<InventorySupplier> _allSuppliers = const [];
  List<RawMaterial> _materials = const [];
  bool _ordersLoaded = false;

  /// In-memory GRN drafts ("Save Draft"), keyed by PO number.
  final _grnDrafts = <String, GrnDraft>{};

  DriftInventoryStore get _store => widget.inventory;

  /// Suppliers that can still be ordered from.
  List<InventorySupplier> get _suppliers =>
      [for (final s in _allSuppliers) if (s.active) s];

  String get _createdBy => widget.currentUserName?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_store.watchPurchaseOrders().listen((o) {
        if (mounted) {
          setState(() {
            _orders = o;
            _ordersLoaded = true;
          });
        }
      }))
      ..add(_store.watchAllSuppliers().listen((s) {
        if (mounted) setState(() => _allSuppliers = s);
      }))
      ..add(_store.watchMaterials().listen((m) {
        if (mounted) setState(() => _materials = m);
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Open = still expecting stock (drafts are not yet orders).
  static bool _isOpen(PurchaseOrder o) => const {
        PurchaseOrderStatus.pending,
        PurchaseOrderStatus.approved,
        PurchaseOrderStatus.partiallyReceived,
      }.contains(o.status);

  static bool _canDelete(PurchaseOrder o) =>
      const {
        PurchaseOrderStatus.draft,
        PurchaseOrderStatus.pending,
        PurchaseOrderStatus.cancelled,
      }.contains(o.status) &&
      !o.lines.any((l) => l.receivedQty > 0);

  InventorySupplier? _supplierOf(String id) =>
      _allSuppliers.where((s) => s.id == id).firstOrNull;

  String _supplierName(String id) => supplierLabel(_allSuppliers, id);

  List<PurchaseOrder> get _filtered {
    final q = _query.trim().toLowerCase();
    return _orders.where((o) {
      final s = _supplierOf(o.supplierId);
      if (q.isNotEmpty &&
          !o.number.toLowerCase().contains(q) &&
          !(s?.name.toLowerCase().contains(q) ?? false) &&
          !(s?.legalName.toLowerCase().contains(q) ?? false) &&
          !o.supplierId.toLowerCase().contains(q)) {
        return false;
      }
      if (_status == _statusOpen && !_isOpen(o)) return false;
      if (_status != _statusAll &&
          _status != _statusOpen &&
          o.status.label != _status) {
        return false;
      }
      if (_supplier != _supplierAll &&
          _supplierName(o.supplierId) != _supplier) {
        return false;
      }
      return true;
    }).toList();
  }

  void _open(PurchaseOrder o) => setState(() {
        _selected = o.number;
        _view = _PoView.detail;
        _query = '';
      });

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _openForm(
      {PurchaseOrder? existing, bool fromLowStock = false}) async {
    if (existing != null && purchaseOrderHasReceipts(existing)) {
      showMasterNotice(context,
          '${existing.number} has already received stock and can no longer be edited');
      return;
    }
    if (_suppliers.isEmpty) {
      showMasterError(context, 'Add a supplier first (Master → Suppliers).');
      return;
    }
    if (fromLowStock &&
        !_materials.any((m) =>
            m.status != StockStatus.inStock &&
            m.preferredSupplierId.isNotEmpty)) {
      showMasterNotice(context,
          'No low-stock materials with a preferred supplier — nothing to reorder');
      return;
    }
    final number = existing?.number ?? await _store.nextPoNumber();
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PurchaseOrderForm(
        inventory: _store,
        number: number,
        existing: existing,
        suppliers: _suppliers,
        materials: _materials,
        prefillLowStock: fromLowStock,
        branches: widget.branches,
        createdBy: _createdBy,
      ),
    );
  }

  Future<void> _delete(PurchaseOrder o) async {
    if (!_canDelete(o)) {
      showMasterNotice(context,
          '${o.number} is ${o.status.label.toLowerCase()} — cancel it instead of deleting');
      return;
    }
    final ok = await confirmMasterAction(context,
        title: 'Delete ${o.number}?',
        message:
            'The purchase order and its ${o.lines.length} line(s) will be removed permanently.');
    if (!ok || !mounted) return;
    await runMasterAction(context, () => _store.deletePurchaseOrder(o.number),
        success: '${o.number} deleted');
  }

  Future<void> _export(List<PurchaseOrder> rows) => exportCsv(context,
      fileName: 'purchase-orders-${purchaseOrderFileDate()}.csv',
      headers: purchaseOrderCsvHeaders,
      rows: purchaseOrderCsvRows(rows));

  Future<void> _import() async {
    final records = await pickCsv(context);
    if (records == null || !mounted) return;
    final summary = ImportSummary();
    final groups = <String, List<CsvRecord>>{};
    for (final r in records) {
      final n = r('po_number');
      if (n.isEmpty) {
        summary.errors.add('Line ${r.line}: po_number is required');
        continue;
      }
      groups.putIfAbsent(n, () => []).add(r);
    }
    final existingByNumber = {for (final o in _orders) o.number: o};
    final supplierIds = {for (final s in _suppliers) s.id};
    RawMaterial? findMaterial(CsvRecord r) {
      final id = r('material_id'), code = r('code'), name = r('material_name');
      return _materials.where((m) => id.isNotEmpty && m.id == id).firstOrNull ??
          _materials
              .where((m) => code.isNotEmpty && m.code == code)
              .firstOrNull ??
          _materials
              .where((m) =>
                  name.isNotEmpty && m.name.toLowerCase() == name.toLowerCase())
              .firstOrNull;
    }

    for (final entry in groups.entries) {
      final number = entry.key;
      final rows = entry.value;
      final first = rows.first;
      final existing = existingByNumber[number];
      if (existing != null && purchaseOrderHasReceipts(existing)) {
        summary.errors.add(
            'Line ${first.line}: $number has already received stock and can no longer be edited — skipped');
        continue;
      }
      final errs = <String>[];
      final supplierId = first('supplier_id');
      if (supplierId.isEmpty) {
        errs.add('Line ${first.line}: supplier_id is required');
      } else if (!supplierIds.contains(supplierId)) {
        errs.add('Line ${first.line}: unknown supplier_id "$supplierId"');
      }
      DateTime? date(String col, DateTime fallback) {
        final raw = first(col);
        if (raw.isEmpty) return fallback;
        DateTime? d;
        try {
          d = parseShortDate(raw);
        } catch (_) {
          d = null;
        }
        if (d == null) {
          errs.add('Line ${first.line}: $col "$raw" is not a date');
        }
        return d;
      }

      final orderDate = date('order_date', DateTime.now());
      final expected = date('expected_delivery', orderDate ?? DateTime.now());
      final statusRaw = first('status');
      final status = statusRaw.isEmpty
          ? PurchaseOrderStatus.draft
          : PurchaseOrderStatus.values
              .where((s) => s.label.toLowerCase() == statusRaw.toLowerCase())
              .firstOrNull;
      if (status == null) {
        errs.add('Line ${first.line}: unknown status "$statusRaw"');
      } else if (status == PurchaseOrderStatus.received ||
          status == PurchaseOrderStatus.partiallyReceived) {
        errs.add(
            'Line ${first.line}: status "${status.label}" can only be reached by posting a goods receipt');
      }
      final taxPct = first.number('tax_pct') ?? existing?.taxPct ?? 0;
      if (taxPct < 0 || taxPct > 100) {
        errs.add('Line ${first.line}: tax_pct must be between 0 and 100');
      }
      final lines = <PurchaseOrderLine>[];
      for (final r in rows) {
        if (!r.has('material_id') &&
            !r.has('material_name') &&
            !r.has('code') &&
            !r.has('ordered_qty')) {
          continue; // order-only row (PO exported without lines)
        }
        final m = findMaterial(r);
        final name = r('material_name', m?.name ?? '');
        final unit = r('unit', m?.unit ?? '');
        final cost = r.number('unit_cost') ?? m?.purchaseCostPerUnit;
        final qty = r.number('ordered_qty');
        final received = r.number('received_qty') ?? 0;
        if (name.isEmpty) {
          errs.add('Line ${r.line}: material_name is required');
        } else if (unit.isEmpty) {
          errs.add('Line ${r.line}: unit is required');
        } else if (cost == null || cost < 0) {
          errs.add('Line ${r.line}: unit_cost must be a number ≥ 0');
        } else if (qty == null || qty <= 0) {
          errs.add('Line ${r.line}: ordered_qty must be greater than 0');
        } else if (received > 0) {
          errs.add(
              'Line ${r.line}: received_qty must be recorded through a goods receipt (GRN), not an import');
        } else {
          lines.add(PurchaseOrderLine(
            materialId: m?.id,
            materialName: name,
            code: r('code', m?.code ?? ''),
            unit: unit,
            unitCost: cost,
            orderedQty: qty,
          ));
        }
      }
      if (lines.isEmpty && errs.isEmpty) {
        errs.add('Line ${first.line}: $number has no line items');
      }
      if (errs.isNotEmpty) {
        summary.errors.addAll(errs);
        continue;
      }
      final po = PurchaseOrder(
        number: number,
        supplierId: supplierId,
        orderDate: formatShortDate(orderDate!),
        expectedDelivery: formatShortDate(expected!),
        status: status!,
        lines: lines,
        // The person importing raised the order; an update keeps its creator.
        createdBy: existing?.createdBy ?? _createdBy,
        deliveryAddress: existing?.deliveryAddress ??
            (widget.branches.length == 1 ? widget.branches.first.name : ''),
        deliveryCity: existing?.deliveryCity ?? '',
        taxPct: taxPct,
        notes: existing?.notes ?? '',
      );
      try {
        await _store.savePurchaseOrder(po);
        if (existing == null) {
          summary.added++;
        } else {
          summary.updated++;
        }
      } catch (e) {
        final why = masterErrorMessage(e,
            fallback: '$number could not be saved. Check the row and try again.');
        summary.errors.add('Line ${first.line}: $why');
      }
    }
    if (mounted) showImportSummary(context, summary);
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (_view == _PoView.detail && selected != null) {
      return MasterPurchaseOrderDetail(
        key: ValueKey('po-detail-$selected'),
        inventory: _store,
        poNumber: selected,
        onBack: () => setState(() => _view = _PoView.list),
        onReceiveStock: () => setState(() => _view = _PoView.receiving),
        onEdit: (o) => _openForm(existing: o),
      );
    }
    if (_view == _PoView.receiving && selected != null) {
      return MasterReceivingGrn(
        key: ValueKey('po-grn-$selected'),
        inventory: _store,
        poNumber: selected,
        draft: _grnDrafts[selected],
        onSaveDraft: (d) => _grnDrafts[selected] = d,
        onBack: () => setState(() => _view = _PoView.detail),
        onPosted: (grnId) {
          _grnDrafts.remove(selected);
          showMasterNotice(context,
              '$grnId posted for $selected — raw-material stock updated');
          setState(() => _view = _PoView.detail);
        },
      );
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final orders = _orders;
    final lowStock =
        _materials.where((m) => m.status != StockStatus.inStock).toList();
    final lowStockSuppliers = lowStock
        .map((m) => m.preferredSupplierId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final open = orders.where(_isOpen).toList();
    final openValue = open.fold<double>(0, (s, o) => s + o.total);
    final received =
        orders.where((o) => o.status == PurchaseOrderStatus.received).toList();
    final receivedValue = received.fold<double>(0, (s, o) => s + o.total);

    final supplierNames = <String>{
      for (final s in _suppliers) s.name,
      for (final o in orders) _supplierName(o.supplierId),
    }.toList()
      ..sort();
    final rows = _filtered;

    return MasterPage(children: [
      MasterPageHeader(
        title: 'Purchase Orders',
        subtitle:
            'Procure raw materials from certified suppliers, track delivery states, and auto-update inventory.',
        actions: [
          MasterButton(
            label: 'Import CSV',
            icon: Icons.upload_outlined,
            onPressed: _import,
          ),
          MasterButton(
            label: 'Export CSV',
            icon: Icons.download_outlined,
            onPressed: () => _export(rows),
          ),
          MasterButton(
            label: 'Create from Low Stock',
            icon: Icons.auto_fix_high_outlined,
            onPressed: () => _openForm(fromLowStock: true),
          ),
          MasterButton(
            label: '+ Add Purchase Order',
            kind: MasterButtonKind.primary,
            onPressed: () => _openForm(),
          ),
        ],
      ),
      MasterGrid(columns: 3, children: [
        MasterStatCard(
          label: 'Low Stock Materials',
          value:
              '${lowStock.length} ${lowStock.length == 1 ? 'Item' : 'Items'}',
          caption:
              'Sourced from $lowStockSuppliers ${lowStockSuppliers == 1 ? 'supplier' : 'suppliers'}',
        ),
        MasterStatCard(
          label: 'Open POs',
          value: '${open.length} Open',
          caption: 'Estimated value ${formatInr(openValue, decimals: 0)}',
        ),
        MasterStatCard(
          label: 'Received',
          value:
              '${received.length} ${received.length == 1 ? 'Order' : 'Orders'}',
          caption: '${formatInr(receivedValue, decimals: 0)} processed',
        ),
      ]),
      const SizedBox(height: 24),
      MasterFilterBar(children: [
        MasterSearchField(
          hint: 'Filter by PO number or supplier name...',
          width: 420,
          onChanged: (v) => setState(() => _query = v),
        ),
        MasterFilterButton(
          label: 'Status: $_status',
          options: [
            _statusAll,
            _statusOpen,
            for (final s in PurchaseOrderStatus.values) s.label,
          ],
          onSelected: (v) => setState(() => _status = v),
        ),
        MasterFilterButton(
          label: 'Supplier: $_supplier',
          options: [_supplierAll, ...supplierNames],
          onSelected: (v) => setState(() => _supplier = v),
        ),
      ]),
      const SizedBox(height: 24),
      MasterTable(
        minWidth: 1040,
        columns: const [
          MasterColumn('PO Number', flex: 10),
          MasterColumn('Supplier', flex: 12),
          MasterColumn('Order Date', flex: 10),
          MasterColumn('Expected Delivery', flex: 11),
          MasterColumn('Materials Listed', flex: 15),
          MasterColumn('Total', flex: 9),
          MasterColumn('Status', flex: 12),
          MasterColumn('Actions', flex: 12),
        ],
        onRowTap: (i) => _open(rows[i]),
        rows: [
          for (final o in rows)
            [
              MasterCellText(o.number, bold: true),
              MasterCellTitle(_supplierName(o.supplierId)),
              MasterCellText(o.orderDate),
              MasterCellText(o.expectedDelivery),
              Text(o.materialsListed.isEmpty ? '—' : o.materialsListed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MasterStyle.body),
              MasterCellText(formatInr(o.total), bold: true),
              MasterStatusPill(o.status.label),
              MasterRowActions([
                'View',
                if (!purchaseOrderHasReceipts(o)) 'Edit',
                if (_canDelete(o)) 'Delete',
              ], onTap: (a) {
                switch (a) {
                  case 'View':
                    _open(o);
                  case 'Edit':
                    _openForm(existing: o);
                  case 'Delete':
                    _delete(o);
                }
              }),
            ],
        ],
        footer: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: !_ordersLoaded
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          orders.isEmpty
                              ? 'No purchase orders yet — use "+ Add Purchase Order" to create one.'
                              : 'No purchase orders match these filters.',
                          style: MasterStyle.muted),
                ),
              )
            : null,
      ),
    ]);
  }
}

// -------------------------------------------------------------------------
// Purchase order form (add / edit)
// -------------------------------------------------------------------------

class _LineDraft {
  _LineDraft({
    this.materialId,
    this.materialName = '',
    this.code = '',
    this.unit = '',
    double? qty,
    double? cost,
  })  : qty = TextEditingController(text: qty == null ? '' : _fmt(qty)),
        cost = TextEditingController(text: cost == null ? '' : _fmt(cost));

  String? materialId;
  String materialName;
  String code;
  String unit;
  final TextEditingController qty;
  final TextEditingController cost;

  double get qtyValue => double.tryParse(qty.text.trim()) ?? 0;
  double get costValue => double.tryParse(cost.text.trim()) ?? 0;
  double get total => qtyValue * costValue;

  void setMaterial(RawMaterial m) {
    materialId = m.id;
    materialName = m.name;
    code = m.code;
    unit = m.unit;
    cost.text = _fmt(m.purchaseCostPerUnit);
  }

  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(3);
  return s.replaceFirst(RegExp(r'0+$'), '');
}

class _PurchaseOrderForm extends StatefulWidget {
  const _PurchaseOrderForm({
    required this.inventory,
    required this.number,
    required this.existing,
    required this.suppliers,
    required this.materials,
    required this.prefillLowStock,
    required this.branches,
    required this.createdBy,
  });

  final DriftInventoryStore inventory;
  final String number;
  final PurchaseOrder? existing;
  final List<InventorySupplier> suppliers;
  final List<RawMaterial> materials;
  final bool prefillLowStock;
  final List<BranchLocation> branches;

  /// Recorded as "Created by" on a new order.
  final String createdBy;

  @override
  State<_PurchaseOrderForm> createState() => _PurchaseOrderFormState();
}

class _PurchaseOrderFormState extends State<_PurchaseOrderForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _tax;
  late final TextEditingController _notes;
  String? _supplierId;
  late DateTime _orderDate;
  late DateTime _expected;
  final _lines = <_LineDraft>[];
  String? _linesMessage;
  bool _linesMessageIsError = false;
  bool _saving = false;

  /// Branch whose name was put into the delivery address (null = typed).
  String? _branchId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // A new order defaults to the only branch, if there is exactly one.
    final onlyBranch =
        e == null && widget.branches.length == 1 ? widget.branches.first : null;
    _branchId = onlyBranch?.id ??
        (e == null
            ? null
            : widget.branches
                .where((b) => b.name == e.deliveryAddress)
                .firstOrNull
                ?.id);
    _address = TextEditingController(
        text: e?.deliveryAddress ?? onlyBranch?.name ?? '');
    _city = TextEditingController(text: e?.deliveryCity ?? '');
    _tax = TextEditingController(text: _fmt(e?.taxPct ?? 5));
    _notes = TextEditingController(text: e?.notes ?? '');
    final today = DateTime.now();
    _orderDate = (e == null ? null : parseShortDate(e.orderDate)) ??
        DateTime(today.year, today.month, today.day);
    _expected = (e == null ? null : parseShortDate(e.expectedDelivery)) ??
        _orderDate.add(const Duration(days: 3));
    if (e != null) {
      if (widget.suppliers.any((s) => s.id == e.supplierId)) {
        _supplierId = e.supplierId;
      }
      for (final l in e.lines) {
        final m = _materialFor(l);
        _lines.add(_LineDraft(
          materialId: m?.id ?? l.materialId,
          materialName: l.materialName,
          code: l.code,
          unit: l.unit,
          qty: l.orderedQty,
          cost: l.unitCost,
        ));
      }
    } else if (widget.prefillLowStock) {
      // Start with the supplier that has the most low-stock materials.
      final counts = <String, int>{};
      for (final m in _lowStock) {
        counts[m.preferredSupplierId] =
            (counts[m.preferredSupplierId] ?? 0) + 1;
      }
      final best = widget.suppliers
          .where((s) => counts.containsKey(s.id))
          .fold<InventorySupplier?>(null,
              (b, s) => b == null || counts[s.id]! > counts[b.id]! ? s : b);
      _supplierId = best?.id;
      if (_supplierId != null) _fillLowStock(replace: true, notify: false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _tax.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  RawMaterial? _materialFor(PurchaseOrderLine l) =>
      widget.materials.where((m) => m.id == l.materialId).firstOrNull ??
      widget.materials
          .where((m) => l.code.isNotEmpty && m.code == l.code)
          .firstOrNull ??
      widget.materials
          .where((m) => m.name.toLowerCase() == l.materialName.toLowerCase())
          .firstOrNull;

  Iterable<RawMaterial> get _lowStock =>
      widget.materials.where((m) => m.status != StockStatus.inStock);

  double get _subtotal => _lines.fold(0, (s, l) => s + l.total);
  double get _taxPct => double.tryParse(_tax.text.trim()) ?? 0;
  double get _taxAmount => _subtotal * _taxPct / 100;

  void _fillLowStock({bool replace = false, bool notify = true}) {
    final supplierId = _supplierId;
    void apply() {
      if (supplierId == null) {
        _linesMessage = 'Choose a supplier first.';
        _linesMessageIsError = true;
        return;
      }
      if (replace) {
        for (final l in _lines) {
          l.dispose();
        }
        _lines.clear();
      }
      var added = 0;
      for (final m
          in _lowStock.where((m) => m.preferredSupplierId == supplierId)) {
        if (_lines.any((l) => l.materialId == m.id)) continue;
        final qty = m.suggestedOrderQty > 0 ? m.suggestedOrderQty : 1.0;
        _lines.add(_LineDraft(qty: qty)..setMaterial(m));
        added++;
      }
      _linesMessageIsError = added == 0;
      _linesMessage = added == 0
          ? 'No low-stock materials list this supplier as preferred.'
          : 'Added $added low-stock ${added == 1 ? 'material' : 'materials'} (quantity = reorder level − stock).';
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _pickDate(bool expected) async {
    final initial = expected ? _expected : _orderDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (expected) {
        _expected = picked;
      } else {
        _orderDate = picked;
        if (_expected.isBefore(_orderDate)) _expected = _orderDate;
      }
    });
  }

  Future<void> _save(PurchaseOrderStatus status) async {
    if (_saving) return;
    final formOk = _formKey.currentState!.validate();
    if (_lines.isEmpty) {
      setState(() {
        _linesMessage = 'Add at least one line item.';
        _linesMessageIsError = true;
      });
      return;
    }
    if (!formOk) return;
    if (_expected.isBefore(_orderDate)) {
      showMasterError(
          context, 'Expected delivery cannot be before the order date.');
      return;
    }
    final e = widget.existing;
    final po = PurchaseOrder(
      number: widget.number,
      supplierId: _supplierId!,
      orderDate: formatShortDate(_orderDate),
      expectedDelivery: formatShortDate(_expected),
      status: status,
      createdBy: e?.createdBy ?? widget.createdBy,
      deliveryAddress: _address.text.trim(),
      deliveryCity: _city.text.trim(),
      taxPct: _taxPct,
      notes: _notes.text.trim(),
      lines: [
        for (final l in _lines)
          PurchaseOrderLine(
            materialId: l.materialId,
            materialName: l.materialName,
            code: l.code,
            unit: l.unit,
            unitCost: l.costValue,
            orderedQty: l.qtyValue,
          ),
      ],
    );
    setState(() => _saving = true);
    final ok = await runMasterAction(
        context, () => widget.inventory.savePurchaseOrder(po),
        success: status == PurchaseOrderStatus.draft
            ? '${po.number} saved as draft'
            : '${po.number} submitted for approval (Pending)');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  // ---- UI helpers -------------------------------------------------------

  static InputDecoration _dec({String? hint, String? prefix, String? suffix}) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: MasterStyle.cardBorder));
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefix,
      suffixText: suffix,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: ViniiColors.greenSolid)),
    );
  }

  static Widget _labeled(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 6),
            child,
          ]);

  static Widget _pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 520
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 16),
              Expanded(child: b),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [a, const SizedBox(height: 14), b]));

  Widget _dateField(String label, DateTime value, bool expected) => _labeled(
        label,
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickDate(expected),
          child: InputDecorator(
            decoration: _dec(),
            child: Row(children: [
              Expanded(
                  child: Text(formatShortDate(value),
                      style: const TextStyle(fontSize: 13))),
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: ViniiColors.textSecondaryLight),
            ]),
          ),
        ),
      );

  String? _numberValidator(String? v,
      {bool positive = false, double? max, String name = 'Value'}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    final n = double.tryParse(t);
    if (n == null) return 'Enter a number';
    if (positive && n <= 0) return '$name must be > 0';
    if (n < 0) return 'Cannot be negative';
    if (max != null && n > max) return 'Max $max';
    return null;
  }

  Widget _lineRow(_LineDraft l) {
    final known = widget.materials.any((m) => m.id == l.materialId);
    return Padding(
      key: ObjectKey(l),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: DropdownButtonFormField<String>(
            initialValue: known ? l.materialId : null,
            isExpanded: true,
            decoration: _dec(),
            hint: Text(
                l.materialName.isEmpty
                    ? 'Select raw material'
                    : '${l.materialName} (not in inventory)',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textPrimaryLight),
            items: [
              for (final m in widget.materials)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                      '${m.name} · ${m.code} (${_fmt(m.stockQty)} ${m.unit} in stock)',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (v) => v == null && l.materialName.isEmpty
                ? 'Pick a raw material'
                : null,
            onChanged: (id) {
              final m = widget.materials.where((m) => m.id == id).firstOrNull;
              if (m == null) return;
              setState(() => l.setMaterial(m));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: l.qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            decoration: _dec(hint: 'Qty', suffix: l.unit),
            validator: (v) =>
                _numberValidator(v, positive: true, name: 'Quantity'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: l.cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            decoration: _dec(hint: 'Unit cost', prefix: '₹'),
            validator: (v) => _numberValidator(v),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Text(formatInr(l.total),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          tooltip: 'Remove line',
          icon: const Icon(Icons.close, size: 18, color: ViniiColors.redSolid),
          onPressed: () => setState(() {
            _lines.remove(l);
            l.dispose();
          }),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final size = MediaQuery.sizeOf(context);
    Widget totalLine(String label, String value, {bool strong = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            const Spacer(),
            Text(label,
                style: strong
                    ? MasterStyle.value
                    : MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 24),
            SizedBox(
              width: 130,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: strong
                      ? MasterStyle.value
                      : MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
        );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
            child: Row(children: [
              Expanded(
                child: Text(
                    editing
                        ? 'Edit Purchase Order ${widget.number}'
                        : widget.prefillLowStock
                            ? 'New Purchase Order from Low Stock · ${widget.number}'
                            : 'New Purchase Order · ${widget.number}',
                    overflow: TextOverflow.ellipsis,
                    style: MasterStyle.sectionTitle),
              ),
              IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          const Divider(height: 1, color: MasterStyle.cardBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pair(
                        _labeled(
                          'Supplier *',
                          DropdownButtonFormField<String>(
                            initialValue: _supplierId,
                            isExpanded: true,
                            decoration: _dec(),
                            hint: const Text('Select supplier',
                                style: TextStyle(fontSize: 13)),
                            style: const TextStyle(
                                fontSize: 13,
                                color: ViniiColors.textPrimaryLight),
                            items: [
                              for (final s in widget.suppliers)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                      s.caption.isEmpty
                                          ? s.name
                                          : '${s.name} · ${s.caption}',
                                      overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            validator: (v) =>
                                v == null ? 'Choose a supplier' : null,
                            onChanged: (v) {
                              setState(() => _supplierId = v);
                              if (widget.prefillLowStock && !editing) {
                                _fillLowStock(replace: true);
                              }
                            },
                          ),
                        ),
                        _labeled(
                          'Tax (GST)',
                          DropdownButtonFormField<double>(
                            initialValue: _taxPct,
                            isExpanded: true,
                            decoration: _dec(),
                            style: const TextStyle(
                                fontSize: 13,
                                color: ViniiColors.textPrimaryLight),
                            items: [
                              // Slabs, plus a custom rate kept from old data.
                              for (final p in {...masterGstSlabs, _taxPct})
                                DropdownMenuItem(
                                    value: p, child: Text(gstSlabLabel(p))),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _tax.text = _fmt(v));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _pair(
                        _dateField('Order Date', _orderDate, false),
                        _dateField('Expected Delivery', _expected, true),
                      ),
                      const SizedBox(height: 14),
                      if (widget.branches.isNotEmpty) ...[
                        _labeled(
                          'Deliver To Branch',
                          DropdownButtonFormField<String?>(
                            initialValue: _branchId,
                            isExpanded: true,
                            decoration: _dec(),
                            style: const TextStyle(
                                fontSize: 13,
                                color: ViniiColors.textPrimaryLight),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Another address (type below)')),
                              for (final b in widget.branches)
                                DropdownMenuItem<String?>(
                                    value: b.id,
                                    child: Text(b.name,
                                        overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (id) => setState(() {
                              _branchId = id;
                              final b = widget.branches
                                  .where((x) => x.id == id)
                                  .firstOrNull;
                              if (b != null) _address.text = b.name;
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _pair(
                        _labeled(
                          'Delivery Address',
                          TextFormField(
                            controller: _address,
                            style: const TextStyle(fontSize: 13),
                            decoration: _dec(
                                hint: widget.branches.isEmpty
                                    ? 'Kitchen or store address'
                                    : 'Filled from the branch — edit if needed'),
                          ),
                        ),
                        _labeled(
                          'City',
                          TextFormField(
                            controller: _city,
                            style: const TextStyle(fontSize: 13),
                            decoration: _dec(hint: 'City'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _labeled(
                        'Notes',
                        TextFormField(
                          controller: _notes,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13),
                          decoration: _dec(
                              hint: 'Delivery instructions, quality notes…'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          const Text('Line Items (Raw Materials)',
                              style: MasterStyle.sectionTitle),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            MasterButton(
                              label: 'Fill from Low Stock',
                              icon: Icons.auto_fix_high_outlined,
                              onPressed: () => _fillLowStock(),
                            ),
                            MasterButton(
                              label: '+ Add Line',
                              onPressed: widget.materials.isEmpty
                                  ? () => setState(() {
                                        _linesMessage =
                                            'No raw materials yet — add them in Master → Inventory.';
                                        _linesMessageIsError = true;
                                      })
                                  : () => setState(() {
                                        _lines.add(_LineDraft(qty: 1));
                                        _linesMessage = null;
                                      }),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_linesMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(_linesMessage!,
                              style: MasterStyle.muted.copyWith(
                                  color: _linesMessageIsError
                                      ? ViniiColors.redSolid
                                      : ViniiColors.greenSolid)),
                        ),
                      if (_lines.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Expanded(
                                flex: 5,
                                child: Text('Raw Material',
                                    style: MasterStyle.label)),
                            SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child:
                                    Text('Quantity', style: MasterStyle.label)),
                            SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: Text('Unit Cost',
                                    style: MasterStyle.label)),
                            SizedBox(width: 10),
                            Expanded(
                                flex: 2,
                                child: Text('Line Total',
                                    textAlign: TextAlign.right,
                                    style: MasterStyle.label)),
                            SizedBox(width: 48),
                          ]),
                        ),
                      for (final l in _lines) _lineRow(l),
                      if (_lines.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MasterStyle.tableHeaderBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MasterStyle.cardBorder),
                          ),
                          child: const Text(
                              'No line items yet — add a raw material or fill from low stock.',
                              style: MasterStyle.muted),
                        ),
                      const Divider(height: 24, color: MasterStyle.cardBorder),
                      totalLine('Subtotal', formatInr(_subtotal)),
                      totalLine(
                          'Tax (${_fmt(_taxPct)}%)', formatInr(_taxAmount)),
                      totalLine('Total', formatInr(_subtotal + _taxAmount),
                          strong: true),
                    ]),
              ),
            ),
          ),
          const Divider(height: 1, color: MasterStyle.cardBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                MasterButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, false)),
                MasterButton(
                  label: 'Save as Draft',
                  onPressed: () => _save(PurchaseOrderStatus.draft),
                ),
                MasterButton(
                  label: _saving ? 'Saving…' : 'Submit (Pending)',
                  kind: MasterButtonKind.primary,
                  onPressed: () => _save(PurchaseOrderStatus.pending),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
