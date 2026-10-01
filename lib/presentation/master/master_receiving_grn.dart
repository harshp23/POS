import 'package:flutter/material.dart';

import '../../data/drift_inventory_store.dart';
import '../../domain/inventory.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// A selectable tax rate in the GRN tax dropdown.
class _TaxOption {
  const _TaxOption(this.group, this.rateLabel, this.pct);
  final String group;
  final String rateLabel;
  final double pct;

  String get label => group == 'Other' ? rateLabel : '$group $rateLabel';

  bool sameAs(_TaxOption o) =>
      o.group == group && o.rateLabel == rateLabel && o.pct == pct;
}

/// Tax types offered by the Figma GRN tax dropdown (GST / VAT / Other).
const _taxOptions = <_TaxOption>[
  _TaxOption('GST', '5%', 5),
  _TaxOption('GST', '12%', 12),
  _TaxOption('GST', '18%', 18),
  _TaxOption('GST', '28%', 28),
  _TaxOption('VAT', '5%', 5),
  _TaxOption('VAT', '10%', 10),
  _TaxOption('Other', 'Exempt', 0),
];

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

/// Unsaved GRN entries for one line, kept by the Purchase Orders screen
/// while the user stays in it ("Save Draft"). Never written to the database.
class GrnDraftLine {
  const GrnDraftLine({
    required this.accepted,
    required this.rejected,
    required this.cost,
    required this.batch,
    required this.expiry,
    required this.taxGroup,
    required this.taxRateLabel,
    required this.taxPct,
  });
  final String accepted;
  final String rejected;
  final String cost;
  final String batch;
  final String expiry;
  final String taxGroup;
  final String taxRateLabel;
  final double taxPct;
}

/// Draft GRN keyed by purchase-order line id.
class GrnDraft {
  const GrnDraft(this.lines);
  final Map<int, GrnDraftLine> lines;
}

/// Editable receiving state for one PO line.
class _GrnLine {
  _GrnLine(this.line, _TaxOption defaultTax, GrnDraftLine? draft)
      : accepted = TextEditingController(
            text: draft?.accepted ?? _fmtQty(_outstanding(line))),
        rejected = TextEditingController(text: draft?.rejected ?? '0'),
        cost = TextEditingController(
            text: draft?.cost ?? line.unitCost.toStringAsFixed(2)),
        batch = TextEditingController(text: draft?.batch ?? ''),
        expiry = TextEditingController(text: draft?.expiry ?? ''),
        tax = draft == null
            ? defaultTax
            : _TaxOption(draft.taxGroup, draft.taxRateLabel, draft.taxPct);

  final PurchaseOrderLine line;
  final TextEditingController accepted;
  final TextEditingController rejected;
  final TextEditingController cost;
  final TextEditingController batch;
  final TextEditingController expiry;
  _TaxOption tax;

  /// Still expected: ordered minus everything already received or rejected
  /// (the same rule the store uses to decide a PO is fully received).
  static double _outstanding(PurchaseOrderLine l) =>
      (l.orderedQty - l.receivedQty - l.rejectedQty)
          .clamp(0, double.infinity)
          .toDouble();

