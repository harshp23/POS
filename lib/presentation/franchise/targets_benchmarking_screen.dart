import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_metrics.dart';
import '../../data/franchise_repository.dart';
import '../../domain/franchise_models.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// A KPI the chain can set a corporate target for. [name] is the key saved
/// in target_amendment records — keep it stable.
class _Kpi {
  const _Kpi(this.name, this.unit, {required this.lowerIsBetter});
  final String name;

  /// '%', '₹' or 'min'.
  final String unit;
  final bool lowerIsBetter;
}

const _kpis = [
  _Kpi('Food Cost Ratio %', '%', lowerIsBetter: true),
  _Kpi('Labour Cost Ratio %', '%', lowerIsBetter: true),
  _Kpi('Average Order Value', '₹', lowerIsBetter: false),
  _Kpi('Wastage Ratio %', '%', lowerIsBetter: true),
  _Kpi('Kitchen Order Prep Time', 'min', lowerIsBetter: true),
];

/// The newest saved target of a KPI.
class _Target {
  const _Target(this.value, this.record);
  final double value;
  final FranchiseRecord record;
}

/// Corporate targets come only from saved `target_amendment` records (no
/// defaults: an unset KPI says "Not set"); actuals only from the chain
/// data the backend computed.
class TargetsBenchmarkingScreen extends StatefulWidget {
  const TargetsBenchmarkingScreen({super.key, this.repository, this.data});

  /// Loads and saves target amendments (pos_franchise_records, type
  /// target_amendment). Null = no server: the screen shows its empty state.
  final FranchiseRepository? repository;

  /// Chain data for the actual figures; null shows them as "—".
  final FranchiseSnapshot? data;

  @override
  State<TargetsBenchmarkingScreen> createState() =>
      _TargetsBenchmarkingScreenState();
}

