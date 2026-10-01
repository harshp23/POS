import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// Open chain exceptions from the backend. Resolving one is saved on the
/// server first; the list only changes once that succeeded.
class FranchiseExceptionsScreen extends StatefulWidget {
  /// Opens Inventory & Supply (where stock transfers are approved).
  final VoidCallback onTriggerTransfer;

  /// Open exceptions from the backend; null shows the empty state.
  final FranchiseSnapshot? data;

  /// Saves resolutions. Null disables every resolve action.
  final FranchiseRepository? repository;

  /// Called after a resolution was saved, so the caller can reload [data].
  final Future<void> Function()? onChanged;

  const FranchiseExceptionsScreen({
    super.key,
    required this.onTriggerTransfer,
    this.data,
    this.repository,
    this.onChanged,
  });

  @override
  State<FranchiseExceptionsScreen> createState() =>
      _FranchiseExceptionsScreenState();
}

class _FranchiseExceptionsScreenState extends State<FranchiseExceptionsScreen> {
  late List<OperationalException> _exceptions =
      List.of(widget.data?.exceptions ?? const []);
  final Set<String> _busy = {};
  bool _bulkBusy = false;

  @override
  void didUpdateWidget(FranchiseExceptionsScreen old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _exceptions = List.of(widget.data?.exceptions ?? const []);
    }
  }

  static String _severity(String s) => s == 'Success' ? 'Info' : s;

  static Color _severityColor(String s) => switch (s) {
        'Critical' => ViniiColors.redSolid,
        'Warning' => ViniiColors.amberSolid,
        _ => ViniiColors.blueSolid,
      };

  Future<void> _resolve(OperationalException exc) async {
    final repo = widget.repository;
    if (repo == null) return;
    setState(() => _busy.add(exc.id));
    try {
      await repo.resolveException(exc.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(exc.id));
      showResultSnack(context, 'Could not resolve the exception: ${friendlyErrorText(e)}',
          error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(exc.id);
      _exceptions.removeWhere((e) => e.id == exc.id);
    });
    showResultSnack(context, 'Exception marked resolved.');
    unawaited(widget.onChanged?.call());
  }

  Future<void> _resolveAll() async {
    final repo = widget.repository;
    if (repo == null || _exceptions.isEmpty) return;
    final count = _exceptions.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve all open exceptions?'),
        content: Text('This marks all $count open exceptions as resolved for '
            'every branch.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resolve all')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      await repo.resolveAllExceptions();
    } catch (e) {
      if (!mounted) return;
      setState(() => _bulkBusy = false);
      showResultSnack(context, 'Could not resolve the exceptions: ${friendlyErrorText(e)}',
          error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _exceptions.clear();
    });
    showResultSnack(
        context,
        count == 1
            ? '1 exception marked resolved.'
            : '$count exceptions marked resolved.');
    unawaited(widget.onChanged?.call());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const FranchiseNoData();
    final c = PanelColors.of(context);
    final canSave = widget.repository != null;
    int count(bool Function(OperationalException e) test) =>
        _exceptions.where(test).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System-Wide Operational Exceptions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Open exceptions raised across your branches',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ViniiColors.successPillBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: ViniiColors.brandGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _exceptions.isEmpty
                        ? 'No open exceptions'
                        : '${_exceptions.length} open '
                            '${_exceptions.length == 1 ? 'exception needs' : 'exceptions need'} review',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ViniiColors.emeraldText,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: widget.onTriggerTransfer,
                  child: const Text('Open Inventory & Supply',
                      style: TextStyle(fontSize: 11)),
                ),
                if (_exceptions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  withTooltip(
                    canSave ? null : kNeedsServerToSave,
                    ElevatedButton(
                      onPressed: canSave && !_bulkBusy ? _resolveAll : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ViniiColors.brandGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      child:
                          Text(_bulkBusy ? 'Resolving…' : 'Bulk Resolve All'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 800 ? 4 : 2;
            final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
            Widget tile(String label, int n, Color color) => SizedBox(
                  width: w,
                  child: StatTile(
                    large: true,
                    label: label,
                    value: '$n',
                    valueColor: n > 0 ? color : null,
                  ),
                );
            return Wrap(spacing: gap, runSpacing: gap, children: [
              tile('Critical', count((e) => e.severityStatus == 'Critical'),
                  ViniiColors.redSolid),
              tile('Warning', count((e) => e.severityStatus == 'Warning'),
                  ViniiColors.amberSolid),
              tile(
                  'Transfer suggested',
                  count((e) => e.actionType == 'Transfer'),
                  ViniiColors.emeraldText),
              tile('Reorder suggested', count((e) => e.actionType == 'Reorder'),
                  ViniiColors.amberSolid),
            ]);
          }),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: _exceptions.isEmpty
                ? const NoDataView(
                    compact: true,
                    icon: Icons.check_circle_outline,
                    title: 'No open exceptions',
                    message: 'New exceptions appear here when a branch needs '
                        'action.',
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 48,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      columns: const [
                        DataColumn(label: _Head('SEVERITY')),
                        DataColumn(label: _Head('EXCEPTION ROOT CAUSE')),
                        DataColumn(label: _Head('LOCATION')),
                        DataColumn(label: _Head('EST. IMPACT')),
                        DataColumn(label: _Head('RECOMMENDED ACTION')),
                        DataColumn(label: _Head('')),
                      ],
                      rows: [
                        for (final exc in _exceptions)
                          DataRow(cells: [
                            DataCell(StatusPill(_severity(exc.severityStatus),
                                color: _severityColor(exc.severityStatus))),
                            DataCell(Text(exc.rootCause,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                            DataCell(Text(exc.location,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                              exc.bottomLineImpact.isEmpty
                                  ? '—'
                                  : exc.bottomLineImpact,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700]),
                            )),
                            DataCell(SizedBox(
                              width: 260,
                              child: Text(
                                exc.recommendedAction.isEmpty
                                    ? exc.actionType
                                    : exc.recommendedAction,
                                style: const TextStyle(fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (exc.actionType == 'Transfer')
                                  TextButton(
                                    onPressed: widget.onTriggerTransfer,
                                    child: const Text('Open transfer',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                withTooltip(
                                  canSave ? null : kNeedsServerToSave,
                                  ElevatedButton(
                                    onPressed:
                                        canSave && !_busy.contains(exc.id)
                                            ? () => _resolve(exc)
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ViniiColors.brandGreen,
                                      foregroundColor: Colors.black,
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    child: Text(_busy.contains(exc.id)
                                        ? 'Saving…'
                                        : 'Mark resolved'),
                                  ),
                                ),
                              ],
                            )),
                          ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
}
