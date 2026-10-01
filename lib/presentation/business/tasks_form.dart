part of 'tasks_screen.dart';

const _taskCategories = [
  'Safety & Compliance',
  'Kitchen Hygiene',
  'Cash & Billing',
  'Inventory',
  'Maintenance',
  'Operations',
];

/// Roles offered when the restaurant's own roles cannot be read.
const _taskRoles = ['Captain', 'Manager', 'Chef', 'Cashier', 'Waiter'];

const _priorityChoices = <(String, String)>[
  ('high', 'High Priority'),
  ('medium', 'Medium Priority'),
  ('low', 'Low Priority'),
];

const _fieldLabel = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: ViniiColors.textPrimaryLight);

/// One editable checklist line.
class _ChecklistLine {
  _ChecklistLine(String text, this.done)
      : controller = TextEditingController(text: text);
  final TextEditingController controller;
  final bool done;
}

/// "Configure Audit Task" (v1/Task Manager/task-create-assign.png):
/// POST /v1/tasks/tasks to create, PATCH /v1/tasks/tasks/:id to edit.
class _TaskForm extends StatefulWidget {
  const _TaskForm(
      {super.key,
      required this.api,
      required this.existing,
      required this.staff,
      required this.staffError,
      required this.onCancel,
      required this.onSaved,
      this.roleOptions = _taskRoles,
      this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> staff;
  final String? staffError;
  final VoidCallback onCancel;

  /// The restaurant's role names and staff designations.
  final List<String> roleOptions;
  final List<BranchLocation> branches;

  /// The saved task's id and a message to show.
  final void Function(String id, String message) onSaved;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final Map<String, dynamic> _e =
      widget.existing ?? const <String, dynamic>{};
  late final _title = TextEditingController(text: textOf(_e['title'], ''));
  late final _description =
      TextEditingController(text: textOf(_e['description'], ''));
  late String _priority = _oneOf(
      _e['priority'], const ['low', 'medium', 'high'], 'medium');
  late String _category = _initialCategory();
  late String? _assignee = _e['assignee_staff_id'] == null
      ? null
      : '${_e['assignee_staff_id']}';
  late final Set<String> _roles = _stringList(_e['roles']).toSet();
  late String? _branch = widget.existing == null
      ? defaultBranchId(widget.branches)
      : (textOf(_e['location_id'], '').isEmpty
          ? null
          : textOf(_e['location_id'], ''));
  late DateTime? _due = DateTime.tryParse('${_e['due_date'] ?? ''}');
  late String _cadence = _oneOf(
      _e['cadence'], const ['once', 'daily', 'weekly', 'monthly'], 'once');
  late bool _photo = _e['photo_required'] == true;
  late bool _checklistRequired = _e['checklist_required'] == true;
  late bool _approval = _e['approval_required'] == true;
  late bool _video = _e['video_required'] == true;
  late final List<_ChecklistLine> _items = [
    for (final i in jsonList(_e['checklist']))
      _ChecklistLine(textOf(i['text'], ''), i['done'] == true),
  ];

  /// Controllers of removed lines, disposed with the form (a TextField may
  /// still hold one for the rest of the frame).
  final List<TextEditingController> _removed = [];
  String? _error;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  /// A new task of a one-branch restaurant belongs to that branch; with
  /// several branches the picker decides.
  bool get _sendBranch =>
      hasManyBranches(widget.branches) ||
      (!_editing && widget.branches.length == 1);

  /// A new task, or a draft being edited: it can be saved as a draft or
  /// assigned. Any other task just saves its changes.
  bool get _isDraft => !_editing || _e['status'] == 'draft';

  static String _oneOf(dynamic v, List<String> allowed, String fallback) {
    final s = '${v ?? ''}';
    return allowed.contains(s) ? s : fallback;
  }

  String _initialCategory() {
    final c = textOf(_e['category'], '');
    if (c.isEmpty) return 'Operations';
    for (final k in _taskCategories) {
      if (k.toLowerCase() == c.toLowerCase()) return k;
    }
    return c;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    for (final c in _removed) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ChecklistLine('', false)));

  void _removeItem(int index) => setState(() {
        _removed.add(_items.removeAt(index).controller);
      });

  void _toggleRole(String role) => setState(() {
        if (!_roles.remove(role)) _roles.add(role);
      });

  Map<String, Object?> _body() {
    final due = _due;
    return {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'priority': _priority,
      'category': _category,
      'roles': _roles.toList(),
      if (_sendBranch) 'location_id': _branch,
      'due_date': due == null ? null : isoDay(due),
      'cadence': _cadence,
      'photo_required': _photo,
      'checklist_required': _checklistRequired,
      'approval_required': _approval,
      'video_required': _video,
      'checklist': [
        for (final i in _items)
          if (i.controller.text.trim().isNotEmpty)
            {'text': i.controller.text.trim(), 'done': i.done},
      ],
    };
  }

  Future<void> _save({required bool draft}) async {
    if (_saving) return;
    final existingId = _e['id'] == null ? null : '${_e['id']}';
    final original = _e['assignee_staff_id'] == null
        ? null
        : '${_e['assignee_staff_id']}';
    final body = _body();
    if (existingId == null) {
      // The server says when the assignee is missing.
      body['assignee_staff_id'] = _assignee;
      body['draft'] = draft;
    } else if (draft) {
      if (_assignee != original) {
        setState(() => _error =
            'Changing who does the task assigns it. Use "Assign & Notify Staff", '
            'or keep the earlier choice to leave it as a draft.');
        return;
      }
    } else {
      if (_assignee == null) {
        setState(() => _error = 'Pick who does the task.');
        return;
      }
      body['assignee_staff_id'] = _assignee;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = existingId == null
          ? await widget.api.post('v1/tasks/tasks', body)
          : await widget.api.patch('v1/tasks/tasks/$existingId', body);
      if (!mounted) return;
      final saved = jsonMap(res);
      final id = textOf(saved['id'], existingId ?? '');
      final who = textOf(saved['assignee_name'], '');
      final String message;
      if (draft) {
        message = 'Draft saved';
      } else if (_isDraft) {
        message = who.isEmpty ? 'Task assigned' : 'Task assigned to $who';
      } else {
        message = 'Task updated';
      }
      widget.onSaved(id, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorText(e);
      });
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged,
          {Key? key}) =>
      InkWell(
        key: key,
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(!value),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
            value: value,
            activeColor: ViniiColors.greenSolid,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: value
                      ? ViniiColors.textPrimaryLight
                      : ViniiColors.textSecondaryLight)),
          const SizedBox(width: 6),
        ]),
      );

  Widget _itemRow(int index) {
    final line = _items[index];
    return Padding(
      key: ObjectKey(line),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        const Icon(Icons.drag_handle,
            size: 18, color: ViniiColors.textMutedLight),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: line.controller,
            style: const TextStyle(fontSize: 13.5),
            decoration: staffInput(hint: 'Checklist step ${index + 1}'),
          ),
        ),
        if (line.done)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Tooltip(
              message: 'Already ticked by staff',
              child: Icon(Icons.check_circle,
                  size: 16, color: ViniiColors.greenSolid),
            ),
          ),
        StaffIconAction(
          icon: Icons.close,
          tooltip: 'Remove item',
          onPressed: () => _removeItem(index),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      ..._taskCategories,
      if (!_taskCategories.contains(_category)) _category,
    ];
    final roles = [
      ...widget.roleOptions,
      for (final r in _roles)
        if (!widget.roleOptions.contains(r)) r,
    ];
    // With a branch picked, staff of that branch (and staff of every
    // branch) are offered; the current assignee always stays.
    final branch = _branch;
    final staff = [
      for (final s in widget.staff)
        if (!hasManyBranches(widget.branches) ||
            branch == null ||
            textOf(s['location_id'], '').isEmpty ||
            s['location_id'] == branch ||
            '${s['id']}' == _assignee)
          s
    ];
    return SingleChildScrollView(
      padding: MasterStyle.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MasterBackLink(
                  label: _editing ? 'Back to task' : 'Back to tasks',
                  onTap: widget.onCancel),
              MasterCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_editing ? 'Edit Task' : 'Configure Audit Task',
                        style: MasterStyle.title.copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    const Text(
                        'Define operations standards, checklists, and mandatory evidence for verification.',
                        style: MasterStyle.subtitle),
                    const Divider(height: 36, color: MasterStyle.cardBorder),
                    BizTextField(
                      key: const Key('task-title'),
                      label: 'Task Title',
                      controller: _title,
                      required: true,
                      hint: 'e.g. Fire extinguisher monthly inspection',
                    ),
                    const SizedBox(height: 14),
                    BizTextField(
                      key: const Key('task-description'),
                      label: 'Operational Description',
                      controller: _description,
                      maxLines: 4,
                      hint: 'What must be done, where, and to what standard',
                    ),
                    const SizedBox(height: 14),
                    StaffFormRow(children: [
                      StaffField(
                        label: 'Task Priority',
                        child: StaffSelect<String>(
                          key: const Key('task-priority'),
                          value: _priority,
                          items: _priorityChoices,
                          onChanged: (v) =>
                              setState(() => _priority = v ?? _priority),
                        ),
                      ),
                      StaffField(
                        label: 'Audit Category',
                        child: StaffSelect<String>(
                          key: const Key('task-category'),
                          value: _category,
                          items: [for (final c in categories) (c, c)],
                          onChanged: (v) =>
                              setState(() => _category = v ?? _category),
                        ),
                      ),
                    ]),
                    if (hasManyBranches(widget.branches))
                      StaffFormRow(children: [
                        BizBranchSelect(
                          selectKey: const Key('task-branch'),
                          branches: widget.branches,
                          value: _branch,
                          onChanged: (v) => setState(() => _branch = v),
                        ),
                        const SizedBox.shrink(),
                      ]),
                    StaffFormRow(children: [
                      StaffField(
                        label: 'Assign to Staff',
                        required: !_isDraft,
                        child: StaffSelect<String>(
                          key: const Key('task-assignee'),
                          value: _assignee,
                          hint: staff.isEmpty
                              ? 'No active staff'
                              : 'Pick a staff member',
                          items: [
                            for (final s in staff)
                              ('${s['id']}', _staffName(s)),
                          ],
                          onChanged: (v) => setState(() => _assignee = v),
                        ),
                      ),
                      StaffField(
                        label: 'Authorized Staff Roles',
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final r in roles)
                            _RoleChip(
                              key: Key('task-role-$r'),
                              label: r,
                              selected: _roles.contains(r),
                              onTap: () => _toggleRole(r),
                            ),
                        ]),
                      ),
                    ]),
                    if (widget.staffError != null)
                      InfoNote(
                          "Couldn't load the staff list: ${widget.staffError}",
                          tone: PillTone.red)
                    else if (widget.staff.isEmpty)
                      const InfoNote(
                          'No active staff in this branch. Add staff under Staff & Users to assign tasks, or save this as a draft.',
                          tone: PillTone.amber),
                    StaffFormRow(children: [
                      StaffField(
                        label: 'Execution Deadline',
                        child: _TaskDate(
                          key: const Key('task-due'),
                          value: _due,
                          emptyLabel: 'No deadline',
                          onChanged: (d) => setState(() => _due = d),
                        ),
                      ),
                      StaffField(
                        label: 'Audit Cadence',
                        child: StaffSelect<String>(
                          key: const Key('task-cadence'),
                          value: _cadence,
                          items: _cadenceLabels,
                          onChanged: (v) =>
                              setState(() => _cadence = v ?? _cadence),
                        ),
                      ),
                    ]),
                    if (_cadence != 'once')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                            'The cadence is recorded on the task as its recurrence; a new copy is not created automatically.',
                            style: MasterStyle.muted),
                      ),
                    const Text('Mandatory Evidence Rules', style: _fieldLabel),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, runSpacing: 0, children: [
                      _check('Live Photo Required', _photo,
                          (v) => setState(() => _photo = v),
                          key: const Key('task-rule-photo')),
                      _check('Checklist Required', _checklistRequired,
                          (v) => setState(() => _checklistRequired = v),
                          key: const Key('task-rule-checklist')),
                      _check('Manager Approval', _approval,
                          (v) => setState(() => _approval = v),
                          key: const Key('task-rule-approval')),
                      _check('Video Evidence', _video,
                          (v) => setState(() => _video = v),
                          key: const Key('task-rule-video')),
                    ]),
                    Text(
                        [
                          if (_photo)
                            'Submitting needs a link to the photo.',
                          if (_checklistRequired)
                            'Every checklist item must be ticked before submitting.',
                          _approval
                              ? 'A manager verifies the submission before the task completes.'
                              : 'Without manager approval the task completes when it is submitted.',
                          if (_video)
                            'Video is recorded as a rule for staff; the submission takes one evidence link.',
                        ].join(' '),
                        style: MasterStyle.muted),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(
                        child: Text('Compliance Checklist Items',
                            style: _fieldLabel),
                      ),
                      TextButton(
                        key: const Key('task-add-item'),
                        onPressed: _addItem,
                        child: const Text('+ Add Item',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ViniiColors.blueSolid)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                            'No checklist items yet. Add the steps staff must tick off.',
                            style: MasterStyle.muted),
                      ),
                    for (var i = 0; i < _items.length; i++) _itemRow(i),
                    const Divider(height: 36, color: MasterStyle.cardBorder),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child:
                            MasterBanner(tone: PillTone.red, message: _error!),
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        if (_isDraft)
                          MasterButton(
                            key: const Key('task-save-draft'),
                            label: 'Save as Draft',
                            onPressed:
                                _saving ? null : () => _save(draft: true),
                          )
                        else
                          MasterButton(
                              label: 'Cancel', onPressed: widget.onCancel),
                        MasterButton(
                          key: const Key('task-assign'),
                          label: _saving
                              ? 'Saving…'
                              : (_isDraft
                                  ? 'Assign & Notify Staff'
                                  : 'Save changes'),
                          kind: MasterButtonKind.primary,
                          onPressed: _saving ? null : () => _save(draft: false),
                        ),
                      ],
                    ),
                    if (_isDraft) ...[
                      const SizedBox(height: 10),
                      const Text(
                          'Assigning puts the task on the staff member\'s list (My Assignments) and on its timeline. '
                          'No SMS or push message is sent.',
                          style: MasterStyle.muted),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle chip for an authorized role.
class _RoleChip extends StatelessWidget {
  const _RoleChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ViniiColors.lightGreenTint : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected ? ViniiColors.greenSolid : kStaffBorder),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? ViniiColors.emeraldText
                        : ViniiColors.textPrimaryLight)),
          ),
        ),
      );
}
