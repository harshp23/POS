import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api/api_client.dart';
import '../../data/csv.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

part 'tasks_detail.dart';
part 'tasks_form.dart';

/// Task Manager (v1/Task Manager/*.png): operational tasks assigned to
/// staff, with a checklist, evidence rules, manager verification and a
/// timeline. Everything is read from /v1/tasks on the Proviyaa server.
///
///   assigned → in_progress → submitted → completed
///                                      ↘ failed → reassigned → …
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.api, this.branches = const []});
  final ProviyaaApiClient api;

  /// The restaurant's branches: a task is done at one of them (the picker
  /// shows when there are several).
  final List<BranchLocation> branches;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum _TaskView { list, form, detail }

// ── shared labels & helpers ─────────────────────────────────────────────

const _statusOptions = <(String, String)>[
  ('', 'All statuses'),
  ('draft', 'Draft'),
  ('assigned', 'Assigned'),
  ('in_progress', 'In Progress'),
  ('submitted', 'Verification Pending'),
  ('completed', 'Completed'),
  ('failed', 'Failed'),
  ('reassigned', 'Reassigned'),
];

const _priorityOptions = <(String, String)>[
  ('', 'All priorities'),
  ('high', 'High'),
  ('medium', 'Medium'),
  ('low', 'Low'),
];

const _dueOptions = <(String, String)>[
  ('', 'Any date'),
  ('today', 'Due today'),
  ('week', 'Due in the next 7 days'),
  ('month', 'Due this month'),
];

const _cadenceLabels = <(String, String)>[
  ('once', 'One-time'),
  ('daily', 'Daily'),
  ('weekly', 'Weekly'),
  ('monthly', 'Monthly'),
];

const _taskCapsLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w600,
    color: ViniiColors.textSecondaryLight);

const _taskOrange = Color(0xFFF59E0B);

String _optionLabel(List<(String, String)> items, dynamic v) {
  final s = '${v ?? ''}';
  for (final (key, label) in items) {
    if (key == s) return label;
  }
  return humanize(s);
}

/// A task's category as it reads in the form ("safety & compliance" →
/// "Safety & Compliance").
String _categoryLabel(dynamic v) {
  final s = textOf(v, '');
  if (s.isEmpty) return '';
  for (final c in _taskCategories) {
    if (c.toLowerCase() == s.toLowerCase()) return c;
  }
  return humanize(s);
}

/// A timeline note: the server writes a recurring task's cadence as
/// "daily task"; it reads "Daily task".
String _eventNote(dynamic v) {
  final s = textOf(v, '');
  final m = RegExp(r'^(once|daily|weekly|monthly) task$', caseSensitive: false)
      .firstMatch(s);
  if (m == null) return s;
  final cadence = m.group(1)!.toLowerCase();
  return cadence == 'once'
      ? 'One-time task'
      : '${_optionLabel(_cadenceLabels, cadence)} task';
}

/// "Raju Patil (Captain)".
String _staffName(Map<String, dynamic> s) {
  final role = textOf(s['designation'], '');
  return '${textOf(s['full_name'])}${role.isEmpty ? '' : ' ($role)'}';
}

/// "Ramesh Singh (Chef)" for the task's assignee.
String _assigneeText(Map<String, dynamic> t) {
  final name = textOf(t['assignee_name'], '');
  if (name.isEmpty) return 'Unassigned';
  final role = textOf(t['assignee_role'], '');
  return role.isEmpty ? name : '$name ($role)';
}

List<String> _stringList(dynamic v) =>
    v is List ? [for (final x in v) '$x'] : const <String>[];

/// Label and tone of a task's status. With [showOverdue], an overdue open
/// task reads "Overdue".
(String, PillTone) _statusLook(Map<String, dynamic> t,
    {bool showOverdue = true}) {
  final s = '${t['status'] ?? ''}';
  if (showOverdue && t['overdue'] == true && s != 'failed') {
    return ('Overdue', PillTone.red);
  }
  return switch (s) {
    'draft' => ('Draft', PillTone.gray),
    'assigned' => ('Assigned', PillTone.gray),
    'in_progress' => ('In Progress', PillTone.amber),
    'submitted' => ('Verification Pending', PillTone.blue),
    'completed' => ('Completed', PillTone.green),
    'failed' => ('Failed', PillTone.red),
    'reassigned' => ('Reassigned', PillTone.blue),
    _ => (humanize(s), PillTone.gray),
  };
}

