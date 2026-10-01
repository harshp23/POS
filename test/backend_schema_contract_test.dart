import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/sync/sync_contract.dart';

/// The backend mirrors the device tables listed in `syncTables`. Its
/// schema file is generated from the Drift metadata, so this test fails
/// when a Drift change (new column, new table) isn't reflected in the
/// backend. To regenerate after an intentional schema change:
///
///   UPDATE_BACKEND_SCHEMA=1 flutter test test/backend_schema_contract_test.dart
///   cd backend && npm run db:generate
void main() {
  test('backend schema contract matches the Drift schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final contract = buildBackendSchemaContract(db);
    final encoded =
        '${const JsonEncoder.withIndent('  ').convert(contract)}\n';
    final file = File('backend/src/schema/pos-schema.json');

    if (Platform.environment['UPDATE_BACKEND_SCHEMA'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(encoded);
      return;
    }

    expect(file.existsSync(), isTrue,
        reason: '${file.path} is missing — run with UPDATE_BACKEND_SCHEMA=1');
    expect(file.readAsStringSync().replaceAll('\r\n', '\n'), encoded,
        reason: 'Drift schema and backend contract differ — run with '
            'UPDATE_BACKEND_SCHEMA=1 and regenerate the migration');
  });

  test('every synced table has a primary key the backend can address', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = buildBackendSchemaContract(db)['tables'] as List;
    for (final t in tables.cast<Map<String, Object?>>()) {
      expect((t['primary_key'] as List), isNotEmpty,
          reason: '${t['local_table']} has no primary key');
    }
  });
}
