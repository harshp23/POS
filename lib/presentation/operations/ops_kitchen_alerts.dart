part of 'ops_kitchen_screen.dart';

// Dialogs for the kitchen screen:
//  * Sound & Alerts   — v1/operations/kds-sound-alerts-settings.png
//  * Kitchen Stations — v1/operations/kds-kitchen-stations-settings.png
// Both persist through DriftOperationsStore (app_metadata).

/// "Alerts On" button from the KOT header — opens Sound & Alerts.
class _AlertsButton extends StatelessWidget {
  const _AlertsButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Sound & alert settings',
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: _Kc.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      enabled
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                      size: 16,
                      color: enabled ? _Kc.label : _Kc.sub),
                  const SizedBox(width: 6),
                  Text(enabled ? 'Alerts On' : 'Alerts Off',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: enabled ? _Kc.label : _Kc.sub)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Plays the on-device alert tone (respects the volume-0 "mute").
void _playTone(KdsAlertSettings s, {bool force = false}) {
  if (!force && (!s.soundsEnabled || s.volume <= 0)) return;
  SystemSound.play(SystemSoundType.alert);
}

// -------------------------------------------------------------------------
// Sound & Alerts
// -------------------------------------------------------------------------

/// Returns the edited settings on Done, null when closed with ✕.
Future<KdsAlertSettings?> _showAlertSettings(
    BuildContext context, KdsAlertSettings current) {
  var s = current;
  return showDialog<KdsAlertSettings>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      Widget alertRow(String title, String caption, bool value,
              ValueChanged<bool> onChanged) =>
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _Kc.ink)),
                    const SizedBox(height: 1),
                    Text(caption,
                        style: const TextStyle(fontSize: 12, color: _Kc.sub)),
                  ],
                ),
              ),
              Tooltip(
                message: 'Preview',
                child: Material(
                  color: _Kc.qtyBg,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _playTone(s, force: true),
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(Icons.play_arrow_outlined,
                          size: 18, color: _Kc.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _KitchenSwitch(value: value, onChanged: onChanged),
            ]),
          );

      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogTitle('Sound & Alerts',
                    onClose: () => Navigator.pop(ctx)),
                const Divider(height: 24, color: _Kc.border),
                Row(children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sounds enabled',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _Kc.ink)),
                        SizedBox(height: 2),
                        Text('Works offline — tones are generated on device',
                            style: TextStyle(fontSize: 12, color: _Kc.sub)),
                      ],
                    ),
                  ),
                  _KitchenSwitch(
                      value: s.soundsEnabled,
                      large: true,
                      onChanged: (v) =>
                          setD(() => s = s.copyWith(soundsEnabled: v))),
                ]),
                const Divider(height: 28, color: _Kc.border),
                Text('Volume · ${(s.volume * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _Kc.ink)),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    trackHeight: 5,
                    activeTrackColor: _Kc.lime,
                    inactiveTrackColor: _Kc.border,
                    thumbColor: Colors.white,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    thumbShape:
                        const _RingThumb(radius: 9, ring: _Kc.progressGreen),
                    padding: EdgeInsets.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Slider(
                      value: s.volume.clamp(0, 1).toDouble(),
                      onChanged: (v) => setD(() => s =
                          s.copyWith(volume: (v * 100).roundToDouble() / 100)),
                    ),
                  ),
                ),
                const Divider(height: 16, color: _Kc.border),
                alertRow('New order', 'Plays when a KOT arrives from POS',
                    s.newOrder, (v) => setD(() => s = s.copyWith(newOrder: v))),
                alertRow('Priority alert', 'Rush / VIP tickets', s.priority,
                    (v) => setD(() => s = s.copyWith(priority: v))),
                alertRow('Delayed order', 'SLA breached', s.delayed,
                    (v) => setD(() => s = s.copyWith(delayed: v))),
                alertRow('Ready notification', 'Item marked ready', s.ready,
                    (v) => setD(() => s = s.copyWith(ready: v))),
                const Divider(height: 28, color: _Kc.border),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 116,
                    child: _SolidButton(
                        label: 'Done',
                        bg: _Kc.lime,
                        fg: _Kc.ink,
                        height: 34,
                        fontSize: 13,
                        onPressed: () => Navigator.pop(ctx, s)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.radius, required this.ring});
  final double radius;
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
        center,
        radius - 1,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }
}

class _DialogTitle extends StatelessWidget {
  const _DialogTitle(this.title, {required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _Kc.ink)),
        ),
        Material(
          color: _Kc.qtyBg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close, size: 16, color: _Kc.sub)),
          ),
        ),
      ]);
}

// -------------------------------------------------------------------------
// Kitchen Stations
// -------------------------------------------------------------------------

