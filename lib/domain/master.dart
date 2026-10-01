import 'dart:typed_data';

import 'inventory.dart';

/// Master-module domain types that are not inventory: offers, media and
/// recipes. Recipes consume raw materials from the common Inventory
/// domain (lib/domain/inventory.dart) — they never hold their own stock.

class MasterOffer {
  const MasterOffer({
    required this.id,
    required this.title,
    required this.code,
    required this.campaignType,
    required this.discountRule,
    required this.status,
    this.minOrder = 0,
    this.maxDiscount = 0,
    this.startDate,
    this.endDate,
    this.channels = '',
    this.linkedItems = '',
    this.usageCount = 0,
  });
  final String id;
  final String title;
  final String code;
  final String campaignType;
  final String discountRule;
  final String status;
  final double minOrder;
  final double maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String channels;
  final String linkedItems;
  final int usageCount;

  String get dateRange => startDate == null
      ? 'Not Scheduled'
      : '${formatShortDate(startDate!)} - '
          '${endDate == null ? 'Open' : formatShortDate(endDate!)}';

  MasterOffer copyWith({
    String? id,
    String? title,
    String? code,
    String? campaignType,
    String? discountRule,
    String? status,
    double? minOrder,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    String? channels,
    String? linkedItems,
    int? usageCount,
  }) =>
      MasterOffer(
        id: id ?? this.id,
        title: title ?? this.title,
        code: code ?? this.code,
        campaignType: campaignType ?? this.campaignType,
        discountRule: discountRule ?? this.discountRule,
        status: status ?? this.status,
        minOrder: minOrder ?? this.minOrder,
        maxDiscount: maxDiscount ?? this.maxDiscount,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        channels: channels ?? this.channels,
        linkedItems: linkedItems ?? this.linkedItems,
        usageCount: usageCount ?? this.usageCount,
      );
}

class MediaAssetRecord {
  const MediaAssetRecord({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.folder,
    required this.createdAt,
    this.sizeBytes = 0,
    this.usageLabel = '',
    this.imageUrl,
    this.bytes,
  });
  final String id;
  final String fileName;
  final String fileType;
  final String folder;
  final int sizeBytes;
  final String usageLabel;
  final String? imageUrl;
  final Uint8List? bytes;
  final DateTime createdAt;

  bool get isVideo => fileType.toLowerCase().contains('video');

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

class RecipeLine {
  const RecipeLine({
    required this.name,
    required this.qty,
    required this.unit,
    this.id,
    this.materialId,
    this.wastagePct = 0,
    this.fallbackUnitCost = 0,
    this.isKey = false,
    this.substitute = '',
  });
  final int? id;
  final String? materialId;
  final String name;

  /// Per portion, in the raw material's own unit (kg / L / pcs).
  final double qty;
  final String unit;
  final double wastagePct;
  final double fallbackUnitCost;
  final bool isKey;
  final String substitute;

  /// Quantity including wastage.
  double get grossQty => qty * (1 + wastagePct / 100);

  /// Cost per portion, priced from the linked raw material when there is
  /// one, so a supplier price change flows straight into recipe costs.
  double costWith(RawMaterial? material) =>
      grossQty * (material?.purchaseCostPerUnit ?? fallbackUnitCost);
}

class Recipe {
  const Recipe({
    required this.id,
    required this.code,
    required this.name,
    this.version = 'v1.0',
    this.linkedMenuItemId,
    this.linkedMenuItemName = '',
    this.category = '',
    this.portion = '',
    this.targetPrice = 0,
    this.laborCost = 0,
    this.packagingCost = 0,
    this.trialResult = 'Pending',
    this.trainingDone = 0,
    this.trainingTotal = 0,
    this.status = 'Draft',
    this.prepMethod = '',
    this.allergens = '',
    this.activeChannels = '',
    this.lines = const [],
  });
  final String id;
  final String code;
  final String name;
  final String version;
  final String? linkedMenuItemId;
  final String linkedMenuItemName;
  final String category;
  final String portion;
  final double targetPrice;
  final double laborCost;
  final double packagingCost;
  final String trialResult;
  final int trainingDone;
  final int trainingTotal;
  final String status;
  final String prepMethod;
  final String allergens;
  final String activeChannels;
  final List<RecipeLine> lines;

  /// The linked dish's name as it is now, looked up by id in [dishNames]
  /// (dish id → current name). Falls back to the name copied when the dish
  /// was linked (e.g. the dish was since deleted); empty when not linked.
  String linkedDishName(Map<String, String> dishNames) {
    final id = linkedMenuItemId;
    if (id == null) return linkedMenuItemName;
    return dishNames[id] ?? linkedMenuItemName;
  }

  double ingredientCost(Map<String, RawMaterial> materials) => lines.fold(
      0,
      (s, l) =>
          s +
          l.costWith(l.materialId == null ? null : materials[l.materialId]));

  double totalCost(Map<String, RawMaterial> materials) =>
      ingredientCost(materials) + laborCost + packagingCost;

  double marginPct(Map<String, RawMaterial> materials) => targetPrice <= 0
      ? 0
      : (targetPrice - totalCost(materials)) / targetPrice * 100;

  Recipe copyWith({
    String? name,
    String? code,
    String? version,
    String? linkedMenuItemId,
    String? linkedMenuItemName,
    String? category,
    String? portion,
    double? targetPrice,
    double? laborCost,
    double? packagingCost,
    String? trialResult,
    int? trainingDone,
    int? trainingTotal,
    String? status,
    String? prepMethod,
    String? allergens,
    String? activeChannels,
    List<RecipeLine>? lines,
  }) =>
      Recipe(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        version: version ?? this.version,
        linkedMenuItemId: linkedMenuItemId ?? this.linkedMenuItemId,
        linkedMenuItemName: linkedMenuItemName ?? this.linkedMenuItemName,
        category: category ?? this.category,
        portion: portion ?? this.portion,
        targetPrice: targetPrice ?? this.targetPrice,
        laborCost: laborCost ?? this.laborCost,
        packagingCost: packagingCost ?? this.packagingCost,
        trialResult: trialResult ?? this.trialResult,
        trainingDone: trainingDone ?? this.trainingDone,
        trainingTotal: trainingTotal ?? this.trainingTotal,
        status: status ?? this.status,
        prepMethod: prepMethod ?? this.prepMethod,
        allergens: allergens ?? this.allergens,
        activeChannels: activeChannels ?? this.activeChannels,
        lines: lines ?? this.lines,
      );
}
