import 'package:flutter/material.dart';

import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';
import 'recipe_workflow_tabs.dart';

/// Tabs 7–10 of the Recipes lifecycle (Staff Training, Feedback & Approval,
/// Menu Activation, Cost Impact), transcribed from the Figma Master section
/// (file YKRdukYpjPUuMz5W1tKlqT, node 423:55270). The tab strip itself is
/// owned by master_recipes_screen.dart; each widget here is only the body
/// below it and scrolls on its own. All figures come from [RecipeData].

// ---------------------------------------------------------------------------
// Small private layout helpers
// ---------------------------------------------------------------------------

/// Two columns side by side (with Figma width ratio) that stack when narrow.
class _Split extends StatelessWidget {
  const _Split(
      {required this.left,
      required this.right,
      required this.leftFlex,
      required this.rightFlex});
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  static const breakpoint = 860.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 24), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 24),
          Expanded(flex: rightFlex, child: right),
        ]);
      });
}

/// Banner row: message on the left, bold status text on the right.
class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner(
      {required this.message, required this.trailing, required this.tone});
  final String message;
  final String trailing;
  final PillTone tone;

  @override
  Widget build(BuildContext context) => MasterBanner(
        tone: tone,
        message: message,
        trailing: Text(trailing,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone == PillTone.blue
                    ? const Color(0xFF1E40AF)
                    : tone == PillTone.green
                        ? ViniiColors.emeraldText
                        : const Color(0xFF92400E))),
      );
}

/// Amber note box (e.g. kitchen issue / system notice).
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: ViniiColors.amberTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCD34D))),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF92400E), height: 1.4)),
      );
}

/// Full-width button (Figma sign-off / activation columns).
class _WideButton extends StatelessWidget {
  const _WideButton(this.label, {required this.kind, required this.onPressed});
  final String label;
  final MasterButtonKind kind;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: MasterButton(label: label, kind: kind, onPressed: onPressed),
      );
}

const _cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ViniiColors.textPrimaryLight);

const _fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: ViniiColors.textPrimaryLight);

// ===========================================================================
// 7. Staff Training
// ===========================================================================

class RecipeStaffTrainingTab extends StatefulWidget {
  const RecipeStaffTrainingTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeStaffTrainingTab> createState() => _RecipeStaffTrainingTabState();
}

class _RecipeStaffTrainingTabState extends State<RecipeStaffTrainingTab> {
  static const _steps = [
    '1. WATCH (Video)',
    '2. PRACTICE',
    '3. SUBMIT MEDIA',
    '4. REVIEW',
  ];

  int _step = 0;
  final _staff = TextEditingController();
  String? _uploaded;

  @override
  void dispose() {
    _staff.dispose();
    super.dispose();
  }

  String get _staffName =>
      _staff.text.trim().isEmpty ? 'the staff member' : _staff.text.trim();

  Future<void> _certify(Recipe r) async {
    if (r.trainingTotal == 0) {
      showMasterError(context,
          'No staff are enrolled for ${r.name}. Set the enrolled count in Trials & Training first.');
      return;
    }
    if (r.trainingDone >= r.trainingTotal) {
      showMasterError(context,
          'All ${r.trainingTotal} enrolled staff are already certified on ${r.name}.');
      return;
    }
    final ok = await saveRecipeRecord(
        context, widget.data, r.copyWith(trainingDone: r.trainingDone + 1),
        success:
            'Certified $_staffName on ${r.name} (${r.trainingDone + 1}/${r.trainingTotal})');
    if (ok && mounted) {
      setState(() {
        _step = 0;
        _uploaded = null;
        _staff.clear();
      });
    }
  }

