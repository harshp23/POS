import 'package:drift/drift.dart';

import '../domain/operations.dart';
import 'app_database.dart';
import 'drift_operations_store.dart';

/// One-time seed of the Operations data from the approved Figma screens
/// (v1/operations/*.png). Times are relative to "now" so timers look
/// live. Runs once per database (app_metadata flag) and never overwrites
/// a table, order or KOT that already exists.
class OperationsSeeder {
  static const _flag = 'operations_seed_v1';

  static Future<void> seedIfNeeded(AppDatabase db, {DateTime? now}) async {
    final done = await (db.select(db.appMetadata)
          ..where((t) => t.key.equals(_flag)))
        .getSingleOrNull();
    if (done != null) return;
    final t0 = now ?? DateTime.now();
    DateTime ago(int minutes) => t0.subtract(Duration(minutes: minutes));
    final store = DriftOperationsStore(db, clock: () => t0);

    await db.transaction(() async {
      // ---- Floor plan -------------------------------------------------
      final existing =
          (await db.select(db.restaurantTables).get()).map((r) => r.id).toSet();
      final tables = <OpsTable>[
        for (final (id, seats, shape, status, floor) in [
          ('T1', 4, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T2', 4, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T3', 2, 'round', OpsTableStatus.reserved, 'Ground Floor'),
          ('T4', 6, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T5', 4, 'round', OpsTableStatus.reserved, 'Ground Floor'),
          ('T6', 8, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T7', 4, 'square', OpsTableStatus.reserved, 'Ground Floor'),
          ('T8', 2, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T9', 2, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T10', 4, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T11', 4, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T12', 4, 'square', OpsTableStatus.available, 'Ground Floor'),
          ('T13', 2, 'square', OpsTableStatus.reserved, 'First Floor'),
          ('T14', 4, 'square', OpsTableStatus.available, 'First Floor'),
          ('T15', 6, 'square', OpsTableStatus.available, 'First Floor'),
          ('T16', 4, 'square', OpsTableStatus.available, 'First Floor'),
          ('T17', 4, 'round', OpsTableStatus.available, 'Terrace'),
          ('T18', 6, 'round', OpsTableStatus.available, 'Terrace'),
          ('C1', 6, 'square', OpsTableStatus.available, 'Private Cabanas'),
          ('C2', 8, 'square', OpsTableStatus.available, 'Private Cabanas'),
        ])
          OpsTable(
            id: id,
            label: id,
            seats: seats,
            floor: floor,
            shape: shape,
            status: status,
            reservedByName: switch (id) {
              'T3' => 'Rahul Sharma',
              'T5' => 'Priya Nair',
              'T7' => 'Amit Verma',
              'T13' => 'Kabir Singh',
              _ => null,
            },
            reservedAt: switch (id) {
              'T3' => _at(t0, 19, 30),
              'T5' => _at(t0, 20, 0),
              'T7' => _at(t0, 20, 30),
              'T13' => _at(t0, 21, 0),
              _ => null,
            },
          ),
      ];
      for (final t in tables) {
        if (!existing.contains(t.id)) await store.upsertTable(t);
      }
      // Available tables were cleaned a few minutes ago.
      await (db.update(db.restaurantTables)
            ..where((r) => r.status.equals('available')))
          .write(RestaurantTablesCompanion(lastCleanedAt: Value(ago(5))));

      // ---- Open dine-in orders (seat + order + KOT) --------------------
      Future<String?> dineIn(String table, int guests, String server,
          int seatedMinutesAgo, List<OpsOrderLine> lines,
          {String notes = '',
          String source = 'Captain',
          String customer = ''}) async {
        final t = await store.getTable(table);
        if (t == null || t.currentOrderId != null) return null;
        await (db.update(db.restaurantTables)..where((r) => r.id.equals(table)))
            .write(RestaurantTablesCompanion(
          status: const Value('occupied'),
          guestCount: Value(guests),
          serverName: Value(server),
          seatedAt: Value(ago(seatedMinutesAgo)),
        ));
        return store.placeOrder(
            channel: OpsChannel.dineIn,
            tableId: table,
            guests: guests,
            serverName: server,
            source: source,
            notes: notes,
            customerName: customer,
            lines: lines);
      }

      final t2 = await dineIn('T2', 4, 'Rahul Sharma', 45, [
        _l('Butter Chicken', 380, 1, veg: false),
        _l('Garlic Naan', 60, 3, station: 'Tandoor'),
        _l('Dal Makhani', 290, 1),
      ]);
      await dineIn(
          'T6',
          8,
          'Amit K.',
          22,
          [
            _l('Paneer Tikka', 280, 2, station: 'Tandoor'),
            _l('Butter Naan', 50, 4, station: 'Tandoor'),
          ],
          notes: 'No onions in Salad');
      await dineIn('T10', 4, 'Priya S.', 12, [
        _l('Veg Biryani', 260, 2),
        _l('Coke Can', 60, 1, station: 'Beverages'),
      ]);
      final t12 = await dineIn('T12', 4, 'Rahul Sharma', 11, [
        _l('Paneer Butter Masala', 320, 1),
        _l('Chicken Tikka', 340, 2, veg: false, station: 'Tandoor'),
        _l('Garlic Naan', 60, 4, station: 'Tandoor'),
        _l('Dal Makhani', 290, 1),
        _l('Butter Naan', 50, 3, station: 'Tandoor'),
        _l('Fresh Lime Soda', 90, 2, station: 'Beverages'),
      ]);
      await dineIn('T15', 6, 'Amit K.', 31, [
        _l('Tandoori Roti', 25, 5, station: 'Tandoor'),
        _l('Chicken Tikka Masala', 340, 1, veg: false),
      ]);
      await dineIn(
          'T1',
          4,
          'Priya S.',
          18,
          [
            _l('Kadhai Chicken', 360, 1, veg: false),
            _l('Butter Naan', 50, 4, station: 'Tandoor'),
            _l('Raita', 60, 2),
          ],
          notes: 'Make it extra spicy');
      // T4 is waiting for payment (bill generated).
      final t4 = await dineIn('T4', 6, 'Rahul Sharma', 58, [
        _l('Mutton Rogan Josh', 450, 2, veg: false),
        _l('Jeera Rice', 140, 2),
      ]);
      if (t4 != null) await store.generateBill(t4);
      if (t12 != null) await store.setDiscount(t12, 10);

      // Advance some KOTs so every kitchen column has cards.
      final kots = await store.getKots();
      String? ticketFor(String? orderId) => orderId == null
          ? null
          : kots.where((k) => k.order.id == orderId).firstOrNull?.ticketId;
      final t2Kot = ticketFor(t2);
      if (t2Kot != null) {
        await store.advanceKot(t2Kot); // preparing
        await store.setKotUrgent(t2Kot, true);
        await store.setLineDone(t2!, 'butter-chicken', true);
      }
      final t4Kot = ticketFor(t4);
      if (t4Kot != null) {
        await store.advanceKot(t4Kot);
        await store.advanceKot(t4Kot);
        await store.advanceKot(t4Kot); // served
      }

      // ---- Takeaway / delivery orders ---------------------------------
      final take1 = await store.placeOrder(
          channel: OpsChannel.takeaway,
          source: 'POS',
          notes: 'Extra spoons',
          lines: [
            _l('Veg Biryani', 260, 2),
            _l('Coke Can', 60, 1, station: 'Beverages'),
          ]);
      final k1 = (await store.getKots())
          .firstWhere((k) => k.order.id == take1)
          .ticketId;
      await store.advanceKot(k1);
      await store.advanceKot(k1); // ready
      await store.placeOrder(
          channel: OpsChannel.takeaway,
          notes: 'Cut into 8 slices',
          lines: [
            _l('Margherita Pizza', 320, 1),
            _l('Garlic Bread', 150, 1),
          ]);
      final del1 = await store.placeOrder(
          channel: OpsChannel.delivery,
          source: 'Online',
          notes: 'Send extra sauces',
          lines: [
            _l('Hakka Noodles', 220, 2),
            _l('Chilli Chicken', 280, 1, veg: false),
          ]);
      await (db.update(db.kitchenTickets)
            ..where((k) => k.clientOrderId.equals(del1)))
          .write(KitchenTicketsCompanion(createdAt: Value(ago(28))));

      // Customer names on the orders (as on the Live Orders design).
      const namesByTable = {
        'T1': 'Rohit Verma',
        'T2': 'Amit Patel',
        'T4': 'Neha Sen',
        'T6': 'Priya Nair',
        'T10': 'Meera Iyer',
        'T12': 'Sanjay Dutta',
        'T15': 'Kabir Singh',
      };
      for (final o in await store.getOrders()) {
        final name = o.tableLabel != null
            ? namesByTable[o.tableLabel]
            : o.id == take1
                ? 'Vikram Malhotra'
                : o.id == del1
                    ? 'Karan Johar'
                    : o.channel == OpsChannel.takeaway
                        ? 'Anjali Gupta'
                        : null;
        if (name != null) await store.setCustomerName(o.id, name);
      }

      // ---- Deliveries --------------------------------------------------
      for (final (
            id,
            order,
            merchant,
            rider,
            status,
            eta,
            km,
            created,
            updated,
            promiseIn
          ) in [
        (
          'DLV-1029',
          'ORD-10842',
          'Spice Garden',
          null,
          DeliveryStatus.unassigned,
          4,
          2.4,
          10,
          2,
          -8
        ),
        (
          'DLV-1028',
          'ORD-10840',
          'Latur Central',
          'Ramesh P.',
          DeliveryStatus.inTransit,
          12,
          4.1,
          22,
          5,
          12
        ),
        (
          'DLV-1025',
          'ORD-10841',
          'Burger Barn',
          'Vijay K.',
          DeliveryStatus.assigned,
          18,
          1.8,
          15,
          12,
          18
        ),
        (
          'DLV-1022',
          'ORD-10838',
          'Pizza Point',
          'Sanjay M.',
          DeliveryStatus.delivered,
          null,
          3.5,
          60,
          32,
          null
        ),
        (
          'DLV-1011',
          'ORD-10820',
          'Spice Garden',
          'Amit K.',
          DeliveryStatus.failed,
          null,
          2.2,
          180,
          150,
          null
        ),
        (
          'DLV-1008',
          'ORD-10815',
          'Latur Central',
          'Sanjay M.',
          DeliveryStatus.delivered,
          null,
          4.0,
          240,
          228,
          null
        ),
      ]) {
        await db.into(db.deliveriesTable).insertOnConflictUpdate(
            DeliveriesTableCompanion.insert(
                id: id,
                orderId: order,
                merchant: merchant,
                riderName: Value(rider),
                status: status.name,
                etaMinutes: Value(eta),
                distanceKm: Value(km),
                promisedAt: Value(promiseIn == null
                    ? null
                    : t0.add(Duration(minutes: promiseIn))),
                createdAt: ago(created),
                updatedAt: ago(updated)));
      }

      // ---- Reservations -------------------------------------------------
      for (final (id, name, phone, email, guests, h, m, status, table, notes)
          in [
        (
          'RSV-101',
          'Ananya Sharma',
          '+91 98765 43210',
          'ananya.sharma@gmail.com',
          4,
          19,
          30,
          ReservationStatus.confirmed,
          'T11',
          'Birthday celebration, window seat preferred'
        ),
        (
          'RSV-102',
          'Suresh Menon',
          '+91 99123 45678',
          '',
          2,
          19,
          45,
          ReservationStatus.pending,
          null,
          'Quiet corner space requested'
        ),
        (
          'RSV-103',
          'Kabir Singh',
          '+91 98456 12345',
          '',
          6,
          20,
          0,
          ReservationStatus.seated,
          'T12',
          ''
        ),
        (
          'RSV-104',
          'Meera Nair',
          '+91 88764 32109',
          '',
          4,
          20,
          15,
          ReservationStatus.confirmed,
          'T5',
          ''
        ),
        (
          'RSV-105',
          'Rohit Kapur',
          '+91 91234 56789',
          '',
          3,
          20,
          30,
          ReservationStatus.noShow,
          'T1',
          ''
        ),
        (
          'RSV-106',
          'Aditi Rao',
          '+91 95432 10987',
          '',
          2,
          21,
          0,
          ReservationStatus.cancelled,
          'T9',
          ''
        ),
        (
          'RSV-107',
          'Vikram Sen',
          '+91 98112 23344',
          '',
          8,
          21,
          15,
          ReservationStatus.confirmed,
          'C2',
          ''
        ),
        (
          'RSV-108',
          'Preeti Desai',
          '+91 87654 32100',
          '',
          4,
          21,
          30,
          ReservationStatus.pending,
          null,
          ''
        ),
      ]) {
        await db.into(db.reservationsTable).insertOnConflictUpdate(
            ReservationsTableCompanion.insert(
                id: id,
                guestName: name,
                phone: phone,
                email: Value(email),
                guests: guests,
                scheduledAt: _at(t0, h, m),
                status: status.name,
                tableId: Value(table),
                notes: Value(notes)));
      }
      // Upcoming (next 48h).
      for (var i = 0; i < 3; i++) {
        await db.into(db.reservationsTable).insertOnConflictUpdate(
            ReservationsTableCompanion.insert(
                id: 'RSV-2${i + 1}0',
                guestName: ['Neha Joshi', 'Arjun Patil', 'Sana Khan'][i],
                phone: '+91 9${i}123 45678',
                guests: 2 + i * 2,
                scheduledAt: _at(t0.add(const Duration(days: 1)), 20, i * 15),
                status: ReservationStatus.confirmed.name));
      }

      // ---- QR ordering ---------------------------------------------------
      await store.generateQrCodes();
      for (final (table, scanned) in [
        ('T1', 5),
        ('T2', 12),
        ('T3', 120),
        ('T4', 1),
        ('T5', 45),
      ]) {
        await (db.update(db.qrCodesTable)
              ..where((q) => q.tableId.equals(table)))
            .write(QrCodesTableCompanion(lastScannedAt: Value(ago(scanned))));
      }
      for (final table in ['T3', 'T6', 'T9', 'T16']) {
        await store.setQrEnabled(table, false);
      }
      for (final (id, table, guests, start, status, items, total) in [
        ('QRS-1', 'Table 1', 2, 35, QrSessionStatus.ordering, 3, 820),
        ('QRS-2', 'Table 4', 4, 65, QrSessionStatus.paymentPending, 6, 1450),
        ('QRS-3', 'Table 8', 3, 20, QrSessionStatus.browsing, 1, 340),
        ('QRS-4', 'Table 12', 5, 45, QrSessionStatus.completed, 8, 2100),
        ('QRS-5', 'Table 5', 2, 10, QrSessionStatus.browsing, 0, 0),
        ('QRS-6', 'Table 3', 4, 80, QrSessionStatus.completed, 5, 1240),
        ('QRS-7', 'Table 14', 6, 40, QrSessionStatus.ordering, 7, 1950),
        ('QRS-8', 'Table 9', 1, 5, QrSessionStatus.ordering, 2, 480),
      ]) {
        await db.into(db.qrSessionsTable).insertOnConflictUpdate(
            QrSessionsTableCompanion.insert(
                id: id,
                tableLabel: table,
                guests: Value(guests),
                startedAt: ago(start),
                status: status.name,
                itemCount: Value(items),
                totalMinor: Value(total * 100)));
      }

      await db.into(db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(key: _flag, value: t0.toIso8601String()));
    });
  }

  static DateTime _at(DateTime day, int h, int m) =>
      DateTime(day.year, day.month, day.day, h, m);

  static OpsOrderLine _l(String name, int price, int qty,
          {bool veg = true, String station = 'Main Kitchen'}) =>
      OpsOrderLine(
        itemId: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        name: name,
        unitMinor: price * 100,
        quantity: qty,
        station: station,
        isVeg: veg,
      );
}
