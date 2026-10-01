import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api/api_client.dart';
import '../../domain/inventory.dart' show formatInr;
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';

/// Shared pieces for the vendor panel's business sections (Customers & CRM,
/// Marketing, Finance, Integrations, Task Manager, Settings). Every screen
/// reads and writes through the Proviyaa backend; there is no local copy.

// ── data helpers ─────────────────────────────────────────────────────────

List<Map<String, dynamic>> jsonList(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>()
      ]
    : const [];

Map<String, dynamic> jsonMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

num numOf(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

String inr(dynamic v, {int decimals = 2}) =>
    formatInr(numOf(v), decimals: decimals);

String textOf(dynamic v, [String fallback = '—']) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty ? fallback : s;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 Sep 2026" from an ISO date or timestamp; "—" when empty.
String fmtDate(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '—';
  final l = d.isUtc ? d.toLocal() : d;
  return '${l.day.toString().padLeft(2, '0')} ${_months[l.month - 1]} ${l.year}';
}

/// "12 Sep 2026, 5:58 PM" from an ISO timestamp.
String fmtDateTime(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '—';
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '${fmtDate(l.toIso8601String())}, $h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// YYYY-MM-DD for the API.
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Words a code may contain that are written a particular way.
const _wordLabels = <String, String>{
  'upi': 'UPI',
  'qr': 'QR',
  'kds': 'KDS',
  'pos': 'POS',
  'sms': 'SMS',
  'smtp': 'SMTP',
  'gst': 'GST',
  'gstin': 'GSTIN',
  'kot': 'KOT',
  'kots': 'KOTs',
  'api': 'API',
  'url': 'URL',
  'ip': 'IP',
  'id': 'ID',
  'utr': 'UTR',
  'fssai': 'FSSAI',
  'mac': 'MAC',
  'usb': 'USB',
  'lan': 'LAN',
  'wifi': 'Wi-Fi',
  'http': 'HTTP',
  'https': 'HTTPS',
  'csv': 'CSV',
  'otp': 'OTP',
  'vip': 'VIP',
  'crm': 'CRM',
  'erp': 'ERP',
  'sku': 'SKU',
  'pdf': 'PDF',
  'hsn': 'HSN',
  'emi': 'EMI',
  'cod': 'COD',
  'ai': 'AI',
  'db': 'DB',
  'ok': 'OK',
  'whatsapp': 'WhatsApp',
  'phonepe': 'PhonePe',
  'paytm': 'Paytm',
  'gpay': 'GPay',
  'razorpay': 'Razorpay',
  'swiggy': 'Swiggy',
  'zomato': 'Zomato',
  'tally': 'Tally',
  'google': 'Google',
  'amazon': 'Amazon',
  'proviyaa': 'Proviyaa',
};

/// Short words kept lower case inside a title ("Cash on Delivery").
const _smallWords = {
  'a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'per',
  'the', 'to', 'via', 'vs',
};

final _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// True for a database id (UUID) — never something to show on screen.
bool isUuidLike(dynamic v) => _uuidLike.hasMatch('${v ?? ''}'.trim());

/// A code as a label: "pending_verification" → "Pending Verification",
/// "upi_payment" → "UPI Payment", "order.created" → "Order Created".
/// Prefer a screen's own label map where it has one. An id is never shown
/// ("—").
String humanize(dynamic v) {
  final raw = '${v ?? ''}'.trim();
  if (raw.isEmpty || isUuidLike(raw)) return '—';
  final words = [
    for (final w in raw.split(RegExp(r'[_.\s]+')))
      if (w.isNotEmpty) w
  ];
  if (words.isEmpty) return '—';
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final lower = w.toLowerCase();
    final known = _wordLabels[lower];
    if (known != null) {
      out.add(known);
    } else if (i > 0 && _smallWords.contains(lower)) {
      out.add(lower);
    } else {
      // A word that already has capitals ("GSTIN", "iPad") keeps them.
      final base = w == lower ? lower : w;
      out.add(base[0].toUpperCase() + base.substring(1));
    }
  }
  return out.join(' ');
}

/// The server's message for a failed call.
String apiErrorText(Object e) => e is ApiException ? e.message : staffErrorText(e);

/// The form's label for a field the server rejected: [labels] maps field
/// keys to the labels on screen; "recipients.2" reads "Recipient 3".
String fieldLabel(String path, [Map<String, String> labels = const {}]) {
  final direct = labels[path];
  if (direct != null) return direct;
  final parts = path.split('.').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final head = labels[parts.first] ?? humanize(parts.first);
  if (parts.length == 1) return head;
  final index = int.tryParse(parts[1]);
  if (index != null) {
    var item = labels['${parts.first}.item'] ?? head;
    if (item.endsWith('s') && !item.endsWith('ss')) {
      item = item.substring(0, item.length - 1);
    }
    final rest = parts.length > 2
        ? ' – ${labels[parts.skip(2).join('.')] ?? humanize(parts.skip(2).join(' '))}'
        : '';
    return '$item ${index + 1}$rest';
  }
  return '$head – ${humanize(parts.skip(1).join(' '))}';
}

/// The server's message, with each invalid field named by its label on
/// the form ([labels]: field key → label).
String fieldErrorText(Object e, [Map<String, String> labels = const {}]) {
  final details = e is ApiException ? e.details : null;
  if (details is List) {
    final parts = <String>[];
    for (final d in details) {
      if (d is! Map) continue;
      final msg = '${d['message'] ?? ''}'.trim();
      if (msg.isEmpty) continue;
      final raw = d['path'];
      final path =
          raw is List ? raw.map((p) => '$p').join('.') : '${raw ?? ''}'.trim();
      parts.add(path.isEmpty ? msg : '${fieldLabel(path, labels)}: $msg');
    }
    if (parts.isNotEmpty) return parts.join('\n');
  }
  return apiErrorText(e);
}

// ── branches ─────────────────────────────────────────────────────────────

/// The name of the branch [id] (a record's location_id); [all] when the
/// record is for every branch. Never the id itself.
String branchLabel(List<BranchLocation> branches, dynamic id,
    {String all = 'All branches'}) {
  final s = '${id ?? ''}'.trim();
  if (s.isEmpty) return all;
  for (final b in branches) {
    if (b.id == s) return b.name;
  }
  return 'Another branch';
}

/// Branch pickers and branch columns show only for a restaurant with more
/// than one branch.
bool hasManyBranches(List<BranchLocation> branches) => branches.length > 1;

/// The branch a new record starts with: the only branch when there is one,
/// otherwise every branch (null).
String? defaultBranchId(List<BranchLocation> branches) =>
    branches.length == 1 ? branches.first.id : null;

/// "Branch" dropdown: every branch of the restaurant, plus "All branches"
/// (null) when [allowAll].
class BizBranchSelect extends StatelessWidget {
  const BizBranchSelect({
    super.key,
    required this.branches,
    required this.value,
    required this.onChanged,
    this.label = 'Branch',
    this.allLabel = 'All branches',
    this.allowAll = true,
    this.selectKey,
  });
  final List<BranchLocation> branches;

  /// The picked branch id; null for all branches.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String allLabel;
  final bool allowAll;
  final Key? selectKey;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final known = v != null && branches.any((b) => b.id == v);
    return StaffField(
      label: label,
      child: StaffSelect<String>(
        key: selectKey,
        value: v ?? '',
        hint: 'Pick a branch',
        items: [
          if (allowAll) ('', allLabel),
          for (final b in branches) (b.id, b.name),
          if (v != null && v.isNotEmpty && !known) (v, 'Another branch'),
        ],
        onChanged: (s) => onChanged(s == null || s.isEmpty ? null : s),
      ),
    );
  }
}

