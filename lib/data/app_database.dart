import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'master_tables.dart';
import 'operations_tables.dart';
import 'sync/sync_tables.dart';

export 'master_tables.dart';
export 'operations_tables.dart';
export 'sync/sync_tables.dart';

part 'app_database.g.dart';

/// The device-local working store. This is a restricted store for the
/// current shift's local data and unsent pending-upload intents — it is
/// not a second independent cloud backend. Central Postgres, reached
/// through the authorized sync adapter, remains the reconciled business
/// record. See docs/SOURCE-UNDERSTANDING.txt section 2.

@DataClassName('OrderRow')
class Orders extends Table {
  TextColumn get clientOrderId => text()();
  TextColumn get locationId => text()();
  TextColumn get currencyCode => text()();
  TextColumn get status => text()();
  TextColumn get orderType => text()();
  TextColumn get tableLabel => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // v4 — Operations fields (defaults keep POS-written rows valid).
  // `status` above stays the sync status; `opsStatus` is the floor
  // lifecycle open → billed → settled / cancelled.
  TextColumn get opsStatus => text().withDefault(const Constant('open'))();
  TextColumn get channel => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant('POS'))();
  IntColumn get guests => integer().nullable()();
  TextColumn get serverName => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get discountPct => real().withDefault(const Constant(0))();
  RealColumn get taxPct => real().withDefault(const Constant(5))();
  IntColumn get billNo => integer().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  DateTimeColumn get settledAt => dateTime().nullable()();
  // v5 — guest / customer name shown on Live Orders cards.
  TextColumn get customerName => text().withDefault(const Constant(''))();
  // v7 — the order's number as the server shows it ("ORD-248"). Set by the
  // server on sync; an order made on this device shows its own key until
  // then. Orders made on the server (online, other devices' REST calls)
  // have a database id as their key and need this to be readable.
  TextColumn get displayNo => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientOrderId};
}

@DataClassName('OrderLineRow')
class OrderLines extends Table {
  TextColumn get clientOrderId => text()();
  TextColumn get itemId => text()();
  TextColumn get name => text()();
  IntColumn get unitMinor => integer()();
  IntColumn get quantity => integer()();

  // v4 — kitchen routing and per-item progress on the kitchen display.
  TextColumn get station =>
      text().withDefault(const Constant('Main Kitchen'))();
  BoolColumn get isVeg => boolean().withDefault(const Constant(true))();
  BoolColumn get kitchenDone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientOrderId, itemId};
}

@DataClassName('PendingUploadIntentRow')
class PendingUploadIntents extends Table {
  TextColumn get intentId => text()();
  TextColumn get clientOrderId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadHash => text()();
  TextColumn get state => text().withDefault(const Constant('queued'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {intentId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientOrderId, operation},
      ];
}

@DataClassName('KitchenTicketRow')
class KitchenTickets extends Table {
  TextColumn get ticketId => text()();
  TextColumn get clientOrderId => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // v4 — kitchen notes and priority for the KOT / KDS screens.
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get urgent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  // v7 — the KOT number the server gave the ticket (kot_tickets.kot_no),
  // set on sync.
  IntColumn get kotNo => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ticketId};
}

@DataClassName('ShiftRow')
class Shifts extends Table {
  TextColumn get shiftId => text()();
  TextColumn get locationId => text()();
  IntColumn get openingFloatMinor => integer()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get countedCashMinor => integer().nullable()();

  @override
  Set<Column> get primaryKey => {shiftId};
}

@DataClassName('PaymentRow')
class Payments extends Table {
  TextColumn get paymentId => text()();
  TextColumn get clientOrderId => text()();
  TextColumn get method => text()();
  IntColumn get amountMinor => integer()();
  IntColumn get receivedMinor => integer()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {paymentId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientOrderId},
      ];
}

