import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

enum _View { list, detail, builder }

/// Training tab — the three screens of v1/staff managment/Dashboard Preview
/// container.png: Staff Training Modules, the module detail (chapters +
/// MCQ assessment) and the Module Creator & Test Builder.
class TrainingTab extends StaffTabWidget {
  const TrainingTab({super.key, required super.repository, super.refreshToken});

  @override
  State<TrainingTab> createState() => TrainingTabState();
}

class TrainingTabState extends State<TrainingTab>
    with StaffLoadState<TrainingTab> {
  TrainingOverview _o = const TrainingOverview();
  List<String> _roleOptions = const ['All Staff'];

  /// Staff codes by staff id, so pickers can tell namesakes apart.
  Map<String, String> _codes = const {};
  _View _view = _View.list;
  String? _openId;
  TrainingModule? _editing;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    _o = await repo.training();
    // Role names and job titles decide who a module is for. Either list
    // may be off-limits to this account; the module still works without.
    final names = <String>['All Staff'];
    void add(String n) {
      final t = n.trim();
      if (t.isNotEmpty &&
          !names.any((x) => x.toLowerCase() == t.toLowerCase())) {
        names.add(t);
      }
    }

    try {
      for (final r in (await repo.roles()).roles) {
        add(r.name);
      }
    } catch (_) {}
    final codes = <String, String>{};
    try {
      for (final s in await repo.employees()) {
        add(s.designation);
        if (s.staffCode.isNotEmpty) codes[s.id] = s.staffCode;
      }
    } catch (_) {}
    _roleOptions = names;
    _codes = codes;
  }

  /// "+ Create Module" in the page header.
  void createModule() => setState(() {
        _editing = null;
        _view = _View.builder;
      });

  void _edit(TrainingModule m) => setState(() {
        _editing = m;
        _view = _View.builder;
      });

  void _open(TrainingModule m) => setState(() {
        _openId = m.id;
        _view = _View.detail;
      });

  void _back() => setState(() => _view = _View.list);

  Future<void> _delete(TrainingModule m) async {
    final ok = await staffConfirm(context,
        title: 'Delete ${m.title}?',
        message: 'The module and all test attempts for it are removed.');
    if (!ok || !mounted) return;
    await act(() => repo.deleteTrainingModule(m.id),
        success: 'Deleted ${m.title}');
  }

  Future<void> _saved(TrainingModule m) async {
    setState(() {
      _view = _View.list;
      _editing = null;
    });
    await reload();
    if (mounted) {
      showStaffNotice(
          context,
          m.status == 'published'
              ? 'Published ${m.title}'
              : 'Saved ${m.title} as draft');
    }
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        guarded(() {
          switch (_view) {
            case _View.builder:
              return _ModuleBuilder(
                repository: repo,
                existing: _editing,
                roleOptions: _roleOptions,
                onCancel: _back,
                onSaved: _saved,
              );
            case _View.detail:
              final m = _o.modules.where((m) => m.id == _openId).firstOrNull;
              if (m == null) return _list();
              return _ModuleDetail(
                repository: repo,
                module: m,
                staffCodes: _codes,
                onBack: _back,
                onEdit: () => _edit(m),
                onSubmitted: reload,
              );
            case _View.list:
              return _list();
          }
        }),
      ]);

  Widget _list() {
    final o = _o;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MasterGrid(columns: 4, minItemWidth: 200, children: [
        StaffStatTile(
            label: 'Total modules',
            value: '${o.totalModules}',
            icon: Icons.menu_book_outlined),
        StaffStatTile(
            label: 'Completions',
            value: '${o.completionsPassed} Passed',
            icon: Icons.check,
            color: kStaffGreen,
            tint: const Color(0xFFF0FDF4)),
        StaffStatTile(
            label: 'In progress',
            value: '${o.inProgress}',
            icon: Icons.hourglass_bottom,
            color: kStaffAmber,
            tint: ViniiColors.amberTint),
        StaffStatTile(
            label: 'Failed attempts',
            value: '${o.failedAttempts}',
            icon: Icons.close,
            color: kStaffRed,
            tint: ViniiColors.redTint),
      ]),
      const SizedBox(height: 24),
      const Text('Active Training Programs', style: MasterStyle.sectionTitle),
      const SizedBox(height: 12),
      if (o.modules.isEmpty)
        MasterCard(
          child: StaffEmptyState(
            icon: Icons.school_outlined,
            title: 'No training modules yet',
            message: 'Create a module with video chapters and a multiple-'
                'choice test, assign it to roles, and track who passed.',
            actions: [
              MasterButton(
                  key: const Key('training-create-empty'),
                  label: 'Create Module',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: createModule),
            ],
          ),
        )
      else
        MasterGrid(
            columns: 2,
            minItemWidth: 420,
            spacing: 16,
            children: [for (final m in o.modules) _card(m)]),
    ]);
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 14) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    return '${d.inDays ~/ 7} weeks ago';
  }

  Widget _card(TrainingModule m) {
    final ratio = m.assignedCount == 0 ? 0.0 : m.passedCount / m.assignedCount;
    final color = ratio >= 0.5
        ? kStaffGreen
        : ratio > 0
            ? kStaffAmber
            : ViniiColors.textMutedLight;
    final attempted = m.progress.any((p) => p.status != 'not_started');
    return MasterCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 84,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF4B5563)]),
            ),
            child: const Icon(Icons.play_lesson_outlined,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(m.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                ),
                MasterStatusPill(
                    m.status == 'published' ? 'Published' : 'Draft',
                    tone: m.status == 'published'
                        ? PillTone.green
                        : PillTone.amber),
              ]),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final r in m.roles)
                      StaffChip(r,
                          color: ViniiColors.textPrimaryLight,
                          tint: const Color(0xFFF3F4F6)),
                    Text(
                        ' • ${m.videos.length} Videos • ${m.questions.length} '
                        'MCQs • ${m.timeLimitMinutes} min',
                        style: MasterStyle.muted),
                  ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text(
                'Completion: ${m.passedCount}/${m.assignedCount} staff passed',
                style: MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text('${(ratio * 100).round()}%',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: color == ViniiColors.textMutedLight ? kStaffGreen : color,
              backgroundColor: const Color(0xFFE5E7EB)),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: kStaffBorder),
        const SizedBox(height: 10),
        Text(attempted ? 'INDIVIDUAL PROGRESS' : 'STATUS',
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textSecondaryLight)),
        const SizedBox(height: 6),
        if (!attempted)
          Text(
              m.assignedCount == 0
                  ? 'No staff match the assigned roles yet'
                  : 'Not Started (${m.assignedCount} staff assigned)',
              style: MasterStyle.body.copyWith(
                  color: ViniiColors.textSecondaryLight,
                  fontWeight: FontWeight.w600))
        else
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final p in m.progress.take(8)) _progressLine(p),
            if (m.progress.length > 8)
              Text('+${m.progress.length - 8} more', style: MasterStyle.muted),
          ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text(
                m.updatedAt == null ? '' : 'Updated ${_ago(m.updatedAt)}',
                style: MasterStyle.muted),
          ),
          IconButton(
            key: Key('training-delete-${m.id}'),
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: busy ? null : () => _delete(m),
            icon: const Icon(Icons.delete_outline,
                size: 19, color: ViniiColors.redSolid),
          ),
          const SizedBox(width: 4),
          MasterButton(
              key: Key('training-edit-${m.id}'),
              label: 'Edit',
              onPressed: () => _edit(m)),
          const SizedBox(width: 8),
          MasterButton(
              key: Key('training-open-${m.id}'),
              label: attempted ? 'View Details' : 'Start Module',
              onPressed: () => _open(m)),
        ]),
      ]),
    );
  }

  static Widget _progressLine(TrainingProgress p) {
    final (icon, color, label) = switch (p.status) {
      'passed' => (Icons.check, kStaffGreen, 'Passed'),
      'failed' => (Icons.close, kStaffRed, 'Failed'),
      'in_progress' => (Icons.hourglass_bottom, kStaffAmber, 'In Progress'),
      _ => (
          Icons.radio_button_unchecked,
          ViniiColors.textMutedLight,
          'Not started'
        ),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(p.staffName, style: MasterStyle.body),
      const SizedBox(width: 4),
      Text('($label)',
          style: MasterStyle.muted.copyWith(fontStyle: FontStyle.italic)),
    ]);
  }
}