  Future<void> _upload(Recipe r) async {
    final file = await pickMediaFile(context);
    if (file == null || !mounted) return;
    final ok = await runMasterAction(
        context,
        () => widget.data.master.addMedia(
            fileName: file.$1,
            bytes: file.$2,
            folder: 'Recipe Training',
            usageLabel: 'Training · ${r.name} · $_staffName'),
        success: 'Uploaded ${file.$1} to Media → Recipe Training');
    if (ok && mounted) {
      setState(() {
        _uploaded = file.$1;
        if (_step < 3) _step = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data.recipe;
    if (r == null) return const RecipeNoSelection();
    return MasterPage(children: [
      _PhaseBanner(
        tone: PillTone.blue,
        message:
            'ℹ️ Live Training Phase: Staff must complete all 4 modules (Watch, Practice, Submit, Review) to achieve certification.',
        trailing:
            'Certified: ${r.trainingDone} of ${r.trainingTotal} Crew Members',
      ),
      const SizedBox(height: 24),
      _Split(
        leftFlex: 380,
        rightFlex: 732,
        left: _RecipeStandardCard(data: widget.data, recipe: r),
        right:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _stepper(),
          const SizedBox(height: 24),
          _form(r),
        ]),
      ),
    ]);
  }

  Widget _stepper() => MasterCard(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final chips = [
            for (var i = 0; i < _steps.length; i++) _stepChip(i),
          ];
          if (!wide) {
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ch in chips)
                SizedBox(width: (c.maxWidth - 8) / 2, child: ch),
            ]);
          }
          return Row(children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: chips[i]),
            ],
          ]);
        }),
      );

  Widget _stepChip(int i) {
    final done = i < _step;
    final current = i == _step;
    final bg = current
        ? ViniiColors.brandGreen
        : done
            ? ViniiColors.successPillBg
            : const Color(0xFFF9FAFB);
    final fg = current
        ? Colors.black
        : done
            ? ViniiColors.successPillText
            : ViniiColors.textSecondaryLight;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _step = i),
        child: SizedBox(
          height: 32,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (done) ...[
              Icon(Icons.check_circle, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(_steps[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _form(Recipe r) => MasterCard(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Execution & Live Verification Form', style: _cardTitle),
          const SizedBox(height: 24),
          if (widget.data.staffNames.isEmpty)
            RecipeField(
                label: 'Staff Member',
                controller: _staff,
                hint: 'Name of the crew member being verified',
                onChanged: (_) => setState(() {}))
          else
            RecipeDropdown<String>(
              key: ValueKey('staff-${_staff.text}'),
              label: 'Staff Member',
              value: _staff.text,
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Choose the crew member')),
                for (final n in {
                  ...widget.data.staffNames,
                  if (_staff.text.isNotEmpty) _staff.text,
                })
                  if (n.isNotEmpty)
                    DropdownMenuItem(
                        value: n,
                        child: Text(n, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _staff.text = v ?? ''),
            ),
          const SizedBox(height: 20),
          const Text('Upload Prep Video or Image Proof', style: _fieldLabel),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _upload(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: _uploaded == null
                    ? const Color(0xFFF9FAFB)
                    : ViniiColors.greenTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _uploaded == null
                        ? MasterStyle.cardBorder
                        : const Color(0xFF86EFAC)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📷', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                      _uploaded == null
                          ? 'Tap to upload a prep photo or video (max 5 MB)'
                          : '$_uploaded uploaded successfully',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _uploaded == null
                              ? ViniiColors.textSecondaryLight
                              : ViniiColors.emeraldText)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
              'Only the certified-staff count is stored on the recipe; individual training attempts are not recorded.',
              style: MasterStyle.muted),
          const SizedBox(height: 20),
          Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                MasterButton(
                    label: 'Save Draft',
                    onPressed: () => showMasterNotice(context,
                        'Nothing to save yet — progress is recorded when $_staffName is certified')),
                MasterButton(
                    label: 'Request Retry',
                    kind: MasterButtonKind.dangerOutline,
                    onPressed: () {
                      setState(() => _step = 1);
                      showMasterNotice(context,
                          '$_staffName sent back to Practice — certification count unchanged');
                    }),
                MasterButton(
                    label: 'Certify Staff',
                    kind: MasterButtonKind.primary,
                    onPressed: () => _certify(r)),
              ]),
        ]),
      );
}

