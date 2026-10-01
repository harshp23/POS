import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show ApiException;
import '../vinii_theme.dart';

/// Said when something failed for a reason nobody can act on.
const kGenericError = 'Something went wrong. Please try again.';

/// Said when the server can't be reached.
const kOfflineError =
    'Could not reach the Proviyaa server. Check the internet connection and '
    'try again.';

final _uuidInText = RegExp(
    r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b');

/// Program text that must never reach a person: Dart type errors, stack
/// frames, database exceptions.
final _technicalText = RegExp(
    r"type '|subtype of|Null check operator|Unexpected null value|"
    r"\bNo element\b|\bToo many elements\b|Instance of '|package:|\.dart:|#0 |"
    r'NoSuchMethodError|RangeError|Exception\(|Error\(|SqliteException|'
    r'DatabaseException|SocketException|ClientException|HandshakeException',
    caseSensitive: false);

/// [message] without ids, or null when it's program text.
String? _humanMessage(String? message) {
  if (message == null) return null;
  var m = message.trim();
  if (m.startsWith('Exception: ')) m = m.substring(11).trim();
  if (m.startsWith('Bad state: ')) m = m.substring(11).trim();
  if (m.startsWith('Invalid argument(s): ')) m = m.substring(21).trim();
  m = m
      .replaceAll(_uuidInText, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAllMapped(RegExp(r'\s+([.,:;!?])'), (x) => x[1]!)
      .trim();
  if (m.isEmpty || _technicalText.hasMatch(m)) return null;
  return m;
}

/// What to tell a person when an action failed: the server's own message
/// (it is written for people), else a plain sentence — never a Dart type
/// name, stack text, database error or record id.
String friendlyErrorText(Object error, {String fallback = kGenericError}) {
  final e = error;
  if (e is ApiException) {
    final m = _humanMessage(e.message);
    if (m != null) return m;
    return e.isNetwork ? kOfflineError : fallback;
  }
  if (e is TimeoutException) {
    return 'The server took too long to answer. Please try again.';
  }
  if (e is TypeError ||
      e is NoSuchMethodError ||
      e is RangeError ||
      e is UnsupportedError ||
      e is ConcurrentModificationError ||
      e is AssertionError) {
    return fallback;
  }
  if (e is FormatException) {
    return 'Some of the data could not be read. Please try again.';
  }
  if (e is StateError) return _humanMessage(e.message) ?? fallback;
  if (e is ArgumentError) {
    final m = e.message;
    return (m is String ? _humanMessage(m) : null) ?? fallback;
  }
  final s = '$e';
  final lower = s.toLowerCase();
  if (lower.contains('sqlite') || lower.contains('databaseexception')) {
    return 'Could not read or save the data on this device. Please try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection closed')) {
    return kOfflineError;
  }
  return _humanMessage(s) ?? fallback;
}

/// Tooltip on every KPI that has no value yet.
const kNotEnoughData = 'Not enough data';

/// Empty state of the chain screens when no franchise data is loaded (local
/// mode, not signed in to a backend, or still loading).
const kConnectForBranchData =
    'Connect to the Proviyaa server to see branch data.';

/// Card / border colours of the vendor panel, light or dark.
class PanelColors {
  const PanelColors._(this.card, this.border, this.muted, this.subtle);

  factory PanelColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? PanelColors._(const Color(0xFF1E1E1E), Colors.grey[800]!,
            Colors.grey[400]!, const Color(0xFF2A2A2A))
        : PanelColors._(Colors.white, Colors.grey[200]!, Colors.grey[600]!,
            const Color(0xFFF8F9FA));
  }

  final Color card;
  final Color border;
  final Color muted;

  /// Background of tiles inside a card.
  final Color subtle;
}

/// A titled white card, the building block of every panel screen.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = PanelColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(fontSize: 11, color: c.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A figure with its label. A null [value] shows "—" with a
/// "Not enough data" tooltip (or [emptyTooltip]).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.emptyTooltip,
    this.large = false,
  });

  final String label;
  final String? value;
  final String? sub;
  final Color? valueColor;
  final String? emptyTooltip;

  /// KPI-card size (the top row) instead of an in-card tile.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = PanelColors.of(context);
    final style = TextStyle(
      fontSize: large ? 22 : 15,
      fontWeight: FontWeight.bold,
      color: value == null ? c.muted : valueColor,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(large ? 16 : 10),
      decoration: BoxDecoration(
        color: large ? c.card : c.subtle,
        borderRadius: BorderRadius.circular(large ? 10 : 8),
        border: large ? Border.all(color: c.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: large ? 10 : 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: c.muted)),
          SizedBox(height: large ? 8 : 4),
          KpiText(value, style: style, emptyTooltip: emptyTooltip),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: TextStyle(fontSize: 11, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

/// [value] as text, or "—" with a "Not enough data" tooltip when null.
class KpiText extends StatelessWidget {
  const KpiText(this.value, {super.key, this.style, this.emptyTooltip});

  final String? value;
  final TextStyle? style;
  final String? emptyTooltip;

  @override
  Widget build(BuildContext context) => value == null
      ? Tooltip(
          message: emptyTooltip ?? kNotEnoughData,
          child: Text('—', style: style),
        )
      : Text(value!, style: style);
}

/// A small coloured label.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      );
}

/// Centered icon + message for empty, not-connected and error states.
class NoDataView extends StatelessWidget {
  const NoDataView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inside a card rather than filling a page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = PanelColors.of(context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 28 : 40, color: c.muted),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 13 : 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.muted)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
    if (compact) {
      return Padding(padding: const EdgeInsets.all(12), child: body);
    }
    return Center(
        child: Padding(padding: const EdgeInsets.all(32), child: body));
  }
}

/// Chain screens' empty state: no franchise data on this device.
class FranchiseNoData extends StatelessWidget {
  const FranchiseNoData({super.key, this.title = 'No branch data yet'});

  final String title;

  @override
  Widget build(BuildContext context) => NoDataView(
        title: title,
        message: '$kConnectForBranchData '
            'Once you are signed in, chain data loads automatically — use '
            'Sync to refresh it.',
      );
}

/// Children side by side on wide layouts, stacked on narrow ones.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.flex,
    this.breakpoint = 900,
    this.spacing = 16,
  });

  final List<Widget> children;

  /// Flex of each child on wide layouts (default 1 each).
  final List<int>? flex;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < breakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) SizedBox(height: spacing),
                  c,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(flex: flex?[i] ?? 1, child: c),
              ],
            ],
          );
        },
      );
}

/// [child] with a tooltip, or bare when [message] is null — e.g. to say why
/// a button is disabled.
Widget withTooltip(String? message, Widget child) =>
    message == null ? child : Tooltip(message: message, child: child);

/// Why write actions are disabled without a backend repository.
const kNeedsServerToSave =
    'Connect to the Proviyaa server to save changes here.';

/// A snackbar for a saved action (green) or a failure (red). It replaces
/// any message still showing, so a result never waits behind a stale one.
void showResultSnack(BuildContext context, String message,
    {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? ViniiColors.redSolid : ViniiColors.emeraldText,
    ));
}

/// "29 Sep 2026, 14:05".
String formatShortDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)} ${months[d.month - 1]} ${d.year}, '
      '${two(d.hour)}:${two(d.minute)}';
}