// ── module detail: chapters + assessment ─────────────────────────────────

class _ModuleDetail extends StatefulWidget {
  const _ModuleDetail({
    required this.repository,
    required this.module,
    required this.onBack,
    required this.onEdit,
    required this.onSubmitted,
    this.staffCodes = const {},
  });
  final StaffRepository repository;
  final TrainingModule module;

  /// Staff codes by staff id (for the "Taking the test" picker).
  final Map<String, String> staffCodes;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final Future<void> Function() onSubmitted;

  @override
  State<_ModuleDetail> createState() => _ModuleDetailState();
}

class _ModuleDetailState extends State<_ModuleDetail> {
  int _chapter = 0;

  /// Chapters opened with the play button (ticked in the outline). There
  /// is no in-app video player, so play only records that it was opened.
  final _opened = <int>{};
  String? _takerId;
  late List<int?> _answers = List.filled(widget.module.questions.length, null);
  int _q = 0;
  bool _submitting = false;
  TrainingResult? _result;
  String? _resultFor;

  TrainingModule get m => widget.module;

  @override
  void didUpdateWidget(covariant _ModuleDetail old) {
    super.didUpdateWidget(old);
    if (old.module.questions.length != m.questions.length) _restart();
    if (_chapter >= m.videos.length) _chapter = 0;
  }

