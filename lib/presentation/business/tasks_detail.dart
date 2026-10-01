part of 'tasks_screen.dart';

/// One task (v1/Task Manager/task-detail-flow.png, task-failed-corrective.png):
/// specification, checklist, evidence, sign-off and the execution timeline,
/// with the actions its status allows.
class _TaskDetail extends StatefulWidget {
  const _TaskDetail(
      {super.key,
      required this.api,
      required this.taskId,
      required this.staff,
      required this.onBack,
      required this.onEdit,
      required this.onDeleted,
      this.branches = const []});
  final ProviyaaApiClient api;
  final String taskId;
  final List<Map<String, dynamic>> staff;
  final List<BranchLocation> branches;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic> task) onEdit;
  final VoidCallback onDeleted;

  @override
  State<_TaskDetail> createState() => _TaskDetailState();
}

typedef _Reassignment = ({String staffId, DateTime? due, String note});

class _TaskDetailState extends State<_TaskDetail> {
  bool _busy = false;

  String get _path => 'v1/tasks/tasks/${widget.taskId}';

  Future<Map<String, dynamic>> _load() async =>
      jsonMap(await widget.api.get(_path));

  /// Runs a task call; on success reloads the task in place.
  Future<void> _run(Future<dynamic> Function() call, VoidCallback reload,
      [String? success]) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await runAction(context, () async {
      await call();
      return true;
    }, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) reload();
  }

  Future<void> _start(VoidCallback reload) =>
      _run(() => widget.api.post('$_path/start'), reload, 'Task started');

  Future<void> _submit(Map<String, dynamic> t, VoidCallback reload) async {
    final needsPhoto = t['photo_required'] == true;
    final review = t['approval_required'] == true;
    final v = await showStaffPrompt(
      context,
      title: 'Submit task',
      subtitle: review
          ? 'It goes to a manager for verification.'
          : 'No manager approval is needed, so the task completes now.',
      width: 520,
      fields: [
        StaffPromptField('url',
            needsPhoto ? 'Evidence photo link (required)' : 'Evidence photo link',
            key: const Key('task-evidence-url'), hint: 'https://…'),
        const StaffPromptField('note', 'Note',
            key: Key('task-evidence-note'), maxLines: 3),
      ],
      note: const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
            'Paste a link to the photo (for example from Google Drive). Files cannot be uploaded here.',
            style: MasterStyle.muted),
      ),
      confirmLabel: 'Submit',
      confirmKey: const Key('task-submit-confirm'),
      validate: (values) {
        final url = values['url'] ?? '';
        if (url.isNotEmpty && !(Uri.tryParse(url)?.hasScheme ?? false)) {
          return 'The evidence link must be a full address starting with https://';
        }
        return null;
      },
    );
    if (v == null || !mounted) return;
    await _run(
        () => widget.api.post('$_path/submit',
            {'evidence_url': v['url'] ?? '', 'note': v['note'] ?? ''}),
        reload,
        review ? 'Submitted for verification' : 'Task completed');
  }

  Future<void> _approve(VoidCallback reload) async {
    final v = await showStaffPrompt(
      context,
      title: 'Approve task',
      subtitle: 'Sign the task off as verified. It completes now.',
      fields: const [
        StaffPromptField('note', 'Sign-off note',
            key: Key('task-verify-note'), maxLines: 3),
      ],
      confirmLabel: 'Approve',
      confirmKey: const Key('task-approve-confirm'),
    );
    if (v == null || !mounted) return;
    await _run(
        () => widget.api.post(
            '$_path/verify', {'approved': true, 'note': v['note'] ?? ''}),
        reload,
        'Task approved and completed');
  }

  Future<void> _fail(VoidCallback reload) async {
    final v = await showStaffPrompt(
      context,
      title: 'Fail verification',
      subtitle:
          'The task is marked failed. Reassign it afterwards to start corrective action.',
      width: 520,
      fields: const [
        StaffPromptField('reason', 'Failure reason',
            key: Key('task-failure-reason'), maxLines: 3),
        StaffPromptField('note', 'Corrective directive',
            key: Key('task-corrective-note'),
            maxLines: 3,
            hint: 'What must be done again'),
      ],
      confirmLabel: 'Fail task',
      confirmKey: const Key('task-fail-confirm'),
      danger: true,
    );
    if (v == null || !mounted) return;
    await _run(
        () => widget.api.post('$_path/verify', {
              'approved': false,
              'failure_reason': v['reason'] ?? '',
              'note': v['note'] ?? '',
            }),
        reload,
        'Task marked failed');
  }

  Future<void> _reassign(Map<String, dynamic> t, VoidCallback reload) async {
    final r = await showDialog<_Reassignment>(
      context: context,
      builder: (_) => _ReassignDialog(staff: widget.staff, task: t),
    );
    if (r == null || !mounted) return;
    final due = r.due;
    await _run(
        () => widget.api.post('$_path/reassign', {
              'assignee_staff_id': r.staffId,
              'due_date': due == null ? null : isoDay(due),
              'note': r.note,
            }),
        reload,
        'Task reassigned');
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await staffConfirm(context,
        title: 'Delete this task?',
        message:
            '"${textOf(t['title'])}" and its timeline will be removed from the Task Manager.');
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await widget.api.delete(_path);
      return true;
    }, success: 'Task deleted');
    if (done == true && mounted) widget.onDeleted();
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showStaffNotice(context, 'Evidence link copied');
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: MasterStyle.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MasterBackLink(label: 'Back to tasks', onTap: widget.onBack),
          ApiLoader<Map<String, dynamic>>(
            load: _load,
            builder: (context, t, reload) => _page(t, reload),
          ),
        ]),
      );

  Widget _page(Map<String, dynamic> t, VoidCallback reload) {
    final status = '${t['status'] ?? ''}';
    final open = const ['assigned', 'in_progress', 'submitted', 'reassigned']
        .contains(status);
    final canRun = !_busy;
    final actions = <Widget>[
      if (status == 'assigned' || status == 'reassigned')
        MasterButton(
          key: const Key('task-start'),
          label: 'Start',
          icon: Icons.play_arrow_outlined,
          onPressed: canRun ? () => _start(reload) : null,
        ),
      if (status == 'in_progress' ||
          status == 'assigned' ||
          status == 'reassigned')
        MasterButton(
          key: const Key('task-submit'),
          label: 'Submit',
          icon: Icons.upload_outlined,
          kind: MasterButtonKind.primary,
          onPressed: canRun ? () => _submit(t, reload) : null,
        ),
      if (status == 'submitted') ...[
        MasterButton(
          key: const Key('task-approve'),
          label: 'Approve',
          icon: Icons.check,
          kind: MasterButtonKind.primary,
          onPressed: canRun ? () => _approve(reload) : null,
        ),
        MasterButton(
          key: const Key('task-fail'),
          label: 'Fail',
          icon: Icons.close,
          kind: MasterButtonKind.dangerOutline,
          onPressed: canRun ? () => _fail(reload) : null,
        ),
      ],
      if (status == 'failed' || open)
        MasterButton(
          key: const Key('task-reassign'),
          label: 'Reassign',
          icon: Icons.swap_horiz,
          onPressed: canRun ? () => _reassign(t, reload) : null,
        ),
      if (status != 'completed')
        MasterButton(
          key: const Key('task-edit'),
          label: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: () => widget.onEdit(t),
        ),
      MasterButton(
        key: const Key('task-delete'),
        label: 'Delete',
        icon: Icons.delete_outline,
        kind: MasterButtonKind.dangerOutline,
        onPressed: canRun ? () => _delete(t) : null,
      ),
    ];
    final category = _categoryLabel(t['category']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterPageHeader(
        title: textOf(t['title']),
        subtitle: [
          if (category.isNotEmpty) category,
          _optionLabel(_cadenceLabels, t['cadence']),
          'Created ${fmtDateTime(t['created_at'])}',
        ].join(' · '),
        actions: actions,
      ),
      LayoutBuilder(builder: (context, c) {
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _spec(t),
            const SizedBox(height: 16),
            _checklist(t, reload),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, inner) {
              if (inner.maxWidth < 560) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _evidence(t),
                      const SizedBox(height: 16),
                      _audit(t),
                    ]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _evidence(t)),
                    const SizedBox(width: 16),
                    Expanded(child: _audit(t)),
                  ]);
            }),
          ],
        );
        if (c.maxWidth < 900) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            left,
            const SizedBox(height: 16),
            _timeline(t),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _timeline(t)),
        ]);
      }),
    ]);
  }

  // ── cards ──

  Widget _spec(Map<String, dynamic> t) {
    final status = '${t['status'] ?? ''}';
    final (label, tone) = _statusLook(t, showOverdue: false);
    final failure = textOf(t['failure_reason'], '');
    final overdue = t['overdue'] == true;
    final description = textOf(t['description'], '');
    final roles = _stringList(t['roles']);
    final rules = <String>[
      if (t['photo_required'] == true) 'Live photo',
      if (t['checklist_required'] == true) 'Checklist',
      if (t['approval_required'] == true) 'Manager approval',
      if (t['video_required'] == true) 'Video evidence',
    ];
    return MasterCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Flexible(
            child: Text(
                status == 'failed'
                    ? 'Audit Exception Report'
                    : 'Task Specification',
                style: MasterStyle.sectionTitle.copyWith(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          MasterStatusPill(status == 'failed' ? 'Audit Failed' : label,
              tone: tone),
          if (overdue) ...[
            const SizedBox(width: 6),
            const MasterStatusPill('Overdue', tone: PillTone.red),
          ],
          const Spacer(),
          _PriorityPill(t['priority']),
        ]),
        const SizedBox(height: 16),
        if (failure.isNotEmpty) _failureBox(t, failure),
        Text(description.isEmpty ? 'No description.' : description,
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: description.isEmpty
                    ? ViniiColors.textMutedLight
                    : ViniiColors.textSecondaryLight)),
        const Divider(height: 32, color: MasterStyle.cardBorder),
        Wrap(spacing: 32, runSpacing: 14, children: [
          MasterKeyValue(
              status == 'reassigned' ? 'Reassigned to' : 'Assigned to',
              _assigneeText(t)),
          MasterKeyValue('Created by', textOf(t['created_by_name'])),
          MasterKeyValue(
              'Recurrence', _optionLabel(_cadenceLabels, t['cadence'])),
          MasterKeyValue('Due date', fmtDate(t['due_date']),
              valueColor: overdue ? ViniiColors.redSolid : null),
          if (hasManyBranches(widget.branches))
            MasterKeyValue(
                'Branch', branchLabel(widget.branches, t['location_id'])),
        ]),
        if (rules.isNotEmpty || roles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in rules)
              StaffChip('Needs: $r',
                  color: ViniiColors.blueSolid, tint: ViniiColors.blueTint),
            for (final r in roles)
              StaffChip(r,
                  color: ViniiColors.emeraldText,
                  tint: ViniiColors.lightGreenTint),
          ]),
        ],
      ]),
    );
  }

  Widget _failureBox(Map<String, dynamic> t, String failure) {
    final status = '${t['status'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Failure Reason & Operational Breach:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ViniiColors.redSolid)),
        const SizedBox(height: 6),
        Text('"$failure"',
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: Color(0xFF7F1D1D))),
        const SizedBox(height: 12),
        Wrap(spacing: 28, runSpacing: 10, children: [
          if (status != 'failed')
            MasterKeyValue('Reassigned to', _assigneeText(t)),
          MasterKeyValue('Failed by', textOf(t['reviewed_by_name'])),
          MasterKeyValue('Failed on', fmtDateTime(t['reviewed_at'])),
          MasterKeyValue(
              status == 'failed' ? 'Deadline' : 'Re-execution deadline',
              fmtDate(t['due_date'])),
        ]),
        if (status == 'failed') ...[
          const SizedBox(height: 10),
          const Text('Reassign the task to start corrective action.',
              style: TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
        ],
      ]),
    );
  }

  Widget _checklist(Map<String, dynamic> t, VoidCallback reload) {
    final status = '${t['status'] ?? ''}';
    final items = jsonList(t['checklist']);
    final done = items.where((i) => i['done'] == true).length;
    final editable =
        const ['assigned', 'reassigned', 'in_progress'].contains(status);
    final failed = status == 'failed';
    final String subtitle;
    if (editable) {
      subtitle = t['checklist_required'] == true
          ? 'Tick items as they are done. Every item must be ticked before submitting.'
          : 'Tick items as they are done.';
    } else {
      subtitle =
          'Locked while the task is ${_statusLook(t, showOverdue: false).$1.toLowerCase()}.';
    }
    return MasterSection(
      title: '${failed ? 'Checklist Audit State' : 'Task Checklist'} '
          '($done/${items.length} Completed)',
      subtitle: subtitle,
      child: items.isEmpty
          ? const Text('This task has no checklist.', style: MasterStyle.muted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  Row(children: [
                    if (failed && items[i]['done'] != true)
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ViniiColors.redSolid),
                        ),
                        child: const Icon(Icons.close,
                            size: 12, color: ViniiColors.redSolid),
                      )
                    else
                      Checkbox(
                        key: Key('task-check-$i'),
                        value: items[i]['done'] == true,
                        activeColor: ViniiColors.greenSolid,
                        onChanged: editable && !_busy
                            ? (v) => _run(
                                () => widget.api.post('$_path/checklist',
                                    {'index': i, 'done': v ?? false}),
                                reload)
                            : null,
                      ),
                    Expanded(
                      child: Text(textOf(items[i]['text']),
                          style: TextStyle(
                              fontSize: 13.5,
                              color: items[i]['done'] == true
                                  ? ViniiColors.textPrimaryLight
                                  : ViniiColors.textSecondaryLight)),
                    ),
                  ]),
              ],
            ),
    );
  }

  static bool _looksLikeImage(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    return RegExp(r'\.(png|jpe?g|gif|webp|bmp)$').hasMatch(path);
  }

  Widget _evidence(Map<String, dynamic> t) {
    final url = textOf(t['evidence_url'], '');
    final note = textOf(t['evidence_note'], '');
    final rejected = t['status'] == 'failed';
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
                rejected ? 'Rejected Evidence' : 'Mandatory Photo Evidence',
                style: MasterStyle.sectionTitle),
          ),
          if (rejected && url.isNotEmpty)
            const MasterStatusPill('Rejected', tone: PillTone.red),
        ]),
        const SizedBox(height: 12),
        if (url.isEmpty)
          Text(
              t['photo_required'] == true
                  ? 'No photo yet. This task needs a photo link when it is submitted.'
                  : 'No evidence submitted yet.',
              style: MasterStyle.muted)
        else ...[
          if (_looksLikeImage(url))
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 90,
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: const Text("The photo couldn't be loaded.",
                      style: MasterStyle.muted),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SelectableText(url, style: MasterStyle.link),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _copyLink(url),
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy link'),
            ),
          ),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"$note"', style: MasterStyle.body),
        ],
      ]),
    );
  }

  Widget _audit(Map<String, dynamic> t) {
    final status = '${t['status'] ?? ''}';
    final reviewer = textOf(t['reviewed_by_name'], '');
    final note = textOf(t['corrective_note'], '');
    final corrective = status == 'failed' ||
        status == 'reassigned' ||
        textOf(t['failure_reason'], '').isNotEmpty;
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(corrective ? 'Manager Corrective Directive' : 'Audit & Sign-Off',
            style: MasterStyle.sectionTitle),
        const SizedBox(height: 12),
        if (reviewer.isEmpty && note.isEmpty)
          Text(
              t['approval_required'] == true
                  ? 'A manager verifies the task after it is submitted.'
                  : 'This task does not need manager approval; it completes when submitted.',
              style: MasterStyle.muted)
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (reviewer.isNotEmpty)
                Text(
                    corrective && status == 'reassigned'
                        ? 'Action required by ${textOf(t['assignee_name'])}:'
                        : '$reviewer:',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
              const SizedBox(height: 4),
              Text(note.isEmpty ? 'No note left.' : '"$note"',
                  style: note.isEmpty ? MasterStyle.muted : MasterStyle.body),
            ]),
          ),
        if (t['reviewed_at'] != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                  '${status == 'completed' ? 'Approved' : 'Reviewed'}: ${fmtDateTime(t['reviewed_at'])}',
                  style: MasterStyle.muted),
            ),
            if (status == 'completed')
              const Icon(Icons.check_circle,
                  size: 18, color: ViniiColors.greenSolid)
            else if (corrective)
              const MasterStatusPill('Corrective stage', tone: PillTone.amber),
          ]),
        ],
      ]),
    );
  }

  static Color _eventColor(dynamic event) {
    final s = '${event ?? ''}'.toLowerCase();
    if (s.contains('failed')) return ViniiColors.redSolid;
    if (s.contains('corrective') || s.contains('reassigned')) {
      return ViniiColors.amberSolid;
    }
    return ViniiColors.greenSolid;
  }

  static String? _nextStep(Map<String, dynamic> t) =>
      switch ('${t['status'] ?? ''}') {
        'draft' => 'Assign to a staff member',
        'assigned' || 'reassigned' => 'Staff starts and submits the task',
        'in_progress' => 'Staff submits the task',
        'submitted' => 'Pending manager verification',
        'failed' => 'Corrective action (reassign)',
        _ => null,
      };

  Widget _timeline(Map<String, dynamic> t) {
    final events = jsonList(t['events']);
    final next = _nextStep(t);
    final deviation = textOf(t['failure_reason'], '').isNotEmpty;
    return MasterCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(deviation ? 'Audit Deviation Timeline' : 'Task Execution Lifecycle',
            style: MasterStyle.sectionTitle.copyWith(fontSize: 17)),
        const SizedBox(height: 18),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No events recorded yet.', style: MasterStyle.muted),
          ),
        for (var i = 0; i < events.length; i++)
          _TimelineItem(
            title: textOf(events[i]['event']).toUpperCase(),
            note: _eventNote(events[i]['note']),
            actor: textOf(events[i]['actor_name'], ''),
            time: fmtDateTime(events[i]['created_at']),
            color: _eventColor(events[i]['event']),
            last: i == events.length - 1 && next == null,
          ),
        if (next != null)
          _TimelineItem(
            title: 'NEXT: ${next.toUpperCase()}',
            note: '',
            actor: '',
            time: '',
            color: ViniiColors.graySolid,
            last: true,
            upcoming: true,
          ),
      ]),
    );
  }
}

