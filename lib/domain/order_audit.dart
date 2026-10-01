/// Order corrections audit trail.
///
/// The device has no order-events table (the server keeps `order_events`,
/// but nothing on the device syncs into it), and the Drift schema is fixed
/// by the sync contract. Every correction (cancel, void / quantity
/// reduction after a KOT, discount change, payment verification, bill
/// reprint) is therefore appended to the order's own `orders.notes` column
/// as one structured line:
///
///     [2026-09-29 12:00 · Asha] Cancelled: guest left
///
/// `orders.notes` syncs to the central order, so the trail travels with
/// the order and is visible in the back office. Lines that do not match
/// the format are the free-text kitchen / guest notes and are kept
/// separate when the notes are read ([parseOrderNotes]).
library;

class OrderAuditEntry {
  const OrderAuditEntry(
      {required this.at, required this.actor, required this.text});

  /// Local wall-clock time of the correction (minute precision).
  final DateTime at;

  /// Who made it; empty when the device did not know the signed-in user.
  final String actor;

  /// "Cancelled: guest left", "Discount 0% → 10%: loyal guest", …
  final String text;

  @override
  String toString() => formatAuditLine(at, actor, text);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Single-line form of [text] (reasons are typed by staff and may contain
/// line breaks or brackets that would break the format).
String _oneLine(String text) =>
    text.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(']', ')').trim();

/// "[2026-09-29 12:00 · Asha] Cancelled: guest left" (no actor part when
/// [actor] is empty).
String formatAuditLine(DateTime at, String actor, String text) {
  final stamp = '${at.year.toString().padLeft(4, '0')}-${_two(at.month)}-'
      '${_two(at.day)} ${_two(at.hour)}:${_two(at.minute)}';
  final who = _oneLine(actor).replaceAll('·', '-');
  final body = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  return who.isEmpty ? '[$stamp] $body' : '[$stamp · $who] $body';
}

final _line = RegExp(
    r'^\[(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})(?: · ([^\]]*))?\] (.*)$');

/// An order's notes split into the free-text notes and the audit trail.
class ParsedOrderNotes {
  const ParsedOrderNotes(this.plain, this.entries);

  /// Kitchen / guest notes as typed (audit lines removed).
  final String plain;

  /// Corrections, oldest first.
  final List<OrderAuditEntry> entries;
}

ParsedOrderNotes parseOrderNotes(String raw) {
  final plain = <String>[];
  final entries = <OrderAuditEntry>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final m = _line.firstMatch(line.trim());
    if (m == null) {
      plain.add(line);
      continue;
    }
    entries.add(OrderAuditEntry(
        at: DateTime(
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
            int.parse(m.group(4)!),
            int.parse(m.group(5)!)),
        actor: (m.group(6) ?? '').trim(),
        text: m.group(7)!.trim()));
  }
  return ParsedOrderNotes(plain.join('\n').trim(), entries);
}

/// [raw] notes with one more audit line at the end.
String appendAuditLine(String raw, DateTime at, String actor, String text) {
  final line = formatAuditLine(at, actor, text);
  final base = raw.trimRight();
  return base.isEmpty ? line : '$base\n$line';
}

/// The reason text staff typed, validated: corrections need one.
String requireReason(String? reason, String what) {
  final r = _oneLine(reason ?? '');
  if (r.isEmpty) {
    throw ArgumentError('Enter a reason to $what.');
  }
  return r;
}