// ── pickers ──────────────────────────────────────────────────────────────

/// Distinct, non-empty values in their first spelling, in order.
List<String> distinctText(Iterable<Object?> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final v in values) {
    final s = '${v ?? ''}'.trim();
    if (s.isEmpty || !seen.add(s.toLowerCase())) continue;
    out.add(s);
  }
  return out;
}

/// Drop-down list under a text box with suggestions.
Widget _optionsList<T extends Object>(AutocompleteOnSelected<T> onSelected,
        Iterable<T> options, String Function(T) label) =>
    Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: [
              for (final o in options)
                InkWell(
                  onTap: () => onSelected(o),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(label(o),
                        style: const TextStyle(
                            fontSize: 13,
                            color: ViniiColors.textPrimaryLight)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

/// A text box that also offers [suggestions] (things that already exist):
/// type anything, pick from the matches shown while typing, or open the
/// whole list with the ⌄ button.
class BizComboField extends StatefulWidget {
  const BizComboField({
    super.key,
    required this.label,
    required this.controller,
    this.suggestions = const [],
    this.hint,
    this.required = false,
    this.onChanged,
    this.fieldKey,
  });
  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final String? hint;
  final bool required;
  final ValueChanged<String>? onChanged;

  /// Key of the text box itself.
  final Key? fieldKey;

  @override
  State<BizComboField> createState() => _BizComboFieldState();
}

class _BizComboFieldState extends State<BizComboField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _pick(String v) {
    widget.controller.value = TextEditingValue(
        text: v, selection: TextSelection.collapsed(offset: v.length));
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final options = distinctText(widget.suggestions);
    return StaffField(
      label: widget.label,
      required: widget.required,
      child: RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return const Iterable<String>.empty();
          return options
              .where((o) =>
                  o.toLowerCase().contains(q) && o.toLowerCase() != q)
              .take(8);
        },
        onSelected: (v) => widget.onChanged?.call(v),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
            TextField(
          key: widget.fieldKey,
          controller: controller,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(
            hint: widget.hint,
            suffix: options.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Pick from the list',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: ViniiColors.textSecondaryLight),
                    onSelected: _pick,
                    itemBuilder: (_) => [
                      for (final o in options)
                        PopupMenuItem<String>(
                            value: o,
                            height: 38,
                            child: Text(o,
                                style: const TextStyle(fontSize: 13))),
                    ],
                  ),
          ).copyWith(
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36)),
        ),
        optionsViewBuilder: (context, onSelected, opts) =>
            _optionsList<String>(onSelected, opts, (o) => o),
      ),
    );
  }
}