const _stationPalette = [
  0xFF76EC00,
  0xFF16A34A,
  0xFF0891B2,
  0xFF2563EB,
  0xFF7C3AED,
  0xFFDB2777,
  0xFFDC2626,
  0xFFEA580C,
  0xFFD97706,
  0xFF6B7280,
];

const _quickAddStations = ['Pizza', 'South Indian', 'Dessert', 'Grill'];

class _StationDraft {
  _StationDraft(KitchenStation s, {this.pick = false})
      : name = TextEditingController(text: s.name),
        target = TextEditingController(text: '${s.targetMinutes}'),
        color = s.colorValue,
        active = s.active;
  final TextEditingController name;
  final TextEditingController target;

  /// A station being added with "+ Custom": its name is picked from the
  /// stations the menu's dishes route to ("Custom…" to type one).
  final bool pick;
  int color;
  bool active;
  String? nameError;
  String? targetError;

  void dispose() {
    name.dispose();
    target.dispose();
  }
}

class _StationsDialog extends StatefulWidget {
  const _StationsDialog(
      {required this.ops, required this.stations, required this.dishes});
  final DriftOperationsStore ops;
  final List<KitchenStation> stations;
  final Stream<List<MasterDishItem>> dishes;

  @override
  State<_StationsDialog> createState() => _StationsDialogState();
}

class _StationsDialogState extends State<_StationsDialog> {
  late final List<_StationDraft> _drafts = [
    for (final s in widget.stations) _StationDraft(s)
  ];
  StreamSubscription<List<MasterDishItem>>? _dishSub;
  List<MasterDishItem> _dishes = const [];