/// One step of the task timeline: dot + connector, name, note, actor, time.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem(
      {required this.title,
      required this.note,
      required this.actor,
      required this.time,
      required this.color,
      required this.last,
      this.upcoming = false});
  final String title;
  final String note;
  final String actor;
  final String time;
  final Color color;
  final bool last;
  final bool upcoming;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 18,
            child: Column(children: [
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: upcoming ? Colors.white : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: upcoming
                    ? null
                    : Icon(
                        color == ViniiColors.redSolid
                            ? Icons.close
                            : Icons.check,
                        size: 10,
                        color: Colors.white),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2, color: color.withValues(alpha: 0.35)),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0.0 : 18.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: upcoming
                                    ? ViniiColors.textMutedLight
                                    : ViniiColors.textPrimaryLight)),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(time,
                            style: const TextStyle(
                                fontSize: 11,
                                color: ViniiColors.textMutedLight)),
                      ],
                    ]),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(note,
                          style: const TextStyle(
                              fontSize: 12,
                              color: ViniiColors.textSecondaryLight)),
                    ],
                    if (actor.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      StaffChip('By $actor',
                          color: ViniiColors.textSecondaryLight,
                          tint: ViniiColors.grayTint),
                    ],
                  ]),
            ),
          ),
        ]),
      );
}

