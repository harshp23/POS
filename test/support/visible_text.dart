import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every piece of text on screen: Text, rich text, selectable text and the
/// values shown in text fields.
List<String> visibleTexts(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    if (s.trim().isNotEmpty) out.add(s);
  }
  for (final e in find.byType(RichText).evaluate()) {
    final s = (e.widget as RichText).text.toPlainText();
    if (s.trim().isNotEmpty) out.add(s);
  }
  for (final e in find.byType(EditableText).evaluate()) {
    final s = (e.widget as EditableText).controller.text;
    if (s.trim().isNotEmpty) out.add(s);
  }
  return out;
}

final _databaseId = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false);

/// Internal codes that must reach people as words ("Dine In", "Branch
/// Manager", "Bank transfer"), never as stored.
final _rawCode = RegExp(r'(^|[\s(·•,:|])([a-z]+_[a-z_]+|[a-z]+[A-Z][a-zA-Z]+)(?=$|[\s)·•,.|])');

/// Technical identifiers that are shown on purpose: webhook event names
/// (order.status_changed), API scopes (orders:read), key prefixes, emails,
/// URLs and file names.
bool _technical(String token, String text) =>
    text.contains('@') ||
    text.contains('://') ||
    text.contains('pv_live_') ||
    text.contains('whsec_') ||
    RegExp(r'[a-z_]+\.[a-z_]+').hasMatch(text) ||
    RegExp(r'[a-z]+:[a-z]+').hasMatch(text) ||
    RegExp(r'\.(png|jpg|jpeg|csv|pdf)\b').hasMatch(text);

/// A stored timestamp ("2026-09-30T11:44:45.770Z") printed as is.
final _isoTimestamp = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');

/// The database ids and raw internal codes on screen (empty when clean).
List<String> internalValuesOnScreen(WidgetTester tester) {
  final texts = visibleTexts(tester);
  final ids = texts.where(_databaseId.hasMatch).toSet();
  final stamps = texts.where(_isoTimestamp.hasMatch).toSet();
  final codes = <String>{};
  for (final t in texts) {
    for (final m in _rawCode.allMatches(t)) {
      final token = m.group(2)!;
      if (!_technical(token, t)) codes.add('"$token" in "$t"');
    }
  }
  return [
    ...ids.map((s) => 'id: "$s"'),
    ...stamps.map((s) => 'timestamp: "$s"'),
    ...codes,
  ];
}

/// Fails when a database id or a raw internal code is on screen.
void expectOnlyRealData(WidgetTester tester, String where) =>
    expect(internalValuesOnScreen(tester), isEmpty,
        reason: '$where shows internal values instead of real data');
