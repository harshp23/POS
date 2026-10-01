import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/operations.dart';
import '../domain/order_audit.dart';
import '../domain/payment.dart';
import 'app_database.dart';

/// The Operations store — every restaurant-admin Operations screen reads
/// and writes through this class. It works on the SAME tables the POS
/// uses (restaurant_tables, orders, order_lines, kitchen_tickets,
/// payments, all_orders_table, pending_upload_intents), so an order taken
/// here shows up in the POS and vice versa; only deliveries, reservations
/// and QR ordering have tables of their own.
///
/// Order lifecycle (orders.ops_status): open → billed → settled, or
/// cancelled. Payments:
///  * cash is final — recording it settles the order;
///  * card / UPI / split-with-card-or-UPI are recorded but the order stays
///    `billed` ("payment pending verification") until [verifyPayment];
///  * a payment row is never overwritten.
/// Corrections (cancel, void, discount, verification, reprint) append an
/// audit line to orders.notes — see domain/order_audit.dart.
class DriftOperationsStore {
  DriftOperationsStore(this.db,
      {DateTime Function()? clock, this.actorName = ''})
      : _now = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _now;

  /// Name of the signed-in user, written on audit lines when a call does
  /// not pass its own `by`. The app sets it after sign-in.
  String actorName;

  static const locationId = 'location-demo';

  /// Re-emits whenever any of [tables] changes.
  Stream<T> _watch<T>(Set<TableInfo> tables, Future<T> Function() load) => db
      .customSelect('SELECT 1', readsFrom: tables)
      .watch()
      .asyncMap((_) => load());

  // ---------------------------------------------------------------------
  // Tables / floors
  // ---------------------------------------------------------------------

  OpsTable _table(RestaurantTableRow r) {
    final base = switch (r.status) {
      'occupied' => OpsTableStatus.occupied,
      'reserved' => OpsTableStatus.reserved,
      'cleaning' => OpsTableStatus.cleaning,
      _ => OpsTableStatus.available,
    };
    return OpsTable(
      id: r.id,
      label: r.label,
      seats: r.seats,
      floor: r.floor,
      shape: r.shape,
      status: r.paymentPending && base == OpsTableStatus.occupied
          ? OpsTableStatus.billing
          : base,
      guests: r.guestCount,
      serverName: r.serverName,
      seatedAt: r.seatedAt,
      currentOrderId: r.currentOrderId,
      reservedByName: r.reservedByName,
      reservedAt: r.reservedAt,
      lastCleanedAt: r.lastCleanedAt,
    );
  }

  static int _labelNumber(String label) =>
      int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<List<OpsTable>> getTables() async {
    final rows = await db.select(db.restaurantTables).get();
    final tables = rows.map(_table).toList()
      ..sort((a, b) => _labelNumber(a.label).compareTo(_labelNumber(b.label)));
    return tables;
  }

  Stream<List<OpsTable>> watchTables() =>
      _watch({db.restaurantTables}, getTables);