  static double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t);
  }

  double get outstanding => _outstanding(line);
  double get acceptedQty => _num(accepted) ?? 0;
  double get rejectedQty => _num(rejected) ?? 0;
  double get unitCost => _num(cost) ?? 0;
  double get value => acceptedQty * unitCost;
  double get taxAmount => value * tax.pct / 100;
  bool get hasQty => acceptedQty + rejectedQty > 0;

  /// Validation message for this line, or null when it can be posted.
  String? get error {
    final a = _num(accepted), r = _num(rejected), c = _num(cost);
    if (a == null || r == null || c == null) return 'Enter valid numbers';
    if (a < 0 || r < 0 || c < 0) return 'Values cannot be negative';
    if (a + r > outstanding + 1e-9) {
      return 'Accepted + rejected exceeds outstanding ${_fmtQty(outstanding)} ${line.unit}';
    }
    final e = expiry.text.trim();
    if (e.isNotEmpty && _safeDate(e) == null) {
      return 'Expiry must look like 31 Dec 2026';
    }
    return null;
  }

  static DateTime? _safeDate(String s) {
    try {
      return parseShortDate(s);
    } catch (_) {
      return null;
    }
  }

  /// Pill shown in the Status column.
  (String, PillTone) get status {
    if (error != null) return ('Invalid', PillTone.red);
    if (!hasQty) return ('Skipped', PillTone.gray);
    if (rejectedQty > 0) return ('Discrepancy', PillTone.red);
    if ((acceptedQty - outstanding).abs() < 1e-9) {
      return ('Approved', PillTone.green);
    }
    return ('Partial', PillTone.amber);
  }

  GrnDraftLine toDraft() => GrnDraftLine(
        accepted: accepted.text,
        rejected: rejected.text,
        cost: cost.text,
        batch: batch.text,
        expiry: expiry.text,
        taxGroup: tax.group,
        taxRateLabel: tax.rateLabel,
        taxPct: tax.pct,
      );

  void dispose() {
    accepted.dispose();
    rejected.dispose();
    cost.dispose();
    batch.dispose();
    expiry.dispose();
  }
}

/// Master → Purchase Orders → Receive Stock: Goods Receipt Note (Figma
/// "receiving-grn" 385:57421). Accepted / rejected quantities, invoice cost
/// and tax are editable per line and the totals recalculate live. "Confirm
/// Receipt & Update Stock" posts the GRN through
/// [DriftInventoryStore.postGoodsReceipt] (stock + movements + PO status in
/// one transaction) and calls [onPosted] with the new GRN id.
class MasterReceivingGrn extends StatefulWidget {
  const MasterReceivingGrn({
    super.key,
    required this.inventory,
    required this.poNumber,
    required this.onBack,
    required this.onPosted,
    this.draft,
    this.onSaveDraft,
  });

  final DriftInventoryStore inventory;
  final String poNumber;
  final VoidCallback onBack;
  final ValueChanged<String> onPosted;

  /// Previously saved (in-memory) draft to restore.
  final GrnDraft? draft;
  final ValueChanged<GrnDraft>? onSaveDraft;

  @override
  State<MasterReceivingGrn> createState() => _MasterReceivingGrnState();
}

class _MasterReceivingGrnState extends State<MasterReceivingGrn> {
  PurchaseOrder? _order;
  String _supplierName = '';
  bool _loading = true;
  bool _posting = false;
  List<_GrnLine> _lines = const [];
  int? _taxOpenFor;
  final String _receivedOn = formatShortDate(DateTime.now());

  // Column flexes follow the Figma column widths.
  static const _cols = <(String, int)>[
    ('Material', 180),
    ('Outstanding', 80),
    ('Accepted Qty', 110),
    ('Rejected Qty', 110),
    ('Unit', 80),
    ('Cost / Unit', 90),
    ('Tax', 120),
    ('Batch / Lot', 100),
    ('Expiry', 90),
    ('Status', 90),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await widget.inventory.getPurchaseOrder(widget.poNumber);
    // Archived suppliers included, so an older order still names its supplier.
    final suppliers = await widget.inventory.getAllSuppliers();
    if (!mounted) return;
    final defaultTax = order == null
        ? _taxOptions.first
        : (order.taxPct == 0
            ? _taxOptions.last
            : _taxOptions.firstWhere((t) => t.pct == order.taxPct,
                orElse: () => _TaxOption(
                    'Other', '${_fmtQty(order.taxPct)}%', order.taxPct)));
    setState(() {
      _loading = false;
      _order = order;
      _supplierName =
          order == null ? '' : supplierLabel(suppliers, order.supplierId);
      _lines = [
        if (order != null)
          for (final l in order.lines)
            _GrnLine(l, defaultTax,
                l.id == null ? null : widget.draft?.lines[l.id!]),
      ];
    });
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.value);
  double get _taxTotal => _lines.fold(0, (s, l) => s + l.taxAmount);
  double get _orderedValue =>
      _lines.fold(0, (s, l) => s + l.outstanding * l.line.unitCost);
  bool get _valid =>
      _lines.every((l) => l.error == null) && _lines.any((l) => l.hasQty);

