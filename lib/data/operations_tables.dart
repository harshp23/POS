import 'package:drift/drift.dart';

/// Drift tables added for restaurant-admin Operations (schema v4). Only
/// records the POS had no table for live here; tables, orders, KOTs and
/// payments reuse the POS tables (see the v4 columns in app_database.dart).

@DataClassName('DeliveryEntity')
class DeliveriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get merchant => text()();
  TextColumn get riderName => text().nullable()();
  TextColumn get status => text()();
  IntColumn get etaMinutes => integer().nullable()();
  RealColumn get distanceKm => real().withDefault(const Constant(0))();
  TextColumn get customerName => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  DateTimeColumn get promisedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReservationEntity')
class ReservationsTable extends Table {
  TextColumn get id => text()();
  TextColumn get guestName => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().withDefault(const Constant(''))();
  IntColumn get guests => integer()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get status => text()();
  TextColumn get tableId => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QrCodeEntity')
class QrCodesTable extends Table {
  TextColumn get tableId => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get token => text()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tableId};
}

@DataClassName('QrSessionEntity')
class QrSessionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get tableLabel => text()();
  IntColumn get guests => integer().withDefault(const Constant(1))();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get status => text()();
  TextColumn get orderId => text().nullable()();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
