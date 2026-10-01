import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_inventory_store.dart';
import 'package:proviyaa_pos/data/drift_master_store.dart';
import 'package:proviyaa_pos/data/drift_menu_store.dart';
import 'package:proviyaa_pos/data/master_seeder.dart';
import 'package:proviyaa_pos/domain/inventory.dart';
import 'package:proviyaa_pos/presentation/master/master_inventory_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_media_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_menu_items_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_offers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_purchase_orders_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_recipes_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_suppliers_screen.dart';
import 'package:proviyaa_pos/presentation/master/master_ui.dart';
import 'package:proviyaa_pos/presentation/vinii_theme.dart';

/// In-memory stand-in for the native file dialogs: captures what the
/// app saves and hands back a prepared file when the app asks to pick one.
class _FakeFilePicker extends FilePickerPlatform {
  String? savedName;
  Uint8List? savedBytes;
  String? nextPickName;
  Uint8List? nextPickBytes;

  String get savedText => utf8.decode(savedBytes!);

  void pickCsvText(String name, String csv) {
    nextPickName = name;
    nextPickBytes = Uint8List.fromList(utf8.encode(csv));
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    return Uri.file('/fake/$fileName');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final bytes = nextPickBytes;
    if (bytes == null) return null;
    return _MemoryFile(nextPickName ?? 'file.csv', bytes);
  }

  /// Files returned by the next multi-file pick.
  List<(String, Uint8List)> nextPickFiles = const [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      [for (final (name, bytes) in nextPickFiles) _MemoryFile(name, bytes)];
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.file('/fake/$name');
  @override
  get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

void main() {
  late AppDatabase db;
  late DriftInventoryStore inv;
  late DriftMasterStore master;
  late _FakeFilePicker picker;

  /// Opens a fresh seeded database, sets a desktop-sized view and shows
  /// [screen] in a MaterialApp.
  Future<void> open(WidgetTester tester, Widget Function() screen) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    picker = _FakeFilePicker();
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);
    // closeStreamsSynchronously: see master_screens_layout_test.dart.
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    inv = DriftInventoryStore(db);
    master = DriftMasterStore(db);
    await tester.runAsync(() => MasterSeeder.seedIfNeeded(db));
    await tester.pumpWidget(MaterialApp(
        theme: viniiLightTheme(), home: Scaffold(body: screen())));
  }