/// Toggle chips for picking several of [options] (value, label).
class BizChipSelect extends StatelessWidget {
  const BizChipSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.keyPrefix,
  });
  final List<(String, String)> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (value, label) in options)
            FilterChip(
              key: keyPrefix == null ? null : Key('$keyPrefix-$value'),
              label: Text(label),
              selected: selected.contains(value),
              showCheckmark: true,
              checkmarkColor: ViniiColors.emeraldText,
              selectedColor: ViniiColors.successPillBg,
              backgroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                  color: selected.contains(value)
                      ? ViniiColors.greenSolid
                      : kStaffBorder),
              labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected.contains(value)
                      ? ViniiColors.emeraldText
                      : ViniiColors.textPrimaryLight),
              onSelected: (on) {
                final next = {...selected};
                if (on) {
                  next.add(value);
                } else {
                  next.remove(value);
                }
                onChanged(next);
              },
            ),
        ],
      );
}

/// One suggestion in [BizTagInput]; each is its own object so picking the
/// same tag again (after removing it) still counts.
class _TagOption {
  _TagOption(this.tag);
  final String tag;
}

/// [tags] plus what is still typed in a tag box ("VIP, Weekend").
List<String> tagsWithPending(List<String> tags, String pending) =>
    distinctText([...tags, ...pending.split(RegExp(r'[,;]'))]);

/// Tags as chips: type to add (Enter or a comma), pick from the existing
/// tags while typing, or tap one of the existing tags below.
class BizTagInput extends StatefulWidget {
  const BizTagInput({
    super.key,
    required this.tags,
    required this.onChanged,
    required this.input,
    this.suggestions = const [],
    this.hint,
    this.inputKey,
    this.maxTags = 20,
  });
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  /// What is being typed. The owner adds it on save with [tagsWithPending].
  final TextEditingController input;
  final List<String> suggestions;
  final String? hint;
  final Key? inputKey;
  final int maxTags;

