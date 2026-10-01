// Shared bits for the Operations and POS screens: human error messages
// and a person picker (rider, captain, server) fed by the staff list.
//
// The owner's rule: a screen shows names, numbers and words — never a
// database id, a device key or a raw error — and anything that already
// exists in the system is picked, not typed.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../../data/staff_repository.dart';

const _genericError = 'Something went wrong — please try again.';

/// A sentence people can act on for an error thrown by a store or by the
/// backend. Store errors (StateError / ArgumentError) and backend errors
/// ([ApiException.message]) already carry a human message; anything else
/// (a database or programming error) is never shown raw.
String friendlyError(Object e) {
  if (e is ApiException) {
    final m = e.message.trim();
    if (m.isNotEmpty) return m;
    return e.isNetwork
        ? 'Could not reach the server — check the connection and try again.'
        : _genericError;
  }
  if (e is TimeoutException) {
    return 'The server took too long to answer — please try again.';
  }
  if (e is StateError) return _humanOr(e.message);
  if (e is ArgumentError) {
    final m = e.message;
    return m is String ? _humanOr(m) : _genericError;
  }
  return _genericError;
}

String _humanOr(String message) {
  final m = message.trim();
  // `Iterable.single` / drift `getSingle()` failures are not sentences.
  if (m == 'No element') {
    return 'That record was not found — it may have been removed.';
  }
  if (m.isEmpty || m == 'Too many elements') return _genericError;
  return m;
}

/// Names for a [PersonPickerField]: the active staff of [staff] (only
/// those with delivery enabled when [deliveryOnly]) plus [include] (e.g.
/// the signed-in person), sorted, without duplicates. Empty when there is
/// no staff list, it has nobody who fits, or it cannot be loaded — the
/// picker then falls back to typing a name.
Future<List<String>> loadStaffNames(StaffRepository? staff,
    {bool deliveryOnly = false, Iterable<String> include = const []}) async {
  if (staff == null) return const [];
  List<StaffMember> all;
  try {
    all = await staff.employees();
  } catch (_) {
    return const [];
  }
  final names = <String>{
    for (final m in all)
      if (m.isActive &&
          (!deliveryOnly || m.deliveryEnabled) &&
          m.fullName.trim().isNotEmpty)
        m.fullName.trim(),
  };
  if (names.isEmpty) return const [];
  for (final n in include) {
    if (n.trim().isNotEmpty) names.add(n.trim());
  }
  return names.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Distinct, non-empty names from [values], sorted — e.g. the riders
/// already used on deliveries, offered as suggestions when there is no
/// staff list.
List<String> distinctNames(Iterable<String?> values) {
  final seen = <String, String>{};
  for (final v in values) {
    final n = v?.trim() ?? '';
    if (n.isNotEmpty) seen.putIfAbsent(n.toLowerCase(), () => n);
  }
  return seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Picks a person (rider, captain, server) by name.
///
/// With [names] (or [namesFuture] resolving to a non-empty list) it is a
/// dropdown of those names plus "Other…", which opens a text field for
/// someone not on the list. Without names it is a text field that
/// suggests [suggestions] as you type. [controller] always holds the
/// chosen name, so callers keep reading `controller.text`; [textFieldKey]
/// keys the text field (whenever it is shown).
class PersonPickerField extends StatefulWidget {
  const PersonPickerField({
    super.key,
    required this.controller,
    this.names = const [],
    this.namesFuture,
    this.suggestions = const [],
    this.decoration = const InputDecoration(),
    this.textFieldKey,
    this.dropdownKey,
    this.otherLabel = 'Other…',
    this.otherHint = 'Type the name',
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final List<String> names;

  /// Loads [names] (e.g. [loadStaffNames]); create it once, not in build.
  final Future<List<String>>? namesFuture;
  final List<String> suggestions;
  final InputDecoration decoration;
  final Key? textFieldKey;
  final Key? dropdownKey;
  final String otherLabel;
  final String otherHint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<PersonPickerField> createState() => _PersonPickerFieldState();
}

class _PersonPickerFieldState extends State<PersonPickerField> {
  static const _other = '\u0000other';
  List<String>? _loaded;
  bool _typing = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load(widget.namesFuture);
  }

  @override
  void didUpdateWidget(PersonPickerField old) {
    super.didUpdateWidget(old);
    if (!identical(old.namesFuture, widget.namesFuture)) {
      _load(widget.namesFuture);
    }
  }

  void _load(Future<List<String>>? f) {
    if (f == null) return;
    f.then((n) {
      if (mounted && identical(f, widget.namesFuture)) {
        setState(() => _loaded = n);
      }
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Distinct, trimmed, non-empty (a dropdown needs unique values).
  List<String> get _names => <String>{
        for (final n
            in widget.names.isNotEmpty ? widget.names : (_loaded ?? const []))
          if (n.trim().isNotEmpty) n.trim()
      }.toList();

  void _set(String v) {
    widget.controller.text = v;
    widget.onChanged?.call(v);
  }

  Widget _textField({required bool suggest, InputDecoration? decoration}) {
    final d = decoration ?? widget.decoration;
    final options = widget.suggestions;
    if (!suggest || options.isEmpty) {
      return TextField(
        key: widget.textFieldKey,
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        decoration: d,
        onChanged: widget.onChanged,
      );
    }
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return [
          for (final o in options)
            if (o.toLowerCase() != q &&
                (q.isEmpty || o.toLowerCase().contains(q)))
              o
        ];
      },
      onSelected: (v) => widget.onChanged?.call(v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
        key: widget.textFieldKey,
        controller: controller,
        focusNode: focusNode,
        autofocus: widget.autofocus,
        decoration: d,
        onChanged: widget.onChanged,
        onSubmitted: (_) => onSubmitted(),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline, size: 18),
                    title: Text(o),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    if (names.isEmpty) return _textField(suggest: true);
    final text = widget.controller.text.trim();
    final inList = names.contains(text);
    final typing = _typing || (text.isNotEmpty && !inList);
    final value = typing ? _other : (inList ? text : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: widget.decoration,
          isEmpty: false,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: widget.dropdownKey,
              value: value,
              isExpanded: true,
              isDense: true,
              hint: Text(widget.decoration.hintText ?? 'Select…',
                  overflow: TextOverflow.ellipsis),
              items: [
                for (final n in names)
                  DropdownMenuItem(
                      value: n,
                      child: Text(n, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: _other,
                    child: Text(widget.otherLabel,
                        style: const TextStyle(fontStyle: FontStyle.italic))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (v == _other) {
                    _typing = true;
                    if (inList) _set('');
                  } else {
                    _typing = false;
                    _set(v);
                  }
                });
              },
            ),
          ),
        ),
        if (typing) ...[
          const SizedBox(height: 8),
          _textField(
              suggest: false,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.otherHint,
                border: const OutlineInputBorder(),
              )),
        ],
      ],
    );
  }
}
