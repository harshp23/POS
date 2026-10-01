/// Minimal RFC 4180 CSV encode/decode for Master import/export. Handles
/// quoted fields, embedded commas, quotes and newlines, CRLF or LF line
/// endings, and a UTF-8 BOM (Excel adds one when saving as CSV UTF-8).
class Csv {
  const Csv._();

  static String _field(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[",\r\n]')) || s.trim() != s) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String encode(List<String> headers, Iterable<List<Object?>> rows) {
    final b = StringBuffer()..writeln(headers.map(_field).join(','));
    for (final r in rows) {
      b.writeln(r.map(_field).join(','));
    }
    return b.toString();
  }

  static List<List<String>> decodeRows(String input) {
    var text = input;
    if (text.startsWith('﻿')) text = text.substring(1);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
        continue;
      }
      if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows.where((r) => r.any((f) => f.trim().isNotEmpty)).toList();
  }

  /// Decodes to one map per data row, keyed by the header row
  /// (headers are trimmed; lookups via [CsvRecord] are case-insensitive).
  static List<CsvRecord> decode(String input) {
    final rows = decodeRows(input);
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
    return [
      for (var i = 1; i < rows.length; i++)
        CsvRecord(i + 1, {
          for (var c = 0; c < headers.length; c++)
            headers[c]: c < rows[i].length ? rows[i][c].trim() : '',
        }),
    ];
  }
}

/// One imported row. [line] is the 1-based line number in the file, for
/// error messages.
class CsvRecord {
  const CsvRecord(this.line, this._values);
  final int line;
  final Map<String, String> _values;

  String call(String header, [String fallback = '']) {
    final v = _values[header.toLowerCase()];
    return (v == null || v.isEmpty) ? fallback : v;
  }

  bool has(String header) => (_values[header.toLowerCase()] ?? '').isNotEmpty;

  /// Parses numbers written as "₹1,240.50", "12 kg", "30%".
  double? number(String header) {
    final raw = call(header).replaceAll(RegExp(r'[^0-9.\-]'), '');
    return raw.isEmpty ? null : double.tryParse(raw);
  }
}

/// Result of an import, shown to the user.
class ImportSummary {
  ImportSummary();
  int added = 0;
  int updated = 0;
  final errors = <String>[];

  String get message {
    final parts = <String>[
      if (added > 0) '$added added',
      if (updated > 0) '$updated updated',
      if (errors.isNotEmpty) '${errors.length} skipped',
    ];
    return parts.isEmpty ? 'Nothing imported' : 'Import: ${parts.join(', ')}';
  }
}