class _TargetsBenchmarkingScreenState extends State<TargetsBenchmarkingScreen> {
  Map<String, _Target> _targets = const {};
  bool _loading = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void didUpdateWidget(TargetsBenchmarkingScreen old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) _load();
  }

  /// A saved target's number: `details.value`, else the first number in
  /// `details.to` (older records saved only the text, e.g. "28.0%").
  static double? _valueOf(FranchiseRecord r) {
    final v = r.details['value'];
    if (v is num) return v.toDouble();
    final to = r.details['to'];
    if (to is! String) return null;
    final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(to.replaceAll(',', ''));
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  Future<void> _load({bool initial = false}) async {
    final repo = widget.repository;
    if (repo == null) return;
    _loading = true;
    _loadError = null;
    if (!initial) setState(() {});
    try {
      final records = await repo.records('target_amendment', limit: 200);
      final targets = <String, _Target>{};
      // Newest first: the first record of each KPI wins.
      for (final r in records) {
        final kpi = r.details['kpi'];
        final value = _valueOf(r);
        if (kpi is String && value != null && !targets.containsKey(kpi)) {
          targets[kpi] = _Target(value, r);
        }
      }
      if (!mounted) return;
      setState(() {
        _targets = targets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  static String _format(_Kpi kpi, double v) => switch (kpi.unit) {
        '₹' => formatPaise((v * 100).round()),
        'min' => '${formatQty(v)} min',
        _ => '${formatQty(v)}%',
      };

  /// The chain's actual value today, or null when there is no data for it.
  double? _actual(_Kpi kpi) {
    final data = widget.data;
    if (data == null) return null;
    return switch (kpi.name) {
      'Food Cost Ratio %' => data.overview.foodCostPercent,
      'Labour Cost Ratio %' => data.overview.labourCostPercent,
      'Average Order Value' => data.averageOrderValueMinor == null
          ? null
          : data.averageOrderValueMinor! / 100,
      _ => null,
    };
  }

  /// The best branch today for [kpi], e.g. "Noida (27.1%)".
  String? _bestPeer(_Kpi kpi) {
    final data = widget.data;
    if (data == null) return null;
    double? valueOf(BranchPerformanceRow b) {
      final k = data.kpisFor(b);
      return switch (kpi.name) {
        'Food Cost Ratio %' => k?.foodCostPercent,
        'Average Order Value' =>
          k?.aovMinor == null ? null : k!.aovMinor! / 100,
        _ => null,
      };
    }

    String? best;
    double? bestValue;
    for (final b in data.branches) {
      final v = valueOf(b);
      if (v == null) continue;
      final better = bestValue == null ||
          (kpi.lowerIsBetter ? v < bestValue : v > bestValue);
      if (better) {
        bestValue = v;
        best = b.branchName;
      }
    }
    return best == null ? null : '$best (${_format(kpi, bestValue!)})';
  }

  ({String text, Color? color}) _progress(
      _Kpi kpi, double? target, double? actual) {
    if (target == null) return (text: 'Target not set', color: null);
    if (actual == null) return (text: 'No actual yet', color: null);
    final met = kpi.lowerIsBetter ? actual <= target : actual >= target;
    if (met) return (text: 'On target', color: ViniiColors.emeraldText);
    final gap = (actual - target).abs();
    final gapText = kpi.unit == '%'
        ? '${formatQty(double.parse(gap.toStringAsFixed(1)))} pts'
        : _format(kpi, gap);
    return (
      text: kpi.lowerIsBetter
          ? 'Above target by $gapText'
          : 'Below target by $gapText',
      color: const Color(0xFFD92D20),
    );
  }

  Future<void> _openAmendmentDialog(_Kpi kpi) async {
    final repo = widget.repository;
    if (repo == null) return;
    final current = _targets[kpi.name];
    final controller = TextEditingController(
        text: current == null ? '' : formatQty(current.value));
    String? error;
    var saving = false;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
        Future<void> apply() async {
          final value = double.tryParse(controller.text.trim());
          if (value == null || value < 0 || (kpi.unit == '%' && value > 100)) {
            setDialog(() => error = kpi.unit == '%'
                ? 'Enter a percentage between 0 and 100.'
                : 'Enter a number of 0 or more.');
            return;
          }
          final from =
              current == null ? 'Not set' : _format(kpi, current.value);
          final to = _format(kpi, value);
          setDialog(() {
            saving = true;
            error = null;
          });
          try {
            await repo.logRecord(
                'target_amendment',
                '${kpi.name} target: $from → $to',
                {'kpi': kpi.name, 'from': from, 'to': to, 'value': value},
                status: 'completed');
          } catch (e) {
            setDialog(() {
              saving = false;
              error = 'Could not save the target: ${friendlyErrorText(e)}';
            });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx, to);
        }

        return AlertDialog(
          title: const Text('Confirm Target Amendment'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the corporate ${kpi.name} target '
                  '(currently ${current == null ? 'not set' : _format(kpi, current.value)}). '
                  'It applies to every branch and is saved as a target '
                  'amendment record.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('target-value'),
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'New target (${kpi.unit})',
                    border: const OutlineInputBorder(),
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
              ),
              child: Text(saving ? 'Saving…' : 'Apply Target'),
            ),
          ],
        );
      }),
    );
    if (saved == null || !mounted) return;
    showResultSnack(context, '${kpi.name} target saved: $saved.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    if (repo == null && widget.data == null) return const FranchiseNoData();
    final c = PanelColors.of(context);
    final setCount = _kpis.where((k) => _targets.containsKey(k.name)).length;
    final latest = _targets.values
        .map((t) => t.record)
        .fold<FranchiseRecord?>(null, (a, r) {
      if (a == null) return r;
      final at = a.createdAt, rt = r.createdAt;
      return rt != null && (at == null || rt.isAfter(at)) ? r : a;
    });
    final foodCost = _actual(_kpis[0]);
    final aov = widget.data?.averageOrderValueMinor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chain / Targets & Benchmarking',
              style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 16),
          const Text(
            'Multi-Branch Target Benchmarking Grid',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Corporate targets you have set, against today\'s chain figures '
            'and the best branch',
            style: TextStyle(fontSize: 13, color: c.muted),
          ),
          if (repo == null) ...[
            const SizedBox(height: 12),
            Text(kNeedsServerToSave,
                style: TextStyle(fontSize: 12, color: Colors.orange[800])),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 16.0;
            final columns = constraints.maxWidth > 900 ? 4 : 2;
            final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
            Widget tile(Widget t) => SizedBox(width: w, child: t);
            return Wrap(spacing: gap, runSpacing: gap, children: [
              tile(StatTile(
                large: true,
                label: 'Targets set',
                value: '$setCount of ${_kpis.length}',
                sub: setCount == _kpis.length
                    ? 'Every KPI has a target'
                    : 'Set the rest below',
              )),
              tile(StatTile(
                large: true,
                label: 'Chain food cost today',
                value: foodCost == null ? null : '$foodCost%',
                sub: _targets['Food Cost Ratio %'] == null
                    ? 'Target not set'
                    : 'Target ${_format(_kpis[0], _targets['Food Cost Ratio %']!.value)}',
              )),
              tile(StatTile(
                large: true,
                label: 'Chain AOV today',
                value: aov == null ? null : formatPaise(aov),
                sub: _targets['Average Order Value'] == null
                    ? 'Target not set'
                    : 'Target ${_format(_kpis[2], _targets['Average Order Value']!.value)}',
              )),
              tile(StatTile(
                large: true,
                label: 'Last target change',
                value: latest?.createdAt == null
                    ? null
                    : formatShortDateTime(latest!.createdAt!.toLocal()),
                emptyTooltip: 'No target saved yet',
                sub: latest?.createdByName,
              )),
            ]);
          }),
          const SizedBox(height: 24),
          DashCard(
            title: 'Key Performance Indicators (KPI) target matrix',
            subtitle: 'Actual and best branch are today\'s figures from the '
                'Proviyaa server',
            trailing: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadError != null)
                  NoDataView(
                    compact: true,
                    icon: Icons.error_outline,
                    title: 'Saved targets could not load',
                    message: friendlyErrorText(_loadError!),
                    actionLabel: 'Try again',
                    onAction: _load,
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 28,
                      columns: const [
                        DataColumn(label: _Head('OPERATIONAL KPI')),
                        DataColumn(label: _Head('CORP TARGET')),
                        DataColumn(label: _Head('CHAIN ACTUAL (TODAY)')),
                        DataColumn(label: _Head('BEST BRANCH PEER')),
                        DataColumn(label: _Head('PROGRESS STATUS')),
                        DataColumn(label: _Head('ACTION')),
                      ],
                      rows: [for (final k in _kpis) _row(k)],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(_Kpi kpi) {
    final target = _targets[kpi.name];
    final actual = _actual(kpi);
    final progress = _progress(kpi, target?.value, actual);
    final canSave = widget.repository != null && !_loading;
    return DataRow(cells: [
      DataCell(Text(kpi.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      DataCell(Text(target == null ? 'Not set' : _format(kpi, target.value),
          style: TextStyle(
              fontSize: 13, color: target == null ? Colors.grey[600] : null))),
      DataCell(KpiText(
        actual == null ? null : _format(kpi, actual),
        emptyTooltip:
            kpi.name.startsWith('Wastage') || kpi.name.startsWith('Kitchen')
                ? '$kNotEnoughData — not recorded yet'
                : kNotEnoughData,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      )),
      DataCell(KpiText(
        _bestPeer(kpi),
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ViniiColors.emeraldText),
      )),
      DataCell(Text(progress.text,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: progress.color ?? Colors.grey[600]))),
      DataCell(withTooltip(
        widget.repository == null ? kNeedsServerToSave : null,
        OutlinedButton(
          onPressed: canSave ? () => _openAmendmentDialog(kpi) : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(target == null ? 'Set Target' : 'Change Target',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      )),
    ]);
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5));
}