  Future<OpsTable?> getTable(String id) async {
    final r = await (db.select(db.restaurantTables)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _table(r);
  }

  /// Floors in first-seen order of the seeded layout.
  static const defaultFloors = [
    'Ground Floor',
    'First Floor',
    'Terrace',
    'Private Cabanas'
  ];

  Future<List<String>> getFloors() async {
    final used = (await getTables()).map((t) => t.floor).toSet();
    return [
      ...defaultFloors.where(used.contains),
      ...used.where((f) => !defaultFloors.contains(f)),
    ];
  }

  Future<void> upsertTable(OpsTable t) async {
    await db
        .into(db.restaurantTables)
        .insertOnConflictUpdate(RestaurantTablesCompanion.insert(
            id: t.id,
            label: t.label,
            seats: t.seats,
            zone: t.floor == 'Terrace' ? 'outdoor' : 'indoor',
            status: switch (t.status) {
              OpsTableStatus.billing => 'occupied',
              OpsTableStatus.available => 'available',
              OpsTableStatus.occupied => 'occupied',
              OpsTableStatus.reserved => 'reserved',
              OpsTableStatus.cleaning => 'cleaning',
            },
            guestCount: Value(t.guests),
            reservedByName: Value(t.reservedByName),
            reservedAt: Value(t.reservedAt),
            floor: Value(t.floor),
            shape: Value(t.shape),
            serverName: Value(t.serverName),
            paymentPending: Value(t.status == OpsTableStatus.billing),
            currentOrderId: Value(t.currentOrderId),
            seatedAt: Value(t.seatedAt)));
  }

  /// Deletes a table that has no open order.
  Future<void> deleteTable(String id) async {
    final t = await getTable(id);
    if (t == null) return;
    if (t.currentOrderId != null) {
      throw StateError(
          '${t.label} has an open order; settle or move it first.');
    }
    await (db.delete(db.restaurantTables)..where((r) => r.id.equals(id))).go();
    await (db.delete(db.qrCodesTable)..where((r) => r.tableId.equals(id))).go();
  }

  Future<String> nextTableId() async {
    final max = (await getTables()).fold<int>(
        0, (m, t) => _labelNumber(t.label) > m ? _labelNumber(t.label) : m);
    return 'T${max + 1}';
  }

  /// Seats guests at an available / reserved table.
  Future<void> seatTable(String tableId,
      {required int guests, String serverName = ''}) async {
    final t = await getTable(tableId);
    if (t == null) throw StateError(_tableNotFound);
    if (t.status == OpsTableStatus.occupied ||
        t.status == OpsTableStatus.billing) {
      throw StateError('${t.label} is already occupied.');
    }
    if (guests < 1) throw ArgumentError('At least one guest is required.');
    await (db.update(db.restaurantTables)..where((r) => r.id.equals(tableId)))
        .write(RestaurantTablesCompanion(
      status: const Value('occupied'),
      guestCount: Value(guests),
      serverName: Value(serverName),
      seatedAt: Value(_now()),
      paymentPending: const Value(false),
      reservedByName: const Value(null),
      reservedAt: const Value(null),
    ));
  }

  /// True when [orderId] is an order still open or awaiting payment.
  Future<bool> _isActiveOrder(String? orderId) async {
    if (orderId == null) return false;
    final o = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    return o != null && (o.opsStatus == 'open' || o.opsStatus == 'billed');
  }

  /// The number people know [orderId] by ("ORD-248", or this device's key
  /// until sync numbers it) — for messages. Never a database id.
  Future<String> _orderNo(String orderId) async {
    final o = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    return orderNumberLabel(orderId, o?.displayNo);
  }

  static const _tableNotFound =
      'This table was not found — it may have been removed.';

  static const _orderNotFound =
      'This order was not found — it may have been removed from this device.';

  Future<void> setTableStatus(String tableId, OpsTableStatus status) async {
    final t = await getTable(tableId);
    if (t == null) return;
    if ((status == OpsTableStatus.available ||
            status == OpsTableStatus.cleaning ||
            status == OpsTableStatus.reserved) &&
        await _isActiveOrder(t.currentOrderId)) {
      throw StateError('${t.label} still has an open order '
          '(${await _orderNo(t.currentOrderId!)}); settle, cancel or move it '
          'first.');
    }
    await (db.update(db.restaurantTables)..where((r) => r.id.equals(tableId)))
        .write(RestaurantTablesCompanion(
      status: Value(switch (status) {
        OpsTableStatus.billing || OpsTableStatus.occupied => 'occupied',
        OpsTableStatus.available => 'available',
        OpsTableStatus.reserved => 'reserved',
        OpsTableStatus.cleaning => 'cleaning',
      }),
      paymentPending: Value(status == OpsTableStatus.billing),
      guestCount: status == OpsTableStatus.available ||
              status == OpsTableStatus.cleaning
          ? const Value(null)
          : const Value.absent(),
      seatedAt: status == OpsTableStatus.available ||
              status == OpsTableStatus.cleaning
          ? const Value(null)
          : const Value.absent(),
      lastCleanedAt: status == OpsTableStatus.available
          ? Value(_now())
          : const Value.absent(),
      // Only a stale link (its order is already closed) can remain here.
      currentOrderId: status == OpsTableStatus.available ||
              status == OpsTableStatus.cleaning
          ? const Value(null)
          : const Value.absent(),
    ));
  }

  /// Moves guests and their open order to an empty table.
  Future<void> transferTable(String fromId, String toId) async {
    await db.transaction(() async {
      final from = await getTable(fromId);
      final to = await getTable(toId);
      if (from == null || to == null) throw StateError(_tableNotFound);
      if (to.status != OpsTableStatus.available) {
        throw StateError('${to.label} is not available.');
      }
      await (db.update(db.restaurantTables)..where((r) => r.id.equals(toId)))
          .write(RestaurantTablesCompanion(
        status: const Value('occupied'),
        guestCount: Value(from.guests),
        serverName: Value(from.serverName),
        seatedAt: Value(from.seatedAt ?? _now()),
        currentOrderId: Value(from.currentOrderId),
        paymentPending: Value(from.status == OpsTableStatus.billing),
      ));
      await (db.update(db.restaurantTables)..where((r) => r.id.equals(fromId)))
          .write(const RestaurantTablesCompanion(
        status: Value('cleaning'),
        guestCount: Value(null),
        seatedAt: Value(null),
        currentOrderId: Value(null),
        paymentPending: Value(false),
      ));
      if (from.currentOrderId != null) {
        await (db.update(db.orders)
              ..where((o) => o.clientOrderId.equals(from.currentOrderId!)))
            .write(OrdersCompanion(tableLabel: Value(to.label)));
        await (db.update(db.allOrdersTable)
              ..where((o) => o.orderId.equals(from.currentOrderId!)))
            .write(AllOrdersTableCompanion(tableOrCustomer: Value(to.label)));
      }
    });
  }

  // ---------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------

  static OpsKotStatus _kotStatus(String s) => OpsKotStatus.values
      .firstWhere((x) => x.name == s, orElse: () => OpsKotStatus.newTicket);

  OpsOrder _order(OrderRow o, List<OrderLineRow> lines,
      {PaymentRow? payment,
      List<KitchenTicketRow> kots = const [],
      bool syncNeedsReview = false}) {
    final notes = parseOrderNotes(o.notes);
    final sortedKots = [...kots]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return OpsOrder(
      id: o.clientOrderId,
      channel: switch (o.channel) {
        'delivery' => OpsChannel.delivery,
        'takeaway' => OpsChannel.takeaway,
        'dineIn' => OpsChannel.dineIn,
        _ =>
          o.orderType == 'takeaway' ? OpsChannel.takeaway : OpsChannel.dineIn,
      },
      status: OpsOrderStatus.values.firstWhere((s) => s.name == o.opsStatus,
          orElse: () => OpsOrderStatus.open),
      createdAt: o.createdAt,
      tableLabel: o.tableLabel,
      guests: o.guests,
      serverName: o.serverName,
      source: o.source,
      notes: notes.plain,
      auditLog: notes.entries,
      discountPct: o.discountPct,
      taxPct: o.taxPct,
      billNo: o.billNo,
      paymentMethod: o.paymentMethod,
      settledAt: o.settledAt,
      customerName: o.customerName,
      displayNo: o.displayNo,
      payment: payment == null
          ? null
          : OpsPaymentRecord(
              paymentId: payment.paymentId,
              method: payment.method,
              amountMinor: payment.amountMinor,
              receivedMinor: payment.receivedMinor,
              recordedAt: payment.recordedAt),
      kotStatuses: [for (final k in sortedKots) _kotStatus(k.status)],
      syncStatus: o.status,
      syncNeedsReview: syncNeedsReview || o.status == 'needsReview',
      lines: [
        for (final l in lines)
          OpsOrderLine(
              itemId: l.itemId,
              name: l.name,
              unitMinor: l.unitMinor,
              quantity: l.quantity,
              station: l.station,
              isVeg: l.isVeg,
              done: l.kitchenDone),
      ],
    );
  }

  static Map<String, List<T>> _byOrder<T>(
      Iterable<T> rows, String Function(T) key) {
    final out = <String, List<T>>{};
    for (final r in rows) {
      out.putIfAbsent(key(r), () => []).add(r);
    }
    return out;
  }

  /// Orders whose last upload the backend refused (conflict / rejected).
  Future<Set<String>> _ordersNeedingReview() async {
    final rows = await (db.select(db.syncRowStates)
          ..where((s) =>
              s.localTable.equals('orders') &
              s.status.isIn(['conflict', 'rejected'])))
        .get();
    return {for (final r in rows) r.rowKey};
  }

  Future<List<OpsOrder>> getOrders({bool openOnly = false}) async {
    final q = db.select(db.orders)
      ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]);
    if (openOnly) {
      q.where((o) => o.opsStatus.isIn(['open', 'billed']));
    }
    final orders = await q.get();
    final lines =
        _byOrder(await db.select(db.orderLines).get(), (l) => l.clientOrderId);
    final kots = _byOrder(
        await db.select(db.kitchenTickets).get(), (k) => k.clientOrderId);
    final pays = {
      for (final p in await db.select(db.payments).get()) p.clientOrderId: p
    };
    final review = await _ordersNeedingReview();
    return [
      for (final o in orders)
        _order(o, lines[o.clientOrderId] ?? const [],
            payment: pays[o.clientOrderId],
            kots: kots[o.clientOrderId] ?? const [],
            syncNeedsReview: review.contains(o.clientOrderId)),
    ];
  }

  Stream<List<OpsOrder>> watchOrders({bool openOnly = false}) => _watch({
        db.orders,
        db.orderLines,
        db.payments,
        db.kitchenTickets,
        db.syncRowStates,
      }, () => getOrders(openOnly: openOnly));

  Future<OpsOrder?> getOrder(String id) async {
    final o = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(id)))
        .getSingleOrNull();
    if (o == null) return null;
    final lines = await (db.select(db.orderLines)
          ..where((t) => t.clientOrderId.equals(id)))
        .get();
    final kots = await (db.select(db.kitchenTickets)
          ..where((t) => t.clientOrderId.equals(id)))
        .get();
    final pay = await (db.select(db.payments)
          ..where((t) => t.clientOrderId.equals(id)))
        .getSingleOrNull();
    final review = await _ordersNeedingReview();
    return _order(o, lines,
        payment: pay, kots: kots, syncNeedsReview: review.contains(id));
  }

  Stream<OpsOrder?> watchOrder(String id) => _watch(
      {db.orders, db.orderLines, db.payments, db.kitchenTickets},
      () => getOrder(id));

  /// Open orders saved without a KOT ("Save & Hold"), oldest first.
  Stream<List<OpsOrder>> watchHeldOrders() =>
      watchOrders(openOnly: true).map((all) => [
            for (final o in all.reversed)
              if (o.isHeld) o
          ]);

  /// This device's tag in the ids it creates: the first five characters
  /// of its device id (app_metadata 'device_id', the id sync uses too).
  /// The server keys a device's records by (branch, id), so two devices of
  /// one branch — a till and the owner's laptop — must never make the same
  /// id, even when both are offline.
  Future<String> _deviceTag() => _tag ??= () async {
        final row = await (db.select(db.appMetadata)
              ..where((m) => m.key.equals('device_id')))
            .getSingleOrNull();
        var id = row?.value;
        if (id == null) {
          id = const Uuid().v4();
          await db.into(db.appMetadata).insertOnConflictUpdate(
              AppMetadataCompanion.insert(key: 'device_id', value: id));
        }
        return id.replaceAll('-', '').substring(0, 5).toUpperCase();
      }();
  Future<String>? _tag;

  /// The next id of this device's sequence (`PREFIX-TAG-N`), counting
  /// only this device's own ids (numbers start after [start]).
  Future<String> _nextId(String prefix, Iterable<String> ids, int start) async {
    final tag = await _deviceTag();
    final own = RegExp('^${RegExp.escape(prefix)}-$tag-(\\d+)\$');
    var max = start;
    for (final id in ids) {
      final m = own.firstMatch(id);
      final n = m == null ? 0 : int.parse(m.group(1)!);
      if (n > max) max = n;
    }
    return '$prefix-$tag-${max + 1}';
  }

  /// The next order key of this device's sequence (`ORD-TAG-9981`, …).
  /// People see it (via [OpsOrder.number]) only until sync gives the order
  /// its server number ("ORD-248").
  Future<String> _nextOrderId() async => _nextId(
      'ORD',
      [for (final r in await db.select(db.orders).get()) r.clientOrderId],
      9980);

  // ---- audit ----------------------------------------------------------

  /// Appends one correction line to the order's notes (see
  /// domain/order_audit.dart). Must run inside the caller's transaction.
  Future<void> _audit(String orderId, String text, {String? by}) async {
    final row = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    if (row == null) throw StateError(_orderNotFound);
    await (db.update(db.orders)..where((t) => t.clientOrderId.equals(orderId)))
        .write(OrdersCompanion(
            notes: Value(appendAuditLine(
                row.notes, _now(), (by ?? actorName).trim(), text))));
  }

  static String _money(int minor) {
    final rupees = minor ~/ 100;
    final paise = (minor % 100).abs();
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }

  /// Creates an order in the POS tables. For dine-in pass [tableId]; the
  /// table becomes occupied and points at the order. If the table already
  /// has an open order the lines are added to it instead. With
  /// [sendToKitchen] false the order is saved without a KOT (held) and can
  /// be resumed and sent later ([sendKot]). Returns the order id.
  Future<String> placeOrder({
    required OpsChannel channel,
    required List<OpsOrderLine> lines,
    String? tableId,
    int? guests,
    String serverName = '',
    String source = 'POS',
    String notes = '',
    String customerName = '',
    bool sendToKitchen = true,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Add at least one item.');
    if (lines.any((l) => l.quantity <= 0)) {
      throw ArgumentError('Quantities must be at least 1.');
    }
    return db.transaction(() async {
      OpsTable? table;
      if (channel == OpsChannel.dineIn) {
        if (tableId == null) throw ArgumentError('Pick a table for dine-in.');
        table = await getTable(tableId);
        if (table == null) throw StateError(_tableNotFound);
        if (await _isActiveOrder(table.currentOrderId)) {
          await addLines(table.currentOrderId!, lines,
              sendToKitchen: sendToKitchen, notes: notes);
          return table.currentOrderId!;
        }
      }
      final id = await _nextOrderId();
      await db.into(db.orders).insert(OrdersCompanion.insert(
            clientOrderId: id,
            locationId: locationId,
            currencyCode: 'INR',
            status: 'pendingUpload',
            orderType: channel == OpsChannel.dineIn ? 'dineIn' : 'takeaway',
            tableLabel: Value(table?.label),
            createdAt: Value(_now()),
            channel: Value(channel.name),
            source: Value(source),
            guests: Value(guests ?? table?.guests),
            // Who took the order: the given server, else whoever is signed in.
            serverName: Value(serverName.isNotEmpty ? serverName : actorName),
            notes: Value(notes),
            customerName: Value(customerName.trim()),
          ));
      await _insertLines(id, lines);
      // Same sync intent the POS writes for its own orders.
      await db.into(db.pendingUploadIntents).insert(
          PendingUploadIntentsCompanion.insert(
              intentId: '$id:create-order',
              clientOrderId: id,
              operation: 'create-order',
              payloadHash: '$id:${lines.length}'),
          mode: InsertMode.insertOrIgnore);
      await db.into(db.allOrdersTable).insertOnConflictUpdate(
          AllOrdersTableCompanion.insert(
              orderId: id,
              type: channel.label,
              source: source,
              tableOrCustomer: table?.label ??
                  (customerName.trim().isEmpty
                      ? channel.label
                      : customerName.trim()),
              itemsLabel: _itemsLabel(lines),
              amountMinor: lines.fold(0, (s, l) => s + l.totalMinor),
              status: sendToKitchen ? 'New' : 'Held',
              createdAt: Value(_now())));
      if (table != null) {
        await _occupyTable(table, id, guests: guests, serverName: serverName);
      }
      if (sendToKitchen) await _createKot(id, notes: notes);
      return id;
    });
  }

  Future<void> _occupyTable(OpsTable table, String orderId,
      {int? guests, String serverName = ''}) async {
    await (db.update(db.restaurantTables)..where((r) => r.id.equals(table.id)))
        .write(RestaurantTablesCompanion(
      status: const Value('occupied'),
      currentOrderId: Value(orderId),
      guestCount: Value(guests ?? table.guests ?? 1),
      seatedAt: Value(table.seatedAt ?? _now()),
      paymentPending: const Value(false),
      reservedByName: const Value(null),
      reservedAt: const Value(null),
      serverName: serverName.isEmpty ? const Value.absent() : Value(serverName),
    ));
  }

  static String _itemsLabel(List<OpsOrderLine> lines) =>
      lines.map((l) => '${l.quantity}x ${l.name}').join(', ');

  Future<void> _insertLines(String orderId, List<OpsOrderLine> lines) async {
    for (final l in lines) {
      final existing = await (db.select(db.orderLines)
            ..where((t) =>
                t.clientOrderId.equals(orderId) & t.itemId.equals(l.itemId)))
          .getSingleOrNull();
      if (existing != null) {
        await (db.update(db.orderLines)
              ..where((t) =>
                  t.clientOrderId.equals(orderId) & t.itemId.equals(l.itemId)))
            .write(OrderLinesCompanion(
                quantity: Value(existing.quantity + l.quantity),
                kitchenDone: const Value(false)));
      } else {
        await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            clientOrderId: orderId,
            itemId: l.itemId,
            name: l.name,
            unitMinor: l.unitMinor,
            quantity: l.quantity,
            station: Value(l.station),
            isVeg: Value(l.isVeg)));
      }
    }
  }

  Future<void> _refreshAllOrdersRow(String orderId) =>
      upsertAllOrdersRow(orderId);

  /// Creates or refreshes the All Orders row of [orderId] from the order
  /// and its lines — used after every change and after orders arrive from
  /// the backend sync. (all_orders_table is a device-only summary; the
  /// All Orders screen reads the orders themselves.)
  Future<void> upsertAllOrdersRow(String orderId) async {
    final o = await getOrder(orderId);
    if (o == null) return;
    final status = switch (o.status) {
      OpsOrderStatus.settled => 'Completed',
      OpsOrderStatus.cancelled => 'Cancelled',
      OpsOrderStatus.billed when o.payment != null => 'Pending verification',
      OpsOrderStatus.billed => 'Billed',
      _ => switch (o.kitchenState) {
          OpsKitchenState.notSent => 'Held',
          OpsKitchenState.queued => 'New',
          OpsKitchenState.preparing => 'Preparing',
          OpsKitchenState.ready => 'Ready',
          OpsKitchenState.served => 'Served',
        },
    };
    await db.into(db.allOrdersTable).insertOnConflictUpdate(
        AllOrdersTableCompanion.insert(
            orderId: orderId,
            type: o.channel.label,
            source: o.source,
            tableOrCustomer: o.tableLabel ??
                (o.customerName.isEmpty ? o.channel.label : o.customerName),
            itemsLabel: _itemsLabel(o.lines),
            amountMinor: o.grandTotalMinor,
            status: status,
            createdAt: Value(o.createdAt)));
  }

  Future<OrderRow> _requireOrderRow(String orderId) async {
    final row = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    if (row == null) throw StateError(_orderNotFound);
    return row;
  }

  /// Adds items to an open order. With [sendToKitchen] the new items reach
  /// the kitchen: a held order gets its first KOT; an order whose tickets
  /// are all ready / served gets a follow-up KOT listing only the new
  /// items; an order with a ticket still being prepared has the items
  /// added to that ticket (its note says what was added and when).
  Future<void> addLines(String orderId, List<OpsOrderLine> lines,
      {bool sendToKitchen = true, String notes = ''}) async {
    if (lines.isEmpty) throw ArgumentError('Add at least one item.');
    if (lines.any((l) => l.quantity <= 0)) {
      throw ArgumentError('Quantities must be at least 1.');
    }
    await db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status != OpsOrderStatus.open) {
        throw StateError('${o.number} is ${o.status.label.toLowerCase()}; '
            'it cannot take new items.');
      }
      if (!sendToKitchen && o.sentToKitchen) {
        throw StateError('${o.number} is already in the kitchen — send the '
            'new items with a KOT instead of holding them.');
      }
      await _insertLines(orderId, lines);
      if (sendToKitchen) await _sendToKitchen(o, lines, notes: notes);
      await _refreshAllOrdersRow(orderId);
    });
  }

  Future<void> _sendToKitchen(OpsOrder o, List<OpsOrderLine> added,
      {String notes = ''}) async {
    final kots = await (db.select(db.kitchenTickets)
          ..where((t) => t.clientOrderId.equals(o.id)))
        .get();
    if (kots.isEmpty) {
      await _createKot(o.id, notes: notes);
      return;
    }
    final open = kots
        .where((t) => t.status == 'newTicket' || t.status == 'preparing')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final what = added.map((l) => '${l.quantity}× ${l.name}').join(' · ');
    if (open.isEmpty) {
      await _createKot(o.id,
          notes: ['Additional items: $what', if (notes.isNotEmpty) notes]
              .join('\n'));
    } else {
      final t = open.first;
      final clock = formatClock(_now());
      await (db.update(db.kitchenTickets)
            ..where((k) => k.ticketId.equals(t.ticketId)))
          .write(KitchenTicketsCompanion(
              notes: Value([
        if (t.notes.trim().isNotEmpty) t.notes.trim(),
        'Added $clock: $what',
        if (notes.isNotEmpty) notes,
      ].join('\n'))));
    }
  }

  /// Sends a held order (no KOT yet) to the kitchen and, for dine-in,
  /// occupies its table. Returns the new ticket id.
  Future<String> sendKot(String orderId, {String notes = ''}) async {
    return db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status != OpsOrderStatus.open) {
        throw StateError('${o.number} is ${o.status.label.toLowerCase()}; '
            'it cannot be sent to the kitchen.');
      }
      if (o.lines.isEmpty) throw StateError('The order has no items.');
      if (o.sentToKitchen) {
        throw StateError('${o.number} is already in the kitchen — add items '
            'to send a new KOT.');
      }
      if (o.channel == OpsChannel.dineIn && o.tableLabel != null) {
        final table = (await getTables())
            .where((t) => t.label == o.tableLabel)
            .firstOrNull;
        if (table != null && table.currentOrderId != orderId) {
          if (await _isActiveOrder(table.currentOrderId)) {
            throw StateError('${table.label} now has order '
                '${await _orderNo(table.currentOrderId!)}; move ${o.number} '
                'to another table.');
          }
          await _occupyTable(table, orderId, guests: o.guests);
        }
      }
      final ticket = await _createKot(orderId, notes: notes);
      await _refreshAllOrdersRow(orderId);
      return ticket;
    });
  }

  /// Sets a line's quantity on an open order (0 removes the line).
  /// Reducing or removing an item after it was sent to the kitchen is a
  /// void: it needs a [reason] and is recorded in the order's audit trail.
  /// Raising a quantity sends the extra units to the kitchen when the
  /// order is already there.
  Future<void> setLineQuantity(String orderId, String itemId, int qty,
      {String reason = '', String? by}) async {
    await db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null || o.status != OpsOrderStatus.open) {
        throw StateError('Only open orders can be changed.');
      }
      final line = o.lines.where((l) => l.itemId == itemId).firstOrNull;
      if (line == null) {
        throw StateError('That item is no longer on ${o.number}.');
      }
      if (qty == line.quantity) return;
      if (qty > line.quantity) {
        final extra = line.copyWith(quantity: qty - line.quantity);
        await _insertLines(orderId, [extra]);
        if (o.sentToKitchen) await _sendToKitchen(o, [extra]);
        await _refreshAllOrdersRow(orderId);
        return;
      }
      if (o.sentToKitchen) {
        final why = requireReason(
            reason,
            qty <= 0
                ? 'remove an item already sent to the kitchen'
                : 'reduce an item already sent to the kitchen');
        await _audit(
            orderId,
            qty <= 0
                ? 'Voided ${line.name} (×${line.quantity}): $why'
                : 'Reduced ${line.name} ${line.quantity} → $qty: $why',
            by: by);
      }
      if (qty <= 0) {
        await (db.delete(db.orderLines)
              ..where((t) =>
                  t.clientOrderId.equals(orderId) & t.itemId.equals(itemId)))
            .go();
      } else {
        await (db.update(db.orderLines)
              ..where((t) =>
                  t.clientOrderId.equals(orderId) & t.itemId.equals(itemId)))
            .write(OrderLinesCompanion(quantity: Value(qty)));
      }
      await _refreshAllOrdersRow(orderId);
    });
  }

  Future<void> setCustomerName(String orderId, String name) async {
    await (db.update(db.orders)..where((t) => t.clientOrderId.equals(orderId)))
        .write(OrdersCompanion(customerName: Value(name.trim())));
  }

  /// Sets the bill discount. Refused on settled / cancelled orders and once
  /// a payment is recorded (the amount paid would no longer match). Every
  /// change is recorded in the audit trail with its [reason]; the screens
  /// always ask for one. (The store accepts an empty reason only because
  /// the first-launch demo seeder applies a discount without one — it is
  /// then recorded as "no reason given".)
  Future<void> setDiscount(String orderId, double pct,
      {String reason = '', String? by}) async {
    if (pct.isNaN || pct < 0 || pct > 100) {
      throw ArgumentError('Discount must be 0–100%.');
    }
    await db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status == OpsOrderStatus.settled ||
          o.status == OpsOrderStatus.cancelled) {
        throw StateError('${o.number} is ${o.status.label.toLowerCase()}; '
            'its discount cannot change.');
      }
      if (o.payment != null) {
        throw StateError('A payment is already recorded for ${o.number}; '
            'the discount cannot change.');
      }
      if (o.discountPct == pct) return;
      await (db.update(db.orders)
            ..where((t) => t.clientOrderId.equals(orderId)))
          .write(OrdersCompanion(discountPct: Value(pct)));
      final why = reason.trim().isEmpty ? 'no reason given' : reason.trim();
      await _audit(orderId,
          'Discount ${_pctText(o.discountPct)}% → ${_pctText(pct)}%: $why',
          by: by);
      await _refreshAllOrdersRow(orderId);
    });
  }

  static String _pctText(double p) =>
      p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);

  /// "Generate Bill": assigns a bill number and flags the table as
  /// payment pending. Returns the bill number.
  Future<int> generateBill(String orderId) async {
    return db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status == OpsOrderStatus.settled ||
          o.status == OpsOrderStatus.cancelled) {
        throw StateError(
            '${o.number} is already ${o.status.label.toLowerCase()}.');
      }
      if (o.lines.isEmpty) throw StateError('The order has no items.');
      final billNo = o.billNo ?? await _nextBillNo();
      await (db.update(db.orders)
            ..where((t) => t.clientOrderId.equals(orderId)))
          .write(OrdersCompanion(
              billNo: Value(billNo), opsStatus: const Value('billed')));
      // Only the table still holding this order (a table released after a
      // pending-verification payment may already have new guests).
      await (db.update(db.restaurantTables)
            ..where((r) => r.currentOrderId.equals(orderId)))
          .write(const RestaurantTablesCompanion(paymentPending: Value(true)));
      await _refreshAllOrdersRow(orderId);
      return billNo;
    });
  }

  Future<int> _nextBillNo() async {
    final rows = await db.select(db.orders).get();
    var max = 4800;
    for (final r in rows) {
      if ((r.billNo ?? 0) > max) max = r.billNo!;
    }
    return max + 1;
  }

  Future<void> _releaseTable(String orderId) async {
    await (db.update(db.restaurantTables)
          ..where((r) => r.currentOrderId.equals(orderId)))
        .write(const RestaurantTablesCompanion(
      status: Value('cleaning'),
      currentOrderId: Value(null),
      paymentPending: Value(false),
      guestCount: Value(null),
      seatedAt: Value(null),
    ));
  }

  /// Records the payment for [orderId] (POS payments table) and returns
  /// where the order's money now stands:
  ///  * cash → [OrderPaymentState.paid]: the order is settled;
  ///  * card / UPI / split with card or UPI →
  ///    [OrderPaymentState.pendingVerification]: the payment row is kept,
  ///    the order stays `billed` (awaiting payment) until [verifyPayment].
  /// In both cases the table is released for cleaning — the guests have
  /// paid and left; an unverified digital payment must not block the
  /// floor. A payment is never overwritten: if one is already recorded
  /// the call is refused.
  Future<OrderPaymentState> settleOrder(String orderId, String method,
      {int? receivedMinor}) async {
    final m = method.trim().toLowerCase();
    if (m.isEmpty) throw ArgumentError('Pick a payment method.');
    return db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status == OpsOrderStatus.settled) {
        throw StateError('${o.number} is already settled.');
      }
      if (o.status == OpsOrderStatus.cancelled) {
        throw StateError('${o.number} was cancelled; it takes no payment.');
      }
      final existing = o.payment;
      if (existing != null) {
        throw StateError('A payment is already recorded for ${o.number} '
            '(${paymentMethodLabel(existing.method)} '
            '${_money(existing.amountMinor)}'
            '${existing.needsVerification ? ', pending verification' : ''}). '
            'Payments are never overwritten — verify or review it instead.');
      }
      if (o.lines.isEmpty) throw StateError('The order has no items.');
      final total = o.grandTotalMinor;
      if (receivedMinor != null && receivedMinor < total) {
        throw ArgumentError('Received amount is less than the bill total.');
      }
      final billNo = o.billNo ?? await _nextBillNo();
      await db.into(db.payments).insert(PaymentsCompanion.insert(
          paymentId: 'PAY-$orderId',
          clientOrderId: orderId,
          method: m,
          amountMinor: total,
          receivedMinor: receivedMinor ?? total,
          recordedAt: Value(_now())));
      final pending = tenderNeedsVerification(m);
      await (db.update(db.orders)
            ..where((t) => t.clientOrderId.equals(orderId)))
          .write(OrdersCompanion(
              opsStatus: Value(pending ? 'billed' : 'settled'),
              billNo: Value(billNo),
              paymentMethod: Value(m),
              settledAt: pending ? const Value.absent() : Value(_now())));
      await _releaseTable(orderId);
      await _refreshAllOrdersRow(orderId);
      return pending
          ? OrderPaymentState.pendingVerification
          : OrderPaymentState.paid;
    });
  }

  /// Confirms a card / UPI / split payment that was recorded pending
  /// verification: the order is settled (settled_at stamped), its table
  /// (if still held) freed, and the verification recorded in the audit
  /// trail. The payment row itself is not changed. Only offer this to
  /// users allowed to verify payments (the screens' `canVerifyPayments`).
  Future<void> verifyPayment(String orderId,
      {String note = '', String? by}) async {
    await db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      final p = o.payment;
      if (o.status == OpsOrderStatus.settled) {
        throw StateError('${o.number} is already settled.');
      }
      if (o.status == OpsOrderStatus.cancelled) {
        throw StateError('${o.number} was cancelled.');
      }
      if (p == null) {
        throw StateError('No payment is recorded for ${o.number} yet.');
      }
      if (!p.needsVerification) {
        throw StateError('${o.number} was paid in cash — nothing to verify.');
      }
      await (db.update(db.orders)
            ..where((t) => t.clientOrderId.equals(orderId)))
          .write(OrdersCompanion(
              opsStatus: const Value('settled'), settledAt: Value(_now())));
      final n = note.trim();
      await _audit(
          orderId,
          'Payment verified: ${paymentMethodLabel(p.method)} '
          '${_money(p.amountMinor)}${n.isEmpty ? '' : ' — $n'}',
          by: by);
      await _releaseTable(orderId);
      await _refreshAllOrdersRow(orderId);
    });
  }

  /// Cancels an open or billed order. A [reason] is required and recorded
  /// in the audit trail. Its KOTs keep their status (the backend's KOT
  /// statuses have no "cancelled"); they leave the kitchen queue and the
  /// kitchen screens show them as "Order cancelled". Refused once a
  /// payment is recorded — that needs a refund, not a cancel.
  Future<void> cancelOrder(String orderId,
      {required String reason, String? by}) async {
    final why = requireReason(reason, 'cancel the order');
    await db.transaction(() async {
      final o = await getOrder(orderId);
      if (o == null) throw StateError(_orderNotFound);
      if (o.status == OpsOrderStatus.settled) {
        throw StateError('A settled order cannot be cancelled.');
      }
      if (o.status == OpsOrderStatus.cancelled) {
        throw StateError('${o.number} is already cancelled.');
      }
      if (o.payment != null) {
        throw StateError('A payment is recorded for ${o.number} — it cannot '
            'be cancelled here; record a refund in the back office.');
      }
      await (db.update(db.orders)
            ..where((t) => t.clientOrderId.equals(orderId)))
          .write(const OrdersCompanion(opsStatus: Value('cancelled')));
      await _audit(orderId, 'Cancelled: $why', by: by);
      await _releaseTable(orderId);
      await _refreshAllOrdersRow(orderId);
    });
  }

  /// Records that the bill was shown / reprinted (on-screen preview — no
  /// printer is connected) in the audit trail.
  Future<void> recordReprint(String orderId, {String? by}) async {
    await db.transaction(() async {
      await _requireOrderRow(orderId);
      await _audit(
          orderId, 'Bill reprint requested (on-screen; printer not connected)',
          by: by);
    });
  }

  // ---------------------------------------------------------------------
  // Kitchen (KOT / KDS) — POS kitchen_tickets
  // ---------------------------------------------------------------------

  Future<String> _createKot(String orderId, {String notes = ''}) async {
    final id = await _nextId(
        'KOT',
        [for (final t in await db.select(db.kitchenTickets).get()) t.ticketId],
        4080);
    await db.into(db.kitchenTickets).insert(KitchenTicketsCompanion.insert(
        ticketId: id,
        clientOrderId: orderId,
        status: 'newTicket',
        createdAt: Value(_now()),
        notes: Value(notes)));
    return id;
  }

  OpsKot _kot(KitchenTicketRow t, OpsOrder order) => OpsKot(
        ticketId: t.ticketId,
        order: order,
        status: _kotStatus(t.status),
        createdAt: t.createdAt,
        notes: t.notes,
        urgent: t.urgent,
        kotNo: t.kotNo,
      );

  /// The kitchen queue: open tickets plus everything served today.
  /// Tickets of cancelled orders are not in the queue — see
  /// [getCancelledKots].
  Future<List<OpsKot>> getKots() async {
    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final tickets = await (db.select(db.kitchenTickets)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final orders = {for (final o in await getOrders()) o.id: o};
    return [
      for (final t in tickets)
        if (orders[t.clientOrderId] case final o?
            when o.status != OpsOrderStatus.cancelled &&
                (t.status != 'completed' ||
                    (t.completedAt ?? t.createdAt).isAfter(dayStart)))
          _kot(t, o),
    ];
  }

  Stream<List<OpsKot>> watchKots() => _watch(
      {db.kitchenTickets, db.orders, db.orderLines, db.payments}, getKots);

  /// Tickets that were still in the kitchen (not served) when their order
  /// was cancelled, sent today — shown as "Order cancelled" so the
  /// kitchen stops preparing them.
  Future<List<OpsKot>> getCancelledKots() async {
    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final tickets = await (db.select(db.kitchenTickets)
          ..where((t) =>
              t.status.isNotIn(['completed']) &
              t.createdAt.isBiggerOrEqualValue(dayStart))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (tickets.isEmpty) return const [];
    final out = <OpsKot>[];
    for (final t in tickets) {
      final o = await getOrder(t.clientOrderId);
      if (o != null && o.status == OpsOrderStatus.cancelled) {
        out.add(_kot(t, o));
      }
    }
    return out;
  }

  Stream<List<OpsKot>> watchCancelledKots() =>
      _watch({db.kitchenTickets, db.orders}, getCancelledKots);

  Future<void> _refuseIfCancelled(String orderId, String what) async {
    final o = await (db.select(db.orders)
          ..where((t) => t.clientOrderId.equals(orderId)))
        .getSingleOrNull();
    if (o != null && o.opsStatus == 'cancelled') {
      throw StateError('${orderNumberLabel(orderId, o.displayNo)} was '
          'cancelled — $what is void.');
    }
  }

  /// New → Preparing → Ready → Served. Marking Preparing→Ready also ticks
  /// every item done; Served stamps completedAt. Forward only.
  Future<OpsKotStatus> advanceKot(String ticketId) async {
    return db.transaction(() async {
      final t = await (db.select(db.kitchenTickets)
            ..where((k) => k.ticketId.equals(ticketId)))
          .getSingleOrNull();
      if (t == null) {
        throw StateError('This kitchen ticket was not found — it may have '
            'been removed.');
      }
      final kot = kotNumberLabel(t.ticketId, t.kotNo);
      await _refuseIfCancelled(t.clientOrderId, kot);
      final next = switch (t.status) {
        'newTicket' => OpsKotStatus.preparing,
        'preparing' => OpsKotStatus.ready,
        'ready' => OpsKotStatus.completed,
        _ => throw StateError('$kot is already served.'),
      };
      await (db.update(db.kitchenTickets)
            ..where((k) => k.ticketId.equals(ticketId)))
          .write(KitchenTicketsCompanion(
        status: Value(next.name),
        completedAt: next == OpsKotStatus.completed
            ? Value(_now())
            : const Value.absent(),
      ));
      if (next == OpsKotStatus.ready) {
        await (db.update(db.orderLines)
              ..where((l) => l.clientOrderId.equals(t.clientOrderId)))
            .write(const OrderLinesCompanion(kitchenDone: Value(true)));
      }
      await _refreshAllOrdersRow(t.clientOrderId);
      return next;
    });
  }

  /// Ticks one item on the kitchen display. A new ticket moves to
  /// Preparing on its first ticked item.
  Future<void> setLineDone(String orderId, String itemId, bool done) async {
    await db.transaction(() async {
      await _refuseIfCancelled(orderId, 'its KOT');
      await (db.update(db.orderLines)
            ..where((l) =>
                l.clientOrderId.equals(orderId) & l.itemId.equals(itemId)))
          .write(OrderLinesCompanion(kitchenDone: Value(done)));
      if (done) {
        await (db.update(db.kitchenTickets)
              ..where((k) =>
                  k.clientOrderId.equals(orderId) &
                  k.status.equals('newTicket')))
            .write(const KitchenTicketsCompanion(status: Value('preparing')));
      }
    });
  }

  Future<void> setKotUrgent(String ticketId, bool urgent) async {
    await (db.update(db.kitchenTickets)
          ..where((k) => k.ticketId.equals(ticketId)))
        .write(KitchenTicketsCompanion(urgent: Value(urgent)));
  }

  // ---------------------------------------------------------------------
  // Deliveries
  // ---------------------------------------------------------------------

  OpsDelivery _delivery(DeliveryEntity d) => OpsDelivery(
        id: d.id,
        orderId: d.orderId,
        merchant: d.merchant,
        status: DeliveryStatus.values.firstWhere((s) => s.name == d.status,
            orElse: () => DeliveryStatus.unassigned),
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
        riderName: d.riderName,
        etaMinutes: d.etaMinutes,
        distanceKm: d.distanceKm,
        customerName: d.customerName,
        address: d.address,
        promisedAt: d.promisedAt,
      );

  Stream<List<OpsDelivery>> watchDeliveries() => (db.select(db.deliveriesTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(_delivery).toList());

  Future<List<OpsDelivery>> getDeliveries() async =>
      (await db.select(db.deliveriesTable).get()).map(_delivery).toList();

  Future<String> nextDeliveryId() async => _nextId('DLV',
      [for (final d in await db.select(db.deliveriesTable).get()) d.id], 1000);

  Future<void> upsertDelivery(OpsDelivery d) async {
    await db.into(db.deliveriesTable).insertOnConflictUpdate(
        DeliveriesTableCompanion.insert(
            id: d.id,
            orderId: d.orderId,
            merchant: d.merchant,
            riderName: Value(d.riderName),
            status: d.status.name,
            etaMinutes: Value(d.etaMinutes),
            distanceKm: Value(d.distanceKm),
            customerName: Value(d.customerName),
            address: Value(d.address),
            promisedAt: Value(d.promisedAt),
            createdAt: d.createdAt,
            updatedAt: _now()));
  }

  Future<void> assignRider(String deliveryId, String rider,
      {int? etaMinutes}) async {
    if (rider.trim().isEmpty) throw ArgumentError('Enter a rider name.');
    await (db.update(db.deliveriesTable)..where((t) => t.id.equals(deliveryId)))
        .write(DeliveriesTableCompanion(
      riderName: Value(rider.trim()),
      status: Value(DeliveryStatus.assigned.name),
      etaMinutes: etaMinutes == null ? const Value.absent() : Value(etaMinutes),
      updatedAt: Value(_now()),
    ));
  }

  /// Allowed moves: assigned → pickedUp → inTransit → delivered, and any
  /// open delivery → failed.
  Future<void> setDeliveryStatus(String deliveryId, DeliveryStatus to) async {
    final row = await (db.select(db.deliveriesTable)
          ..where((t) => t.id.equals(deliveryId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('This delivery was not found — it may have been '
          'removed.');
    }
    final d = _delivery(row);
    if (!d.isOpen) {
      throw StateError('The delivery for ${await _orderNo(d.orderId)} is '
          'already ${d.status.label.toLowerCase()}.');
    }
    if (to != DeliveryStatus.failed &&
        to != DeliveryStatus.unassigned &&
        d.riderName == null) {
      throw StateError('Assign a rider first.');
    }
    await (db.update(db.deliveriesTable)..where((t) => t.id.equals(deliveryId)))
        .write(DeliveriesTableCompanion(
      status: Value(to.name),
      etaMinutes: to == DeliveryStatus.delivered || to == DeliveryStatus.failed
          ? const Value(null)
          : const Value.absent(),
      updatedAt: Value(_now()),
    ));
  }

  // ---------------------------------------------------------------------
  // Reservations
  // ---------------------------------------------------------------------

  OpsReservation _reservation(ReservationEntity r) => OpsReservation(
        id: r.id,
        guestName: r.guestName,
        phone: r.phone,
        email: r.email,
        guests: r.guests,
        dateTime: r.scheduledAt,
        status: ReservationStatus.values.firstWhere((s) => s.name == r.status,
            orElse: () => ReservationStatus.pending),
        tableId: r.tableId,
        notes: r.notes,
      );

  Stream<List<OpsReservation>> watchReservations() =>
      (db.select(db.reservationsTable)
            ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
          .watch()
          .map((rows) => rows.map(_reservation).toList());

  Future<List<OpsReservation>> getReservations() async =>
      (await db.select(db.reservationsTable).get()).map(_reservation).toList();

  Future<void> upsertReservation(OpsReservation r) async {
    if (r.guestName.trim().isEmpty) {
      throw ArgumentError('Enter the guest name.');
    }
    if (r.guests < 1) throw ArgumentError('Party size must be at least 1.');
    if (r.tableId != null) {
      final t = await getTable(r.tableId!);
      if (t != null && t.seats < r.guests) {
        throw StateError(
            '${t.label} seats ${t.seats}; the party is ${r.guests}.');
      }
    }
    await db.into(db.reservationsTable).insertOnConflictUpdate(
        ReservationsTableCompanion.insert(
            id: r.id,
            guestName: r.guestName.trim(),
            phone: r.phone.trim(),
            email: Value(r.email.trim()),
            guests: r.guests,
            scheduledAt: r.dateTime,
            status: r.status.name,
            tableId: Value(r.tableId),
            notes: Value(r.notes)));
  }

  Future<void> setReservationStatus(String id, ReservationStatus s) async {
    await (db.update(db.reservationsTable)..where((t) => t.id.equals(id)))
        .write(ReservationsTableCompanion(status: Value(s.name)));
  }

  static const _reservationNotFound =
      'This reservation was not found — it may have been removed.';

  Future<void> assignReservationTable(String id, String tableId) async {
    final row = await (db.select(db.reservationsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw StateError(_reservationNotFound);
    final r = _reservation(row);
    final t = await getTable(tableId);
    if (t == null) throw StateError(_tableNotFound);
    if (t.seats < r.guests) {
      throw StateError(
          '${t.label} seats ${t.seats}; the party is ${r.guests}.');
    }
    await (db.update(db.reservationsTable)..where((x) => x.id.equals(id)))
        .write(ReservationsTableCompanion(tableId: Value(tableId)));
  }

  /// Seats the party: reservation → Seated and its table → occupied.
  Future<void> seatReservation(String id) async {
    await db.transaction(() async {
      final row = await (db.select(db.reservationsTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) throw StateError(_reservationNotFound);
      final r = _reservation(row);
      if (r.tableId == null) throw StateError('Assign a table first.');
      final t = await getTable(r.tableId!);
      if (t != null && t.seats < r.guests) {
        throw StateError('${t.label} seats ${t.seats}; the party is '
            '${r.guests}. Reassign a larger table.');
      }
      await seatTable(r.tableId!, guests: r.guests);
      await setReservationStatus(id, ReservationStatus.seated);
    });
  }

  // ---------------------------------------------------------------------
  // QR ordering
  // ---------------------------------------------------------------------

  Future<List<QrTableCode>> getQrCodes() async {
    final codes = {
      for (final c in await db.select(db.qrCodesTable).get()) c.tableId: c
    };
    return [
      for (final t in await getTables())
        if (codes[t.id] != null)
          QrTableCode(
              tableId: t.id,
              tableLabel: t.label,
              enabled: codes[t.id]!.enabled,
              token: codes[t.id]!.token,
              lastScannedAt: codes[t.id]!.lastScannedAt),
    ];
  }

  Stream<List<QrTableCode>> watchQrCodes() =>
      _watch({db.qrCodesTable, db.restaurantTables}, getQrCodes);

  String _token(String tableId) =>
      '$tableId-${_now().microsecondsSinceEpoch.toRadixString(36)}';

  /// Creates a code for every table that doesn't have one yet.
  Future<int> generateQrCodes() async {
    var created = 0;
    await db.transaction(() async {
      final have = (await db.select(db.qrCodesTable).get())
          .map((c) => c.tableId)
          .toSet();
      for (final t in await getTables()) {
        if (have.contains(t.id)) continue;
        await db.into(db.qrCodesTable).insert(
            QrCodesTableCompanion.insert(tableId: t.id, token: _token(t.id)));
        created++;
      }
    });
    return created;
  }

  /// New tokens for every code — previously printed codes stop working.
  Future<void> regenerateQrCodes() async {
    await db.transaction(() async {
      for (final c in await db.select(db.qrCodesTable).get()) {
        await (db.update(db.qrCodesTable)
              ..where((t) => t.tableId.equals(c.tableId)))
            .write(QrCodesTableCompanion(token: Value(_token(c.tableId))));
      }
    });
  }

  Future<void> setQrEnabled(String tableId, bool enabled) async {
    await (db.update(db.qrCodesTable)..where((t) => t.tableId.equals(tableId)))
        .write(QrCodesTableCompanion(enabled: Value(enabled)));
  }

  QrSession _session(QrSessionEntity s) => QrSession(
        id: s.id,
        tableLabel: s.tableLabel,
        guests: s.guests,
        startedAt: s.startedAt,
        status: QrSessionStatus.values.firstWhere((x) => x.name == s.status,
            orElse: () => QrSessionStatus.browsing),
        orderId: s.orderId,
        itemCount: s.itemCount,
        totalMinor: s.totalMinor,
      );

  Stream<List<QrSession>> watchQrSessions({bool activeOnly = true}) {
    final q = db.select(db.qrSessionsTable)
      ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]);
    if (activeOnly) {
      q.where((t) => t.status.isNotIn(['closed']));
    }
    return q.watch().map((rows) => rows.map(_session).toList());
  }

  Future<List<QrSession>> getQrSessions() async =>
      (await db.select(db.qrSessionsTable).get()).map(_session).toList();

  Future<void> closeQrSession(String id) async {
    await (db.update(db.qrSessionsTable)..where((t) => t.id.equals(id))).write(
        QrSessionsTableCompanion(
            status: const Value('closed'), closedAt: Value(_now())));
  }

  // ---------------------------------------------------------------------
  // KDS settings (kept in app_metadata as JSON)
  // ---------------------------------------------------------------------

  static const _stationsKey = 'kds_kitchen_stations';
  static const _alertsKey = 'kds_alert_settings';

  Stream<String?> _watchMeta(String key) =>
      (db.select(db.appMetadata)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((r) => r?.value);

  Future<void> _putMeta(String key, String value) =>
      db.into(db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(key: key, value: value));

  Stream<List<KitchenStation>> watchKitchenStations() =>
      _watchMeta(_stationsKey).map((v) {
        if (v == null) return defaultKitchenStations;
        try {
          return [
            for (final e in jsonDecode(v) as List)
              KitchenStation.fromJson((e as Map).cast<String, dynamic>()),
          ];
        } catch (_) {
          return defaultKitchenStations;
        }
      });

  /// Station names must be unique and non-empty; at least one station.
  Future<void> saveKitchenStations(List<KitchenStation> stations) async {
    final names = stations.map((s) => s.name.trim().toLowerCase()).toList();
    if (stations.isEmpty) throw ArgumentError('Keep at least one station.');
    if (names.any((n) => n.isEmpty)) {
      throw ArgumentError('Every station needs a name.');
    }
    if (names.toSet().length != names.length) {
      throw ArgumentError('Station names must be unique.');
    }
    if (stations.any((s) => s.targetMinutes < 1)) {
      throw ArgumentError('Target time must be at least 1 minute.');
    }
    await _putMeta(
        _stationsKey, jsonEncode([for (final s in stations) s.toJson()]));
  }

  Stream<KdsAlertSettings> watchAlertSettings() =>
      _watchMeta(_alertsKey).map((v) {
        if (v == null) return const KdsAlertSettings();
        try {
          return KdsAlertSettings.fromJson(
              (jsonDecode(v) as Map).cast<String, dynamic>());
        } catch (_) {
          return const KdsAlertSettings();
        }
      });

  Future<void> saveAlertSettings(KdsAlertSettings s) =>
      _putMeta(_alertsKey, jsonEncode(s.toJson()));
}