/// Cached offline authorization grant — PRD §11 "Expired offline grant:
/// preserve data and allow designated recovery/finish-open-work
/// behavior" and D04: 24-hour offline staff authorization, one row per
/// device (this device serves one location, D02).
@DataClassName('DeviceSessionRow')
class DeviceSessions extends Table {
  TextColumn get deviceId => text()();
  TextColumn get staffId => text()();
  TextColumn get staffName => text()();
  TextColumn get locationId => text()();
  DateTimeColumn get grantedAt => dateTime()();
  DateTimeColumn get grantExpiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

@DataClassName('RestaurantTableRow')
class RestaurantTables extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  IntColumn get seats => integer()();
  TextColumn get zone => text()();
  TextColumn get status => text()();
  IntColumn get guestCount => integer().nullable()();
  IntColumn get elapsedMinutes => integer().nullable()();
  IntColumn get orderTotalMinor => integer().nullable()();
  TextColumn get reservedByName => text().nullable()();
  DateTimeColumn get reservedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // v4 — floor plan fields for Operations → Dine In / Captain Orders.
  TextColumn get floor => text().withDefault(const Constant('Ground Floor'))();
  TextColumn get shape => text().withDefault(const Constant('square'))();
  TextColumn get serverName => text().withDefault(const Constant(''))();
  BoolColumn get paymentPending =>
      boolean().withDefault(const Constant(false))();
  TextColumn get currentOrderId => text().nullable()();
  DateTimeColumn get seatedAt => dateTime().nullable()();
  // v5 — when the table was last marked clean / available.
  DateTimeColumn get lastCleanedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AllOrderEntity')
class AllOrdersTable extends Table {
  TextColumn get orderId => text()();
  TextColumn get type => text()();
  TextColumn get source => text()();
  TextColumn get tableOrCustomer => text()();
  TextColumn get itemsLabel => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {orderId};
}

@DataClassName('MenuCategoryEntity')
class MenuCategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MenuItemEntity')
class MenuItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  IntColumn get priceMinor => integer()();
  BoolColumn get isVeg => boolean().withDefault(const Constant(true))();
  BoolColumn get isBestseller => boolean().withDefault(const Constant(false))();
  BoolColumn get available => boolean().withDefault(const Constant(true))();
  TextColumn get unavailableReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // v3 — Master catalogue fields. Nullable/defaulted so rows written by
  // the POS menu screen (which never sets them) stay valid.
  TextColumn get sku => text().withDefault(const Constant(''))();
  TextColumn get hsn => text().withDefault(const Constant(''))();
  IntColumn get foodCostMinor => integer().withDefault(const Constant(0))();
  TextColumn get channels => text().withDefault(const Constant('POS'))();
  TextColumn get kitchenStation => text().withDefault(const Constant(''))();
  TextColumn get menuStatus => text().withDefault(const Constant('Active'))();
  TextColumn get availabilityLabel =>
      text().withDefault(const Constant('In Stock'))();
  TextColumn get imageUrl => text().withDefault(const Constant(''))();
  TextColumn get dietType => text().withDefault(const Constant('veg'))();

  /// Remaining Add/Edit Item form fields (short name, barcode, prep time,
  /// tax, packaging, order types, …) as a JSON object.
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Orders,
  OrderLines,
  PendingUploadIntents,
  KitchenTickets,
  Shifts,
  Payments,
  DeviceSessions,
  RestaurantTables,
  AllOrdersTable,
  MenuCategoriesTable,
  MenuItemsTable,
  AppMetadata,
  RawMaterialsTable,
  SuppliersTable,
  SupplierPricesTable,
  PurchaseOrdersTable,
  PurchaseOrderLinesTable,
  GoodsReceiptsTable,
  StockMovementsTable,
  OffersTable,
  MediaAssetsTable,
  RecipesTable,
  RecipeLinesTable,
  DeliveriesTable,
  ReservationsTable,
  QrCodesTable,
  QrSessionsTable,
  SyncRowStates,
])
class AppDatabase extends _$AppDatabase {
  /// Kept for tests and any caller that wants to hand in its own
  /// [QueryExecutor] (e.g. an in-memory database).
  AppDatabase(super.executor);