  void _saveDraft() {
    final save = widget.onSaveDraft;
    if (save == null) return;
    save(GrnDraft({
      for (final l in _lines)
        if (l.line.id != null) l.line.id!: l.toDraft(),
    }));
    showMasterNotice(context,
        'Draft kept on this screen only — it is not saved to the database and is lost when you leave Purchase Orders');
  }

  Future<void> _confirm() async {
    final order = _order;
    if (order == null || _posting) return;
    final bad = _lines.where((l) => l.error != null).toList();
    if (bad.isNotEmpty) {
      showMasterError(
          context, '${bad.first.line.materialName}: ${bad.first.error}');
      return;
    }
    if (!_lines.any((l) => l.hasQty)) {
      showMasterError(context, 'Enter an accepted or rejected quantity first.');
      return;
    }
    final ok = await confirmMasterAction(context,
        title: 'Post goods receipt?',
        message:
            'Adds ${formatInr(_subtotal)} of accepted stock to raw-material inventory against ${order.number}. This cannot be undone.',
        confirmLabel: 'Post GRN',
        destructive: false);
    if (!ok || !mounted) return;

    final subtotal = _subtotal;
    final taxPct = subtotal > 0 ? _taxTotal / subtotal * 100 : 0.0;
    final noteParts = <String>[
      for (final l in _lines)
        if (l.hasQty &&
            (l.batch.text.trim().isNotEmpty || l.expiry.text.trim().isNotEmpty))
          '${l.line.materialName}: ${[
            if (l.batch.text.trim().isNotEmpty) 'lot ${l.batch.text.trim()}',
            if (l.expiry.text.trim().isNotEmpty) 'exp ${l.expiry.text.trim()}',
          ].join(', ')}',
      if (_taxTotal > 0)
        'Tax: ${{
          for (final l in _lines)
            if (l.acceptedQty > 0) l.tax.label
        }.join(' + ')}',
    ];
    final inputs = [
      for (final l in _lines)
        if (l.hasQty && l.line.id != null)
          GrnLineInput(
            lineId: l.line.id!,
            acceptedQty: l.acceptedQty,
            rejectedQty: l.rejectedQty,
            unitCost: l.unitCost,
          ),
    ];
    setState(() => _posting = true);
    String? grnId;
    final done = await runMasterAction(context, () async {
      grnId = await widget.inventory.postGoodsReceipt(order.number, inputs,
          taxPct: taxPct, notes: noteParts.join('; '));
    });
    if (!mounted) return;
    setState(() => _posting = false);
    if (done && grnId != null) widget.onPosted(grnId!);
  }

  Future<void> _customTax(_GrnLine g) async {
    final controller = TextEditingController();
    final pct = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v < 0 || v > 100) {
                setLocal(() => error = 'Enter a rate between 0 and 100');
                return;
              }
              Navigator.pop(ctx, v);
            }

            return AlertDialog(
              title: const Text('Custom tax rate'),
              content: SizedBox(
                width: 320,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => submit(),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    suffixText: '%',
                    errorText: error,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(onPressed: submit, child: const Text('Apply')),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (pct == null || !mounted) return;
    setState(() {
      g.tax = _TaxOption('Other', '${_fmtQty(pct)}%', pct);
      _taxOpenFor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return MasterPage(children: [
        MasterBackLink(
            label: 'Back to ${widget.poNumber}', onTap: widget.onBack),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : Text('${widget.poNumber} no longer exists.',
                    style: MasterStyle.muted),
          ),
        ),
      ]);
    }
    final valid = _valid;
    return MasterPage(children: [
      MasterBackLink(label: 'Back to ${order.number}', onTap: widget.onBack),
      const MasterBanner(
        tone: PillTone.green,
        icon: '✓',
        title: 'Raw material stock only',
        message:
            'This transaction only updates Raw Material stocks and will not create duplicate operational items.',
      ),
      const SizedBox(height: 20),
      MasterPageHeader(
        title: 'Goods Receipt Note',
        titleTrailing: const MasterStatusPill('GRN', tone: PillTone.gray),
        subtitle:
            'Record actual inbound physical counts against ${order.number} for $_supplierName',
        actions: [
          MasterStatusPill(
              '${_lines.length} ${_lines.length == 1 ? 'Item' : 'Items'}',
              tone: PillTone.gray),
          MasterStatusPill(valid ? 'Ready to Post' : 'In Progress',
              tone: valid ? PillTone.green : PillTone.amber),
        ],
      ),
      MasterCard(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Inbound Shipment Reconciliation',
                          style: MasterStyle.sectionTitle),
                      MasterStatusPill('${order.number} · $_supplierName',
                          tone: PillTone.blue),
                    ]),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Received: ', style: MasterStyle.muted),
                  TextSpan(
                      text: _receivedOn,
                      style: MasterStyle.muted.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ViniiColors.textPrimaryLight)),
                ])),
              ],
            ),
          ),
          LayoutBuilder(builder: (context, c) {
            const minWidth = 1100.0;
            final table = _buildTable();
            return c.maxWidth >= minWidth
                ? table
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: minWidth, child: table));
          }),
          _buildTotals(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: MasterStyle.cardBorder))),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                MasterButton(
                  label: 'Print',
                  icon: Icons.print_outlined,
                  onPressed: () => showMasterNotice(context,
                      'Printing needs a configured printer, which is not available here — export the PO as CSV from its detail page instead'),
                ),
                if (widget.onSaveDraft != null)
                  MasterButton(label: 'Save Draft', onPressed: _saveDraft),
                MasterButton(label: 'Cancel', onPressed: widget.onBack),
                Opacity(
                  opacity: valid && !_posting ? 1 : 0.5,
                  child: MasterButton(
                    label: _posting
                        ? 'Posting…'
                        : 'Confirm Receipt & Update Stock',
                    kind: MasterButtonKind.primary,
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _cells(List<Widget> cells) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _cols.length; i++)
            Expanded(
              flex: _cols[i].$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Align(alignment: Alignment.centerLeft, child: cells[i]),
              ),
            ),
        ],
      );

  Widget _buildTable() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const BoxDecoration(
            color: MasterStyle.tableHeaderBg,
            border: Border(
                top: BorderSide(color: MasterStyle.cardBorder),
                bottom: BorderSide(color: MasterStyle.cardBorder)),
          ),
          child: _cells([
            for (final c in _cols)
              Text(c.$1,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.textSecondaryLight)),
          ]),
        ),
        if (_lines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('This purchase order has no line items.',
                style: MasterStyle.muted),
          ),
        for (var i = 0; i < _lines.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : const Border(
                      top: BorderSide(color: MasterStyle.cardBorder)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(i),
                  if (_lines[i].error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                      child: Text(_lines[i].error!,
                          style: MasterStyle.muted
                              .copyWith(color: ViniiColors.redSolid)),
                    ),
                ]),
          ),
          if (_taxOpenFor == i) _taxPanel(_lines[i]),
        ],
      ]);

  Widget _row(int i) {
    final g = _lines[i];
    final l = g.line;
    final (statusText, statusTone) = g.status;
    return _cells([
      MasterCellTitle(l.materialName,
          subtitle: l.code.isEmpty ? _supplierName : l.code),
      MasterCellTitle('${_fmtQty(g.outstanding)} ${l.unit}',
          subtitle: 'of ${_fmtQty(l.orderedQty)}'),
      _GrnInput(controller: g.accepted, onChanged: () => setState(() {})),
      _GrnInput(controller: g.rejected, onChanged: () => setState(() {})),
      _boxed(Text(l.unit, style: MasterStyle.body)),
      _GrnInput(
          controller: g.cost, prefix: '₹', onChanged: () => setState(() {})),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _taxOpenFor = _taxOpenFor == i ? null : i),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _taxOpenFor == i
                    ? ViniiColors.greenSolid
                    : MasterStyle.cardBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.tax.label,
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(formatInr(g.taxAmount),
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.muted),
                  ]),
            ),
            Icon(
                _taxOpenFor == i
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 14,
                color: ViniiColors.textSecondaryLight),
          ]),
        ),
      ),
      _GrnInput(controller: g.batch, hint: 'LOT-…', numeric: false),
      _GrnDateInput(controller: g.expiry, onChanged: () => setState(() {})),
      MasterStatusPill(statusText, tone: statusTone),
    ]);
  }

  Widget _boxed(Widget child) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: MasterStyle.tableHeaderBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MasterStyle.cardBorder),
        ),
        child: child,
      );

  Widget _taxPanel(_GrnLine g) {
    final groups = <String>{for (final t in _taxOptions) t.group};
    final isCustom = !_taxOptions.any((t) => t.sameAs(g.tax));
    Widget chip(String text, bool selected, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? ViniiColors.brandGreen : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected
                      ? ViniiColors.brandGreen
                      : MasterStyle.cardBorder),
            ),
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.black
                        : ViniiColors.textPrimaryLight)),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MasterStyle.tableHeaderBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Select Tax Type',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          for (final group in groups)
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(group, style: MasterStyle.label),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in _taxOptions.where((t) => t.group == group))
                      chip(t.rateLabel, t.sameAs(g.tax), () {
                        setState(() {
                          g.tax = t;
                          _taxOpenFor = null;
                        });
                      }),
                    if (group == 'Other')
                      chip(isCustom ? 'Custom ${g.tax.rateLabel}' : 'Custom',
                          isCustom, () => _customTax(g)),
                  ]),
                ]),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final taxLabels = <String>{
      for (final l in _lines)
        if (l.acceptedQty > 0) l.tax.label
    }.join(' + ');
    final variance = _subtotal - _orderedValue;
    Widget line(String label, String value,
            {Widget? chip, bool strong = false, Color? valueColor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Flexible(
              child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label,
                        style: strong
                            ? MasterStyle.value.copyWith(fontSize: 15)
                            : MasterStyle.body),
                    if (chip != null) chip,
                  ]),
            ),
            const SizedBox(width: 16),
            Text(value,
                style: (strong
                        ? MasterStyle.value.copyWith(fontSize: 18)
                        : MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600))
                    .copyWith(color: valueColor)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: MasterStyle.tableHeaderBg,
        border: Border(top: BorderSide(color: MasterStyle.cardBorder)),
      ),
      child: Column(children: [
        line('Subtotal (accepted goods)', formatInr(_subtotal)),
        line('Tax Total', formatInr(_taxTotal),
            chip: taxLabels.isEmpty
                ? null
                : MasterStatusPill(taxLabels, tone: PillTone.gray)),
        line('Variance vs outstanding PO value', formatInr(variance),
            valueColor: variance.abs() < 0.005
                ? ViniiColors.textSecondaryLight
                : ViniiColors.redSolid),
        const Divider(height: 14, color: MasterStyle.cardBorder),
        line('GRN Total', formatInr(_subtotal + _taxTotal), strong: true),
      ]),
    );
  }
}