class _RecipeStandardCard extends StatelessWidget {
  const _RecipeStandardCard({required this.data, required this.recipe});
  final RecipeData data;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final key = [
      for (final l in r.lines)
        if (l.isKey) '${l.name} (${recipeQty(l.qty)} ${l.unit})'
    ];
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Persistent Recipe Standard', style: _cardTitle),
        const SizedBox(height: 20),
        _StdField('Recipe Name', '${r.name} · ${r.version}'),
        _StdField('Key Ingredient & Qty',
            key.isEmpty ? 'No key ingredients tagged' : key.join(', ')),
        _StdField('Preparation Method',
            r.prepMethod.isEmpty ? 'Not documented yet' : r.prepMethod),
        _StdField('Target Portion & Cost',
            '${r.portion.isEmpty ? 'Portion not set' : r.portion} · Food Cost: ${formatInr(data.totalCost(r))} · Target Sell: ${formatInr(r.targetPrice)}'),
        const Text('Allergen Classifications', style: MasterStyle.label),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: MasterStatusPill(
              r.allergens.isEmpty ? 'None declared' : r.allergens,
              tone: r.allergens.isEmpty ? PillTone.gray : PillTone.amber),
        ),
      ]),
    );
  }
}

class _StdField extends StatelessWidget {
  const _StdField(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: MasterStyle.label),
          const SizedBox(height: 3),
          Text(value, style: MasterStyle.value),
        ]),
      );
}

// ===========================================================================
// 8. Feedback & Approval
// ===========================================================================

class RecipeFeedbackApprovalTab extends StatelessWidget {
  const RecipeFeedbackApprovalTab({super.key, required this.data});
  final RecipeData data;

  Future<void> _setStatus(BuildContext context, Recipe r, String status,
      {required String success}) async {
    if (status == 'Rejected') {
      final ok = await confirmMasterAction(context,
          title: 'Reject recipe?',
          message:
              'Mark "${r.name}" ${r.version} as Rejected? It can be revised and resubmitted later.',
          confirmLabel: 'Reject');
      if (!ok || !context.mounted) return;
    }
    await saveRecipeRecord(context, data, r.copyWith(status: status),
        success: success);
  }