/// "Reassign": who re-does the task, by when, and the directive.
class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.staff, required this.task});
  final List<Map<String, dynamic>> staff;
  final Map<String, dynamic> task;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  late String? _staffId = widget.task['assignee_staff_id'] == null
      ? null
      : '${widget.task['assignee_staff_id']}';
  late DateTime? _due = DateTime.tryParse('${widget.task['due_date'] ?? ''}');
  final _note = TextEditingController();
  String? _error;

  bool get _failed => widget.task['status'] == 'failed';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _staffId;
    if (id == null) {
      setState(() => _error = 'Pick who does the task.');
      return;
    }
    final _Reassignment result =
        (staffId: id, due: _due, note: _note.text.trim());
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Reassign task',
        subtitle: _failed
            ? 'Start corrective action: who re-does the task, and by when'
            : 'Hand the task to someone else',
        width: 520,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
            key: const Key('task-reassign-confirm'),
            label: 'Reassign',
            kind: MasterButtonKind.primary,
            onPressed: _submit,
          ),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffField(
            label: 'Staff member',
            required: true,
            child: StaffSelect<String>(
              key: const Key('task-reassign-staff'),
              value: _staffId,
              hint: widget.staff.isEmpty
                  ? 'No active staff'
                  : 'Pick a staff member',
              items: [
                for (final s in widget.staff) ('${s['id']}', _staffName(s)),
              ],
              onChanged: (v) => setState(() => _staffId = v),
            ),
          ),
          const SizedBox(height: 14),
          StaffField(
            label: 'New deadline',
            child: _TaskDate(
              value: _due,
              emptyLabel: 'Keep the current deadline',
              onChanged: (d) => setState(() => _due = d),
            ),
          ),
          const SizedBox(height: 14),
          BizTextField(
            key: const Key('task-reassign-note'),
            label: _failed ? 'Corrective directive' : 'Note',
            controller: _note,
            maxLines: 3,
            hint: _failed
                ? 'What must be done again, and how'
                : 'Why the task changes hands',
          ),
          const SizedBox(height: 10),
          const Text(
              'Reassigning clears the checklist ticks and the earlier evidence link.',
              style: MasterStyle.muted),
        ]),
      );
}
