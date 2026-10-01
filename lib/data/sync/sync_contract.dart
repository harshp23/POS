import 'package:drift/drift.dart';

/// The device ↔ backend sync contract.
///
/// Lists every device table the Proviyaa backend keeps in the central
/// database, and the backend service (module) and resource that own it.
/// The app never talks to Supabase: it sends device rows to the backend
/// (`backend/`), and the backend maps them onto the central tables — the
/// existing Proviyaa OS tables where one exists (menu_items, orders,
/// kot_tickets, …) and the `pos_*` tables otherwise. The device doesn't
/// know or care which.
///
/// `backend/src/schema/pos-schema.json` is generated from this list plus
/// the Drift column metadata, and `test/backend_schema_contract_test.dart`
/// fails whenever the two drift apart — so a Drift migration that adds a
/// column can't silently stop syncing it.
///
/// Tables not listed stay on the device only: the durable outbox
/// (`pending_upload_intents`), the offline sign-in grant
/// (`device_sessions`), seed flags in `app_metadata`, the All Orders list
/// (`all_orders_table`, rebuilt from orders after a pull) and the sync
/// bookkeeping itself (`sync_row_states`).
enum SyncModule { master, operations }

class SyncTableSpec {
  const SyncTableSpec(this.localTable, this.module, this.resource,
      {this.onlyKeys});

  /// Drift table name on the device (`TableInfo.actualTableName`).
  final String localTable;

  /// Backend service that owns the table.
  final SyncModule module;

  /// Resource name on the backend's sync API.
  final String resource;

  /// For key/value tables: only rows whose `key` is in this set sync.
  final Set<String>? onlyKeys;
}

const kitchenStationsSettingKey = 'kds_kitchen_stations';
const alertSettingsSettingKey = 'kds_alert_settings';

/// In dependency order: a row's parents come before it, so a push never
/// references a record the backend hasn't seen yet.
const syncTables = <SyncTableSpec>[
  // Master: catalogue, recipes, common inventory, purchasing.
  SyncTableSpec('menu_categories_table', SyncModule.master, 'menu-categories'),
  SyncTableSpec('menu_items_table', SyncModule.master, 'menu-items'),
  SyncTableSpec('offers_table', SyncModule.master, 'offers'),
  SyncTableSpec('media_assets_table', SyncModule.master, 'media-assets'),
  SyncTableSpec('suppliers_table', SyncModule.master, 'suppliers'),
  SyncTableSpec('raw_materials_table', SyncModule.master, 'raw-materials'),
  SyncTableSpec('supplier_prices_table', SyncModule.master, 'supplier-prices'),
  SyncTableSpec('recipes_table', SyncModule.master, 'recipes'),
  SyncTableSpec('recipe_lines_table', SyncModule.master, 'recipe-lines'),
  SyncTableSpec('purchase_orders_table', SyncModule.master, 'purchase-orders'),
  SyncTableSpec(
      'purchase_order_lines_table', SyncModule.master, 'purchase-order-lines'),
  SyncTableSpec('goods_receipts_table', SyncModule.master, 'goods-receipts'),
  SyncTableSpec('stock_movements_table', SyncModule.master, 'stock-movements'),

  // Operations: floor, orders, kitchen, billing, delivery, QR.
  SyncTableSpec('app_metadata', SyncModule.operations, 'settings',
      onlyKeys: {kitchenStationsSettingKey, alertSettingsSettingKey}),
  SyncTableSpec('restaurant_tables', SyncModule.operations, 'tables'),
  SyncTableSpec('shifts', SyncModule.operations, 'shifts'),
  SyncTableSpec('orders', SyncModule.operations, 'orders'),
  SyncTableSpec('order_lines', SyncModule.operations, 'order-lines'),
  SyncTableSpec('kitchen_tickets', SyncModule.operations, 'kitchen-tickets'),
  SyncTableSpec('payments', SyncModule.operations, 'payments'),
  SyncTableSpec('deliveries_table', SyncModule.operations, 'deliveries'),
  SyncTableSpec('reservations_table', SyncModule.operations, 'reservations'),
  SyncTableSpec('qr_codes_table', SyncModule.operations, 'qr-codes'),
  SyncTableSpec('qr_sessions_table', SyncModule.operations, 'qr-sessions'),
];

/// Wire type of a column in the contract and on the sync API.
String contractTypeFor(GeneratedColumn column) {
  final type = column.type;
  if (type == DriftSqlType.string) return 'text';
  if (type == DriftSqlType.int || type == DriftSqlType.bigInt) return 'int';
  if (type == DriftSqlType.double) return 'real';
  if (type == DriftSqlType.bool) return 'bool';
  if (type == DriftSqlType.dateTime) return 'timestamp';
  if (type == DriftSqlType.blob) return 'blob';
  throw UnsupportedError(
      'Column ${column.tableName}.${column.name} has type $type, which the '
      'sync contract does not map. Add a mapping here and in the backend.');
}

/// The column's SQL default as contract JSON: `{"value": x}` for a
/// constant, `{"now": true}` for the current time, or null.
Map<String, Object?>? contractDefaultFor(GeneratedColumn column) {
  final def = column.defaultValue;
  if (def == null) return null;
  if (def is Constant) {
    final value = def.value;
    return {
      'value': value is DateTime ? value.toUtc().toIso8601String() : value
    };
  }
  if (column.type == DriftSqlType.dateTime) return {'now': true};
  throw UnsupportedError(
      'Column ${column.tableName}.${column.name} has a non-constant default '
      'the sync contract cannot express.');
}

/// Builds the backend schema contract from the live Drift tables.
Map<String, Object?> buildBackendSchemaContract(GeneratedDatabase db) {
  final byName = {for (final t in db.allTables) t.actualTableName: t};
  return {
    'contract_version': 1,
    'drift_schema_version': db.schemaVersion,
    'tables': [
      for (final spec in syncTables)
        _tableContract(
            spec,
            byName[spec.localTable] ??
                (throw StateError('Sync table ${spec.localTable} is not a '
                    'Drift table of this database.'))),
    ],
  };
}

Map<String, Object?> _tableContract(SyncTableSpec spec, TableInfo table) {
  final auto = table.$columns.where((c) => c.hasAutoIncrement).toList();
  return {
    'local_table': spec.localTable,
    'module': spec.module.name,
    'resource': spec.resource,
    'primary_key': [for (final c in table.$primaryKey) c.name],
    'unique_keys': [
      for (final key in table.uniqueKeys) [for (final c in key) c.name],
    ],
    'auto_increment': auto.isEmpty ? null : auto.single.name,
    'only_keys':
        spec.onlyKeys == null ? null : (spec.onlyKeys!.toList()..sort()),
    'columns': [
      for (final c in table.$columns)
        {
          'name': c.name,
          'type': contractTypeFor(c),
          'nullable': c.$nullable,
          'default': contractDefaultFor(c),
        },
    ],
  };
}