  AppDatabase.defaults()
      : super(driftDatabase(
            name: 'proviyaa_pos',
            web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'))));

  /// Adds [column] unless it already exists. Skips tables that don't
  /// exist yet (beforeOpen creates them with every column), so an upgrade
  /// never fails on a partially-migrated or unusual device database.
  Future<void> _addColumnIfMissing(
      Migrator m, TableInfo table, GeneratedColumn column) async {
    final cols =
        await customSelect('PRAGMA table_info("${table.actualTableName}")')
            .get();
    if (cols.isEmpty) return;
    if (cols.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  int _transactionDepth = 0;

  /// Web durability fix. When the browser isn't cross-origin isolated
  /// (plain `flutter run` / a static server without COOP+COEP headers),
  /// drift stores the database in IndexedDB and copies it there after
  /// each *non-transactional* statement only — the COMMIT of a
  /// transaction runs while drift still flags the connection as "in a
  /// transaction", so it is never flushed. A save done in a transaction
  /// then lives only in memory until some later plain write, and a page
  /// reload in between silently loses it (seen in the Master module:
  /// an item saved seconds before a reload disappeared). Running one
  /// trivial statement after the outermost transaction completes
  /// triggers drift's flush. On native/OPFS storage it is a no-op query.
  @override
  Future<T> transaction<T>(Future<T> Function() action,
      {bool requireNew = false}) async {
    _transactionDepth++;
    try {
      return await super.transaction(action, requireNew: requireNew);
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        try {
          await customStatement('SELECT 1');
        } catch (_) {
          // Database closing — nothing left to flush.
        }
      }
    }
  }

  // Bump this and add a numbered step under `migration` whenever the
  // schema changes. Never drop or recreate a table that may hold unsynced
  // data — local orders and pending_upload_intents rows must survive
  // every upgrade; see D10 in docs/DECISIONS-AND-QUESTIONS.txt.
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(restaurantTables);
            await m.createTable(allOrdersTable);
            await m.createTable(menuCategoriesTable);
            await m.createTable(menuItemsTable);
            await m.createTable(appMetadata);
          }
          if (from < 3) {
            // from == 2 databases already have menu_items_table without
            // the Master columns; from < 2 created it above with them.
            if (from == 2) {
              await _addColumnIfMissing(m, menuItemsTable, menuItemsTable.sku);
              await _addColumnIfMissing(m, menuItemsTable, menuItemsTable.hsn);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.foodCostMinor);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.channels);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.kitchenStation);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.menuStatus);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.availabilityLabel);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.imageUrl);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.dietType);
              await _addColumnIfMissing(
                  m, menuItemsTable, menuItemsTable.detailsJson);
            }
            // New Master tables are created by beforeOpen below.
          }
          if (from < 4) {
            // orders / order_lines / kitchen_tickets exist since v1;
            // restaurant_tables since v2 (a from < 2 upgrade created it
            // above with the v4 columns already).
            for (final c in [
              orders.opsStatus,
              orders.channel,
              orders.source,
              orders.guests,
              orders.serverName,
              orders.notes,
              orders.discountPct,
              orders.taxPct,
              orders.billNo,
              orders.paymentMethod,
              orders.settledAt,
            ]) {
              await _addColumnIfMissing(m, orders, c);
            }
            for (final c in [
              orderLines.station,
              orderLines.isVeg,
              orderLines.kitchenDone,
            ]) {
              await _addColumnIfMissing(m, orderLines, c);
            }
            for (final c in [
              kitchenTickets.notes,
              kitchenTickets.urgent,
              kitchenTickets.completedAt,
            ]) {
              await _addColumnIfMissing(m, kitchenTickets, c);
            }
            if (from >= 2) {
              for (final c in [
                restaurantTables.floor,
                restaurantTables.shape,
                restaurantTables.serverName,
                restaurantTables.paymentPending,
                restaurantTables.currentOrderId,
                restaurantTables.seatedAt,
              ]) {
                await _addColumnIfMissing(m, restaurantTables, c);
              }
            }
            // New Operations tables are created by beforeOpen below.
          }
          if (from < 5) {
            await _addColumnIfMissing(m, orders, orders.customerName);
            if (from >= 2) {
              await _addColumnIfMissing(
                  m, restaurantTables, restaurantTables.lastCleanedAt);
            }
          }
          // v6 — sync bookkeeping (sync_row_states) for the backend sync;
          // a new table only, created by beforeOpen below. Existing rows
          // have no sync state yet, which the first sync treats as
          // "never synchronized" — nothing is dropped or rewritten.
          if (from < 7) {
            await _addColumnIfMissing(m, orders, orders.displayNo);
            await _addColumnIfMissing(m, kitchenTickets, kitchenTickets.kotNo);
            // Pull orders and KOTs again so rows synced before v7 get their
            // numbers (the next sync starts from the server's first-sync
            // window: open orders and the last 36 hours).
            final hasCursors = await customSelect(
                    "SELECT 1 FROM sqlite_master WHERE type = 'table' "
                    "AND name = 'app_metadata'")
                .get();
            if (hasCursors.isNotEmpty) {
              await customStatement("DELETE FROM app_metadata WHERE key IN "
                  "('sync_cursor:orders', 'sync_cursor:kitchen-tickets')");
            }
          }
        },
        beforeOpen: (details) async {
          final m = createMigrator();
          for (final table in allTables) {
            try {
              await m.createTable(table);
            } catch (_) {
              // Table already exists, ignore
            }
          }
        },
      );

  /// Brings the schema up to date when [migration] did not run for this
  /// app. On the web the database lives in a shared worker, and only the
  /// first tab that opens it runs the migration — a tab still on an older
  /// app version may have opened it first. Every step only adds missing
  /// tables and columns, so this is safe to call on every start.
  Future<void> ensureSchema() async {
    final version = (await customSelect('PRAGMA user_version').getSingle())
        .read<int>('user_version');
    if (version >= schemaVersion) return;
    final m = createMigrator();
    await migration.onUpgrade(m, version, schemaVersion);
    for (final table in allTables) {
      await m.createTable(table); // CREATE TABLE IF NOT EXISTS
    }
    await customStatement('PRAGMA user_version = $schemaVersion');
  }
}