  @override
  State<BizTagInput> createState() => _BizTagInputState();
}

class _BizTagInputState extends State<BizTagInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool _has(String tag) =>
      widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());

  void _add(Iterable<String> tags) {
    final next = [...widget.tags];
    for (final raw in tags) {
      final t = raw.trim();
      if (t.isEmpty || next.length >= widget.maxTags) continue;
      if (next.any((x) => x.toLowerCase() == t.toLowerCase())) continue;
      // An existing tag keeps its spelling.
      final known = widget.suggestions
          .where((s) => s.toLowerCase() == t.toLowerCase())
          .firstOrNull;
      next.add(known ?? t);
    }
    widget.onChanged(next);
  }

  void _typed(String text) {
    if (!text.contains(',') && !text.contains(';')) return;
    final parts = text.split(RegExp(r'[,;]'));
    _add(parts.take(parts.length - 1));
    final rest = parts.last;
    widget.input.value = TextEditingValue(
        text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  void _submit() {
    _add(widget.input.text.split(RegExp(r'[,;]')));
    widget.input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final options = distinctText(widget.suggestions);
    final quick = [
      for (final s in options)
        if (!_has(s)) s
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.tags.isNotEmpty) ...[
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in widget.tags)
            InputChip(
              label: Text(t),
              visualDensity: VisualDensity.compact,
              backgroundColor: ViniiColors.blueTint,
              side: BorderSide.none,
              labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.blueSolid),
              deleteIconColor: ViniiColors.blueSolid,
              onDeleted: () => widget
                  .onChanged([for (final x in widget.tags) if (x != t) x]),
            ),
        ]),
        const SizedBox(height: 8),
      ],
      RawAutocomplete<_TagOption>(
        textEditingController: widget.input,
        focusNode: _focus,
        displayStringForOption: (o) => o.tag,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return const Iterable<_TagOption>.empty();
          return [
            for (final s in quick)
              if (s.toLowerCase().contains(q)) _TagOption(s)
          ].take(8);
        },
        onSelected: (o) {
          _add([o.tag]);
          widget.input.clear();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
            TextField(
          key: widget.inputKey,
          controller: controller,
          focusNode: focusNode,
          onChanged: _typed,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(
              hint: widget.hint ?? 'Type a tag and press Enter'),
        ),
        optionsViewBuilder: (context, onSelected, opts) =>
            _optionsList<_TagOption>(onSelected, opts, (o) => o.tag),
      ),
      if (quick.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Existing tags:', style: MasterStyle.muted),
            for (final s in quick.take(15))
              ActionChip(
                label: Text('+ $s'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white,
                side: const BorderSide(color: kStaffBorder),
                labelStyle: const TextStyle(
                    fontSize: 12, color: ViniiColors.textPrimaryLight),
                onPressed: () => _add([s]),
              ),
          ],
        ),
      ],
    ]);
  }
}

/// Opens a searchable list of [options] to tick several; returns the
/// ticked ones (in [options] order, earlier picks not in [options] first),
/// or null when cancelled.
Future<List<String>?> showBizMultiPick(
  BuildContext context, {
  required String title,
  required List<String> options,
  required List<String> selected,
  String? subtitle,
  String searchHint = 'Search…',
  String emptyText = 'Nothing to pick from yet.',
}) =>
    showDialog<List<String>>(
      context: context,
      builder: (_) => _BizMultiPickDialog(
        title: title,
        subtitle: subtitle,
        options: options,
        selected: selected,
        searchHint: searchHint,
        emptyText: emptyText,
      ),
    );

class _BizMultiPickDialog extends StatefulWidget {
  const _BizMultiPickDialog({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.searchHint,
    required this.emptyText,
  });
  final String title;
  final String? subtitle;
  final List<String> options;
  final List<String> selected;
  final String searchHint;
  final String emptyText;

  @override
  State<_BizMultiPickDialog> createState() => _BizMultiPickDialogState();
}