  /// Stations the menu's dishes route to: each dish's own kitchen station
  /// ("Tandoor Counter") and the KDS station it lands on ("Tandoor").
  List<String> _routed = const [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dishSub = widget.dishes.listen((d) {
      if (!mounted) return;
      setState(() {
        _dishes = d;
        _routed = distinctNames([
          for (final dish in d) ...[
            dish.kitchenStation,
            stationForDish(dish.category, dish.kitchenStation),
          ],
        ]);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _dishSub?.cancel();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  bool _exists(String name) => _drafts.any(
      (d) => d.name.text.trim().toLowerCase() == name.trim().toLowerCase());

  /// Adds a station; an empty [name] ("+ Custom") is picked from the
  /// stations dishes route to.
  void _add(String name) => setState(() {
        _drafts.add(_StationDraft(KitchenStation(name: name),
            pick: name.trim().isEmpty));
        _error = null;
      });

  /// Routed stations not already configured by another row of the dialog.
  List<String> _choicesFor(_StationDraft d) {
    final taken = <String>{
      for (final o in _drafts)
        if (!identical(o, d)) o.name.text.trim().toLowerCase()
    };
    return [
      for (final s in _routed)
        if (!taken.contains(s.toLowerCase())) s
    ];
  }

  Future<void> _remove(_StationDraft d) async {
    final label = d.name.text.trim().isEmpty ? 'this station' : d.name.text;
    final ok = await confirmMasterAction(context,
        title: 'Remove station?',
        message: 'Remove $label from the kitchen display? Items routed to it '
            'will show under "Other". Takes effect when you save.',
        confirmLabel: 'Remove');
    if (!ok || !mounted) return;
    setState(() {
      _drafts.remove(d);
      d.dispose();
    });
  }

  List<String> _categoriesFor(String station) {
    final key = station.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final cats = <String>{
      for (final dish in _dishes)
        if (dish.category.trim().isNotEmpty &&
            (stationForDish(dish.category, dish.kitchenStation).toLowerCase() ==
                    key ||
                dish.kitchenStation.trim().toLowerCase() == key))
          dish.category.trim(),
    };
    return cats.toList()..sort();
  }

  Future<void> _pickColor(_StationDraft d) async {
    final c = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Station colour',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 260,
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final v in _stationPalette)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(ctx, v),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(v),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: v == d.color ? _Kc.ink : Colors.transparent,
                        width: 2.5),
                  ),
                  child: v == d.color
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ]),
        ),
      ),
    );
    if (c != null && mounted) setState(() => d.color = c);
  }

  Future<void> _save() async {
    var ok = true;
    final seen = <String>{};
    setState(() {
      _error = null;
      for (final d in _drafts) {
        final n = d.name.text.trim();
        d.nameError = n.isEmpty
            ? 'Required'
            : !seen.add(n.toLowerCase())
                ? 'Duplicate name'
                : null;
        final t = int.tryParse(d.target.text.trim());
        d.targetError = t == null || t < 1 ? 'Min 1' : null;
        if (d.nameError != null || d.targetError != null) ok = false;
      }
      if (_drafts.isEmpty) {
        _error = 'Keep at least one station.';
        ok = false;
      }
    });
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await widget.ops.saveKitchenStations([
        for (final d in _drafts)
          KitchenStation(
              name: d.name.text.trim(),
              targetMinutes: int.parse(d.target.text.trim()),
              colorValue: d.color,
              active: d.active),
      ]);
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } on StateError catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not save: ${friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _field(String? error, {Widget? suffix}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        errorText: error,
        errorStyle: const TextStyle(fontSize: 10.5, height: 1),
        suffixIcon: suffix,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 24, minHeight: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _Kc.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _Kc.green)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _Kc.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _Kc.red)),
      );

  static const _fieldLabel = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563));

  Widget _labelled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _fieldLabel),
          const SizedBox(height: 5),
          child,
        ],
      );

  /// A configured station's name is edited as text. A station being added
  /// ("+ Custom") is picked from the stations dishes route to, with
  /// "Custom…" for a new one — typed directly when there is nothing to
  /// pick (no dishes, or every routed station is already configured).
  Widget _nameField(_StationDraft d) {
    void changed(String _) => setState(() => d.nameError = null);
    final choices = d.pick ? _choicesFor(d) : const <String>[];
    if (choices.isEmpty) {
      return TextField(
        controller: d.name,
        style: const TextStyle(fontSize: 13, color: _Kc.ink),
        decoration: _field(d.nameError),
        onChanged: changed,
      );
    }
    return PersonPickerField(
      controller: d.name,
      names: choices,
      decoration: _field(d.nameError).copyWith(hintText: 'Select a station'),
      otherLabel: 'Custom…',
      otherHint: 'Type the station name',
      onChanged: changed,
    );
  }

  Widget _stationCard(_StationDraft d) {
    final cats = _categoriesFor(d.name.text);
    return Container(
      // Keeps each row's field state (e.g. "Custom…" chosen) with its
      // station when another row is removed.
      key: ObjectKey(d),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _Kc.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: _labelled('Station name', _nameField(d)),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 88,
              child: _labelled(
                  'Target (min)',
                  TextField(
                    controller: d.target,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 13, color: _Kc.ink),
                    decoration: _field(d.targetError,
                        suffix: const Icon(Icons.unfold_more,
                            size: 13, color: _Kc.sub)),
                    onChanged: (_) => setState(() => d.targetError = null),
                  )),
            ),
            const SizedBox(width: 14),
            _labelled(
                'Colour',
                Tooltip(
                  message: 'Pick colour',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _pickColor(d),
                    child: Container(
                      width: 64,
                      height: 34,
                      decoration: BoxDecoration(
                          color: Color(d.color),
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                )),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _labelled(
                  'Active',
                  _KitchenSwitch(
                      value: d.active,
                      large: true,
                      onChanged: (v) => setState(() => d.active = v))),
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Tooltip(
                message: 'Remove station',
                child: Material(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _remove(d),
                    child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(Icons.delete_outline,
                            size: 16, color: _Kc.red)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          const Text('Menu categories routed here', style: _fieldLabel),
          const SizedBox(height: 3),
          Text(cats.isEmpty ? 'No menu categories found' : cats.join(', '),
              style: TextStyle(
                  fontSize: 12,
                  color: cats.isEmpty ? _Kc.textMuted : _Kc.label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: _DialogTitle('Kitchen Stations',
                    onClose: () => Navigator.pop(context)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Divider(height: 26, color: _Kc.border),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final n in _quickAddStations)
                          if (!_exists(n))
                            Material(
                              color: _Kc.qtyBg,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _add(n),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Text('+ $n',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _Kc.label)),
                                ),
                              ),
                            ),
                        Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: _Kc.border)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _add(''),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text('+ Custom',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _Kc.sub)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      for (final d in _drafts) _stationCard(d),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 12.5, color: _Kc.red)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _Kc.ink,
                          side: const BorderSide(color: _Kc.border),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 128,
                      child: _SolidButton(
                          label: 'Save changes',
                          bg: _Kc.lime,
                          fg: _Kc.ink,
                          height: 38,
                          fontSize: 13,
                          busy: _saving,
                          onPressed: _save),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Compact lime switch used on KDS item rows and in the settings dialogs.
class _KitchenSwitch extends StatelessWidget {
  const _KitchenSwitch(
      {required this.value, required this.onChanged, this.large = false});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: large ? 42 : 36,
        height: large ? 25 : 22,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            thumbIcon: const WidgetStatePropertyAll(null),
            trackColor: WidgetStateProperty.resolveWith((states) {
              final on = states.contains(WidgetState.selected);
              final disabled = states.contains(WidgetState.disabled);
              final c = on ? _Kc.lime : const Color(0xFFE5E7EB);
              return disabled ? c.withValues(alpha: 0.55) : c;
            }),
          ),
        ),
      );
}