  @override
  Widget build(BuildContext context) {
    final r = data.recipe;
    if (r == null) return const RecipeNoSelection();
    final margin = data.marginPct(r);
    final checks = <(String, String, bool)>[
      (
        'Kitchen Trial',
        r.trialResult,
        r.trialResult.toLowerCase().startsWith('pass')
      ),
      (
        'Staff Training',
        '${r.trainingDone}/${r.trainingTotal} certified',
        r.trainingTotal > 0 && r.trainingDone >= r.trainingTotal
      ),
      (
        'Projected Margin',
        recipePct(margin),
        margin >= recipeMarginThresholdPct
      ),
    ];
    final issues = <String>[
      if (r.lines.isEmpty) 'No ingredients in the BOM yet.',
      for (final l in r.lines)
        if (data.materialFor(l) == null)
          "'${l.name}' is not linked to inventory (fallback price used).",
      for (final l in r.lines)
        if (l.substitute.trim().isEmpty)
          "'${l.name}' has no standard substitute.",
      if (r.linkedMenuItemId == null)
        'No linked menu item — activation will not be possible.',
      if (margin < recipeMarginThresholdPct)
        'Margin ${recipePct(margin)} is below the ${recipeMarginThresholdPct.toStringAsFixed(0)}% threshold.',
    ];
    return MasterPage(children: [
      MasterPageHeader(
        title: 'Trial Evaluation & Approval Portal',
        subtitle:
            'Verify trial results, training and costing, then finalize recipe approval',
        actions: [MasterStatusPill(r.status, tone: recipeStatusTone(r.status))],
      ),
      _Split(
        leftFlex: 652,
        rightFlex: 460,
        left: MasterCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Readiness Summary · ${r.name} ${r.version}',
                style: _cardTitle),
            const SizedBox(height: 16),
            MasterGrid(columns: 3, spacing: 12, minItemWidth: 150, children: [
              for (final (label, value, ok) in checks)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ok ? ViniiColors.greenTint : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: ok
                            ? const Color(0xFF86EFAC)
                            : MasterStyle.cardBorder),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${ok ? '✅' : '⚠️'} $label',
                            style: MasterStyle.label),
                        const SizedBox(height: 4),
                        Text(value,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ViniiColors.textPrimaryLight)),
                      ]),
                ),
            ]),
            const SizedBox(height: 32),
            const Text('Open Issues', style: _fieldLabel),
            const SizedBox(height: 8),
            if (issues.isEmpty)
              const MasterBanner(
                  icon: '✅',
                  tone: PillTone.green,
                  message: 'No open issues — the recipe is ready for approval.')
            else
              _Note(issues.map((i) => '⚠️ $i').join('\n')),
          ]),
        ),
        right: MasterCard(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Manager Sign-Off', style: _cardTitle),
            const SizedBox(height: 12),
            Text('Current status: ${r.status} · Trial: ${r.trialResult}',
                style: MasterStyle.body),
            const SizedBox(height: 20),
            const Text(
                '* Approval unlocks Menu Activation, which pushes the target price and food cost to the linked POS menu item.',
                style: MasterStyle.muted),
            const SizedBox(height: 20),
            _WideButton('Approve Recipe',
                kind: MasterButtonKind.primary,
                onPressed: r.status == 'Approved' || r.status == 'Active'
                    ? null
                    : () => _setStatus(context, r, 'Approved',
                        success: '${r.name} approved')),
            const SizedBox(height: 16),
            _WideButton('Request Revisions',
                kind: MasterButtonKind.outline,
                onPressed: () => _setStatus(context, r, 'Needs Attention',
                    success: '${r.name} sent back for revisions')),
            const SizedBox(height: 16),
            _WideButton('Reject Recipe',
                kind: MasterButtonKind.dangerOutline,
                onPressed: r.status == 'Rejected'
                    ? null
                    : () => _setStatus(context, r, 'Rejected',
                        success: '${r.name} rejected')),
          ]),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// 9. Menu Activation
// ===========================================================================

/// Channels a recipe can be activated on — the shared Master channel list
/// (the same names menu items and offers use).
const recipeChannels = masterSalesChannels;

class RecipeMenuActivationTab extends StatefulWidget {
  const RecipeMenuActivationTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeMenuActivationTab> createState() =>
      _RecipeMenuActivationTabState();
}