class _BizMultiPickDialogState extends State<_BizMultiPickDialog> {
  late final Set<String> _on = {
    for (final s in widget.selected) s.toLowerCase()
  };
  late final List<String> _all = distinctText([
    for (final s in widget.selected)
      if (!widget.options.any((o) => o.toLowerCase() == s.toLowerCase())) s,
    ...widget.options,
  ]);
  String _q = '';

  void _toggle(String v, bool on) => setState(() {
        if (on) {
          _on.add(v.toLowerCase());
        } else {
          _on.remove(v.toLowerCase());
        }
      });

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final o in _all)
        if (q.isEmpty || o.toLowerCase().contains(q)) o
    ];
    return StaffDialog(
      title: widget.title,
      subtitle: widget.subtitle,
      width: 520,
      actions: [
        MasterButton(
            label: 'Clear',
            kind: MasterButtonKind.text,
            onPressed: _on.isEmpty ? null : () => setState(_on.clear)),
        MasterButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        MasterButton(
            key: const Key('multi-pick-done'),
            label: 'Done (${_on.length})',
            kind: MasterButtonKind.primary,
            onPressed: () => Navigator.pop(context, [
                  for (final o in _all)
                    if (_on.contains(o.toLowerCase())) o
                ])),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('multi-pick-search'),
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(
              hint: widget.searchHint,
              suffix: const Icon(Icons.search, size: 18)),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        if (_all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(widget.emptyText, style: MasterStyle.muted),
          )
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nothing matches.', style: MasterStyle.muted),
          )
        else
          SizedBox(
            height: 340,
            child: ListView(children: [
              for (final o in shown)
                CheckboxListTile(
                  key: Key('multi-pick-$o'),
                  value: _on.contains(o.toLowerCase()),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: ViniiColors.greenSolid,
                  title: Text(o, style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => _toggle(o, v == true),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// A labelled box showing the picked values as chips; tapping it opens
/// [showBizMultiPick].
class BizPickField extends StatelessWidget {
  const BizPickField({
    super.key,
    required this.label,
    required this.values,
    required this.onTap,
    this.hint = 'None picked',
    this.boxKey,
  });
  final String label;
  final List<String> values;
  final VoidCallback? onTap;
  final String hint;
  final Key? boxKey;

  @override
  Widget build(BuildContext context) => StaffField(
        label: label,
        child: InkWell(
          key: boxKey,
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kStaffBorder),
            ),
            child: Row(children: [
              Expanded(
                child: values.isEmpty
                    ? Text(hint,
                        style: const TextStyle(
                            fontSize: 13, color: ViniiColors.textMutedLight))
                    : Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final v in values)
                          StaffChip(v, color: ViniiColors.blueSolid),
                      ]),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: ViniiColors.textSecondaryLight),
            ]),
          ),
        ),
      );
}

/// Runs a server call with a snackbar for the outcome. Returns the result,
/// or null when it failed (the error is shown).
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action,
    {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final out = await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return out;
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text(apiErrorText(e)), backgroundColor: ViniiColors.redSolid));
    return null;
  }
}

// ── layout ───────────────────────────────────────────────────────────────

/// Shown instead of a business section when the app runs without the
/// Proviyaa server (local demo mode).
class ServerRequiredPanel extends StatelessWidget {
  const ServerRequiredPanel({super.key, required this.section});
  final String section;

  @override
  Widget build(BuildContext context) => Center(
        child: StaffEmptyState(
          icon: Icons.cloud_off_outlined,
          title: '$section needs the Proviyaa server',
          message:
              'This section keeps its data on the server. Sign in with a restaurant account to use it.',
        ),
      );
}

/// The row of section tabs under the top bar (Dashboard · Customers · …).
class SectionTabBar extends StatelessWidget {
  const SectionTabBar(
      {super.key,
      required this.tabs,
      required this.selected,
      required this.onSelect,
      this.keyPrefix = 'section-tab'});
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: MasterStyle.cardBorder)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  key: Key('$keyPrefix-${tabs[i]}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelect(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? ViniiColors.successPillBg
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: i == selected
                              ? ViniiColors.greenSolid
                              : Colors.transparent),
                    ),
                    child: Text(tabs[i],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                i == selected ? FontWeight.w700 : FontWeight.w500,
                            color: i == selected
                                ? ViniiColors.emeraldText
                                : ViniiColors.textPrimaryLight)),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// Loads [load] once (and again on [ApiLoaderState.reload]), showing a
