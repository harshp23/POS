import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// Chain stock matrix, transfer suggestions and pending purchase orders —
/// all from the backend. Every action is saved on the server first and only
/// reported as done once that succeeded.
class FranchiseInventoryScreen extends StatefulWidget {
  const FranchiseInventoryScreen({
    super.key,
    this.data,
    this.repository,
    this.onChanged,
  });

  /// Chain data from the backend; null shows the empty state.
  final FranchiseSnapshot? data;

  /// Where transfers, purchase decisions and escalations are saved. Null
  /// disables those actions.
  final FranchiseRepository? repository;

  /// Called after something was saved, so the caller can reload [data].
  final Future<void> Function()? onChanged;

  @override
  State<FranchiseInventoryScreen> createState() =>
      _FranchiseInventoryScreenState();
}

class _FranchiseInventoryScreenState extends State<FranchiseInventoryScreen> {
  bool _isTransferApproved = false;
  bool _busy = false;
  int _selectedPurchase = 0;
  final Set<String> _approvedItems = {};

  FranchiseSnapshot get _snapshot => widget.data!;
  List<ChainStockRow> get _inventoryItems => _snapshot.inventory;
  HighImpactRecommendation? get _transfer => _snapshot.recommendations.isEmpty
      ? null
      : _snapshot.recommendations.first;
  List<PurchaseRequirement> get _purchases => _snapshot.purchaseRequirements;
  bool get _canSave => widget.repository != null;

