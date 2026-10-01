import 'package:drift/drift.dart';

import '../domain/inventory.dart';
import 'app_database.dart';

/// The common Inventory store (PRD R09) — the only code that reads or
/// writes raw materials, suppliers, supplier prices, purchase orders,
/// goods receipts and stock movements. Inventory, Recipes, Suppliers and
/// Purchase Orders screens all go through this one class.
class DriftInventoryStore {
  DriftInventoryStore(this.db);
  final AppDatabase db;

  // ---------------------------------------------------------------------
  // Raw materials
  // ---------------------------------------------------------------------

  RawMaterial _material(RawMaterialEntity r) => RawMaterial(
        id: r.id,
        code: r.code,
        name: r.name,
        category: r.category,
        unit: r.unit,
        stockQty: r.stockQty,
        reorderLevel: r.reorderLevel,
        maxCapacity: r.maxCapacity,
        purchaseCostPerUnit: r.purchaseCost,
        lastPurchasePrice: r.lastPurchasePrice,
        preferredSupplierId: r.preferredSupplierId ?? '',
        status: stockStatusFor(r.stockQty, r.reorderLevel),
        hsn: r.hsn,
        emoji: r.emoji,
        leadTimeDays: r.leadTimeDays,
      );

  Stream<List<RawMaterial>> watchMaterials() => (db.select(db.rawMaterialsTable)
        ..where((t) => t.active.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch()
      .map((rows) => rows.map(_material).toList());

  Future<List<RawMaterial>> getMaterials() async =>
      (await (db.select(db.rawMaterialsTable)
                ..where((t) => t.active.equals(true))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get())
          .map(_material)
          .toList();

  Future<RawMaterial?> getMaterial(String id) async {
    final r = await (db.select(db.rawMaterialsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _material(r);
  }

  /// Insert or update. Stock on hand is NOT written here for existing rows
  /// — it only changes through [adjustStock] / [postGoodsReceipt], so every
  /// change has a stock movement behind it.
  Future<void> upsertMaterial(RawMaterial m) async {
    await db.transaction(() async {
      final existing = await (db.select(db.rawMaterialsTable)
            ..where((t) => t.id.equals(m.id)))
          .getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.rawMaterialsTable)
            .insert(RawMaterialsTableCompanion.insert(
              id: m.id,
              code: m.code,
              name: m.name,
              category: m.category,
              unit: m.unit,
              stockQty: Value(m.stockQty),
              reorderLevel: Value(m.reorderLevel),
              maxCapacity: Value(m.maxCapacity),
              purchaseCost: Value(m.purchaseCostPerUnit),
              lastPurchasePrice: Value(m.lastPurchasePrice),
              preferredSupplierId: Value(
                  m.preferredSupplierId.isEmpty ? null : m.preferredSupplierId),
              hsn: Value(m.hsn),
              emoji: Value(m.emoji),
              leadTimeDays: Value(m.leadTimeDays),
            ));
        if (m.stockQty != 0) {
          await _movement(
              m.id, m.stockQty, 'Opening Stock', '', m.purchaseCostPerUnit);
        }
      } else {
        await (db.update(db.rawMaterialsTable)..where((t) => t.id.equals(m.id)))
            .write(RawMaterialsTableCompanion(
          code: Value(m.code),
          name: Value(m.name),
          category: Value(m.category),
          unit: Value(m.unit),
          reorderLevel: Value(m.reorderLevel),
          maxCapacity: Value(m.maxCapacity),
          purchaseCost: Value(m.purchaseCostPerUnit),
          preferredSupplierId: Value(
              m.preferredSupplierId.isEmpty ? null : m.preferredSupplierId),
          hsn: Value(m.hsn),
          emoji: Value(m.emoji),
          leadTimeDays: Value(m.leadTimeDays),
          active: const Value(true),
        ));
      }
    });
  }

  /// Soft delete — movements and PO history keep pointing at the row.
  Future<void> archiveMaterial(String id) async {
    await (db.update(db.rawMaterialsTable)..where((t) => t.id.equals(id)))
        .write(const RawMaterialsTableCompanion(active: Value(false)));
  }

  /// Manual stock change (count correction, wastage, …). [delta] may be
  /// negative; stock never goes below zero.
  Future<void> adjustStock(String materialId, double delta,
      {required String reason, String reference = ''}) async {
    await db.transaction(() async {
      final r = await (db.select(db.rawMaterialsTable)
            ..where((t) => t.id.equals(materialId)))
          .getSingle();
      final next = (r.stockQty + delta).clamp(0, double.infinity).toDouble();
      await (db.update(db.rawMaterialsTable)
            ..where((t) => t.id.equals(materialId)))
          .write(RawMaterialsTableCompanion(stockQty: Value(next)));
      await _movement(
          materialId, next - r.stockQty, reason, reference, r.purchaseCost);
    });
  }

  Future<void> _movement(String materialId, double delta, String reason,
      String reference, double? unitCost) async {
    await db.into(db.stockMovementsTable).insert(
        StockMovementsTableCompanion.insert(
            materialId: materialId,
            qtyDelta: delta,
            reason: reason,
            reference: Value(reference),
            unitCost: Value(unitCost)));
  }

  Stream<List<StockMovement>> watchMovements(String materialId) =>
      (db.select(db.stockMovementsTable)
            ..where((t) => t.materialId.equals(materialId))
            // createdAt has one-second resolution; id breaks ties.
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch()
          .map((rows) => rows
              .map((r) => StockMovement(
                  materialId: r.materialId,
                  qtyDelta: r.qtyDelta,
                  reason: r.reason,
                  reference: r.reference,
                  unitCost: r.unitCost,
                  createdAt: r.createdAt))
              .toList());

  /// Next free code for a category prefix, e.g. RM-DAI-005.
  Future<String> nextMaterialCode(String category) async {
    final prefix = category.length >= 3
        ? category.substring(0, 3).toUpperCase()
        : category.toUpperCase().padRight(3, 'X');
    final rows = await db.select(db.rawMaterialsTable).get();
    var n = rows.where((r) => r.code.startsWith('RM-$prefix-')).length + 1;
    String code() => 'RM-$prefix-${n.toString().padLeft(3, '0')}';
    while (rows.any((r) => r.code == code())) {
      n++;
    }
    return code();
  }

  // ---------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------

  InventorySupplier _supplier(SupplierEntity r) => InventorySupplier(
        id: r.id,
        name: r.name,
        legalName: r.legalName.isEmpty ? r.name : r.legalName,
        category: r.category,
        contactPerson: r.contactPerson,
        phone: r.phone,
        gstin: r.gstin,
        city: r.city,
        rating: r.rating,
        paymentTerms: r.paymentTerms,
        email: r.email,
        active: r.active,
      );

  /// Active suppliers only — for pickers and supplier lists.
  Stream<List<InventorySupplier>> watchSuppliers() =>
      (db.select(db.suppliersTable)
            ..where((t) => t.active.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((rows) => rows.map(_supplier).toList());

  /// Active suppliers only — for pickers and supplier lists.
  Future<List<InventorySupplier>> getSuppliers() async =>
      (await (db.select(db.suppliersTable)
                ..where((t) => t.active.equals(true))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get())
          .map(_supplier)
          .toList();

  /// Every supplier, archived ones included ([InventorySupplier.active] is
  /// false for those) — for naming the supplier of old orders, prices and
  /// materials. Pickers keep using [watchSuppliers].
  Stream<List<InventorySupplier>> watchAllSuppliers() =>
      (db.select(db.suppliersTable)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((rows) => rows.map(_supplier).toList());

  /// Every supplier, archived ones included. See [watchAllSuppliers].
  Future<List<InventorySupplier>> getAllSuppliers() async =>
      (await (db.select(db.suppliersTable)
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get())
          .map(_supplier)
          .toList();

  /// One supplier by id, archived or not; null when there is no such row.
  Future<InventorySupplier?> getSupplier(String id) async {
    final r = await (db.select(db.suppliersTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _supplier(r);
  }

  Future<void> upsertSupplier(InventorySupplier s) async {
    await db.into(db.suppliersTable).insertOnConflictUpdate(
        SuppliersTableCompanion.insert(
            id: s.id,
            name: s.name,
            legalName: Value(s.legalName),
            category: Value(s.category),
            contactPerson: Value(s.contactPerson),
            phone: Value(s.phone),
            email: Value(s.email),
            gstin: Value(s.gstin),
            city: Value(s.city),
            rating: Value(s.rating),
            paymentTerms: Value(s.paymentTerms),
            active: const Value(true)));
  }

  Future<void> archiveSupplier(String id) async {
    await (db.update(db.suppliersTable)..where((t) => t.id.equals(id)))
        .write(const SuppliersTableCompanion(active: Value(false)));
  }

  Future<String> nextSupplierId() async {
    final rows = await db.select(db.suppliersTable).get();
    var max = 0;
    for (final r in rows) {
      final n = int.tryParse(r.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return 'SPL-${(max + 1).toString().padLeft(4, '0')}';
  }

  // ---------------------------------------------------------------------
  // Supplier prices
  // ---------------------------------------------------------------------

  SupplierPriceQuote _price(SupplierPriceEntity r) => SupplierPriceQuote(
        id: r.id,
        ingredientName: r.ingredientName,
        emoji: r.emoji,
        linkedTo: r.linkedTo,
        supplierId: r.supplierId,
        unit: r.unit,
        lastPrice: r.lastPrice,
        currentPrice: r.currentPrice,
        lowestWeek: r.lowestWeek,
        source: priceSourceFromLabel(r.source),
        priority: r.priority,
        skuId: r.skuId,
        materialId: r.materialId,
        approved: r.approved,
      );

  Stream<List<SupplierPriceQuote>> watchSupplierPrices() =>
      (db.select(db.supplierPricesTable)
            ..orderBy([(t) => OrderingTerm.asc(t.ingredientName)]))
          .watch()
          .map((rows) => rows.map(_price).toList());

  Future<List<SupplierPriceQuote>> getSupplierPrices() async =>
      (await db.select(db.supplierPricesTable).get()).map(_price).toList();

  Future<void> upsertSupplierPrice(SupplierPriceQuote q) async {
    await db.into(db.supplierPricesTable).insertOnConflictUpdate(
        SupplierPricesTableCompanion.insert(
            id: q.id,
            ingredientName: q.ingredientName,
            materialId: Value(q.materialId),
            emoji: Value(q.emoji),
            linkedTo: Value(q.linkedTo),
            supplierId: q.supplierId,
            unit: q.unit,
            lastPrice: q.lastPrice,
            currentPrice: q.currentPrice,
            lowestWeek: q.lowestWeek,
            source: q.source.label,
            priority: Value(q.priority),
            skuId: Value(q.skuId),
            approved: Value(q.approved),
            updatedAt: Value(DateTime.now())));
  }

  /// Records a new quoted price: the old current price becomes "last".
  Future<void> updateQuotedPrice(String id, double newPrice) async {
    await db.transaction(() async {
      final r = await (db.select(db.supplierPricesTable)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await (db.update(db.supplierPricesTable)..where((t) => t.id.equals(id)))
          .write(SupplierPricesTableCompanion(
        lastPrice: Value(r.currentPrice),
        currentPrice: Value(newPrice),
        lowestWeek: Value(newPrice < r.lowestWeek ? newPrice : r.lowestWeek),
        source: Value(PriceSource.merchantEntered.label),
        approved: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  /// Approving a price makes it the costing price of the linked raw
  /// material, so recipe costs pick it up immediately.
  Future<void> approveSupplierPrice(String id) async {
    await db.transaction(() async {
      final r = await (db.select(db.supplierPricesTable)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await (db.update(db.supplierPricesTable)..where((t) => t.id.equals(id)))
          .write(SupplierPricesTableCompanion(
              approved: const Value(true), updatedAt: Value(DateTime.now())));
      if (r.materialId != null) {
        await (db.update(db.rawMaterialsTable)
              ..where((t) => t.id.equals(r.materialId!)))
            .write(RawMaterialsTableCompanion(
                purchaseCost: Value(r.currentPrice),
                preferredSupplierId: Value(r.supplierId)));
      }
    });
  }

  Future<void> deleteSupplierPrice(String id) async {
    await (db.delete(db.supplierPricesTable)..where((t) => t.id.equals(id)))
        .go();
  }

  // ---------------------------------------------------------------------
  // Purchase orders
  // ---------------------------------------------------------------------

  PurchaseOrder _po(PurchaseOrderEntity r, List<PurchaseOrderLineEntity> ls) =>
      PurchaseOrder(
        number: r.number,
        supplierId: r.supplierId,
        orderDate: formatShortDate(r.orderDate),
        expectedDelivery: formatShortDate(r.expectedDelivery),
        status: purchaseOrderStatusFromLabel(r.status),
        createdBy: r.createdBy,
        deliveryAddress: r.deliveryAddress,
        deliveryCity: r.deliveryCity,
        taxPct: r.taxPct,
        notes: r.notes,
        lines: [
          for (final l in ls)
            PurchaseOrderLine(
                id: l.id,
                materialId: l.materialId,
                materialName: l.materialName,
                code: l.code,
                unit: l.unit,
                unitCost: l.unitCost,
                orderedQty: l.orderedQty,
                receivedQty: l.receivedQty,
                rejectedQty: l.rejectedQty),
        ],
      );

  Future<List<PurchaseOrder>> _loadOrders(
      List<PurchaseOrderEntity> orders) async {
    final lines = await db.select(db.purchaseOrderLinesTable).get();
    return [
      for (final o in orders)
        _po(o, lines.where((l) => l.poNumber == o.number).toList()),
    ];
  }

  /// Emits whenever an order or any order line changes.
  Stream<List<PurchaseOrder>> watchPurchaseOrders() {
    final orders = db.select(db.purchaseOrdersTable)
      ..orderBy([(t) => OrderingTerm.desc(t.number)]);
    return db
        .customSelect('SELECT 1',
            readsFrom: {db.purchaseOrdersTable, db.purchaseOrderLinesTable})
        .watch()
        .asyncMap((_) async => _loadOrders(await orders.get()));
  }

  Future<PurchaseOrder?> getPurchaseOrder(String number) async {
    final o = await (db.select(db.purchaseOrdersTable)
          ..where((t) => t.number.equals(number)))
        .getSingleOrNull();
    if (o == null) return null;
    return (await _loadOrders([o])).first;
  }

  Future<String> nextPoNumber() async {
    final rows = await db.select(db.purchaseOrdersTable).get();
    var max = 1000;
    for (final r in rows) {
      final n = int.tryParse(r.number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return 'PO-${max + 1}';
  }

  /// Next readable goods-receipt number: GRN-0001, GRN-0002, … Older
  /// receipts were stored under a timestamp id (GRN-1727…); those are
  /// skipped when counting.
  Future<String> nextGrnNumber() async {
    final rows = await db.select(db.goodsReceiptsTable).get();
    final ids = {for (final r in rows) r.id};
    var max = 0;
    for (final id in ids) {
      final m = RegExp(r'^GRN-(\d{1,6})$').firstMatch(id);
      final n = m == null ? 0 : int.parse(m.group(1)!);
      if (n > max) max = n;
    }
    var next = max + 1;
    String number() => 'GRN-${next.toString().padLeft(4, '0')}';
    while (ids.contains(number())) {
      next++;
    }
    return number();
  }

  /// Creates or replaces a purchase order and its lines. Only orders that
  /// have not received stock may be edited.
  Future<void> savePurchaseOrder(PurchaseOrder po) async {
    await db.transaction(() async {
      final existing = await getPurchaseOrder(po.number);
      if (existing != null &&
          existing.lines.any((l) => l.receivedQty > 0 || l.rejectedQty > 0)) {
        throw StateError(
            '${po.number} has already received stock and can no longer be edited.');
      }
      await db.into(db.purchaseOrdersTable).insertOnConflictUpdate(
          PurchaseOrdersTableCompanion.insert(
              number: po.number,
              supplierId: po.supplierId,
              orderDate: parseShortDate(po.orderDate) ?? DateTime.now(),
              expectedDelivery:
                  parseShortDate(po.expectedDelivery) ?? DateTime.now(),
              status: po.status.label,
              createdBy: Value(po.createdBy),
              deliveryAddress: Value(po.deliveryAddress),
              deliveryCity: Value(po.deliveryCity),
              taxPct: Value(po.taxPct),
              notes: Value(po.notes),
              updatedAt: Value(DateTime.now())));
      await (db.delete(db.purchaseOrderLinesTable)
            ..where((t) => t.poNumber.equals(po.number)))
          .go();
      for (final l in po.lines) {
        await db.into(db.purchaseOrderLinesTable).insert(
            PurchaseOrderLinesTableCompanion.insert(
                poNumber: po.number,
                materialId: Value(l.materialId),
                materialName: l.materialName,
                code: Value(l.code),
                unit: l.unit,
                unitCost: l.unitCost,
                orderedQty: l.orderedQty,
                receivedQty: Value(l.receivedQty),
                rejectedQty: Value(l.rejectedQty)));
      }
    });
  }

  Future<void> setPurchaseOrderStatus(
      String number, PurchaseOrderStatus status) async {
    await (db.update(db.purchaseOrdersTable)
          ..where((t) => t.number.equals(number)))
        .write(PurchaseOrdersTableCompanion(
            status: Value(status.label), updatedAt: Value(DateTime.now())));
  }

  /// Deletes an order that never received stock (draft / pending / cancelled).
  Future<void> deletePurchaseOrder(String number) async {
    await db.transaction(() async {
      final po = await getPurchaseOrder(number);
      if (po == null) return;
      if (po.lines.any((l) => l.receivedQty > 0)) {
        throw StateError('$number has received stock; cancel it instead.');
      }
      await (db.delete(db.purchaseOrderLinesTable)
            ..where((t) => t.poNumber.equals(number)))
          .go();
      await (db.delete(db.purchaseOrdersTable)
            ..where((t) => t.number.equals(number)))
          .go();
    });
  }

  /// Posts a Goods Receipt Note: for each line adds the accepted quantity
  /// to raw-material stock (with a stock movement), records received /
  /// rejected quantities on the PO line, updates the last purchase price,
  /// moves the PO to Received / Partially Received, and stores the GRN.
  /// All-or-nothing (one transaction). Returns the GRN number (its id),
  /// e.g. GRN-0007.
  Future<String> postGoodsReceipt(
    String poNumber,
    List<GrnLineInput> receipt, {
    double taxPct = 0,
    String notes = '',
  }) async {
    return db.transaction(() async {
      final po = await getPurchaseOrder(poNumber);
      if (po == null) throw StateError('$poNumber not found');
      if (po.status == PurchaseOrderStatus.cancelled ||
          po.status == PurchaseOrderStatus.received) {
        throw StateError(
            '$poNumber is ${po.status.label}; nothing to receive.');
      }
      final grnId = await nextGrnNumber();
      final materials = await db.select(db.rawMaterialsTable).get();
      var subtotal = 0.0;
      for (final input in receipt) {
        final line = po.lines.firstWhere((l) => l.id == input.lineId);
        if (input.acceptedQty < 0 || input.rejectedQty < 0) {
          throw ArgumentError('Quantities cannot be negative.');
        }
        if (input.acceptedQty + input.rejectedQty >
            line.outstandingQty + 1e-9) {
          throw StateError('${line.materialName}: only '
              '${line.outstandingQty} ${line.unit} is still outstanding.');
        }
        subtotal += input.acceptedQty * input.unitCost;
        await (db.update(db.purchaseOrderLinesTable)
              ..where((t) => t.id.equals(line.id!)))
            .write(PurchaseOrderLinesTableCompanion(
          receivedQty: Value(line.receivedQty + input.acceptedQty),
          rejectedQty: Value(line.rejectedQty + input.rejectedQty),
        ));
        final resolved = _resolveMaterial(line, materials);
        // Re-read so two lines for the same material both count.
        final material = resolved == null
            ? null
            : await (db.select(db.rawMaterialsTable)
                  ..where((t) => t.id.equals(resolved.id)))
                .getSingle();
        if (material != null && input.acceptedQty > 0) {
          await (db.update(db.rawMaterialsTable)
                ..where((t) => t.id.equals(material.id)))
              .write(RawMaterialsTableCompanion(
            stockQty: Value(material.stockQty + input.acceptedQty),
            lastPurchasePrice: Value(input.unitCost),
          ));
          await _movement(material.id, input.acceptedQty, 'GRN Receipt',
              '$poNumber / $grnId', input.unitCost);
        }
      }
      final tax = subtotal * taxPct / 100;
      await db.into(db.goodsReceiptsTable).insert(
          GoodsReceiptsTableCompanion.insert(
              id: grnId,
              poNumber: poNumber,
              receivedAt: DateTime.now(),
              subtotal: subtotal,
              tax: tax,
              total: subtotal + tax,
              notes: Value(notes)));
      final updated = await getPurchaseOrder(poNumber);
      final complete = updated!.lines
          .every((l) => l.receivedQty + l.rejectedQty >= l.orderedQty);
      await setPurchaseOrderStatus(
          poNumber,
          complete
              ? PurchaseOrderStatus.received
              : PurchaseOrderStatus.partiallyReceived);
      return grnId;
    });
  }

  RawMaterialEntity? _resolveMaterial(
      PurchaseOrderLine line, List<RawMaterialEntity> materials) {
    for (final m in materials) {
      if (line.materialId != null && m.id == line.materialId) return m;
    }
    for (final m in materials) {
      if (line.code.isNotEmpty && m.code == line.code) return m;
    }
    final name = line.materialName.toLowerCase();
    for (final m in materials) {
      if (m.name.toLowerCase() == name ||
          m.name.toLowerCase().startsWith(name)) {
        return m;
      }
    }
    return null;
  }
}

/// One line of a Goods Receipt Note being posted.
class GrnLineInput {
  const GrnLineInput({
    required this.lineId,
    required this.acceptedQty,
    required this.rejectedQty,
    required this.unitCost,
  });
  final int lineId;
  final double acceptedQty;
  final double rejectedQty;
  final double unitCost;
}
