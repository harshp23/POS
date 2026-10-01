import 'package:flutter/material.dart';

import '../../data/franchise_repository.dart';
import '../../domain/vendor_account.dart';
import '../dashboard/dashboard_widgets.dart';
import '../vinii_theme.dart';

/// Audits and compliance tasks, listed from the chain's saved records
/// (`audit_report`, `compliance_task`). Logging an audit, raising a task and
/// moving a task along are saved on the server first; nothing is reported
/// as done unless that succeeded.
class ComplianceAuditScreen extends StatefulWidget {
  const ComplianceAuditScreen({
    super.key,
    this.repository,
    this.branches,
    this.locations,
  });

  /// Loads and saves the records. Null = no server: empty state.
  final FranchiseRepository? repository;

  /// The account's branches; new audits and tasks are saved against the
  /// chosen branch's id.
  final List<BranchLocation>? locations;

  /// Older wiring: branch names only (records then carry the name but no
  /// branch id). Ignored when [locations] is given.
  final List<String>? branches;

  @override
  State<ComplianceAuditScreen> createState() => _ComplianceAuditScreenState();
}

/// A branch offered in the dialogs.
typedef _Branch = ({String? id, String name});

class _ComplianceAuditScreenState extends State<ComplianceAuditScreen> {
  static const _categories = [
    'Food Hygiene',
    'Pest Control',
    'Fire Safety',
    'Licence & Permits',
    'Equipment & Maintenance',
    'Staff Health & Training',
    'Other',
  ];

  List<FranchiseRecord> _audits = const [];
  List<FranchiseRecord> _tasks = const [];
  bool _loading = false;
  Object? _loadError;
  bool _showClosed = false;
  final Set<String> _busy = {};