  void _restart() {
    _answers = List.filled(m.questions.length, null);
    _q = 0;
    _result = null;
  }

  Future<void> _submit() async {
    final taker = _takerId;
    if (taker == null) return;
    setState(() => _submitting = true);
    try {
      final r = await widget.repository.submitTrainingAttempt(
          m.id, taker, [for (final a in _answers) a ?? -1]);
      if (!mounted) return;
      setState(() {
        _result = r;
        _resultFor = m.progress
            .where((p) => p.staffId == taker)
            .map((p) => p.staffName)
            .firstOrNull;
      });
      await widget.onSubmitted();
    } catch (e) {
      if (mounted) showStaffError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Staff Training > ${m.title}',
                        style: MasterStyle.muted),
                    const SizedBox(height: 4),
                    Text(m.title,
                        style: MasterStyle.title.copyWith(fontSize: 20)),
                  ]),
              Wrap(spacing: 10, children: [
                MasterButton(
                    key: const Key('training-edit-open'),
                    label: 'Edit Module',
                    icon: Icons.edit_outlined,
                    onPressed: widget.onEdit),
                MasterButton(
                    key: const Key('training-back'),
                    label: 'Back to Modules',
                    onPressed: widget.onBack),
              ]),
            ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final left = _videoColumn();
          final right = _assessment();
          if (c.maxWidth < 900) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: right),
          ]);
        }),
      ]);

  Widget _videoColumn() {
    final videos = m.videos;
    final current = videos.isEmpty ? null : videos[_chapter];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 320,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111827), Color(0xFF374151)]),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Material(
                color: ViniiColors.brandGreen,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('training-play'),
                  customBorder: const CircleBorder(),
                  onTap: current == null
                      ? null
                      : () => setState(() => _opened.add(_chapter)),
                  child: const SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(Icons.play_arrow,
                          size: 36, color: Colors.black)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                    current == null
                        ? 'No video chapters yet'
                        : 'Chapter ${_chapter + 1}: ${current.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(height: 4),
              Text(
                  current == null
                      ? 'Add chapters in Edit Module.'
                      : [
                          m.title,
                          if (current.duration.isNotEmpty) current.duration,
                        ].join(' • '),
                  style:
                      const TextStyle(fontSize: 12.5, color: Colors.white70)),
            ]),
          ),
          if (current != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                  current.url.isEmpty
                      ? 'No video link for this chapter.'
                      : 'Preview only — open ${current.url} to watch.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11.5, color: Colors.white60)),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      MasterCard(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Chapter Outline', style: MasterStyle.sectionTitle),
          const SizedBox(height: 10),
          if (videos.isEmpty)
            const Text('This module has no video chapters.',
                style: MasterStyle.muted),
          for (var i = 0; i < videos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color:
                    i == _chapter ? ViniiColors.lightGreenTint : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  key: Key('training-chapter-$i'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _chapter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: i == _chapter
                              ? ViniiColors.brandGreen
                              : kStaffBorder),
                    ),
                    child: Row(children: [
                      Icon(
                          i == _chapter
                              ? Icons.play_arrow
                              : _opened.contains(i)
                                  ? Icons.check
                                  : Icons.radio_button_unchecked,
                          size: 18,
                          color: i == _chapter || _opened.contains(i)
                              ? ViniiColors.textPrimaryLight
                              : ViniiColors.textMutedLight),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Ch ${i + 1}: ${videos[i].title}',
                            overflow: TextOverflow.ellipsis,
                            style: MasterStyle.body.copyWith(
                                fontWeight: i == _chapter
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                      Text(videos[i].duration, style: MasterStyle.muted),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _assessment() {
    final questions = m.questions;
    final takers = m.progress;
    Widget body;
    if (questions.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
            'No questions in this module yet. Edit the module to add '
            'some.',
            style: MasterStyle.muted),
      );
    } else if (_result != null) {
      final r = _result!;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        MasterBanner(
          tone: r.passed ? PillTone.green : PillTone.red,
          title: r.passed ? 'Passed' : 'Failed',
          message: '${_resultFor ?? 'Staff'} scored ${r.score}% '
              '(${r.correct}/${r.total} correct) · pass mark ${m.passScore}%',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: MasterButton(
              key: const Key('training-retake'),
              label: 'Take again',
              icon: Icons.refresh,
              onPressed: () => setState(_restart)),
        ),
      ]);
    } else {
      final q = questions[_q];
      final last = _q == questions.length - 1;
      final answered = _answers.every((a) => a != null);
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 14),
        Text('QUESTION ${_q + 1} OF ${questions.length}',
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textSecondaryLight)),
        const SizedBox(height: 6),
        Text(q.question,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textPrimaryLight)),
        const SizedBox(height: 12),
        for (var j = 0; j < q.options.length; j++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color:
                  _answers[_q] == j ? ViniiColors.lightGreenTint : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('training-option-$j'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _answers[_q] = j),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _answers[_q] == j
                            ? ViniiColors.greenSolid
                            : kStaffBorder),
                  ),
                  child: Row(children: [
                    Text(String.fromCharCode(65 + j),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _answers[_q] == j
                                ? ViniiColors.greenSolid
                                : ViniiColors.textSecondaryLight)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(q.options[j], style: MasterStyle.body)),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          MasterButton(
              key: const Key('training-prev'),
              label: 'Previous',
              onPressed: _q == 0 ? null : () => setState(() => _q--)),
          const Spacer(),
          if (!last)
            MasterButton(
                key: const Key('training-next'),
                label: 'Next Question',
                kind: MasterButtonKind.primary,
                onPressed: () => setState(() => _q++))
          else
            MasterButton(
                key: const Key('training-submit'),
                label: _submitting ? 'Submitting…' : 'Submit Test',
                kind: MasterButtonKind.primary,
                onPressed: _submitting || _takerId == null || !answered
                    ? null
                    : _submit),
        ]),
        if (last && (_takerId == null || !answered))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                _takerId == null
                    ? 'Pick who is taking the test to submit.'
                    : 'Answer every question to submit '
                        '(${_answers.where((a) => a == null).length} left).',
                style: MasterStyle.muted),
          ),
      ]);
    }
    return MasterCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('Assessment Test', style: MasterStyle.sectionTitle)),
          Text('PASS MARK: ${m.passScore}%',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kStaffGreen)),
        ]),
        const SizedBox(height: 4),
        Text(
            '${questions.length} question${questions.length == 1 ? '' : 's'}'
            '${m.timeLimitMinutes > 0 ? ' · ${m.timeLimitMinutes} min time limit' : ''}',
            style: MasterStyle.muted),
        const SizedBox(height: 12),
        const Divider(height: 1, color: kStaffBorder),
        const SizedBox(height: 12),
        StaffField(
          label: 'Taking the test',
          child: StaffSelect<String>(
            key: const Key('training-taker'),
            dense: true,
            value: _takerId,
            hint: takers.isEmpty ? 'No staff assigned' : 'Select staff',
            items: [
              for (final p in takers)
                (
                  p.staffId,
                  staffPickLabel(p.staffName, widget.staffCodes[p.staffId])
                )
            ],
            onChanged: takers.isEmpty
                ? null
                : (v) => setState(() {
                      _takerId = v;
                      _restart();
                    }),
          ),
        ),
        body,
        const SizedBox(height: 16),
        const Divider(height: 1, color: kStaffBorder),
        const SizedBox(height: 12),
        const Text('RECENT SUBMISSIONS',
            style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
                color: ViniiColors.textSecondaryLight)),
        const SizedBox(height: 8),
        if (takers.isEmpty)
          const Text('No staff match the roles this module is assigned to.',
              style: MasterStyle.muted),
        for (final p in takers)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                  child: Text(p.staffName,
                      overflow: TextOverflow.ellipsis,
                      style: MasterStyle.body)),
              Text(
                  switch (p.status) {
                    'passed' => 'Passed ${p.bestScore ?? 0}%',
                    'failed' => 'Failed ${p.bestScore ?? 0}%',
                    'in_progress' => 'In Progress',
                    _ => 'Not started',
                  },
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: switch (p.status) {
                        'passed' => kStaffGreen,
                        'failed' => kStaffRed,
                        'in_progress' => kStaffAmber,
                        _ => ViniiColors.textMutedLight,
                      })),
            ]),
          ),
      ]),
    );
  }
}