/// spinner, then [builder] — or the error with a Retry button.
class ApiLoader<T> extends StatefulWidget {
  const ApiLoader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
      builder;

  @override
  State<ApiLoader<T>> createState() => ApiLoaderState<T>();
}

class ApiLoaderState<T> extends State<ApiLoader<T>> {
  late Future<T> _future = widget.load();

  void reload() => setState(() {
        _future = widget.load();
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: StaffErrorPanel(
                  message: apiErrorText(snap.error!), onRetry: reload),
            );
          }
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return const Padding(
                padding: EdgeInsets.all(48), child: StaffLoading());
          }
          return widget.builder(context, snap.data as T, reload);
        },
      );
}

/// A page body: padding, scrolling, and the section's header.
class BusinessPage extends StatelessWidget {
  const BusinessPage(
      {super.key,
      required this.title,
      this.subtitle,
      this.actions = const [],
      this.badge,
      required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: MasterStyle.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MasterPageHeader(
              title: title,
              subtitle: subtitle,
              actions: actions,
              titleTrailing: badge == null
                  ? null
                  : MasterStatusPill(badge!, tone: PillTone.green),
            ),
            ...children,
          ],
        ),
      );
}

/// KPI cards in a responsive grid.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.cards, this.columns = 4});
  final List<Widget> cards;
  final int columns;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: MasterGrid(columns: columns, minItemWidth: 190, children: cards),
      );
}

/// A labelled text box bound to [controller].
class BizTextField extends StatelessWidget {
  const BizTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.number = false,
    this.decimal = true,
    this.prefix,
    this.onChanged,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final bool number;
  final bool decimal;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => StaffField(
        label: label,
        required: required,
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          keyboardType: number
              ? TextInputType.numberWithOptions(decimal: decimal)
              : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: number
              ? [
                  FilteringTextInputFormatter.allow(
                      RegExp(decimal ? r'[0-9.\-]' : r'[0-9\-]'))
                ]
              : null,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixText: prefix,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

/// A labelled on/off row.
class BizToggle extends StatelessWidget {
  const BizToggle(
      {super.key, required this.label, required this.value, this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          StaffSwitch(value: value, onChanged: onChanged),
        ]),
      );
}

/// Tone of a status word for [MasterStatusPill].
PillTone toneOf(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'completed':
    case 'success':
    case 'connected':
    case 'approved':
    case 'healthy':
    case 'live':
    case 'resolved':
    case 'verified':
    case 'sent':
    case 'paid':
      return PillTone.green;
    case 'pending':
    case 'queued':
    case 'scheduled':
    case 'in_progress':
    case 'submitted':
    case 'draft':
    case 'requested':
    case 'expiring soon':
    case 'pending_verification':
    case 'reassigned':
    case 'acknowledged':
    case 'warning':
    case 'attention':
      return PillTone.amber;
    case 'failed':
    case 'rejected':
    case 'expired':
    case 'revoked':
    case 'error':
    case 'cancelled':
    case 'critical':
    case 'alert':
      return PillTone.red;
    case 'running':
    case 'assigned':
    case 'new':
      return PillTone.blue;
    default:
      return PillTone.gray;
  }
}

/// A status pill whose colour follows [toneOf].
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) =>
      MasterStatusPill(label ?? humanize(status), tone: toneOf(status));
}

/// A simple horizontal bar for shares and breakdowns (0..1).
class ShareBar extends StatelessWidget {
  const ShareBar(
      {super.key,
      required this.label,
      required this.value,
      required this.share,
      this.color = ViniiColors.greenSolid});
  final String label;
  final String value;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFF3F4F6),
            ),
          ),
        ]),
      );
}

/// A small note in a tinted box (e.g. why nothing was sent).
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.tone = PillTone.blue});
  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MasterBanner(message: text, tone: tone),
      );
}
