import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// Keys of the Add/Edit Item form fields that have no dedicated column on
/// [MasterDishItem] and are persisted in its `details` map.
class DishDetail {
  const DishDetail._();
  static const shortName = 'shortName';
  static const displayName = 'displayName';
  static const internalCode = 'internalCode';
  static const barcode = 'barcode';
  static const pricingType = 'pricingType';
  static const maxQty = 'maxQty';
  static const cuisine = 'cuisine';
  static const mealType = 'mealType';
  static const taxPct = 'taxPct';
  static const gstType = 'gstType';
  static const packaging = 'packaging';
  static const containerCharge = 'containerCharge';
  static const outOfStock = 'outOfStock';
  static const prepTimeMin = 'prepTimeMin';
  static const kdsGroup = 'kdsGroup';
  static const printerGroup = 'printerGroup';
  static const kitchenPriority = 'kitchenPriority';
  static const availability = 'availability';
  static const availabilityMode = 'availabilityMode';
  static const autoOutOfStock = 'autoOutOfStock';
  static const portionWeight = 'portionWeight';
  static const targetMarginPct = 'targetMarginPct';
  static const orderTypes = 'orderTypes';
  static const exposeIn = 'exposeIn';
  static const schedule = 'schedule';
  static const subSection = 'subSection';
  static const portionUnit = 'portionUnit';
  static const mediaId = 'mediaId';
  static const mediaName = 'mediaName';
  static const videoMediaId = 'videoMediaId';
  static const videoName = 'videoName';
  static const channelPrices = 'channelPrices';
}

/// Folder that dish images uploaded from the item form are stored in.
const dishMediaFolder = 'Covers & Dishes';

/// Channels offered in the form even before any dish uses them — the
/// shared Master channel list (offers and recipe activation use it too).
const defaultDishChannels = masterSalesChannels;

/// Makes the kitchen stations configured in Operations → KDS available to
/// the item editor opened from anywhere below it. The menu screens put it
/// around their body when they are given the operations store; without it
/// the station fields stay free text with a menu of values already used.
class MenuKitchenStations extends InheritedWidget {
  const MenuKitchenStations(
      {super.key, required this.names, required super.child});

  /// Active station names, in their configured order; null when the
  /// stations are not available (not loaded, or no operations store).
  final List<String>? names;

  static List<String>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MenuKitchenStations>()?.names;

  @override
  bool updateShouldNotify(MenuKitchenStations oldWidget) =>
      oldWidget.names?.join('\n') != names?.join('\n');
}

String dishText(MasterDishItem d, String key) {
  final v = d.details[key];
  if (v == null) return '';
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return '$v';
}

List<String> dishList(MasterDishItem d, String key) {
  final v = d.details[key];
  if (v is List) {
    return [
      for (final e in v)
        if ('$e'.trim().isNotEmpty) '$e'.trim()
    ];
  }
  return const [];
}

bool dishFlag(MasterDishItem d, String key) => d.details[key] == true;

String dietLabel(MasterDishItem d) => d.isNonVeg
    ? 'Non-Veg'
    : d.isEgg
        ? 'Egg'
        : 'Veg';

String formatRupees(double v) => '₹${v.toStringAsFixed(2)}';

String _numText(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Dish thumbnail: uploaded media bytes (details.mediaId) first, then the
/// dish / media image URL, else a placeholder.
class MenuItemImage extends StatelessWidget {
  const MenuItemImage({
    super.key,
    required this.dish,
    this.media = const {},
    this.width,
    this.height,
    this.iconSize = 32,
  });
  final MasterDishItem dish;
  final Map<String, MediaAssetRecord> media;
  final double? width;
  final double? height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final m = media[dish.details[DishDetail.mediaId]];
    Widget placeholder(BuildContext c, Object e, StackTrace? s) => _ph();
    if (m != null && m.bytes != null && !m.isVideo) {
      return Image.memory(m.bytes!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: placeholder);
    }
    final url =
        (m?.imageUrl?.isNotEmpty ?? false) ? m!.imageUrl! : dish.imageUrl;
    if (url.startsWith('http')) {
      return Image.network(url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: placeholder);
    }
    return _ph();
  }

  Widget _ph() => Container(
        width: width,
        height: height,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: Icon(Icons.restaurant, size: iconSize, color: Colors.grey[400]),
      );
}

/// Opens the Add (dish == null) or Edit item form. Returns true if saved
/// or deleted. [kitchenStations] defaults to the [MenuKitchenStations]
/// above [context], if any.
Future<bool> openMenuItemEditor(
  BuildContext context, {
  required DriftMasterStore store,
  required List<MasterDishItem> allDishes,
  MasterDishItem? dish,
  List<String>? kitchenStations,
}) async {
  final stations = kitchenStations ?? MenuKitchenStations.maybeOf(context);
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AddEditMenuItemModal(
        store: store,
        dish: dish,
        allDishes: allDishes,
        kitchenStations: stations),
  );
  return r ?? false;
}

/// Confirms, then deletes the given dishes. Returns true if deleted.
Future<bool> deleteMenuItems(BuildContext context, DriftMasterStore store,
    List<MasterDishItem> dishes) async {
  if (dishes.isEmpty) return false;
  final what =
      dishes.length == 1 ? '"${dishes.first.name}"' : '${dishes.length} items';
  final ok = await confirmMasterAction(context,
      title: 'Delete $what?',
      message:
          'This removes $what from the master menu and the POS. This cannot be undone.');
  if (!ok || !context.mounted) return false;
  return runMasterAction(
      context, () => store.deleteDishes(dishes.map((d) => d.id)),
      success: 'Deleted $what');
}