// ── module creator & test builder ────────────────────────────────────────

class _VideoDraft {
  _VideoDraft([TrainingVideo? v])
      : title = TextEditingController(text: v?.title),
        url = TextEditingController(text: v?.url),
        duration = TextEditingController(text: v?.duration);
  final TextEditingController title;
  final TextEditingController url;
  final TextEditingController duration;

  void dispose() {
    title.dispose();
    url.dispose();
    duration.dispose();
  }
}

class _QuestionDraft {
  _QuestionDraft([TrainingQuestion? q])
      : question = TextEditingController(text: q?.question),
        options = [
          for (var i = 0; i < 4; i++)
            TextEditingController(
                text: q != null && i < q.options.length ? q.options[i] : '')
        ],
        correct = q?.answerIndex ?? 0;
  final TextEditingController question;
  final List<TextEditingController> options;
  int correct;

  void dispose() {
    question.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class _ModuleBuilder extends StatefulWidget {
  const _ModuleBuilder({
    required this.repository,
    required this.existing,
    required this.roleOptions,
    required this.onCancel,
    required this.onSaved,
  });
  final StaffRepository repository;
  final TrainingModule? existing;
  final List<String> roleOptions;
  final VoidCallback onCancel;
  final ValueChanged<TrainingModule> onSaved;

  @override
  State<_ModuleBuilder> createState() => _ModuleBuilderState();
}

class _ModuleBuilderState extends State<_ModuleBuilder> {
  late final TrainingModule? _e = widget.existing;
  late final _title = TextEditingController(text: _e?.title);
  late final _description = TextEditingController(text: _e?.description);
  late final _pass = TextEditingController(text: '${_e?.passScore ?? 80}');
  late final _time =
      TextEditingController(text: '${_e?.timeLimitMinutes ?? 30}');
  late final Set<String> _roles = {...?_e?.roles};
  late final List<_VideoDraft> _videos = [
    for (final v in _e?.videos ?? const <TrainingVideo>[]) _VideoDraft(v)
  ];
  late final List<_QuestionDraft> _questions = [
    for (final q in _e?.questions ?? const <TrainingQuestion>[])
      _QuestionDraft(q)
  ];
  int _expanded = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_roles.isEmpty) _roles.add('All Staff');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pass.dispose();
    _time.dispose();
    for (final v in _videos) {
      v.dispose();
    }
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  List<String> get _roleChoices => [
        ...widget.roleOptions,
        for (final r in _roles)
          if (!widget.roleOptions.contains(r)) r,
      ];

  void _toggleRole(String r) => setState(() {
        if (r == 'All Staff') {
          _roles
            ..clear()
            ..add('All Staff');
          return;
        }
        _roles.remove('All Staff');
        _roles.contains(r) ? _roles.remove(r) : _roles.add(r);
        if (_roles.isEmpty) _roles.add('All Staff');
      });

  Future<void> _save(String status) async {
    final title = _title.text.trim();
    final pass = int.tryParse(_pass.text.trim());
    final time = int.tryParse(_time.text.trim());
    String? problem;
    if (title.isEmpty) problem = 'Give the module a name.';
    if (pass == null || pass < 1 || pass > 100) {
      problem ??= 'Pass score is a percentage from 1 to 100.';
    }
    if (time == null || time < 0) {
      problem ??= 'Time limit is a number of minutes.';
    }
    final questions = <TrainingQuestion>[];
    for (var i = 0; i < _questions.length && problem == null; i++) {
      final d = _questions[i];
      final text = d.question.text.trim();
      final opts = [for (final o in d.options) o.text.trim()];
      final kept = [
        for (var j = 0; j < opts.length; j++)
          if (opts[j].isNotEmpty) j
      ];
      if (text.isEmpty) {
        problem = 'Question ${i + 1} has no text.';
      } else if (kept.length < 2) {
        problem = 'Question ${i + 1} needs at least two options.';
      } else if (opts[d.correct].isEmpty) {
        problem = 'Mark a filled-in option as correct for question ${i + 1}.';
      } else {
        questions.add(TrainingQuestion(
          question: text,
          options: [for (final j in kept) opts[j]],
          answerIndex: kept.indexOf(d.correct),
        ));
      }
    }
    if (problem == null && status == 'published' && questions.isEmpty) {
      problem = 'Add at least one question before publishing.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveTrainingModule(TrainingModule(
        id: _e?.id ?? '',
        title: title,
        description: _description.text.trim(),
        category: _e?.category ?? '',
        roles: _roles.toList(),
        passScore: pass!,
        timeLimitMinutes: time!,
        videos: [
          for (final v in _videos)
            if (v.title.text.trim().isNotEmpty)
              TrainingVideo(
                  title: v.title.text.trim(),
                  url: v.url.text.trim(),
                  duration: v.duration.text.trim()),
        ],
        questions: questions,
        status: status,
      ));
      if (mounted) widget.onSaved(saved);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
                color: ViniiColors.textSecondaryLight)),
      );

  Widget _input(TextEditingController c,
          {Key? key, String? hint, int maxLines = 1, bool number = false}) =>
      TextField(
        key: key,
        controller: c,
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        style: const TextStyle(fontSize: 13.5),
        decoration: staffInput(hint: hint),
      );

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'Staff Training > '
                        '${_e == null ? 'Create Module' : 'Edit Module'} / '
                        'Test Builder',
                        style: MasterStyle.muted),
                    const SizedBox(height: 4),
                    Text('Module Creator & Test Builder',
                        style: MasterStyle.title.copyWith(fontSize: 20)),
                  ]),
              Wrap(spacing: 10, children: [
                MasterButton(
                    key: const Key('training-cancel'),
                    label: 'Cancel',
                    kind: MasterButtonKind.text,
                    onPressed: _saving ? null : widget.onCancel),
                MasterButton(
                    key: const Key('training-save-draft'),
                    label: 'Save as Draft',
                    onPressed: _saving ? null : () => _save('draft')),
                MasterButton(
                    key: const Key('training-publish'),
                    label: _saving ? 'Saving…' : 'Publish Module',
                    kind: MasterButtonKind.primary,
                    onPressed: _saving ? null : () => _save('published')),
              ]),
            ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          MasterBanner(tone: PillTone.red, message: _error!),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final left = _specs();
          final right = _questionsCard();
          if (c.maxWidth < 900) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 11, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 9, child: right),
          ]);
        }),
      ]);

  Widget _specs() => MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Module Specifications', style: MasterStyle.sectionTitle),
          const SizedBox(height: 12),
          _label('MODULE NAME'),
          _input(_title,
              key: const Key('training-title'),
              hint: 'Kitchen Fire Safety Protocol'),
          const SizedBox(height: 12),
          _label('DESCRIPTION / LEARNING OBJECTIVES'),
          _input(_description,
              key: const Key('training-description'), maxLines: 3),
          const SizedBox(height: 12),
          _label('ASSIGN TO STAFF ROLES'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _roleChoices)
              FilterChip(
                key: Key('training-role-$r'),
                label: Text(r),
                selected: _roles.contains(r),
                showCheckmark: true,
                checkmarkColor: ViniiColors.textPrimaryLight,
                selectedColor: const Color(0xFFF3F4F6),
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: _roles.contains(r)
                        ? ViniiColors.textPrimaryLight
                        : kStaffBorder),
                labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        _roles.contains(r) ? FontWeight.w700 : FontWeight.w500,
                    color: ViniiColors.textPrimaryLight),
                onSelected: (_) => _toggleRole(r),
              ),
          ]),
          const SizedBox(height: 4),
          const Text(
              'Staff are assigned by their login role or job title. '
              'All Staff = every active employee.',
              style: MasterStyle.muted),
          const SizedBox(height: 12),
          StaffFormRow(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _label('PASS SCORE (%)'),
              _input(_pass, key: const Key('training-pass'), number: true),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _label('TIME LIMIT (MINUTES)'),
              _input(_time, key: const Key('training-time'), number: true),
            ]),
          ]),
          const Divider(height: 1, color: kStaffBorder),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('MODULE VIDEO CHAPTERS (${_videos.length})',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ViniiColors.textPrimaryLight)),
            ),
            TextButton.icon(
              key: const Key('training-add-video'),
              onPressed: () => setState(() => _videos.add(_VideoDraft())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Video'),
              style: TextButton.styleFrom(
                  foregroundColor: ViniiColors.greenSolid,
                  backgroundColor: ViniiColors.lightGreenTint),
            ),
          ]),
          const SizedBox(height: 8),
          if (_videos.isEmpty)
            const Text(
                'No chapters yet — add the video links staff should '
                'watch before the test.',
                style: MasterStyle.muted),
          for (var i = 0; i < _videos.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kStaffBorder),
              ),
              child: Row(children: [
                Text('${i + 1})',
                    style:
                        MasterStyle.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 5,
                    child: _input(_videos[i].title,
                        key: Key('training-video-$i-title'),
                        hint: 'Chapter title')),
                const SizedBox(width: 8),
                Expanded(
                    flex: 5,
                    child: _input(_videos[i].url,
                        key: Key('training-video-$i-url'), hint: 'https://…')),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: _input(_videos[i].duration,
                        key: Key('training-video-$i-duration'), hint: 'mm:ss')),
                IconButton(
                  key: Key('training-video-$i-remove'),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _videos.removeAt(i).dispose()),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: ViniiColors.textSecondaryLight),
                ),
              ]),
            ),
        ]),
      );

  Widget _questionsCard() => MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('Assessment Questions (${_questions.length})',
                  style: MasterStyle.sectionTitle),
            ),
            MasterButton(
                key: const Key('training-add-question'),
                label: 'Add Question',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: () => setState(() {
                      _questions.add(_QuestionDraft());
                      _expanded = _questions.length - 1;
                    })),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kStaffBorder),
          const SizedBox(height: 12),
          if (_questions.isEmpty)
            const Text(
                'No questions yet. Staff answer these after the '
                'videos; the pass score decides who passes.',
                style: MasterStyle.muted),
          for (var i = 0; i < _questions.length; i++)
            i == _expanded ? _expandedQuestion(i) : _collapsedQuestion(i),
        ]),
      );

  Widget _collapsedQuestion(int i) {
    final text = _questions[i].question.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('training-q-$i-expand'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kStaffBorder),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                    'Q${i + 1}: ${text.isEmpty ? '(no text yet)' : text}',
                    overflow: TextOverflow.ellipsis,
                    style:
                        MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Text('Edit ✎', style: MasterStyle.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _expandedQuestion(int i) {
    final d = _questions[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FEE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ViniiColors.brandGreen),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('Q${i + 1} (EXPANDED)',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.greenSolid)),
          ),
          TextButton(
            key: Key('training-q-$i-delete'),
            onPressed: () => setState(() {
              _questions.removeAt(i).dispose();
              if (_expanded >= _questions.length) {
                _expanded = _questions.length - 1;
              }
            }),
            style: TextButton.styleFrom(foregroundColor: ViniiColors.redSolid),
            child: const Text('Delete'),
          ),
        ]),
        _input(d.question,
            key: Key('training-q-$i'), hint: 'Question', maxLines: 2),
        const SizedBox(height: 8),
        for (var j = 0; j < 4; j++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Tooltip(
                message: 'Mark as correct',
                child: InkWell(
                  key: Key('training-q-$i-correct-$j'),
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => setState(() => d.correct = j),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.correct == j
                          ? ViniiColors.greenSolid
                          : Colors.white,
                      border: Border.all(
                          color: d.correct == j
                              ? ViniiColors.greenSolid
                              : kStaffBorder),
                    ),
                    child: d.correct == j
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(String.fromCharCode(65 + j),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ViniiColors.textSecondaryLight)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _input(d.options[j],
                    key: Key('training-q-$i-opt-$j'),
                    hint: 'Option ${String.fromCharCode(65 + j)}'
                        '${d.correct == j ? ' (correct)' : ''}'),
              ),
            ]),
          ),
        const Text('Tap a letter to mark the correct answer.',
            style: MasterStyle.muted),
      ]),
    );
  }
}