/// Compact date box for the Expiry column: opens a date picker and writes
/// the chosen date ("31 Dec 2026") into [controller]; × clears it.
class _GrnDateInput extends StatelessWidget {
  const _GrnDateInput({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 10, 12, 31);
    var initial = _GrnLine._safeDate(controller.text.trim()) ?? now;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Expiry date',
    );
    if (picked == null) return;
    controller.text = formatShortDate(picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _pick(context),
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MasterStyle.cardBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Text(text.isEmpty ? 'Pick date' : text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: text.isEmpty
                        ? ViniiColors.textMutedLight
                        : ViniiColors.textPrimaryLight)),
          ),
          if (text.isEmpty)
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: ViniiColors.textSecondaryLight)
          else
            InkWell(
              onTap: () {
                controller.clear();
                onChanged();
              },
              child: const Icon(Icons.close,
                  size: 14, color: ViniiColors.textMutedLight),
            ),
        ]),
      ),
    );
  }
}

/// Compact bordered input used inside GRN table cells.
class _GrnInput extends StatelessWidget {
  const _GrnInput(
      {required this.controller,
      this.onChanged,
      this.hint,
      this.prefix,
      this.numeric = true});
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String? hint;
  final String? prefix;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: MasterStyle.cardBorder));
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged?.call(),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixText: prefix,
          hintStyle:
              const TextStyle(fontSize: 12, color: ViniiColors.textMutedLight),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: ViniiColors.greenSolid)),
        ),
      ),
    );
  }
}