/// Read-only details of one dish, with an Edit shortcut.
Future<void> showMenuItemDetails(
  BuildContext context, {
  required DriftMasterStore store,
  required MasterDishItem dish,
  required List<MasterDishItem> allDishes,
  Map<String, MediaAssetRecord> media = const {},
  List<String>? kitchenStations,
}) async {
  final stations = kitchenStations ?? MenuKitchenStations.maybeOf(context);
  final d = dish;
  final schedule = d.details[DishDetail.schedule];
  String scheduleText = '';
  if (schedule is Map) {
    final days = (schedule['days'] as List?)?.join(', ') ?? '';
    final from = schedule['from'] ?? '';
    final to = schedule['to'] ?? '';
    scheduleText = [
      if (days.isNotEmpty) days,
      if ('$from$to'.isNotEmpty) '$from – $to',
    ].join(' · ');
  }
  final channelPrices = d.details[DishDetail.channelPrices];
  final rows = <(String, String)>[
    ('Menu Section', d.category),
    ('Sub-section', dishText(d, DishDetail.subSection)),
    ('Selling Price', formatRupees(d.sellingPrice)),
    ('Food Cost', formatRupees(d.foodCost)),
    ('Margin', '${d.marginPercent.toStringAsFixed(1)}%'),
    ('Target Margin', _suffix(dishText(d, DishDetail.targetMarginPct), '%')),
    ('Pricing Type', dishText(d, DishDetail.pricingType)),
    ('Tax', _suffix(dishText(d, DishDetail.taxPct), '%')),
    ('GST Type', dishText(d, DishDetail.gstType)),
    ('Max Qty / Order', dishText(d, DishDetail.maxQty)),
    ('Weight / Portion', dishText(d, DishDetail.portionWeight)),
    ('Short Name', dishText(d, DishDetail.shortName)),
    ('Display Name', dishText(d, DishDetail.displayName)),
    ('Internal Code', dishText(d, DishDetail.internalCode)),
    ('SKU', d.sku),
    ('Barcode', dishText(d, DishDetail.barcode)),
    ('HSN', d.hsn),
    ('Cuisine', dishText(d, DishDetail.cuisine)),
    ('Meal Type', masterHumanLabel(dishText(d, DishDetail.mealType))),
    ('Status', d.status),
    ('Dietary', dietLabel(d)),
    ('Availability', d.availability),
    ('Availability Mode', dishText(d, DishDetail.availabilityMode)),
    ('Schedule', scheduleText),
    (
      'Auto Out-of-Stock',
      dishFlag(d, DishDetail.autoOutOfStock) ? 'Yes' : 'No'
    ),
    ('Kitchen Station', d.kitchenStation),
    ('Prep Time', _suffix(dishText(d, DishDetail.prepTimeMin), ' min')),
    ('KDS Group', dishText(d, DishDetail.kdsGroup)),
    ('Printer Group', dishText(d, DishDetail.printerGroup)),
    ('Kitchen Priority', dishText(d, DishDetail.kitchenPriority)),
    ('Packaging', masterHumanLabel(dishText(d, DishDetail.packaging))),
    (
      'Container Charges',
      _suffix(dishText(d, DishDetail.containerCharge), '', prefix: '₹')
    ),
    ('Order Types', dishList(d, DishDetail.orderTypes).join(', ')),
    ('Channels', d.channels.join(', ')),
    if (channelPrices is Map && channelPrices.isNotEmpty)
      (
        'Channel Prices',
        channelPrices.entries.map((e) => '${e.key}: ₹${e.value}').join(', ')
      ),
    (
      'Image',
      dishText(d, DishDetail.mediaName).isNotEmpty
          ? dishText(d, DishDetail.mediaName)
          : (d.imageUrl.trim().isEmpty ? '' : 'Image from URL')
    ),
    ('Video', dishText(d, DishDetail.videoName)),
  ];
  final edit = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(children: [
        Expanded(child: Text(d.name, style: MasterStyle.sectionTitle)),
        IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, size: 20)),
      ]),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MenuItemImage(dish: d, media: media, height: 180),
              ),
              const SizedBox(height: 16),
              for (final r in rows)
                if (r.$2.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 150,
                            child: Text(r.$1, style: MasterStyle.label)),
                        Expanded(child: Text(r.$2, style: MasterStyle.body)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ViniiColors.brandGreen,
              foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Edit'),
        ),
      ],
    ),
  );
  if (edit == true && context.mounted) {
    await openMenuItemEditor(context,
        store: store,
        allDishes: allDishes,
        dish: dish,
        kitchenStations: stations);
  }
}

String _suffix(String v, String suffix, {String prefix = ''}) =>
    v.isEmpty ? '' : '$prefix$v$suffix';

/// Lets the user pick an existing image from the media library.
Future<MediaAssetRecord?> pickLibraryImage(
    BuildContext context, DriftMasterStore store) {
  return showDialog<MediaAssetRecord>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pick from media library'),
      content: SizedBox(
        width: 560,
        height: 400,
        child: StreamBuilder<List<MediaAssetRecord>>(
          stream: store.watchMedia(),
          builder: (c, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!.where((m) => !m.isVideo).toList();
            if (items.isEmpty) {
              return const Center(
                  child: Text('No images in the media library yet.',
                      style: MasterStyle.muted));
            }
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final m = items[i];
                return InkWell(
                  onTap: () => Navigator.pop(ctx, m),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _mediaThumb(m),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(m.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  );
}

Widget _mediaThumb(MediaAssetRecord m) {
  Widget ph(BuildContext c, Object e, StackTrace? s) => Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(Icons.image_outlined, color: Colors.grey));
  if (m.bytes != null) {
    return Image.memory(m.bytes!, fit: BoxFit.cover, errorBuilder: ph);
  }
  if (m.imageUrl != null && m.imageUrl!.startsWith('http')) {
    return Image.network(m.imageUrl!, fit: BoxFit.cover, errorBuilder: ph);
  }
  return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(Icons.image_outlined, color: Colors.grey));
}

/// Single-line text prompt. Returns the trimmed value, or null if cancelled.
Future<String?> promptMasterText(BuildContext context,
    {required String title,
    required String label,
    String initial = '',
    String? hint,
    String? Function(String)? validate}) {
  final ctrl = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (key.currentState!.validate()) {
          Navigator.pop(ctx, ctrl.text.trim());
        }
      }

      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration(hint).copyWith(labelText: label),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return '$label is required';
                return validate?.call(t);
              },
              onFieldSubmitted: (_) => submit(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ViniiColors.brandGreen,
                  foregroundColor: Colors.black),
              onPressed: submit,
              child: const Text('OK')),
        ],
      );
    },
  );
}

InputDecoration _inputDecoration(String? hint, {Widget? suffixIcon}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 13, color: ViniiColors.textMutedLight),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MasterStyle.cardBorder)),
    );