  List<_Branch> get _branchOptions {
    final locations = widget.locations;
    if (locations != null && locations.isNotEmpty) {
      return [for (final l in locations) (id: l.id, name: l.name)];
    }
    return [
      for (final b in widget.branches ?? const <String>[]) (id: null, name: b)
    ];
  }

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void didUpdateWidget(ComplianceAuditScreen old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) _load();
  }

  Future<void> _load({bool initial = false}) async {
    final repo = widget.repository;
    if (repo == null) return;
    _loading = true;
    _loadError = null;
    if (!initial) setState(() {});
    try {
      final lists = await Future.wait([
        repo.records('audit_report', limit: 50),
        repo.records('compliance_task', limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _audits = lists[0];
        _tasks = lists[1];
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

  static String _grade(int score) => score >= 90
      ? 'A'
      : score >= 75
          ? 'B'
          : score >= 60
              ? 'C'
              : 'D';

  String _branchOf(FranchiseRecord r) {
    final named = r.details['branch'];
    if (named is String && named.isNotEmpty) return named;
    final id = r.locationId;
    if (id != null) {
      for (final l in widget.locations ?? const <BranchLocation>[]) {
        if (l.id == id) return l.name;
      }
    }
    return '—';
  }

  static DateTime? _dueOf(FranchiseRecord r) {
    final v = r.details['due_date'];
    return v is String ? DateTime.tryParse(v) : null;
  }

  static bool _isOpen(FranchiseRecord r) =>
      r.status == 'open' || r.status == 'in_progress';

  bool _isOverdue(FranchiseRecord r, DateTime today) {
    final due = _dueOf(r);
    return _isOpen(r) && due != null && due.isBefore(today);
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Saves a record; reloads and confirms only after the save succeeded.
  Future<bool> _save(
      Future<void> Function(FranchiseRepository r) action, String done) async {
    final repo = widget.repository;
    if (repo == null) return false;
    try {
      await action(repo);
    } catch (e) {
      if (mounted) showResultSnack(context, 'Could not save: ${friendlyErrorText(e)}', error: true);
      return false;
    }
    if (mounted) showResultSnack(context, done);
    await _load();
    return true;
  }

  Future<void> _setTaskStatus(FranchiseRecord task, String status) async {
    setState(() => _busy.add(task.id));
    await _save(
        (r) => r.updateRecordStatus(task.id, status),
        status == 'completed'
            ? 'Task marked done.'
            : 'Task moved to In progress.');
    if (mounted) setState(() => _busy.remove(task.id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository == null) return const FranchiseNoData();
    final c = PanelColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scores = [
      for (final a in _audits)
        if (a.details['score'] is num) (a.details['score'] as num).toDouble(),
    ];
    final avg =
        scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
    final openTasks = _tasks.where(_isOpen).toList();
    final overdue = _tasks.where((t) => _isOverdue(t, today)).length;
    final shownTasks = _showClosed ? _tasks : openTasks;
    final canRaise = _branchOptions.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chain / Compliance & Audit',
              style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 16),
          if (overdue > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFEDF89)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFB54708)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      overdue == 1
                          ? '1 compliance task is past its due date.'
                          : '$overdue compliance tasks are past their due date.',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB54708)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FSSAI Compliance, Hygiene & Safety Audit Center',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Internal audits and corrective-action tasks recorded '
                    'for your branches',
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  withTooltip(
                    canRaise ? null : 'This account has no branches.',
                    OutlinedButton.icon(
                      onPressed: canRaise ? _showRaiseTaskModal : null,
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                      label: const Text('Raise Task'),
                    ),
                  ),
                  withTooltip(
                    canRaise ? null : 'This account has no branches.',
                    ElevatedButton.icon(
                      onPressed: canRaise ? _showLogAuditModal : null,
                      icon: const Icon(Icons.add_task, size: 16),
                      label: const Text('Log Audit Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ViniiColors.brandGreen,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loadError != null)
            DashCard(
              title: 'Records could not load',
              child: NoDataView(
                compact: true,
                icon: Icons.error_outline,
                title: 'Audits and tasks could not load',
                message: friendlyErrorText(_loadError!),
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          else if (_loading && _audits.isEmpty && _tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              const gap = 16.0;
              final columns = constraints.maxWidth > 900 ? 4 : 2;
              final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
              Widget tile(Widget t) => SizedBox(width: w, child: t);
              final latest = _audits.isEmpty ? null : _audits.first;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                tile(StatTile(
                  large: true,
                  label: 'Average internal audit score',
                  value: avg == null ? null : '${avg.round()} / 100',
                  emptyTooltip: 'No audit scores logged yet',
                  sub: avg == null
                      ? 'No audits logged yet'
                      : 'Grade ${_grade(avg.round())} · ${scores.length} '
                          '${scores.length == 1 ? 'audit' : 'audits'}',
                )),
                tile(StatTile(
                  large: true,
                  label: 'Open compliance tasks',
                  value: '${openTasks.length}',
                  sub: '${_tasks.length - openTasks.length} closed',
                )),
                tile(StatTile(
                  large: true,
                  label: 'Overdue tasks',
                  value: '$overdue',
                  valueColor: overdue > 0 ? const Color(0xFFB54708) : null,
                  sub: 'Past their due date',
                )),
                tile(StatTile(
                  large: true,
                  label: 'Latest audit',
                  value: latest?.createdAt == null
                      ? null
                      : _date(latest!.createdAt!.toLocal()),
                  emptyTooltip: 'No audits logged yet',
                  sub: latest == null ? null : _branchOf(latest),
                )),
              ]);
            }),
            const SizedBox(height: 24),
            DashCard(
              title: 'Corrective Actions Queue',
              subtitle: 'Compliance tasks raised for your branches',
              trailing: Wrap(spacing: 6, children: [
                ChoiceChip(
                  label: const Text('Open', style: TextStyle(fontSize: 11)),
                  selected: !_showClosed,
                  onSelected: (_) => setState(() => _showClosed = false),
                ),
                ChoiceChip(
                  label: const Text('All', style: TextStyle(fontSize: 11)),
                  selected: _showClosed,
                  onSelected: (_) => setState(() => _showClosed = true),
                ),
              ]),
              child: shownTasks.isEmpty
                  ? Text(
                      _tasks.isEmpty
                          ? 'No compliance tasks yet. Use Raise Task to add one.'
                          : 'No open compliance tasks.',
                      style: TextStyle(fontSize: 12, color: c.muted))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        horizontalMargin: 12,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: _Head('CATEGORY')),
                          DataColumn(label: _Head('BRANCH')),
                          DataColumn(label: _Head('OBSERVATION')),
                          DataColumn(label: _Head('RAISED')),
                          DataColumn(label: _Head('DUE')),
                          DataColumn(label: _Head('STATUS')),
                          DataColumn(label: _Head('')),
                        ],
                        rows: [
                          for (final t in shownTasks) _taskRow(t, today),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            DashCard(
              title: 'Audit Reports',
              subtitle: 'Most recent first',
              child: _audits.isEmpty
                  ? Text('No audits logged yet.',
                      style: TextStyle(fontSize: 12, color: c.muted))
                  : Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final a in _audits.take(20))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.fact_check_outlined,
                                  size: 18),
                              title: Text(a.title,
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(
                                  [
                                    _branchOf(a),
                                    if (a.createdByName != null)
                                      a.createdByName!,
                                    if (a.createdAt != null)
                                      formatShortDateTime(
                                          a.createdAt!.toLocal()),
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 11)),
                              trailing: a.details['score'] is num
                                  ? Text(
                                      '${a.details['score']}/100',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  DataRow _taskRow(FranchiseRecord t, DateTime today) {
    final due = _dueOf(t);
    final overdue = _isOverdue(t, today);
    final busy = _busy.contains(t.id);
    final category = t.details['category'];
    final observation = t.details['observation'];
    final statusLabel = switch (t.status) {
      'open' => 'Open',
      'in_progress' => 'In progress',
      'completed' => 'Done',
      'cancelled' => 'Cancelled',
      _ => t.status,
    };
    return DataRow(cells: [
      DataCell(StatusPill(category is String ? category : 'Task',
          color: ViniiColors.blueSolid)),
      DataCell(Text(_branchOf(t),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      DataCell(SizedBox(
        width: 260,
        child: Text(observation is String ? observation : t.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
      )),
      DataCell(Text(
          [
            if (t.createdAt != null) _date(t.createdAt!.toLocal()),
            if (t.createdByName != null) t.createdByName!,
          ].join(' · '),
          style: const TextStyle(fontSize: 11))),
      DataCell(Text(due == null ? '—' : _date(due),
          style: TextStyle(
              fontSize: 12,
              fontWeight: overdue ? FontWeight.bold : null,
              color: overdue ? const Color(0xFFB54708) : null))),
      DataCell(StatusPill(statusLabel,
          color: switch (t.status) {
            'completed' => ViniiColors.emeraldText,
            'in_progress' => ViniiColors.amberSolid,
            'cancelled' => ViniiColors.graySolid,
            _ => ViniiColors.redSolid,
          })),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.status == 'open')
            TextButton(
              onPressed: busy ? null : () => _setTaskStatus(t, 'in_progress'),
              child: const Text('Start', style: TextStyle(fontSize: 11)),
            ),
          if (_isOpen(t))
            ElevatedButton(
              onPressed: busy ? null : () => _setTaskStatus(t, 'completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              child: Text(busy ? 'Saving…' : 'Mark done'),
            ),
        ],
      )),
    ]);
  }

  Widget _branchField(_Branch value, ValueChanged<_Branch> onChanged) {
    final options = _branchOptions;
    return DropdownButtonFormField<int>(
      initialValue: options.indexOf(value),
      decoration: const InputDecoration(
          labelText: 'Branch', border: OutlineInputBorder()),
      items: [
        for (final (i, b) in options.indexed)
          DropdownMenuItem(value: i, child: Text(b.name)),
      ],
      onChanged: (i) {
        if (i != null) onChanged(options[i]);
      },
    );
  }

  Future<void> _showLogAuditModal() async {
    final scoreController = TextEditingController();
    final notesController = TextEditingController();
    var branch = _branchOptions.first;
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
        Future<void> submit() async {
          final score = int.tryParse(scoreController.text.trim());
          if (score == null || score < 0 || score > 100) {
            setDialog(() => error = 'Enter a score between 0 and 100.');
            return;
          }
          setDialog(() {
            error = null;
            saving = true;
          });
          final grade = _grade(score);
          final notes = notesController.text.trim();
          final ok = await _save(
              (r) => r.logRecord(
                  'audit_report',
                  'Internal audit: ${branch.name} — $score/100 ($grade)',
                  {
                    'branch': branch.name,
                    'score': score,
                    'grade': grade,
                    if (notes.isNotEmpty) 'notes': notes,
                  },
                  status: 'completed',
                  locationId: branch.id),
              'Audit logged: ${branch.name}, $score/100 (grade $grade).');
          if (ok) {
            if (ctx.mounted) Navigator.pop(ctx);
          } else {
            setDialog(() => saving = false);
          }
        }

        return AlertDialog(
          title: const Text('Log New Internal Compliance Audit'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _branchField(branch, (b) => setDialog(() => branch = b)),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('audit-score'),
                  controller: scoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Audit score (out of 100)',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
              ),
              child: Text(saving ? 'Saving…' : 'Save Audit Report'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showRaiseTaskModal() async {
    final observationController = TextEditingController();
    var branch = _branchOptions.first;
    var category = _categories.first;
    DateTime? due;
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
        Future<void> submit() async {
          final observation = observationController.text.trim();
          if (observation.isEmpty) {
            setDialog(() => error = 'Describe what needs to be fixed.');
            return;
          }
          setDialog(() {
            error = null;
            saving = true;
          });
          final ok = await _save(
              (r) => r.logRecord(
                  'compliance_task',
                  '$category: $observation (${branch.name})',
                  {
                    'branch': branch.name,
                    'category': category,
                    'observation': observation,
                    if (due != null) 'due_date': _iso(due!),
                  },
                  status: 'open',
                  locationId: branch.id),
              'Task raised for ${branch.name}.');
          if (ok) {
            if (ctx.mounted) Navigator.pop(ctx);
          } else {
            setDialog(() => saving = false);
          }
        }

        return AlertDialog(
          title: const Text('Raise Compliance Task'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _branchField(branch, (b) => setDialog(() => branch = b)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setDialog(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('task-observation'),
                  controller: observationController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observation / corrective action',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(due == null ? 'No due date' : 'Due ${_date(due!)}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: due ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 3),
                        );
                        if (picked != null) setDialog(() => due = picked);
                      },
                      child: const Text('Set due date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
              ),
              child: Text(saving ? 'Saving…' : 'Raise Task'),
            ),
          ],
        );
      }),
    );
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