  /// Lets real database work finish and streams deliver, while advancing
  /// fake time so dialog / route animations complete.
  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) async {
    // Let snackbars time out so no timers are left pending.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  /// Runs [op] against the database outside fake time.
  Future<T> read<T>(WidgetTester tester, Future<T> Function() op) async =>
      (await tester.runAsync(op)) as T;

  Future<void> tap(WidgetTester tester, Finder f) async {
    expect(f, findsWidgets);
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first, warnIfMissed: false);
    await settle(tester);
  }

  /// [target] inside the nearest ancestor of [anchor] that contains one.
  Finder near(Finder anchor, Finder target) {
    final el = anchor.evaluate().first;
    Finder? result;
    el.visitAncestorElements((a) {
      final f = find.descendant(
          of: find.byElementPredicate((e) => identical(e, a)),
          matching: target);
      if (f.evaluate().isNotEmpty) {
        result = f;
        return false;
      }
      return true;
    });
    if (result == null) fail('No $target near $anchor');
    return result!;
  }

  Finder field(String label) =>
      near(find.text(label).last, find.byType(TextFormField)).first;

  Future<void> enter(WidgetTester tester, String label, String text) async {
    final f = field(label);
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.enterText(f, text);
    await tester.pump();
  }

  // =====================================================================
  // 1. Menu items
  // =====================================================================
  group('Menu items', () {
    Widget screen() => MasterMenuItemsScreen(store: master);

    testWidgets('Add Item saves a dish the POS can sell', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, find.widgetWithText(ElevatedButton, 'Add Item'));
      await enter(tester, 'Dish Name *', 'Veg Biryani');
      await enter(tester, 'Selling Price ₹ *', '260');
      await tap(tester, find.text('Select a section'));
      await tap(tester, find.text('MAIN COURSE').last);
      await tap(tester, near(find.text('Veg').last, find.byType(Checkbox)));
      await tap(tester, find.text('Save Item'));

      expect(find.text('Save Item'), findsNothing, reason: 'dialog closed');
      final dishes = await read(tester, master.getDishes);
      final d = dishes.singleWhere((d) => d.name == 'Veg Biryani');
      expect(d.sellingPrice, 260);
      expect(d.category, 'MAIN COURSE');
      expect(d.isVeg, isTrue);
      final pos = await read(tester, () => DriftMenuStore(db).getAllItems());
      final item = pos.singleWhere((i) => i.id == d.id);
      expect(item.priceMinor, 26000);
      expect(item.available, isTrue);
      expect(find.text('Veg Biryani'), findsWidgets, reason: 'shown in grid');
      await close(tester);
    });

    testWidgets('Save on an empty form shows errors and writes nothing',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final before = (await read(tester, master.getDishes)).length;
      await tap(tester, find.widgetWithText(ElevatedButton, 'Add Item'));
      await tap(tester, find.text('Save Item'));
      expect(find.text('Dish name is required'), findsOneWidget);
      expect(find.text('Selling price is required'), findsOneWidget);
      expect(find.text('Menu section is required'), findsOneWidget);
      expect(find.text('Choose a dietary type'), findsOneWidget);
      expect(find.text('Save Item'), findsOneWidget, reason: 'still open');
      expect((await read(tester, master.getDishes)).length, before);
      await close(tester);
    });

    testWidgets('Edit changes the price', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, near(find.text('Garlic Naan'), find.text('Edit')));
      expect(field('Dish Name *'), findsOneWidget);
      await enter(tester, 'Selling Price ₹ *', '155');
      await tap(tester, find.text('Save Item'));
      expect(find.text('Save Item'), findsNothing);
      final d = (await read(tester, master.getDishes))
          .singleWhere((d) => d.id == 'dish-6');
      expect(d.sellingPrice, 155);
      expect(d.name, 'Garlic Naan');
      expect(d.category, 'BREADS');
      await close(tester);
    });

    testWidgets('Mark Unavailable on two selected dishes', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, near(find.text('Garlic Naan'), find.byType(Checkbox)));
      await tap(tester, near(find.text('Palak Paneer'), find.byType(Checkbox)));
      expect(find.text('✓ 2 selected'), findsOneWidget);
      await tap(tester, find.text('Mark Unavailable'));
      final pos = await read(tester, () => DriftMenuStore(db).getAllItems());
      for (final id in ['dish-5', 'dish-6']) {
        expect(pos.singleWhere((i) => i.id == id).available, isFalse,
            reason: id);
      }
      expect(pos.singleWhere((i) => i.id == 'dish-1').available, isTrue);
      await close(tester);
    });

    testWidgets('Delete from the overflow menu after confirming',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(
          tester, near(find.text('Jalebi (2 pcs)'), find.byTooltip('More actions')));
      await tap(tester, find.text('Delete').last);
      expect(find.text('Delete "Jalebi (2 pcs)"?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
      final dishes = await read(tester, master.getDishes);
      expect(dishes.any((d) => d.id == 'dish-7'), isFalse);
      await close(tester);
    });

    testWidgets('Export then Import round-trips through CSV', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, find.widgetWithText(OutlinedButton, 'Export'));
      expect(picker.savedName, startsWith('menu-items-'));
      final lines = const LineSplitter().convert(picker.savedText);
      expect(lines.first, contains('id,name,category,selling_price'));
      expect(lines.length, 1 + 7);
      expect(lines.any((l) => l.startsWith('dish-6,Garlic Naan,BREADS,140.00')),
          isTrue);

      picker.pickCsvText(
          'menu.csv',
          'id,name,category,selling_price,diet\n'
              'dish-6,,,150,\n'
              ',Masala Dosa,South Indian,120,veg\n'
              ',Bad Row,Snacks,abc,veg\n');
      await tap(tester, find.widgetWithText(OutlinedButton, 'Import'));
      expect(find.text('Import: 1 added, 1 updated, 1 skipped'), findsOneWidget);
      await tap(tester, find.text('Close'));

      final dishes = await read(tester, master.getDishes);
      expect(dishes.singleWhere((d) => d.id == 'dish-6').sellingPrice, 150);
      expect(dishes.singleWhere((d) => d.id == 'dish-6').name, 'Garlic Naan');
      final dosa = dishes.singleWhere((d) => d.name == 'Masala Dosa');
      expect(dosa.category, 'South Indian');
      expect(dishes.any((d) => d.name == 'Bad Row'), isFalse);
      await close(tester);
    });
  });

  // =====================================================================
  // 2. Inventory
  // =====================================================================
  group('Inventory', () {
    Widget screen() => MasterInventoryScreen(inventory: inv, master: master);

    testWidgets('+ Add Raw Material saves it with an opening movement',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, find.widgetWithText(MasterButton, '+ Add Raw Material'));
      expect(find.text('Add Raw Material'), findsOneWidget);
      await enter(tester, 'Material Name *', 'Basmati Rice');
      // The category is picked from the list, or added as a new one.
      await tap(
          tester,
          near(find.text('Category *'),
              find.byType(DropdownButtonFormField<String>)));
      await tap(tester, find.text('+ Add new category…').last);
      await enter(tester, 'New Category Name *', 'Grains');
      await settle(tester); // auto item code from the category
      await enter(tester, 'Opening Stock', '25');
      await enter(tester, 'Reorder Level *', '10');
      await enter(tester, 'Max Capacity *', '100');
      await enter(tester, 'Purchase Cost / unit (₹) *', '95');
      await tap(tester, find.widgetWithText(MasterButton, 'Save'));

      expect(find.text('Add Raw Material'), findsNothing);
      final m = (await read(tester, inv.getMaterials))
          .singleWhere((m) => m.name == 'Basmati Rice');
      expect(m.category, 'Grains');
      expect(m.code, 'RM-GRA-001');
      expect(m.stockQty, 25);
      expect(m.reorderLevel, 10);
      expect(m.purchaseCostPerUnit, 95);
      final moves = await read(tester, () => inv.watchMovements(m.id).first);
      expect(moves.single.reason, 'Opening Stock');
      expect(moves.single.qtyDelta, 25);
      expect(find.text('Basmati Rice'), findsWidgets);
      await close(tester);
    });

    testWidgets('Adjust stock +5 updates stock and logs a movement',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final before = (await read(tester, () => inv.getMaterial('rm-paneer')))!;
      await tap(tester,
          near(find.text('Fresh Paneer (Block)').first, find.text('Adjust')));
      expect(find.text('Adjust Stock · Fresh Paneer (Block)'), findsOneWidget);
      await enter(tester, 'Quantity *', '5');
      await enter(tester, 'Reference', 'Count sheet #7');
      await tap(tester, find.widgetWithText(MasterButton, 'Save Adjustment'));

      final after = (await read(tester, () => inv.getMaterial('rm-paneer')))!;
      expect(after.stockQty, closeTo(before.stockQty + 5, 1e-9));
      final moves =
          await read(tester, () => inv.watchMovements('rm-paneer').first);
      expect(moves.first.qtyDelta, closeTo(5, 1e-9));
      expect(moves.first.reason, 'Count Correction');
      expect(moves.first.reference, 'Count sheet #7');
      await close(tester);
    });

    testWidgets('Export CSV then Import CSV updates the database',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, find.widgetWithText(MasterButton, 'Export CSV'));
      expect(picker.savedName, startsWith('raw-materials-'));
      final lines = const LineSplitter().convert(picker.savedText);
      expect(lines.first, contains('id,code,name,category,unit,stock_qty'));
      expect(lines.length, 1 + 6);
      expect(lines.any((l) => l.startsWith('rm-onion,RM-VEG-011,Red Onion')),
          isTrue);

      picker.pickCsvText(
          'materials.csv',
          'id,code,name,category,unit,stock_qty,reorder_level,purchase_cost,preferred_supplier_id\n'
              'rm-onion,,,,,50,,32,\n'
              ',,Basmati Rice,Grains,kg,10,5,95,SPL-0091\n'
              ',,Mystery Item,Misc,kg,1,1,1,SPL-9999\n');
      await tap(tester, find.widgetWithText(MasterButton, 'Import CSV'));
      expect(find.text('Import: 1 added, 1 updated, 1 skipped'), findsOneWidget);
      expect(find.textContaining('unknown preferred_supplier_id'),
          findsOneWidget);
      await tap(tester, find.text('Close'));

      final all = await read(tester, inv.getMaterials);
      final onion = all.singleWhere((m) => m.id == 'rm-onion');
      expect(onion.stockQty, 50);
      expect(onion.purchaseCostPerUnit, 32);
      final moves =
          await read(tester, () => inv.watchMovements('rm-onion').first);
      expect(moves.first.reason, 'CSV Import');
      expect(moves.first.qtyDelta, closeTo(5, 1e-9));
      final rice = all.singleWhere((m) => m.name == 'Basmati Rice');
      expect(rice.stockQty, 10);
      expect(rice.preferredSupplierId, 'SPL-0091');
      expect(all.any((m) => m.name == 'Mystery Item'), isFalse);
      await close(tester);
    });
  });

  // =====================================================================
  // 3. Suppliers
  // =====================================================================
  group('Suppliers', () {
    Widget screen() => MasterSuppliersScreen(inventory: inv);

    testWidgets('Approve a quote makes it the raw-material costing price',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester,
          near(find.text('Fresh Malai Paneer').first, find.text('Approve')));
      expect(find.textContaining('Approve ₹'), findsOneWidget,
          reason: 'confirmation dialog');
      await tap(tester, find.widgetWithText(FilledButton, 'Approve'));

      final q = (await read(tester, inv.getSupplierPrices))
          .singleWhere((q) => q.id == 'sp-paneer');
      expect(q.approved, isTrue);
      final paneer = (await read(tester, () => inv.getMaterial('rm-paneer')))!;
      expect(paneer.purchaseCostPerUnit, 410);
      expect(paneer.preferredSupplierId, 'SPL-0082');
      await close(tester);
    });

    testWidgets('Suppliers tab: + Add Supplier saves it', (tester) async {
      await open(tester, screen);
      await settle(tester);
      final id = await read(tester, inv.nextSupplierId);
      await tap(tester, find.textContaining('Suppliers ('));
      await tap(tester, find.widgetWithText(MasterButton, '+ Add Supplier'));
      // A supplier's key is never shown.
      expect(find.text('Add Supplier'), findsWidgets);
      expect(find.textContaining(id), findsNothing);
      await enter(tester, 'Supplier Name *', 'Fresh Greens Co');
      await tap(tester, find.text('No category').last);
      await tap(tester, find.text('+ Add new category…').last);
      await enter(tester, 'New Category Name', 'Vegetables');
      await enter(tester, 'Phone', '+91 98765 43210');
      await enter(tester, 'Email', 'orders@freshgreens.test');
      await tap(tester, find.widgetWithText(MasterButton, 'Save'));

      final s = (await read(tester, inv.getSuppliers))
          .singleWhere((s) => s.name == 'Fresh Greens Co');
      expect(s.id, id);
      expect(s.category, 'Vegetables');
      expect(s.phone, '+91 98765 43210');
      expect(s.email, 'orders@freshgreens.test');
      expect(find.text('Fresh Greens Co'), findsWidgets);
      await close(tester);
    });
  });

  // =====================================================================
  // 4. Purchase orders
  // =====================================================================
  group('Purchase orders', () {
    Widget screen() => MasterPurchaseOrdersScreen(inventory: inv);

    Finder hinted(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint);

    testWidgets('+ Add Purchase Order with one line is submitted as Pending',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final number = await read(tester, inv.nextPoNumber);
      await tap(
          tester, find.widgetWithText(MasterButton, '+ Add Purchase Order'));
      expect(find.text('New Purchase Order · $number'), findsOneWidget);
      await tap(tester, find.text('Select supplier'));
      await tap(tester, find.text('ABC Foods · New Delhi · Vikram Mehta').last);
      await tap(tester, find.widgetWithText(MasterButton, '+ Add Line'));
      await tap(tester, find.text('Select raw material'));
      await tap(tester, find.textContaining('Tomato · RM-VEG-004').last);
      await tester.enterText(hinted('Qty'), '12');
      await tester.pump();
      await tap(tester, find.widgetWithText(MasterButton, 'Submit (Pending)'));

      expect(find.textContaining('New Purchase Order'), findsNothing);
      final po = (await read(tester, () => inv.getPurchaseOrder(number)))!;
      expect(po.status, PurchaseOrderStatus.pending);
      expect(po.supplierId, 'SPL-0082');
      expect(po.lines.single.materialId, 'rm-tomato');
      expect(po.lines.single.orderedQty, 12);
      final tomato = (await read(tester, () => inv.getMaterial('rm-tomato')))!;
      expect(po.lines.single.unitCost, tomato.purchaseCostPerUnit);
      await close(tester);
    });

    testWidgets('Saving with no lines keeps the dialog open, saves nothing',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final number = await read(tester, inv.nextPoNumber);
      await tap(
          tester, find.widgetWithText(MasterButton, '+ Add Purchase Order'));
      await tap(tester, find.widgetWithText(MasterButton, 'Save as Draft'));
      expect(find.text('Add at least one line item.'), findsOneWidget);
      expect(await read(tester, () => inv.getPurchaseOrder(number)), isNull);
      await close(tester);
    });

    testWidgets('PO-1042: Approve, Receive Stock, Confirm Receipt',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final paneer0 = (await read(tester, () => inv.getMaterial('rm-paneer')))!;
      final tomato0 = (await read(tester, () => inv.getMaterial('rm-tomato')))!;
      await tap(tester, near(find.text('PO-1042').first, find.text('View')));
      await tap(tester, find.widgetWithText(MasterButton, 'Approve'));
      expect(
          (await read(tester, () => inv.getPurchaseOrder('PO-1042')))!.status,
          PurchaseOrderStatus.approved);

      await tap(tester, find.widgetWithText(MasterButton, 'Receive Stock'));
      await tap(tester,
          find.widgetWithText(MasterButton, 'Confirm Receipt & Update Stock'));
      expect(find.text('Post goods receipt?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Post GRN'));

      final po = (await read(tester, () => inv.getPurchaseOrder('PO-1042')))!;
      expect(po.status, PurchaseOrderStatus.received);
      final paneer = (await read(tester, () => inv.getMaterial('rm-paneer')))!;
      final tomato = (await read(tester, () => inv.getMaterial('rm-tomato')))!;
      expect(paneer.stockQty, closeTo(paneer0.stockQty + 10, 1e-9));
      expect(tomato.stockQty, closeTo(tomato0.stockQty + 25, 1e-9));
      final moves =
          await read(tester, () => inv.watchMovements('rm-paneer').first);
      expect(moves.first.reason, 'GRN Receipt');
      // Back on the PO detail page after posting.
      expect(find.text('Back to Purchase Orders'), findsOneWidget);
      await close(tester);
    });
  });

  // =====================================================================
  // 5. Offers
  // =====================================================================
  group('Offers', () {
    Widget screen() => MasterOffersScreen(store: master);

    testWidgets('Create Campaign saves; a duplicate code is rejected',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      final before = (await read(tester, master.getOffers)).length;
      await tap(tester, find.widgetWithText(MasterButton, 'Create Campaign'));
      await enter(tester, 'Offer Title', 'Monsoon Madness');
      await enter(tester, 'Coupon Code', 'monsoon20');
      await enter(tester, 'Discount Rule', '20% OFF (Upto ₹60)');
      await enter(tester, 'Minimum Cart Value (₹)', '300');
      await tap(tester, find.widgetWithText(MasterButton, 'Save Draft'));

      var offers = await read(tester, master.getOffers);
      expect(offers.length, before + 1);
      final o = offers.singleWhere((o) => o.code == 'MONSOON20');
      expect(o.title, 'Monsoon Madness');
      expect(o.status, 'Draft');
      expect(o.minOrder, 300);

      await tap(tester, find.text('Back to Campaigns & Offers'));
      await tap(tester, find.widgetWithText(MasterButton, 'Create Campaign'));
      await enter(tester, 'Offer Title', 'Copycat');
      await enter(tester, 'Coupon Code', 'superfest30');
      await enter(tester, 'Discount Rule', '10%');
      await tap(tester, find.widgetWithText(MasterButton, 'Save Draft'));
      expect(
          find.textContaining('SUPERFEST30 is already used'), findsOneWidget);
      offers = await read(tester, master.getOffers);
      expect(offers.length, before + 1);
      expect(offers.any((o) => o.title == 'Copycat'), isFalse);
      await close(tester);
    });

    testWidgets('Pause an Active offer, then Delete one', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(
          tester,
          near(find.text('Swiggy Super Weekend Fest').first,
              find.text('Pause')));
      var offers = await read(tester, master.getOffers);
      expect(
          offers.singleWhere((o) => o.id == 'OFF-2026-0041').status, 'Paused');

      await tap(
          tester,
          near(find.text('Latur Special Sweet Treat').first,
              find.byTooltip('More actions')));
      await tap(tester, find.text('Delete').last);
      expect(find.text('Delete campaign?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
      offers = await read(tester, master.getOffers);
      expect(offers.any((o) => o.id == 'OFF-2026-0043'), isFalse);
      expect(offers.length, 3);
      await close(tester);
    });
  });

  // =====================================================================
  // 6. Recipes
  // =====================================================================
  group('Recipes', () {
    Widget screen() => MasterRecipesScreen(master: master, inventory: inv);

    testWidgets('Ingredients tab: edit a line quantity', (tester) async {
      await open(tester, screen);
      await settle(tester);
      // The first recipe by name is selected: Dal Makhani Premium.
      await tap(tester, find.text('Ingredients'));
      await tap(
          tester, near(find.text('Black Urad Dal').first, find.text('Edit')));
      expect(find.text('Edit Ingredient'), findsOneWidget);
      await enter(tester, 'Quantity per Portion *', '0.2');
      await tap(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('Edit Ingredient'), findsNothing);
      final r = (await read(tester, master.getRecipes))
          .singleWhere((r) => r.id == 'rcp-dal');
      final line = r.lines.singleWhere((l) => l.name == 'Black Urad Dal');
      expect(line.qty, closeTo(0.2, 1e-9));
      expect(line.fallbackUnitCost, 140);
      expect(r.lines.length, 4);
      await close(tester);
    });

    testWidgets('Feedback & Approval: Approve Recipe', (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester, find.text('Feedback & Approval'));
      await tap(tester, find.text('Approve Recipe'));
      final r = (await read(tester, master.getRecipes))
          .singleWhere((r) => r.id == 'rcp-dal');
      expect(r.status, 'Approved');
      expect(find.textContaining('Current status: Approved'), findsOneWidget);
      await close(tester);
    });
  });

  // =====================================================================
  // 7. Media
  // =====================================================================
  group('Media', () {
    Widget screen() => MasterMediaScreen(store: master);

    testWidgets('Select an asset, Delete Selected, confirm -> archived',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      await tap(tester,
          near(find.text('paneer_raw.png').first, find.byType(Checkbox)));
      await tap(tester, find.widgetWithText(ElevatedButton, 'Delete Selected'));
      expect(find.text('Archive 1 asset?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Delete Selected'));

      final rows =
          await read(tester, () => db.select(db.mediaAssetsTable).get());
      expect(rows.singleWhere((r) => r.id == 'media-1').archived, isTrue);
      expect(rows.where((r) => r.archived).length, 1);
      expect(find.text('paneer_raw.png'), findsNothing);
      await close(tester);
    });

    testWidgets('Upload Files stores small files and rejects files over 5 MB',
        (tester) async {
      await open(tester, screen);
      await settle(tester);
      // Tiny payloads: the screen only needs bytes; decoding is not checked.
      picker.nextPickFiles = [
        ('new_dish.png', Uint8List.fromList(List.filled(64, 1))),
        ('huge_video.mp4', Uint8List(DriftMasterStore.maxMediaBytes + 1)),
      ];
      await tap(tester, find.widgetWithText(ElevatedButton, 'Upload Files'));
      expect(find.text('Upload into folder'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Choose Files'));
      expect(find.text('Uploaded 1 of 2 files'), findsOneWidget);
      expect(find.textContaining('huge_video.mp4 is'), findsOneWidget);
      await tap(tester, find.text('Close'));

      final rows =
          await read(tester, () => db.select(db.mediaAssetsTable).get());
      final added = rows.singleWhere((r) => r.fileName == 'new_dish.png');
      expect(added.sizeBytes, 64);
      expect(added.bytes, hasLength(64));
      expect(rows.any((r) => r.fileName == 'huge_video.mp4'), isFalse);
      await close(tester);
    });
  });
}