const _addCategory = '__add_category__';
const _addNew = '__add_new__';
const _videoExts = {'mp4', 'mov', 'webm'};
const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Stored meal types (lower case) — shown with human labels.
const _mealTypes = ['all day', 'breakfast', 'lunch', 'dinner', 'snacks'];

/// Stored packaging types (lower case) — shown with human labels.
const _packagingTypes = ['none', 'container', 'box', 'bag', 'cup'];

/// Add / Edit menu item form. Saves through [DriftMasterStore.upsertDish]
/// and pops `true` when saved or deleted.
class AddEditMenuItemModal extends StatefulWidget {
  const AddEditMenuItemModal({
    super.key,
    required this.store,
    required this.allDishes,
    this.dish,
    this.kitchenStations,
  });

  final DriftMasterStore store;
  final List<MasterDishItem> allDishes;
  final MasterDishItem? dish;

  /// Kitchen stations configured in Operations → KDS. When given, "Kitchen
  /// Station" and "KDS Group" are dropdowns of these; null keeps the
  /// free-text fields with a menu of values already used.
  final List<String>? kitchenStations;

  @override
  State<AddEditMenuItemModal> createState() => _AddEditMenuItemModalState();
}

class _AddEditMenuItemModalState extends State<AddEditMenuItemModal> {
  final _formKey = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};

  TextEditingController _ctrl(String key, [String text = '']) =>
      _c.putIfAbsent(key, () => TextEditingController(text: text));

  String? _category;
  int _categoryKey = 0;
  final _extraCategories = <String>[];
  String _pricingType = 'MRP-Based';
  String _mealType = 'all day';
  String _menuStatus = 'Active';
  String _gstType = 'Services';
  String _availability = 'In Stock';
  String _availabilityMode = 'Always available';
  bool _outOfStock = false;
  bool _autoOutOfStock = false;
  String? _diet; // 'veg' | 'non-veg' | 'egg'
  final _orderTypes = <String>{};
  final _channels = <String>{};
  final _knownChannels = <String>{};
  final _days = <String>{};

  // Media
  String _imageUrl = '';
  String? _mediaId;
  String? _mediaName;
  (String, Uint8List)? _pendingImage;
  String? _videoMediaId;
  String? _videoName;
  (String, Uint8List)? _pendingVideo;
  Map<String, MediaAssetRecord> _mediaIndex = const {};

  bool _saving = false;

  MasterDishItem? get _dish => widget.dish;

  @override
  void initState() {
    super.initState();
    final d = _dish;
    _ctrl('name', d?.name ?? '');
    _ctrl('price', d == null ? '' : _numText(d.sellingPrice));
    _ctrl('cost', d == null ? '' : _numText(d.foodCost));
    _ctrl('sku', d?.sku ?? '');
    _ctrl('hsn', d?.hsn ?? '');
    _ctrl('kitchen', d?.kitchenStation ?? '');
    for (final k in [
      DishDetail.shortName,
      DishDetail.displayName,
      DishDetail.internalCode,
      DishDetail.barcode,
      DishDetail.maxQty,
      DishDetail.cuisine,
      DishDetail.taxPct,
      DishDetail.packaging,
      DishDetail.containerCharge,
      DishDetail.prepTimeMin,
      DishDetail.kdsGroup,
      DishDetail.printerGroup,
      DishDetail.portionWeight,
      DishDetail.targetMarginPct,
      DishDetail.subSection,
      DishDetail.kitchenPriority,
    ]) {
      _ctrl(k, d == null ? '' : dishText(d, k));
    }
    final sched = d?.details[DishDetail.schedule];
    _ctrl('from', sched is Map ? '${sched['from'] ?? ''}' : '');
    _ctrl('to', sched is Map ? '${sched['to'] ?? ''}' : '');
    if (sched is Map && sched['days'] is List) {
      _days.addAll((sched['days'] as List).map((e) => '$e'));
    }
    if (sched is Map) {
      _isItemScheduleEnabled = sched['enabled'] == true ||
          (sched['enabled'] == null &&
              (_days.isNotEmpty || _t('from').isNotEmpty));
    }
    if (d != null) {
      final unit = dishText(d, DishDetail.portionUnit);
      if (unit.isNotEmpty) _selectedPortionUnit = unit;
    }

    if (d != null) {
      _category = d.category.isEmpty ? null : d.category;
      _menuStatus = d.status.isEmpty ? 'Active' : d.status;
      _diet = d.isNonVeg
          ? 'non-veg'
          : d.isEgg
              ? 'egg'
              : 'veg';
      _pricingType = _or(dishText(d, DishDetail.pricingType), _pricingType);
      _mealType = _or(dishText(d, DishDetail.mealType), _mealType);
      _gstType = _or(dishText(d, DishDetail.gstType), _gstType);
      _availabilityMode =
          _or(dishText(d, DishDetail.availabilityMode), _availabilityMode);
      _autoOutOfStock = dishFlag(d, DishDetail.autoOutOfStock);
      // Any unavailable item (out of stock here or bulk-marked unavailable)
      // shows the "Mark out of stock" switch on.
      final unavailable = d.availability == 'Unavailable';
      _outOfStock = unavailable;
      final label = unavailable
          ? _or(dishText(d, DishDetail.availability), 'In Stock')
          : _or(d.availability, 'In Stock');
      _availability = label == 'Unavailable' ? 'In Stock' : label;
      _orderTypes.addAll(dishList(d, DishDetail.orderTypes));
      _channels.addAll(d.channels);
      _imageUrl = d.imageUrl;
      final mid = dishText(d, DishDetail.mediaId);
      _mediaId = mid.isEmpty ? null : mid;
      final mn = dishText(d, DishDetail.mediaName);
      _mediaName = mn.isEmpty ? null : mn;
      final vid = dishText(d, DishDetail.videoMediaId);
      _videoMediaId = vid.isEmpty ? null : vid;
      final vn = dishText(d, DishDetail.videoName);
      _videoName = vn.isEmpty ? null : vn;
    } else {
      _orderTypes.addAll(['Delivery', 'Take Away', 'Dine In']);
      _channels.add('POS');
    }
    _knownChannels.addAll(_channels);
    widget.store.watchMedia().first.then((items) {
      if (mounted) {
        setState(() => _mediaIndex = {for (final m in items) m.id: m});
      }
    }).catchError((Object _) {});
  }

  static String _or(String v, String fallback) => v.isEmpty ? fallback : v;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _c[key]!.text.trim();

  // ---------------------------------------------------------------- options

  List<String> _distinct(Iterable<String> values,
      [Iterable<String> extra = const []]) {
    final s = <String>{
      for (final v in [...extra, ...values])
        if (v.trim().isNotEmpty) v.trim()
    };
    return s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get _categories => _distinct(
      widget.allDishes.map((d) => d.category),
      [..._extraCategories, if (_category != null) _category!]);

  List<String> _detailOptions(String key, [List<String> defaults = const []]) =>
      _distinct(widget.allDishes.map((d) => dishText(d, key)), defaults);

  List<String> get _stations =>
      _distinct(widget.allDishes.map((d) => d.kitchenStation));

  List<String> get _channelOptions => _distinct(
      widget.allDishes.expand((d) => d.channels),
      [...defaultDishChannels, ..._channels]);

  /// The shared channel list first, then any other channel this item is
  /// already on (older spellings stay visible and editable, never lost).
  List<String> get _exposeOptions => [
        ...defaultDishChannels,
        for (final c in _distinct({..._knownChannels, ..._channels}))
          if (!defaultDishChannels.contains(c)) c,
      ];

  /// Bumped to re-create a picker after "+ Add new…" is cancelled.
  int _pickerGen = 0;

  // ------------------------------------------------------------ validators

  String? Function(String?) _number(String label,
          {bool required = false, double? max, bool integer = false}) =>
      (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return required ? '$label is required' : null;
        final n = double.tryParse(t);
        if (n == null) return 'Enter a number';
        if (n < 0) return 'Must be 0 or more';
        if (max != null && n > max) return 'Must be at most ${_numText(max)}';
        if (integer && n != n.roundToDouble()) return 'Whole number only';
        return null;
      };

  Future<void> _pickTime(String key) async {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_t(key));
    final initial = m == null
        ? const TimeOfDay(hour: 11, minute: 0)
        : TimeOfDay(
            hour: int.parse(m.group(1)!).clamp(0, 23),
            minute: int.parse(m.group(2)!).clamp(0, 59));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() => _ctrl(key).text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
  }

  // ---------------------------------------------------------------- media

  Future<void> _pickUpload({required bool video}) async {
    final picked = await pickMediaFile(context);
    if (picked == null || !mounted) return;
    final (name, bytes) = picked;
    if (bytes.length > DriftMasterStore.maxMediaBytes) {
      showMasterError(context,
          '$name is ${(bytes.length / 1048576).toStringAsFixed(1)} MB; the limit is 5 MB.');
      return;
    }
    final isVideo = _videoExts.contains(name.split('.').last.toLowerCase());
    if (video && !isVideo) {
      showMasterError(context, 'Pick a video file (MP4, MOV or WEBM).');
      return;
    }
    setState(() {
      if (isVideo) {
        _pendingVideo = picked;
        _videoName = name;
        _videoMediaId = null;
      } else {
        _pendingImage = picked;
        _mediaName = name;
        _mediaId = null;
        _imageUrl = '';
      }
    });
  }

  Future<void> _pickUrl() async {
    final url = await promptMasterText(context,
        title: 'Image URL',
        label: 'Image URL',
        initial: _imageUrl,
        hint: 'https://…',
        validate: (t) => Uri.tryParse(t)?.hasScheme == true &&
                (t.startsWith('http://') || t.startsWith('https://'))
            ? null
            : 'Enter a full http(s) URL');
    if (url == null || !mounted) return;
    setState(() {
      _imageUrl = url;
      _pendingImage = null;
      _mediaId = null;
      _mediaName = null;
    });
  }

  Future<void> _pickLibrary() async {
    final m = await pickLibraryImage(context, widget.store);
    if (m == null || !mounted) return;
    setState(() {
      _mediaIndex = {..._mediaIndex, m.id: m};
      _pendingImage = null;
      _mediaId = m.id;
      _mediaName = m.fileName;
      _imageUrl = m.bytes == null ? (m.imageUrl ?? '') : '';
    });
  }

  Future<String?> _uploadMedia((String, Uint8List) file, String usage) async {
    final (name, bytes) = file;
    await widget.store.addMedia(
        fileName: name,
        bytes: bytes,
        folder: dishMediaFolder,
        usageLabel: usage);
    final all = await widget.store.watchMedia().first;
    for (final m in all) {
      if (m.fileName == name && m.folder == dishMediaFolder) return m.id;
    }
    return null;
  }

  // ---------------------------------------------------------------- save

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      showMasterError(context, 'Please fix the highlighted fields.');
      return;
    }
    setState(() => _saving = true);
    final name = _t('name');
    final ok = await runMasterAction(context, () async {
      var mediaId = _mediaId;
      if (_pendingImage != null) {
        mediaId = await _uploadMedia(_pendingImage!, name);
      } else if (mediaId != null &&
          (_mediaIndex[mediaId]?.usageLabel ?? '').isEmpty) {
        await widget.store.updateMedia(mediaId, usageLabel: name);
      }
      var videoId = _videoMediaId;
      if (_pendingVideo != null) {
        videoId = await _uploadMedia(_pendingVideo!, name);
      }

      double? num(String key) {
        final t = _t(key);
        return t.isEmpty ? null : double.parse(t);
      }

      final details = <String, Object?>{...?_dish?.details};
      void put(String key, Object? value) {
        if (value == null || (value is String && value.isEmpty)) {
          details.remove(key);
        } else {
          details[key] = value;
        }
      }

      for (final k in [
        DishDetail.shortName,
        DishDetail.displayName,
        DishDetail.internalCode,
        DishDetail.barcode,
        DishDetail.cuisine,
        DishDetail.packaging,
        DishDetail.kdsGroup,
        DishDetail.printerGroup,
        DishDetail.portionWeight,
        DishDetail.subSection,
      ]) {
        put(k, _t(k));
      }
      for (final k in [
        DishDetail.taxPct,
        DishDetail.containerCharge,
        DishDetail.prepTimeMin,
        DishDetail.targetMarginPct,
      ]) {
        put(k, num(k));
      }
      put(DishDetail.maxQty, num(DishDetail.maxQty)?.toInt());
      put(DishDetail.kitchenPriority, num(DishDetail.kitchenPriority)?.toInt());
      put(DishDetail.portionUnit,
          _selectedPortionUnit == 'Select...' ? null : _selectedPortionUnit);
      put(DishDetail.pricingType, _pricingType);
      put(DishDetail.mealType, _mealType);
      put(DishDetail.gstType, _gstType);
      put(DishDetail.availability, _availability);
      put(DishDetail.availabilityMode, _availabilityMode);
      details[DishDetail.outOfStock] = _outOfStock;
      details[DishDetail.autoOutOfStock] = _autoOutOfStock;
      details[DishDetail.orderTypes] = _orderTypes.toList();
      final channels = _channelOptions.where(_channels.contains).toList();
      details[DishDetail.exposeIn] = channels;
      details[DishDetail.schedule] = {
        'enabled': _isItemScheduleEnabled,
        'days': _weekDays.where(_days.contains).toList(),
        'from': _t('from'),
        'to': _t('to'),
      };
      put(DishDetail.mediaId, mediaId);
      put(DishDetail.mediaName, mediaId == null ? null : _mediaName);
      put(DishDetail.videoMediaId, videoId);
      put(DishDetail.videoName, videoId == null ? null : _videoName);

      final price = double.parse(_t('price'));
      final cost = num('cost') ?? 0;
      final dish = MasterDishItem(
        id: _dish?.id ?? 'dish-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _category!,
        sellingPrice: price,
        foodCost: cost,
        marginPercent: price > 0 ? (price - cost) / price * 100 : 0,
        availability: _outOfStock
            ? 'Out of Stock'
            : (_availability == 'Unavailable' ? 'In Stock' : _availability),
        channels: channels,
        kitchenStation: _t('kitchen'),
        status: _menuStatus,
        sku: _t('sku'),
        hsn: _t('hsn'),
        imageUrl: mediaId != null && _pendingImage != null ? '' : _imageUrl,
        isVeg: _diet == 'veg',
        isNonVeg: _diet == 'non-veg',
        isEgg: _diet == 'egg',
        details: details,
      );
      await widget.store.upsertDish(dish);
    }, success: '$name saved');
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final d = _dish;
    if (d == null) return;
    final ok = await deleteMenuItems(context, widget.store, [d]);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onCategory(String? v) async {
    if (v == _addCategory) {
      final name = await promptMasterText(context,
          title: 'Add Category',
          label: 'Category name',
          hint: 'e.g. Starters',
          validate: (t) =>
              _categories.any((c) => c.toLowerCase() == t.toLowerCase())
                  ? 'That category already exists'
                  : null);
      if (!mounted) return;
      setState(() {
        if (name != null) {
          _extraCategories.add(name);
          _category = name;
        }
        _categoryKey++;
      });
      return;
    }
    setState(() {
      _category = v;
      _categoryKey++;
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _titleBar(isDark, borderColor),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('DISH MEDIA'),
                        _mediaSection(isDark, cardBg, borderColor),
                        const SizedBox(height: 20),

                        _buildSectionHeader('BASIC INFO'),
                        _field('Dish Name *', 'name',
                            hint: 'e.g., Paneer Tikka Masala',
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Dish name is required'
                                : null),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _categoryDropdownWithAddButton()),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _combo(
                                      'Sub-section (optional)',
                                      DishDetail.subSection,
                                      _detailOptions(DishDetail.subSection),
                                      hint: 'Pick a menu section first'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Optional. Pick a sub-section other dishes already use from the ▾ menu, or type a new one.',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildSectionHeader('PRICING & ATTRIBUTES'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 620;
                            final pricingTypeColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pricing Type', style: _labelStyle),
                                const SizedBox(height: 6),
                                Row(children: [
                                  for (final p in [
                                    'MRP-Based',
                                    'Portion-Based'
                                  ]) ...[
                                    _buildTogglePill(p, _pricingType == p,
                                        () => setState(() => _pricingType = p)),
                                    const SizedBox(width: 8),
                                  ],
                                ]),
                              ],
                            );
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  pricingTypeColumn,
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _field(
                                            'Selling Price ₹ *', 'price',
                                            hint: '0',
                                            numeric: true,
                                            validator: _number('Selling price',
                                                required: true)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _field('Food Cost ₹', 'cost',
                                            hint: '0',
                                            numeric: true,
                                            validator: _number('Food cost')),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _field('Max Qty (optional)',
                                            DishDetail.maxQty,
                                            hint: 'No limits',
                                            numeric: true,
                                            validator: _number('Max qty',
                                                integer: true)),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                pricingTypeColumn,
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _field('Selling Price ₹ *', 'price',
                                      hint: '0',
                                      numeric: true,
                                      validator: _number('Selling price',
                                          required: true)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field('Food Cost ₹', 'cost',
                                      hint: '0',
                                      numeric: true,
                                      validator: _number('Food cost')),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                      'Max Qty (optional)', DishDetail.maxQty,
                                      hint: 'No limits',
                                      numeric: true,
                                      validator:
                                          _number('Max qty', integer: true)),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        _buildSectionHeader('IDENTITY & CODES'),
                        _row([
                          _field('Short Name optional', DishDetail.shortName,
                              hint: 'Paneer Tikka'),
                          _field(
                              'Display Name optional', DishDetail.displayName,
                              hint: 'Shown on Menu'),
                          _field('Internal Code', DishDetail.internalCode,
                              hint: 'ITM-1002'),
                        ]),
                        const SizedBox(height: 12),
                        _row([
                          _field('SKU', 'sku', hint: 'Enter SKU code',
                              validator: (v) {
                            final t = (v ?? '').trim().toLowerCase();
                            if (t.isEmpty) return null;
                            final clash = widget.allDishes.any((d) =>
                                d.id != _dish?.id && d.sku.toLowerCase() == t);
                            return clash
                                ? 'SKU already used by another item'
                                : null;
                          }),
                          _field('Barcode', DishDetail.barcode,
                              hint: 'Scan or enter barcode'),
                          _field('HSN Code', 'hsn', hint: 'Enter HSN Code'),
                        ]),
                        const SizedBox(height: 20),

                        _buildSectionHeader('CLASSIFICATION & STATUS'),
                        _row([
                          _combo(
                              'Cuisine',
                              DishDetail.cuisine,
                              _detailOptions(DishDetail.cuisine, [
                                'North Indian',
                                'South Indian',
                                'Chinese',
                                'Continental',
                              ]),
                              hint: 'Select cuisine'),
                          _dropdown(
                              'Meal Type',
                              _mealType,
                              _mealTypes,
                              (v) => setState(() => _mealType = v),
                              labelOf: masterHumanLabel),
                          _dropdown(
                              'Menu Status',
                              _menuStatus,
                              ['Active', 'Draft', 'Inactive'],
                              (v) => setState(() => _menuStatus = v)),
                        ]),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 480) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _taxDropdown(),
                                  const SizedBox(height: 12),
                                  _packagingDropdown(),
                                  const SizedBox(height: 12),
                                  _switch('Mark out of stock', _outOfStock,
                                      (v) => setState(() => _outOfStock = v)),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _taxDropdown()),
                                const SizedBox(width: 12),
                                Expanded(child: _packagingDropdown()),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _switch(
                                        'Mark out of stock',
                                        _outOfStock,
                                        (v) => setState(() => _outOfStock = v)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        _buildSectionHeader('KITCHEN & PREPARATION'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 580) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _field('Prep Time (min)',
                                            DishDetail.prepTimeMin,
                                            hint: '15',
                                            numeric: true,
                                            validator: _number('Prep time')),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: _kitchenStationField()),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _kdsGroupField()),
                                      const SizedBox(width: 12),
                                      Expanded(child: _printerGroupField()),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field(
                                      'Prep Time (min)', DishDetail.prepTimeMin,
                                      hint: '15',
                                      numeric: true,
                                      validator: _number('Prep time')),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: _kitchenStationField()),
                                const SizedBox(width: 12),
                                Expanded(child: _kdsGroupField()),
                                const SizedBox(width: 12),
                                Expanded(child: _printerGroupField()),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 220,
                              child: _field('Kitchen Priority',
                                  DishDetail.kitchenPriority,
                                  hint: '0',
                                  numeric: true,
                                  validator: _number('Kitchen priority',
                                      integer: true)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Higher priority items are bumped first on kitchen display terminals.',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildSectionHeader('AVAILABILITY'),
                        _dropdown(
                            'Availability Mode',
                            _availabilityMode,
                            ['Always available', 'Time-based', 'Scheduled'],
                            (v) => setState(() => _availabilityMode = v)),
                        const SizedBox(height: 8),
                        _switch(
                            'Auto out-of-stock when inventory hits zero',
                            _autoOutOfStock,
                            (v) => setState(() => _autoOutOfStock = v)),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 500) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _field('Container Charges ₹ *',
                                      DishDetail.containerCharge,
                                      hint: '0',
                                      numeric: true,
                                      validator: _number('Container charges')),
                                  const SizedBox(height: 12),
                                  _portionWeightWithUnit(),
                                  const SizedBox(height: 12),
                                  _field('Profit Margin (%)',
                                      DishDetail.targetMarginPct,
                                      hint: 'e.g., 40',
                                      numeric: true,
                                      validator: _number('Margin', max: 100)),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field('Container Charges ₹ *',
                                      DishDetail.containerCharge,
                                      hint: '0',
                                      numeric: true,
                                      validator: _number('Container charges')),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _portionWeightWithUnit(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field('Profit Margin (%)',
                                      DishDetail.targetMarginPct,
                                      hint: 'e.g., 40',
                                      numeric: true,
                                      validator: _number('Margin', max: 100)),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        _buildSectionHeader('DIETARY *'),
                        _dietField(),
                        const SizedBox(height: 16),

                        // ORDER TYPE | EXPOSE THIS ITEM IN | GST TYPE * (3 Column Row matching Figma)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final col1 = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ORDER TYPE', style: _labelStyle),
                                const SizedBox(height: 6),
                                for (final o in [
                                  'Delivery',
                                  'Take Away',
                                  'Dine In'
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildCheckbox(
                                        o, _orderTypes.contains(o), (v) {
                                      setState(() => v == true
                                          ? _orderTypes.add(o)
                                          : _orderTypes.remove(o));
                                    }),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Used for the offline POS billing only',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            );
                            final col2 = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('EXPOSE THIS ITEM IN',
                                    style: _labelStyle),
                                const SizedBox(height: 6),
                                for (final exp in _exposeOptions)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildCheckbox(
                                        exp, _channels.contains(exp), (v) {
                                      setState(() => v == true
                                          ? _channels.add(exp)
                                          : _channels.remove(exp));
                                    }),
                                  ),
                              ],
                            );
                            final col3 = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GST TYPE *', style: _labelStyle),
                                const SizedBox(height: 6),
                                for (final gst in ['Services', 'Goods'])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildCheckbox(gst, _gstType == gst,
                                        (v) {
                                      if (v == true) {
                                        setState(() => _gstType = gst);
                                      }
                                    }),
                                  ),
                              ],
                            );
                            if (constraints.maxWidth < 520) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  col1,
                                  const SizedBox(height: 16),
                                  col2,
                                  const SizedBox(height: 16),
                                  col3,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: col1),
                                const SizedBox(width: 12),
                                Expanded(child: col2),
                                const SizedBox(width: 12),
                                Expanded(child: col3),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Item Schedule Section (Matching Figma)
                        _itemScheduleSection(),
                        const SizedBox(height: 20),

                        // Modifier Groups Section (Matching Figma 1:1)
                        _modifierGroupsSection(borderColor, isDark),
                      ],
                    ),
                  ),
                ),
              ),
              _footer(borderColor),
            ],
          ),
        ),
      ),
    );
  }

  static const _labelStyle =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

  Widget _titleBar(bool isDark, Color borderColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dish == null ? 'Add New Menu Item' : 'Edit Menu Item',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add rich details so customers and POS see the same dish across every channel.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      );

  Widget _footer(Color borderColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            if (_dish != null)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: ViniiColors.redSolid),
                label: const Text('Delete',
                    style: TextStyle(color: ViniiColors.redSolid)),
              ),
            const Spacer(),
            OutlinedButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Item'),
            ),
          ],
        ),
      );

  Widget _mediaSection(bool isDark, Color cardBg, Color borderColor) {
    final media = _mediaId == null ? null : _mediaIndex[_mediaId];
    Widget? preview;
    if (_pendingImage != null) {
      preview = Image.memory(_pendingImage!.$2, fit: BoxFit.cover);
    } else if (media != null) {
      preview = _mediaThumb(media);
    } else if (_imageUrl.startsWith('http')) {
      preview = Image.network(_imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.broken_image_outlined, color: Colors.grey));
    }
    final imageLabel =
        _mediaName ?? (_imageUrl.isNotEmpty ? 'Image from URL' : null);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Product Media',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildMediaTab('Image', _pendingImage != null || _mediaId != null,
                  () => _pickUpload(video: false)),
              _buildMediaTab(
                  'Video', _videoName != null, () => _pickUpload(video: true)),
              _buildMediaTab(
                  'URL',
                  _mediaId == null &&
                      _pendingImage == null &&
                      _imageUrl.isNotEmpty,
                  _pickUrl),
              _buildMediaTab('Library', false, _pickLibrary),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(8),
            child: preview == null && imageLabel == null && _videoName == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: Colors.grey[400]),
                        const SizedBox(height: 6),
                        Text(
                          'No media yet. Upload an image or video, paste a URL or pick from the library.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      if (preview != null || imageLabel != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                              width: 84,
                              height: 84,
                              child: preview ??
                                  Container(
                                      color: const Color(0xFFF3F4F6),
                                      child: const Icon(Icons.image_outlined,
                                          color: Colors.grey))),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (imageLabel != null)
                              _mediaLine(
                                  Icons.image_outlined,
                                  imageLabel,
                                  _pendingImage != null
                                      ? 'Uploads on save'
                                      : null,
                                  () => setState(() {
                                        _pendingImage = null;
                                        _mediaId = null;
                                        _mediaName = null;
                                        _imageUrl = '';
                                      })),
                            if (_videoName != null)
                              _mediaLine(
                                  Icons.videocam_outlined,
                                  _videoName!,
                                  _pendingVideo != null
                                      ? 'Uploads on save'
                                      : null,
                                  () => setState(() {
                                        _pendingVideo = null;
                                        _videoMediaId = null;
                                        _videoName = null;
                                      })),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mediaLine(
          IconData icon, String name, String? note, VoidCallback onRemove) =>
      Row(children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(note == null ? name : '$name · $note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 16),
        ),
      ]);

  Widget _dietField() => FormField<String>(
        validator: (_) => _diet == null ? 'Choose a dietary type' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dietary *', style: _labelStyle),
            Wrap(spacing: 16, children: [
              // Stored as veg / non-veg / egg; shown as Veg / Non-Veg / Egg.
              for (final d in ['veg', 'non-veg', 'egg'])
                _buildCheckbox(masterHumanLabel(d), _diet == d, (v) {
                  setState(() => _diet = v == true ? d : null);
                  state.didChange(_diet);
                }),
            ]),
            if (state.hasError)
              Text(state.errorText!,
                  style: const TextStyle(
                      fontSize: 12, color: ViniiColors.redSolid)),
          ],
        ),
      );

  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _field(String label, String key,
      {String? hint,
      bool numeric = false,
      String? Function(String?)? validator,
      Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        TextFormField(
          controller: _ctrl(key),
          style: const TextStyle(fontSize: 13),
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _inputDecoration(hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }

  /// Free-text field with a menu of values already used by other dishes.
  Widget _combo(String label, String key, List<String> options,
      {String? hint}) {
    return _field(label, key,
        hint: hint,
        suffixIcon: options.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Choose existing',
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                onSelected: (v) => setState(() => _ctrl(key).text = v),
                itemBuilder: (_) => [
                  for (final o in options)
                    PopupMenuItem(
                        value: o,
                        child: Text(o, style: const TextStyle(fontSize: 13))),
                ],
              ));
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged,
      {String Function(String)? labelOf}) {
    final opts = [...options, if (!options.contains(value)) value];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey('$label|$value'),
          initialValue: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black),
          decoration: _inputDecoration(null),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: [
            for (final o in opts)
              DropdownMenuItem(
                  value: o, child: Text(labelOf == null ? o : labelOf(o))),
          ],
        ),
      ],
    );
  }

  Widget _categoryDropdown() {
    final cats = _categories;
    return DropdownButtonFormField<String>(
      key: ValueKey('category|$_categoryKey'),
      initialValue: _category,
      isExpanded: true,
      isDense: true,
      hint: const Text('Select a section', style: TextStyle(fontSize: 13)),
      style: const TextStyle(fontSize: 13, color: Colors.black),
      decoration: _inputDecoration(null),
      validator: (v) =>
          v == null || v == _addCategory ? 'Menu section is required' : null,
      onChanged: _onCategory,
      items: [
        for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
        const DropdownMenuItem(
          value: _addCategory,
          child: Text('+ Add Category',
              style: TextStyle(
                  color: ViniiColors.emeraldText, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildTogglePill(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ViniiColors.brandGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTab(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? ViniiColors.successPillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MasterStyle.cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? ViniiColors.emeraldText : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ViniiColors.emeraldText),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
      ]);

  Widget _categoryDropdownWithAddButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Menu Section *', style: _labelStyle),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _categoryDropdown()),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _onCategory(_addCategory),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Category', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _selectedPortionUnit = 'Select...';

  Widget _portionWeightWithUnit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Weight / Portion', style: _labelStyle),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _ctrl(DishDetail.portionWeight),
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration('e.g., 250'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPortionUnit,
                isExpanded: true,
                isDense: true,
                style: const TextStyle(fontSize: 12, color: Colors.black),
                decoration: _inputDecoration(null),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPortionUnit = v);
                },
                items: ['Select...', 'g', 'kg', 'ml', 'L', 'pcs', 'serves']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isItemScheduleEnabled = false;

  Widget _itemScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isItemScheduleEnabled,
              onChanged: (v) =>
                  setState(() => _isItemScheduleEnabled = v ?? false),
              activeColor: ViniiColors.emeraldText,
            ),
            const Text(
              'Item Schedule',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            'If category scheduling is enabled, it will override item scheduling. This feature is currently supported only for offline POS billing.',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ),
        if (_isItemScheduleEnabled) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in _weekDays)
                    FilterChip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      selected: _days.contains(d),
                      visualDensity: VisualDensity.compact,
                      selectedColor: ViniiColors.successPillBg,
                      onSelected: (s) =>
                          setState(() => s ? _days.add(d) : _days.remove(d)),
                    ),
                ]),
                const SizedBox(height: 8),
                _row([
                  _timeField('Available From', 'from'),
                  _timeField('Available To', 'to'),
                  const SizedBox(),
                ]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _modifierGroupsSection(Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modifier groups',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            'Modifiers are not set up yet. Variants (portion sizes) and add-ons for this item will be managed here once modifier groups are available.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- pickers

  /// Labelled dropdown that writes the chosen value into the text
  /// controller [key] (so saving works exactly as for a text field).
  /// [items] are (stored value, label); with [addNewTitle] a "+ Add new…"
  /// entry prompts for a value that is not in the list yet.
  Widget _pickDropdown(String label, String key, List<(String, String)> items,
      {String? addNewTitle, String? addNewHint}) {
    final current = _t(key);
    final seen = <String>{};
    final unique = [
      for (final i in items)
        if (seen.add(i.$1)) i
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey('$key|$current|$_pickerGen'),
          initialValue: unique.any((i) => i.$1 == current) ? current : null,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black),
          decoration: _inputDecoration(null),
          items: [
            for (final (v, text) in unique)
              DropdownMenuItem(
                  value: v,
                  child: Text(text, overflow: TextOverflow.ellipsis)),
            if (addNewTitle != null)
              const DropdownMenuItem(
                value: _addNew,
                child: Text('+ Add new…',
                    style: TextStyle(
                        color: ViniiColors.emeraldText,
                        fontWeight: FontWeight.w600)),
              ),
          ],
          onChanged: (v) async {
            if (v != _addNew) {
              setState(() => _ctrl(key).text = v ?? '');
              return;
            }
            final name = await promptMasterText(context,
                title: addNewTitle ?? label,
                label: label,
                hint: addNewHint);
            if (!mounted) return;
            setState(() {
              if (name != null && name.isNotEmpty) {
                _ctrl(key).text = name;
              } else {
                _pickerGen++; // cancelled: show the previous value again
              }
            });
          },
        ),
      ],
    );
  }

  /// GST slab picker for the item's tax rate (stored as a number).
  Widget _taxDropdown() {
    final current = double.tryParse(_t(DishDetail.taxPct));
    final options = <double>{...masterGstSlabs, if (current != null) current};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tax (GST)', style: _labelStyle),
        const SizedBox(height: 4),
        DropdownButtonFormField<double?>(
          key: ValueKey('tax|${_t(DishDetail.taxPct)}'),
          initialValue: current,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black),
          decoration: _inputDecoration(null),
          items: [
            const DropdownMenuItem<double?>(
                value: null, child: Text('Not set')),
            for (final p in options)
              DropdownMenuItem<double?>(
                  value: p, child: Text(gstSlabLabel(p))),
          ],
          onChanged: (v) => setState(() =>
              _ctrl(DishDetail.taxPct).text = v == null ? '' : _numText(v)),
        ),
      ],
    );
  }

  /// Packaging type (stored lower case, shown with a human label).
  Widget _packagingDropdown() => _pickDropdown(
        'Packaging',
        DishDetail.packaging,
        [
          ('', 'Not set'),
          for (final p in _detailOptions(DishDetail.packaging, _packagingTypes))
            (p, masterHumanLabel(p)),
          if (_t(DishDetail.packaging).isNotEmpty)
            (_t(DishDetail.packaging),
                masterHumanLabel(_t(DishDetail.packaging))),
        ],
        addNewTitle: 'Add packaging type',
        addNewHint: 'e.g. Tray',
      );

  /// A kitchen station picked from the stations configured in Operations →
  /// KDS; a value not in that list (older data) stays selectable.
  Widget _stationPicker(String label, String key, String emptyLabel) {
    final stations = widget.kitchenStations ?? const <String>[];
    final current = _t(key);
    return _pickDropdown(label, key, [
      ('', emptyLabel),
      for (final s in stations)
        if (s.trim().isNotEmpty) (s, s),
      if (current.isNotEmpty && !stations.contains(current))
        (current, '$current (not a configured station)'),
    ]);
  }

  Widget _kitchenStationField() => widget.kitchenStations == null
      ? _combo('Kitchen Station', 'kitchen', _stations, hint: 'Unassigned')
      : _stationPicker('Kitchen Station', 'kitchen', 'Unassigned');

  Widget _kdsGroupField() => widget.kitchenStations == null
      ? _combo('KDS Group', DishDetail.kdsGroup,
          _detailOptions(DishDetail.kdsGroup),
          hint: 'Tandoor')
      : _stationPicker('KDS Group', DishDetail.kdsGroup, 'Same as station');

  /// Printer groups live on the server; offer the ones already in use.
  Widget _printerGroupField() => _pickDropdown(
        'Printer Group',
        DishDetail.printerGroup,
        [
          ('', 'None'),
          for (final g in _detailOptions(DishDetail.printerGroup)) (g, g),
          if (_t(DishDetail.printerGroup).isNotEmpty)
            (_t(DishDetail.printerGroup), _t(DishDetail.printerGroup)),
        ],
        addNewTitle: 'Add printer group',
        addNewHint: 'e.g. Hot Kitchen',
      );

  /// Time of day picked with the time picker, stored as "HH:MM".
  Widget _timeField(String label, String key) {
    final v = _t(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickTime(key),
          child: InputDecorator(
            isEmpty: v.isEmpty,
            decoration: _inputDecoration('Pick a time',
                suffixIcon: v.isEmpty
                    ? const Icon(Icons.schedule, size: 18)
                    : IconButton(
                        tooltip: 'Clear',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _ctrl(key).clear()),
                      )),
            child: Text(v, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
      String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: ViniiColors.emeraldText,
        ),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