  /// Branch columns of the stock matrix, in first-seen order.
  List<String> get _branchNames => {
        for (final row in _inventoryItems)
          for (final b in row.branches) b.branchName,
      }.toList();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    showResultSnack(context, message, error: error);
  }

  /// Saves through the backend, reloads, then confirms. Nothing is reported
  /// as done unless the save succeeded.
  Future<bool> _save(Future<void> Function(FranchiseRepository repo) action,
      String done) async {
    final repo = widget.repository;
    if (repo == null) return false;
    setState(() => _busy = true);
    try {
      await action(repo);
    } catch (e) {
      _toast('Could not save: ${friendlyErrorText(e)}', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _toast(done);
    await widget.onChanged?.call();
    return true;
  }

  bool _canTransfer(HighImpactRecommendation rec) =>
      _canSave &&
      rec.materialId != null &&
      rec.fromLocationId != null &&
      rec.toLocationId != null;

  Future<void> _approveTransfer(HighImpactRecommendation rec) async {
    final ok = await _save(
        (repo) => repo.initiateTransfer(rec),
        'Transfer recorded: ${_recQty(rec)} ${rec.item} from '
        '${rec.sourceBranch} to ${rec.targetBranch}.');
    if (ok && mounted) {
      setState(() {
        _isTransferApproved = true;
        _approvedItems.add(rec.item);
      });
    }
  }

  PurchaseRequirement? get _currentPurchase => _purchases.isEmpty
      ? null
      : _purchases[_selectedPurchase.clamp(0, _purchases.length - 1)];

  /// "4 kg" — a transfer's quantity with its unit.
  static String _recQty(HighImpactRecommendation rec) =>
      quantityWithUnit(formatQty(rec.quantityKg), rec.unit);

  /// "10 kg" / "10" — an order's quantity, with the unit when known.
  static String _poQty(PurchaseRequirement p) =>
      quantityWithUnit(formatQty(p.quantityKg), p.unit);

  /// "PO-0012" or, without a number, "the purchase order".
  static String _poName(PurchaseRequirement p) {
    final n = p.poNumber?.trim() ?? '';
    return n.isEmpty ? 'purchase order' : 'purchase order $n';
  }

  /// "29 Sep 2026" from the order date; "—" when unknown.
  static String _poDate(PurchaseRequirement p) {
    final d = p.orderDate;
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final l = d.isUtc && d.hour == 0 && d.minute == 0 ? d : d.toLocal();
    return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
  }

  static String _poAmount(PurchaseRequirement p) =>
      p.amountMinor == null ? '—' : formatPaise(p.amountMinor!);

  Future<void> _decidePurchase({required bool approve}) async {
    final req = _currentPurchase;
    if (req == null) return;
    await _save((repo) => repo.decidePurchase(req, approve: approve),
        '${approve ? 'Approved' : 'Rejected'} the ${_poName(req)} from ${req.supplier} for ${req.branch}.');
  }

  /// "Escalate Shortage": pick the branch (the first short one to start
  /// with) and log an incident naming it and its short materials.
  Future<void> _escalateShortage(List<ChainStockRow> shortRows) async {
    // Branches with a short material, in first-seen order, then the rest.
    final options = <String, ({String? id, String name, List<String> items})>{};
    void add(String? id, String name, String? item) {
      final key = id ?? 'name:$name';
      final prev = options[key];
      options[key] = (
        id: id,
        name: name,
        items: [...?prev?.items, if (item != null) item],
      );
    }

    for (final row in shortRows) {
      for (final b in row.branches) {
        if (b.status == 'Critical' || b.status == 'Low') {
          add(b.locationId, b.branchName,
              '${row.name} (${quantityWithUnit(formatQty(b.stockQty), row.unit)})');
        }
      }
    }
    for (final b in _snapshot.branches) {
      if (b.id == 'unassigned') continue;
      if (!options.containsKey(b.id) &&
          !options.values.any((o) => o.name == b.branchName)) {
        add(b.id, b.branchName, null);
      }
    }
    if (options.isEmpty) return;
    var picked = options.keys.first;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final o = options[picked]!;
          return AlertDialog(
            title: const Text('Escalate stock shortage'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('escalate-branch'),
                    initialValue: picked,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Branch', border: OutlineInputBorder()),
                    items: [
                      for (final e in options.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(
                              e.value.items.isEmpty
                                  ? e.value.name
                                  : '${e.value.name} · ${e.value.items.length} short',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialog(() => picked = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    o.items.isEmpty
                        ? 'No material is short at ${o.name} right now; the '
                            'incident will say so.'
                        : 'Short at ${o.name}: ${o.items.join(', ')}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                  key: const Key('escalate-confirm'),
                  onPressed: () => Navigator.pop(ctx, picked),
                  child: const Text('Escalate')),
            ],
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;
    final o = options[chosen]!;
    await _save(
        (repo) => repo.logRecord(
            'incident',
            'Stock shortage escalated — ${o.name}',
            {
              'branch': o.name,
              'materials': o.items,
            },
            locationId: o.id),
        'Shortage at ${o.name} logged as an incident '
        '(${o.items.length} ${o.items.length == 1 ? 'material' : 'materials'}).');
  }

  bool _matchesTransfer(ChainStockRow row) => _approvedItems
      .any((item) => row.name == item || row.name.startsWith(item));

  bool _unquoted(PurchaseRequirement p) =>
      p.rowId != null && _snapshot.purchasesWithoutQuote.contains(p.rowId);

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const FranchiseNoData();
    final rec = _transfer;
    final branchNames = _branchNames;
    final shortRows = _inventoryItems.where((r) => r.isShort).toList();
    final c = PanelColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _currentPurchase;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Franchise V1 Chain Inventory & Supply',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Chain-wide stock health, inter-branch transfers and purchase '
            'orders waiting for approval',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(builder: (context, constraints) {
            const gap = 16.0;
            final columns = constraints.maxWidth >= 700 ? 3 : 1;
            final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              SizedBox(
                width: w,
                child: StatTile(
                  large: true,
                  label: 'Materials tracked',
                  value: '${_inventoryItems.length}',
                  sub: 'Across ${branchNames.length} '
                      '${branchNames.length == 1 ? 'branch' : 'branches'}',
                ),
              ),
              SizedBox(
                width: w,
                child: StatTile(
                  large: true,
                  label: 'Short materials',
                  value: '${shortRows.length}',
                  valueColor: shortRows.isEmpty ? null : Colors.orange[800],
                  sub: 'Critical or low at one or more branches',
                ),
              ),
              SizedBox(
                width: w,
                child: StatTile(
                  large: true,
                  label: 'Pending POs',
                  value: '${_purchases.length}',
                  sub: 'Awaiting approval',
                ),
              ),
            ]);
          }),
          const SizedBox(height: 20),

          // Recommended transfer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B2E1D)
                  : ViniiColors.successPillBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ViniiColors.brandGreen.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'RECOMMENDED LATERAL INVENTORY TRANSFER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ViniiColors.emeraldText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text('Computed from current branch stock',
                        style: TextStyle(fontSize: 11, color: c.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87),
                    children: rec == null
                        ? const [
                            TextSpan(
                                text: 'No transfers suggested — no branch is '
                                    'short of a material another branch has '
                                    'in surplus.'),
                          ]
                        : [
                            TextSpan(
                                text: 'Transfer ${_recQty(rec)} ${rec.item} ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            TextSpan(text: 'from ${rec.sourceBranch} to '),
                            TextSpan(
                                text: '${rec.targetBranch} ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            TextSpan(text: '(${rec.rootCause}).'),
                          ],
                  ),
                ),
                if (rec != null) ...[
                  const SizedBox(height: 8),
                  Text(rec.financialImpact,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ViniiColors.emeraldText)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    withTooltip(
                      rec == null || _canTransfer(rec)
                          ? null
                          : kNeedsServerToSave,
                      ElevatedButton(
                        onPressed: _isTransferApproved ||
                                _busy ||
                                rec == null ||
                                !_canTransfer(rec)
                            ? null
                            : () => _approveTransfer(rec),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          foregroundColor: Colors.black,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(_isTransferApproved
                            ? 'Transfer Approved'
                            : 'Approve Transfer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: rec == null
                          ? null
                          : () => _showReviewTransferModal(context, rec),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Review Transfer',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stock matrix
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: _inventoryItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        'No raw materials yet — add them in Master → Inventory.',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 48,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      columns: [
                        const DataColumn(label: _Head('INGREDIENT CATEGORY')),
                        const DataColumn(label: _Head('ITEM NAME')),
                        for (final name in branchNames)
                          DataColumn(
                              label: _Head('${name.toUpperCase()} STOCK')),
                        const DataColumn(
                            label: Tooltip(
                          message: 'Twice the sum of the branches\' reorder '
                              'levels',
                          child: _Head('CHAIN TARGET'),
                        )),
                        const DataColumn(label: _Head('SUGGESTION')),
                      ],
                      rows: [
                        for (final item in _inventoryItems)
                          DataRow(cells: [
                            DataCell(Text(item.category,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(item.name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                            for (final name in branchNames)
                              DataCell(_stockCell(item, name)),
                            DataCell(Text(
                                '${formatQty(item.chainTarget)} ${item.unit}',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(StatusPill(
                              _matchesTransfer(item)
                                  ? 'Transfer recorded'
                                  : item.suggestion,
                              color: switch (item.suggestion) {
                                'Transfer' => ViniiColors.blueSolid,
                                'Reorder' => ViniiColors.amberSolid,
                                _ => ViniiColors.emeraldText,
                              },
                            )),
                          ]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Procurement & Supply Controls',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Purchase orders waiting for approval, with the supplier\'s '
            'quoted prices',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 16),

          ResponsiveRow(
            breakpoint: 1000,
            flex: const [3, 2],
            children: [
              DashCard(
                title: 'Purchase Requirements by Branch',
                child: _purchases.isEmpty
                    ? Text('No purchase orders are waiting for approval.',
                        style: TextStyle(fontSize: 12, color: c.muted))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 40,
                          dataRowMinHeight: 48,
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: _Head('PO', size: 10)),
                            DataColumn(label: _Head('ORDERED', size: 10)),
                            DataColumn(label: _Head('BRANCH', size: 10)),
                            DataColumn(label: _Head('SUPPLIER', size: 10)),
                            DataColumn(label: _Head('QTY', size: 10)),
                            DataColumn(label: _Head('AMOUNT', size: 10)),
                            DataColumn(label: _Head('LAST PRICE', size: 10)),
                            DataColumn(label: _Head('CURRENT PRICE', size: 10)),
                            DataColumn(label: _Head('VARIANCE', size: 10)),
                          ],
                          rows: [
                            for (final (index, req) in _purchases.indexed)
                              _purchaseRow(index, req),
                          ],
                        ),
                      ),
              ),
              DashCard(
                title: 'Pending Purchase Actions',
                trailing: StatusPill('${_purchases.length}',
                    color: _purchases.isEmpty
                        ? ViniiColors.emeraldText
                        : ViniiColors.redSolid),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current == null
                          ? 'No purchase orders are waiting for approval.'
                          : 'Selected: '
                              '${(current.poNumber ?? '').isEmpty ? '' : '${current.poNumber} · '}'
                              '${current.supplier} → ${current.branch} '
                              '(quantity ${_poQty(current)}'
                              '${current.amountMinor == null ? '' : ', ${_poAmount(current)}'}). '
                              'Tap a row to select another order.',
                      style: TextStyle(fontSize: 11, color: c.muted),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        withTooltip(
                          _canSave ? null : kNeedsServerToSave,
                          ElevatedButton(
                            onPressed: _busy ||
                                    !_canSave ||
                                    current == null ||
                                    current.rowId == null
                                ? null
                                : () => _decidePurchase(approve: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ViniiColors.brandGreen,
                              foregroundColor: Colors.black,
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Approve Purchase',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        withTooltip(
                          _canSave ? null : kNeedsServerToSave,
                          ElevatedButton(
                            onPressed: _busy ||
                                    !_canSave ||
                                    current == null ||
                                    current.rowId == null
                                ? null
                                : () => _decidePurchase(approve: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Reject Purchase',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        withTooltip(
                          _canSave ? null : kNeedsServerToSave,
                          OutlinedButton(
                            onPressed: _busy || !_canSave || shortRows.isEmpty
                                ? null
                                : () => _escalateShortage(shortRows),
                            child: const Text('Escalate Shortage',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _showPoQueueModal(context),
                          child: const Text('View PO Queue',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _purchaseRow(int index, PurchaseRequirement req) {
    final unquoted = _unquoted(req);
    const noQuote = 'No supplier price quote on file';
    final v = req.variancePercent;
    return DataRow(
      selected: index == _selectedPurchase,
      onSelectChanged: (_) => setState(() => _selectedPurchase = index),
      cells: [
        DataCell(Text(
            (req.poNumber ?? '').isEmpty ? '—' : req.poNumber!,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        DataCell(Text(_poDate(req), style: const TextStyle(fontSize: 11))),
        DataCell(Text(req.branch,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        DataCell(Text(req.supplier, style: const TextStyle(fontSize: 11))),
        DataCell(Text(_poQty(req), style: const TextStyle(fontSize: 11))),
        DataCell(Text(_poAmount(req), style: const TextStyle(fontSize: 11))),
        DataCell(KpiText(
            unquoted ? null : '${formatPaise(req.lastPricePerKg * 100)}/unit',
            emptyTooltip: noQuote,
            style: const TextStyle(fontSize: 11))),
        DataCell(KpiText(
            unquoted
                ? null
                : '${formatPaise(req.currentPricePerKg * 100)}/unit',
            emptyTooltip: noQuote,
            style: const TextStyle(fontSize: 11))),
        DataCell(KpiText(
          unquoted
              ? null
              : v == 0
                  ? 'Stable'
                  : '${v > 0 ? '+' : ''}$v%',
          emptyTooltip: noQuote,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: unquoted
                ? null
                : v > 0
                    ? Colors.red[700]
                    : ViniiColors.emeraldText,
          ),
        )),
      ],
    );
  }

  Widget _stockCell(ChainStockRow item, String branchName) {
    final b =
        item.branches.where((b) => b.branchName == branchName).firstOrNull;
    if (b == null) return const Text('—', style: TextStyle(fontSize: 12));
    final short = b.status == 'Critical' || b.status == 'Low';
    final spare = b.status == 'Surplus' || b.status == 'Excess';
    return Text(
      '${formatQty(b.stockQty)} ${item.unit} (${b.status})',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: short
            ? Colors.red[700]
            : spare
                ? ViniiColors.emeraldText
                : null,
      ),
    );
  }

  void _showReviewTransferModal(
      BuildContext context, HighImpactRecommendation rec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review Lateral Stock Transfer'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item: ${rec.item} (${_recQty(rec)})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Source: ${rec.sourceBranch}'),
              Text('Destination: ${rec.targetBranch}'),
              const SizedBox(height: 8),
              Text('Why: ${rec.rootCause}'),
              Text(rec.financialImpact),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPoQueueModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pending PO Queue (${_purchases.length})'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_purchases.isEmpty)
                const ListTile(title: Text('No purchase orders are pending.')),
              for (final p in _purchases)
                ListTile(
                  title: Text([
                    if ((p.poNumber ?? '').isNotEmpty) p.poNumber!,
                    '${p.supplier} — ${_poQty(p)}',
                    if (p.amountMinor != null) _poAmount(p),
                  ].join(' · ')),
                  subtitle: Text([
                    p.branch,
                    if (p.orderDate != null) 'ordered ${_poDate(p)}',
                    _unquoted(p)
                        ? 'no price quote'
                        : p.variancePercent == 0
                            ? 'price stable'
                            : 'price ${p.variancePercent > 0 ? '+' : ''}${p.variancePercent}%',
                  ].join(' · ')),
                  trailing: const Text('Pending',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.size = 11});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold));
}