class _RecipeMenuActivationTabState extends State<RecipeMenuActivationTab> {
  Set<String> _enabled = {};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecipeMenuActivationTab old) {
    super.didUpdateWidget(old);
    final r = widget.data.recipe;
    final o = old.data.recipe;
    if (r?.id != o?.id || (!_dirty && r?.activeChannels != o?.activeChannels)) {
      _load();
    }
  }

  void _load() {
    final r = widget.data.recipe;
    // Older spellings ("Swiggy Delivery", "POS Dine-In"…) map onto the
    // shared channel names.
    _enabled = {
      for (final c in (r?.activeChannels ?? '').split(','))
        if (recipeChannels.contains(canonicalSalesChannel(c)))
          canonicalSalesChannel(c)
    };
    _dirty = false;
  }

  /// Channels the recipe is live on, in the shared vocabulary.
  static Set<String> _liveChannels(Recipe r) => {
        for (final c in r.activeChannels.split(','))
          if (c.trim().isNotEmpty) canonicalSalesChannel(c)
      };

  List<String> get _selected => [
        for (final c in recipeChannels)
          if (_enabled.contains(c)) c
      ];

  /// Why activation is blocked, or null when it is allowed.
  String? _blocker(Recipe r) {
    if (r.status != 'Approved' && r.status != 'Active') {
      return 'Only Approved recipes can be activated — "${r.name}" is ${r.status}. Approve it in Feedback & Approval first.';
    }
    if (r.linkedMenuItemId == null) {
      return '"${r.name}" has no linked menu item. Link one in the Recipe Draft tab so there is a POS item to update.';
    }
    if (widget.data.dish(r.linkedMenuItemId) == null) {
      return 'The linked menu item "${r.linkedMenuItemName}" no longer exists. Pick another one in the Recipe Draft tab.';
    }
    if (_enabled.isEmpty) return 'Enable at least one channel to activate on.';
    return null;
  }

  Future<void> _activate(Recipe r) async {
    final block = _blocker(r);
    if (block != null) {
      showMasterError(context, block);
      return;
    }
    final cost = widget.data.totalCost(r);
    final ok = await runMasterAction(
        context,
        () => widget.data.master
            .activateRecipe(r.id, foodCost: cost, channels: _selected),
        success:
            '${r.name} active on ${_selected.join(', ')} — POS item price ${formatInr(r.targetPrice)}, food cost ${formatInr(cost)}');
    if (ok && mounted) setState(() => _dirty = false);
  }

  Future<void> _saveChannels(Recipe r) async {
    final ok = await saveRecipeRecord(
        context, widget.data, r.copyWith(activeChannels: _selected.join(', ')),
        success: 'Channel selection saved for ${r.name}');
    if (ok && mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final r = d.recipe;
    if (r == null) return const RecipeNoSelection();
    final dish = d.dish(r.linkedMenuItemId);
    final cost = d.totalCost(r);
    final block = _blocker(r);
    final targets = _selected.isEmpty ? 'None selected' : _selected.join(', ');
    return MasterPage(children: [
      _PhaseBanner(
        tone: block == null ? PillTone.green : PillTone.amber,
        message: block == null
            ? '✅ Ready for POS Sync: activation updates "${dish!.name}" on the POS menu with the approved price and food cost.'
            : '⚠️ $block',
        trailing: 'POS Target: $targets',
      ),
      const SizedBox(height: 24),
      _Split(
        leftFlex: 692,
        rightFlex: 420,
        left: MasterCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Menu / POS Channel Selection', style: _cardTitle),
            const SizedBox(height: 16),
            MasterTable(
              minWidth: 560,
              columns: const [
                MasterColumn('POS Channel', flex: 14),
                MasterColumn('Target Price', flex: 12),
                MasterColumn('Status', flex: 12),
                MasterColumn('Enable', flex: 8),
              ],
              rows: [
                for (final c in recipeChannels)
                  [
                    MasterCellText(c, bold: true),
                    MasterCellText(formatInr(r.targetPrice)),
                    _enabled.contains(c)
                        ? MasterStatusPill(
                            r.status == 'Active' &&
                                    _liveChannels(r).contains(c)
                                ? 'Live'
                                : 'Ready',
                            tone: PillTone.green)
                        : const MasterStatusPill('Disabled',
                            tone: PillTone.gray),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 24,
                        child: FittedBox(
                          child: Switch(
                            value: _enabled.contains(c),
                            activeTrackColor: ViniiColors.brandGreen,
                            onChanged: (v) => setState(() {
                              v ? _enabled.add(c) : _enabled.remove(c);
                              _dirty = true;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ]),
        ),
        right: MasterCard(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Final Activation Settings', style: _cardTitle),
            const SizedBox(height: 20),
            MasterKeyValue('Recipe', '${r.name} · ${r.version} · ${r.status}'),
            const SizedBox(height: 12),
            MasterKeyValue(
                'POS Menu Item',
                dish?.name ??
                    (r.linkedMenuItemName.isEmpty
                        ? 'Not linked'
                        : '${r.linkedMenuItemName} (missing)')),
            const SizedBox(height: 12),
            MasterKeyValue(
                'Selling Price',
                dish == null
                    ? formatInr(r.targetPrice)
                    : '${formatInr(dish.sellingPrice)} → ${formatInr(r.targetPrice)}'),
            const SizedBox(height: 12),
            MasterKeyValue(
                'Food Cost',
                dish == null
                    ? formatInr(cost)
                    : '${formatInr(dish.foodCost)} → ${formatInr(cost)}'),
            const SizedBox(height: 24),
            const _Note(
                '⚠️ System Notice: Activation writes the target price, food cost and channels to the POS menu item immediately. Ensure all menu margins meet policy minimums.'),
            const SizedBox(height: 20),
            _WideButton('Activate on POS',
                kind: MasterButtonKind.primary, onPressed: () => _activate(r)),
            const SizedBox(height: 16),
            _WideButton('Save Channel Selection',
                kind: MasterButtonKind.outline,
                onPressed: () => _saveChannels(r)),
          ]),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// 10. Cost Impact
// ===========================================================================

/// One BOM line traced against a supplier quote for its material.
class _Impact {
  const _Impact({
    required this.line,
    required this.material,
    required this.quote,
    required this.supplier,
    required this.costDelta,
    required this.costAtQuote,
    required this.marginAtQuote,
  });
  final RecipeLine line;
  final RawMaterial material;
  final SupplierPriceQuote quote;
  final String supplier;

  /// Per-portion change from the quote's last → current price.
  final double costDelta;

  /// Recipe total cost if this material were priced at the quote.
  final double costAtQuote;
  final double marginAtQuote;
}

class RecipeCostImpactTab extends StatefulWidget {
  const RecipeCostImpactTab({super.key, required this.data});
  final RecipeData data;

  @override
  State<RecipeCostImpactTab> createState() => _RecipeCostImpactTabState();
}

class _RecipeCostImpactTabState extends State<RecipeCostImpactTab> {
  int _node = 2;

  List<_Impact> _impacts(Recipe r) {
    final d = widget.data;
    final total = d.totalCost(r);
    final out = <_Impact>[];
    for (final l in r.lines) {
      final m = d.materialFor(l);
      if (m == null) continue;
      final quotes = d.quotesFor(m.id);
      if (quotes.isEmpty) continue;
      // Preferred supplier's quote when there is one.
      final q = quotes.firstWhere((q) => q.supplierId == m.preferredSupplierId,
          orElse: () => quotes.first);
      final at = total - d.lineCost(l) + l.grossQty * q.currentPrice;
      out.add(_Impact(
        line: l,
        material: m,
        quote: q,
        supplier: d.supplierName(q.supplierId),
        costDelta: l.grossQty * (q.currentPrice - q.lastPrice),
        costAtQuote: at,
        marginAtQuote:
            r.targetPrice <= 0 ? 0 : (r.targetPrice - at) / r.targetPrice * 100,
      ));
    }
    return out;
  }

  Future<void> _export(Recipe r, List<_Impact> rows) => exportCsv(context,
          fileName: 'recipe-cost-impact-${r.code}-${recipeToday()}.csv',
          headers: const [
            'recipe_code',
            'recipe_name',
            'ingredient',
            'material_code',
            'supplier',
            'last_price',
            'current_price',
            'change_pct',
            'cost_delta_per_portion',
            'current_recipe_cost',
            'recipe_cost_at_quote',
            'target_price',
            'margin_at_quote_pct',
          ],
          rows: [
            for (final i in rows)
              [
                r.code,
                r.name,
                i.line.name,
                i.material.code,
                i.supplier,
                i.quote.lastPrice.toStringAsFixed(2),
                i.quote.currentPrice.toStringAsFixed(2),
                i.quote.changePct.toStringAsFixed(1),
                i.costDelta.toStringAsFixed(2),
                widget.data.totalCost(r).toStringAsFixed(2),
                i.costAtQuote.toStringAsFixed(2),
                r.targetPrice.toStringAsFixed(2),
                i.marginAtQuote.toStringAsFixed(1),
              ],
          ]);

  Future<void> _revise(Recipe r, List<_Impact> rows) async {
    final worst = rows.fold<double>(widget.data.totalCost(r),
        (m, i) => i.costAtQuote > m ? i.costAtQuote : m);
    final suggested = worst / (1 - recipeMarginThresholdPct / 100);
    final price = await showDialog<double>(
        context: context,
        builder: (_) =>
            _PriceDialog(recipe: r, worstCost: worst, suggested: suggested));
    if (price == null || !mounted) return;
    await saveRecipeRecord(context, widget.data, r.copyWith(targetPrice: price),
        success:
            'Target price for ${r.name} set to ${formatInr(price)}${r.status == 'Active' ? ' — re-activate to push it to the POS' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final r = d.recipe;
    if (r == null) return const RecipeNoSelection();
    final rows = _impacts(r);
    final total = d.totalCost(r);
    final margin = d.marginPct(r);
    // Biggest mover drives the trace map.
    final top = rows.isEmpty
        ? null
        : rows.reduce((a, b) => a.costDelta.abs() >= b.costDelta.abs() ? a : b);
    final allowedPct = 100 - recipeMarginThresholdPct;
    final foodCostPct = r.targetPrice <= 0 ? 0.0 : total / r.targetPrice * 100;
    final warning = margin < recipeMarginThresholdPct ||
        rows.any((i) => i.marginAtQuote < recipeMarginThresholdPct);

    final nodes = [
      (
        '1. SUPPLIER PRICE',
        top?.supplier ?? 'No supplier quotes',
        top == null
            ? 'No quotes for this recipe\'s materials'
            : '${top.material.name}: ${top.quote.changePct >= 0 ? '+' : ''}${recipePct(top.quote.changePct)} (${formatInr(top.quote.lastPrice)} → ${formatInr(top.quote.currentPrice)}/${top.quote.unit})',
        false
      ),
      (
        '2. RAW INGREDIENT',
        top?.material.name ?? '-',
        top == null
            ? '-'
            : '${recipeQty(top.line.grossQty)} ${top.line.unit} per portion · Δ ${formatInr(top.costDelta)}',
        false
      ),
      (
        '3. RECIPE COST',
        r.name,
        'Food Cost: ${formatInr(total)} (${foodCostPct > allowedPct ? 'Exceeds' : 'Within'} target ${allowedPct.toStringAsFixed(0)}%)',
        foodCostPct > allowedPct
      ),
      (
        '4. TARGET SELLING PRICE',
        d.dishName(r).isEmpty ? 'Not linked' : d.dishName(r),
        '${formatInr(r.targetPrice)} (GP Margin: ${recipePct(margin)})',
        margin < recipeMarginThresholdPct
      ),
    ];

    return MasterPage(children: [
      MasterPageHeader(
        title: 'Supply-Chain to Menu Impact Mapper',
        subtitle:
            'Trace supplier price variations instantly down to final menu profit margins',
        actions: [
          if (warning)
            const MasterStatusPill('⚠ Margin Threshold Warning',
                tone: PillTone.red),
        ],
      ),
      MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Interactive Traceability Map', style: _cardTitle),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final boxes = [
              for (var i = 0; i < nodes.length; i++)
                _TraceNode(
                  step: nodes[i].$1,
                  title: nodes[i].$2,
                  detail: nodes[i].$3,
                  alert: nodes[i].$4,
                  selected: _node == i,
                  onTap: () => setState(() => _node = i),
                ),
            ];
            if (!wide) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < boxes.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Center(
                              child: Text('↓',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: ViniiColors.textMutedLight))),
                        ),
                      boxes[i],
                    ],
                  ]);
            }
            return IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < boxes.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('→',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: ViniiColors.textMutedLight)),
                        ),
                      Expanded(child: boxes[i]),
                    ],
                  ]),
            );
          }),
        ]),
      ),
      const SizedBox(height: 24),
      MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ingredient Price Impact on Recipe Margin',
              style: _cardTitle),
          const SizedBox(height: 16),
          MasterTable(
            minWidth: 900,
            columns: const [
              MasterColumn('Ingredient / Supplier', flex: 22),
              MasterColumn('Quote Change', flex: 9),
              MasterColumn('Cost Δ / Portion', flex: 9),
              MasterColumn('Recipe Cost at Quote', flex: 10),
              MasterColumn('New Margin', flex: 9),
            ],
            rows: [
              for (final i in rows)
                [
                  MasterCellTitle(i.line.name,
                      subtitle:
                          '${i.supplier} · ${formatInr(i.quote.lastPrice)} → ${formatInr(i.quote.currentPrice)}/${i.quote.unit}'),
                  MasterCellText(
                      '${i.quote.changePct >= 0 ? '+' : ''}${recipePct(i.quote.changePct)}',
                      bold: true,
                      color: i.quote.changePct > 0
                          ? ViniiColors.redSolid
                          : ViniiColors.emeraldText),
                  MasterCellText(
                      '${i.costDelta >= 0 ? '+' : ''}${formatInr(i.costDelta)}',
                      color: i.costDelta > 0
                          ? ViniiColors.redSolid
                          : ViniiColors.emeraldText),
                  MasterCellText(formatInr(i.costAtQuote), bold: true),
                  MasterCellText(recipePct(i.marginAtQuote),
                      bold: true,
                      color: i.marginAtQuote < recipeMarginThresholdPct
                          ? ViniiColors.redSolid
                          : ViniiColors.emeraldText),
                ],
            ],
            footer: Text(
                rows.isEmpty
                    ? 'No supplier quotes exist for this recipe\'s inventory-linked ingredients.'
                    : 'Current recipe cost ${formatInr(total)} · margin ${recipePct(margin)} at ${formatInr(r.targetPrice)}',
                style: MasterStyle.muted),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
        MasterButton(
            label: 'Export Report',
            icon: Icons.download_outlined,
            onPressed: rows.isEmpty ? null : () => _export(r, rows)),
        MasterButton(
            label: 'Revise Pricing',
            kind: MasterButtonKind.primary,
            onPressed: () => _revise(r, rows)),
      ]),
    ]);
  }
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog(
      {required this.recipe, required this.worstCost, required this.suggested});
  final Recipe recipe;
  final double worstCost;
  final double suggested;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _form = GlobalKey<FormState>();
  late final _ctrl =
      TextEditingController(text: widget.recipe.targetPrice.toStringAsFixed(2));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggested.ceilToDouble();
    return AlertDialog(
      title: Text('Revise Pricing · ${widget.recipe.name}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Worst-case cost ${formatInr(widget.worstCost)} per portion. A ${recipeMarginThresholdPct.toStringAsFixed(0)}% margin needs at least ${formatInr(widget.suggested)}.',
                    style: MasterStyle.body),
                const SizedBox(height: 16),
                RecipeField(
                    label: 'New Target Selling Price *',
                    controller: _ctrl,
                    number: true,
                    suffix: '₹',
                    validator: recipeNumber(positive: true)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () =>
                          _ctrl.text = suggested.toStringAsFixed(2),
                      child: Text('Use suggested ${formatInr(suggested)}')),
                ),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, recipeParse(_ctrl.text));
              }
            },
            child: const Text('Save Price')),
      ],
    );
  }
}

class _TraceNode extends StatelessWidget {
  const _TraceNode(
      {required this.step,
      required this.title,
      required this.detail,
      required this.alert,
      required this.selected,
      required this.onTap});
  final String step;
  final String title;
  final String detail;
  final bool alert;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? (alert ? ViniiColors.redSolid : ViniiColors.greenSolid)
        : (alert ? const Color(0xFFFCA5A5) : MasterStyle.cardBorder);
    final bg = alert
        ? ViniiColors.redTint
        : selected
            ? ViniiColors.greenTint
            : const Color(0xFFF9FAFB);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: ViniiColors.textSecondaryLight)),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
                const SizedBox(height: 8),
                Text(detail,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: alert
                            ? ViniiColors.redSolid
                            : ViniiColors.textSecondaryLight)),
              ]),
        ),
      ),
    );
  }
}