/// Outlined "● High" priority pill.
class _PriorityPill extends StatelessWidget {
  const _PriorityPill(this.priority);
  final dynamic priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch ('${priority ?? ''}') {
      'high' => ('High', ViniiColors.redSolid),
      'low' => ('Low', ViniiColors.greenSolid),
      _ => ('Medium', ViniiColors.amberSolid),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ViniiColors.textPrimaryLight)),
      ]),
    );
  }
}

/// KPI tile: caps label with an optional dot, big value, caption.
class _TaskStat extends StatelessWidget {
  const _TaskStat(
      {required this.label,
      required this.value,
      required this.caption,
      this.dot,
      this.valueColor = ViniiColors.textPrimaryLight});
  final String label;
  final String value;
  final String caption;
  final Color? dot;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _taskCapsLabel),
            ),
            if (dot != null)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot!, shape: BoxShape.circle),
              ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: valueColor)),
          const SizedBox(height: 6),
          Text(caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MasterStyle.muted),
        ]),
      );
}

/// A date box that may be empty (with a clear button).
class _TaskDate extends StatelessWidget {
  const _TaskDate(
      {super.key,
      required this.value,
      required this.onChanged,
      this.emptyLabel = 'Not set'});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(children: [
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final today = staffToday();
            final picked = await showDatePicker(
              context: context,
              initialDate: v ?? today,
              firstDate: DateTime(today.year - 2),
              lastDate: DateTime(today.year + 3, 12, 31),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kStaffBorder),
            ),
            child: Row(children: [
              Expanded(
                child: Text(v == null ? emptyLabel : staffDay(v),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            v == null ? FontWeight.w400 : FontWeight.w600,
                        color: v == null
                            ? ViniiColors.textMutedLight
                            : ViniiColors.textPrimaryLight)),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 15, color: ViniiColors.textSecondaryLight),
            ]),
          ),
        ),
      ),
      if (v != null)
        StaffIconAction(
            icon: Icons.close,
            tooltip: 'Clear date',
            onPressed: () => onChanged(null)),
    ]);
  }
}

// ── the screen ───────────────────────────────────────────────────────────

class _TasksScreenState extends State<TasksScreen> {
  _TaskView _view = _TaskView.list;
  String? _taskId;
  Map<String, dynamic>? _editing;
  int _rev = 0;

  int _tab = 0;
  String _status = '';
  String _priority = '';
  String _assignee = '';
  String _due = '';

  /// Active staff who can be given tasks (GET /v1/tasks/assignees).
  List<Map<String, dynamic>> _staff = const [];
  String? _staffError;

  /// The restaurant's staff role names (GET /v1/staff/roles); empty when
  /// they cannot be read.
  List<String> _roleNames = const [];

  static const _tabs = <(String, String)>[
    ('all', 'All Tasks'),
    ('active', 'Active'),
    ('completed', 'Completed'),
    ('failed', 'Failed'),
    ('mine', 'My Assignments'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final d = jsonMap(await widget.api.get('v1/staff/roles'));
      if (!mounted) return;
      setState(() => _roleNames = distinctText([
            for (final r in jsonList(d['roles'])) r['name'],
          ]));
    } catch (_) {
      // The form falls back to the usual restaurant roles.
    }
  }

  /// Roles a task can be meant for: the restaurant's roles and the
  /// designations of its staff; the usual roles when neither could be read.
  List<String> get _roleOptions {
    final real = distinctText([
      ..._roleNames,
      for (final s in _staff) s['designation'],
    ]);
    return real.isEmpty ? _taskRoles : real;
  }

  Future<void> _loadStaff() async {
    try {
      final rows = jsonList(await widget.api.get('v1/tasks/assignees'));
      if (!mounted) return;
      setState(() {
        _staff = rows;
        _staffError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _staffError = apiErrorText(e));
    }
  }

  Map<String, String> get _query {
    final q = <String, String>{'tab': _tabs[_tab].$1};
    if (_status.isNotEmpty) q['status'] = _status;
    if (_priority.isNotEmpty) q['priority'] = _priority;
    if (_assignee.isNotEmpty) q['assignee'] = _assignee;
    final t = staffToday();
    if (_due == 'today') {
      q['from'] = isoDay(t);
      q['to'] = isoDay(t);
    } else if (_due == 'week') {
      q['from'] = isoDay(t);
      q['to'] = isoDay(DateTime(t.year, t.month, t.day + 6));
    } else if (_due == 'month') {
      q['from'] = isoDay(DateTime(t.year, t.month, 1));
      q['to'] = isoDay(DateTime(t.year, t.month + 1, 0));
    }
    return q;
  }

  bool get _filtered =>
      _status.isNotEmpty ||
      _priority.isNotEmpty ||
      _assignee.isNotEmpty ||
      _due.isNotEmpty;

  void _openDetail(String id) => setState(() {
        _taskId = id;
        _view = _TaskView.detail;
      });

  void _openForm([Map<String, dynamic>? task]) {
    setState(() {
      _editing = task;
      _view = _TaskView.form;
    });
    _loadStaff();
  }

  void _backToList() => setState(() {
        _view = _TaskView.list;
        _editing = null;
        _rev++;
      });

  void _formDone(String id, String message) {
    showStaffNotice(context, message);
    if (_editing == null || id.isEmpty) {
      _backToList();
    } else {
      setState(() => _editing = null);
      _openDetail(id);
    }
  }

  void _formCancel() {
    final editing = _editing;
    if (editing == null) {
      _backToList();
    } else {
      setState(() => _editing = null);
      _openDetail('${editing['id']}');
    }
  }

  Future<void> _export(List<Map<String, dynamic>> rows) async {
    await Clipboard.setData(ClipboardData(
        text: Csv.encode([
      'Task',
      'Category',
      'Assigned to',
      'Role',
      if (hasManyBranches(widget.branches)) 'Branch',
      'Priority',
      'Due date',
      'Status',
      'Evidence',
    ], [
      for (final t in rows)
        [
          textOf(t['title'], ''),
          _categoryLabel(t['category']),
          textOf(t['assignee_name'], ''),
          textOf(t['assignee_role'], ''),
          if (hasManyBranches(widget.branches))
            branchLabel(widget.branches, t['location_id']),
          humanize(t['priority']),
          t['due_date'] == null ? '' : fmtDate(t['due_date']),
          _statusLook(t).$1,
          textOf(t['evidence_url'], ''),
        ],
    ])));
    if (!mounted) return;
    showStaffNotice(
        context, 'Copied ${rows.length} task(s) as CSV to the clipboard');
  }

  @override
  Widget build(BuildContext context) => switch (_view) {
        _TaskView.form => _TaskForm(
            key: ValueKey('task-form-${_editing?['id'] ?? 'new'}'),
            api: widget.api,
            existing: _editing,
            staff: _staff,
            staffError: _staffError,
            roleOptions: _roleOptions,
            branches: widget.branches,
            onCancel: _formCancel,
            onSaved: _formDone,
          ),
        _TaskView.detail => _TaskDetail(
            key: ValueKey('task-detail-$_taskId'),
            api: widget.api,
            taskId: _taskId ?? '',
            staff: _staff,
            branches: widget.branches,
            onBack: _backToList,
            onEdit: _openForm,
            onDeleted: _backToList,
          ),
        _TaskView.list => _list(),
      };

  Widget _list() => BusinessPage(
        title: 'Task Manager',
        subtitle:
            'Operational tasks for your staff, with checklists, evidence and manager sign-off',
        actions: [
          MasterButton(
            key: const Key('task-create'),
            label: '+ Create Task',
            kind: MasterButtonKind.primary,
            onPressed: () => _openForm(),
          ),
        ],
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < _tabs.length; i++)
                Material(
                  color: i == _tab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: Key('task-tab-${_tabs[i].$1}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: i == _tab
                                ? MasterStyle.cardBorder
                                : Colors.transparent),
                      ),
                      child: Text(_tabs[i].$2,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == _tab
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == _tab
                                  ? ViniiColors.textPrimaryLight
                                  : ViniiColors.textSecondaryLight)),
                    ),
                  ),
                ),
            ]),
          ),
          ApiLoader<Map<String, dynamic>>(
            key: ValueKey(
                'tasks-${_query.entries.map((e) => '${e.key}=${e.value}').join('&')}-$_rev'),
            load: () => widget.api.getEnvelope('v1/tasks/tasks', query: _query),
            builder: (context, env, _) =>
                _listBody(jsonList(env['data']), jsonMap(env['summary'])),
          ),
        ],
      );

  Widget _filter(String name, List<(String, String)> options, String value,
      ValueChanged<String> onChanged,
      {Key? key}) {
    var label = options.first.$2;
    for (final (v, l) in options) {
      if (v == value) label = l;
    }
    return MasterFilterButton(
      key: key,
      label: '$name: $label',
      options: [for (final o in options) o.$2],
      onSelected: (picked) {
        for (final (v, l) in options) {
          if (l == picked) {
            onChanged(v);
            return;
          }
        }
      },
    );
  }

  Widget _listBody(List<Map<String, dynamic>> rows, Map<String, dynamic> s) {
    int n(String k) => numOf(s[k]).toInt();
    final staffOptions = <(String, String)>[
      ('', 'All staff'),
      for (final m in _staff) ('${m['id']}', _staffName(m)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KpiGrid(cards: [
        _TaskStat(
            label: 'Total tasks',
            value: '${n('total_this_month')}',
            caption: 'Created this month (drafts included)'),
        _TaskStat(
            label: 'In progress',
            value: '${n('in_progress')}',
            dot: _taskOrange,
            valueColor: ViniiColors.amberSolid,
            caption: 'Started, or submitted and awaiting verification'),
        _TaskStat(
            label: 'Completed',
            value: '${n('completed')}',
            dot: ViniiColors.greenSolid,
            valueColor: ViniiColors.greenSolid,
            caption: 'Closed after sign-off or submission (all time)'),
        _TaskStat(
            label: 'Failed / overdue',
            value: '${n('failed_or_overdue')}',
            dot: ViniiColors.redSolid,
            valueColor: ViniiColors.redSolid,
            caption: 'Requires corrective action'),
      ]),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _filter('Staff', staffOptions, _assignee,
                (v) => setState(() => _assignee = v),
                key: const Key('task-filter-staff')),
            _filter('Priority', _priorityOptions, _priority,
                (v) => setState(() => _priority = v),
                key: const Key('task-filter-priority')),
            _filter('Status', _statusOptions, _status,
                (v) => setState(() => _status = v),
                key: const Key('task-filter-status')),
            _filter('Due', _dueOptions, _due, (v) => setState(() => _due = v),
                key: const Key('task-filter-due')),
            if (_filtered)
              MasterButton(
                label: 'Clear filters',
                kind: MasterButtonKind.text,
                onPressed: () => setState(() {
                  _status = '';
                  _priority = '';
                  _assignee = '';
                  _due = '';
                }),
              ),
            MasterButton(
              key: const Key('task-export'),
              label: 'Export CSV',
              icon: Icons.description_outlined,
              onPressed: () => _export(rows),
            ),
          ],
        ),
      ),
      if (_staffError != null)
        InfoNote("Couldn't load the staff list: $_staffError",
            tone: PillTone.red),
      if (rows.isEmpty)
        MasterCard(
          child: Center(
            child: StaffEmptyState(
              icon: Icons.task_alt_outlined,
              title: _tabs[_tab].$1 == 'mine'
                  ? 'Nothing is assigned to you'
                  : 'No tasks here',
              message: _tabs[_tab].$1 == 'mine'
                  ? 'This tab lists tasks for the staff profile linked to your login.'
                  : (_filtered
                      ? 'No task matches these filters.'
                      : 'Create a task to assign work, a checklist and the evidence you need.'),
            ),
          ),
        )
      else
        MasterTable(
          onRowTap: (i) => _openDetail('${rows[i]['id']}'),
          columns: [
            const MasterColumn('Task name', flex: 4),
            const MasterColumn('Assigned to', flex: 2),
            const MasterColumn('Role', flex: 2),
            if (hasManyBranches(widget.branches))
              const MasterColumn('Branch', flex: 2),
            const MasterColumn('Priority', flex: 2),
            const MasterColumn('Due date', flex: 2),
            const MasterColumn('Status', flex: 3),
            const MasterColumn('Evidence', flex: 2),
          ],
          rows: [for (final t in rows) _cells(t)],
        ),
    ]);
  }

  List<Widget> _cells(Map<String, dynamic> t) {
    final title = '${t['title'] ?? ''}';
    final (label, tone) = _statusLook(t);
    final (real, _) = _statusLook(t, showOverdue: false);
    final evidence = textOf(t['evidence_url'], '');
    final category = _categoryLabel(t['category']);
    return [
      MasterCellTitle(title.isEmpty ? '—' : title,
          key: Key('task-row-$title'),
          subtitle: category.isEmpty ? null : category),
      MasterCellText(textOf(t['assignee_name'], 'Unassigned')),
      MasterCellText(textOf(t['assignee_role'])),
      if (hasManyBranches(widget.branches))
        MasterCellText(branchLabel(widget.branches, t['location_id'])),
      _PriorityPill(t['priority']),
      MasterCellText(fmtDate(t['due_date']),
          color: t['overdue'] == true ? ViniiColors.redSolid : null),
      Tooltip(
        message: label == real ? label : 'Overdue · $real',
        child: MasterStatusPill(label, tone: tone),
      ),
      evidence.isEmpty
          ? const MasterCellText('—', color: ViniiColors.textMutedLight)
          : const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.photo_camera_outlined,
                  size: 14, color: ViniiColors.textSecondaryLight),
              SizedBox(width: 4),
              Text('Photo',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.blueSolid,
                      decoration: TextDecoration.underline,
                      decorationColor: ViniiColors.blueSolid)),
            ]),
    ];
  }
}
