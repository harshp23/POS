class MasterDishItem {
  final String id;
  final String name;
  final String category;
  final double sellingPrice;
  final double foodCost;
  final double marginPercent;
  final String availability;
  final List<String> channels;
  final String kitchenStation;
  final String status;
  final String sku;
  final String hsn;
  final String imageUrl;
  final bool isVeg;
  final bool isNonVeg;
  final bool isEgg;

  /// Remaining Add/Edit Item form fields (short name, barcode, prep time,
  /// tax %, packaging, order types, …). Persisted as JSON.
  final Map<String, Object?> details;

  const MasterDishItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    required this.foodCost,
    required this.marginPercent,
    required this.availability,
    required this.channels,
    required this.kitchenStation,
    required this.status,
    required this.sku,
    required this.hsn,
    required this.imageUrl,
    this.isVeg = true,
    this.isNonVeg = false,
    this.isEgg = false,
    this.details = const {},
  });

  MasterDishItem copyWith({
    String? name,
    String? category,
    double? sellingPrice,
    double? foodCost,
    String? availability,
    List<String>? channels,
    String? kitchenStation,
    String? status,
    String? sku,
    String? hsn,
    String? imageUrl,
    bool? isVeg,
    bool? isNonVeg,
    bool? isEgg,
    Map<String, Object?>? details,
  }) {
    final price = sellingPrice ?? this.sellingPrice;
    final cost = foodCost ?? this.foodCost;
    return MasterDishItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      sellingPrice: price,
      foodCost: cost,
      marginPercent: price > 0 ? (price - cost) / price * 100 : 0,
      availability: availability ?? this.availability,
      channels: channels ?? this.channels,
      kitchenStation: kitchenStation ?? this.kitchenStation,
      status: status ?? this.status,
      sku: sku ?? this.sku,
      hsn: hsn ?? this.hsn,
      imageUrl: imageUrl ?? this.imageUrl,
      isVeg: isVeg ?? this.isVeg,
      isNonVeg: isNonVeg ?? this.isNonVeg,
      isEgg: isEgg ?? this.isEgg,
      details: details ?? this.details,
    );
  }
}

class MasterMediaAsset {
  final String id;
  final String fileName;
  final String fileType;
  final String fileSize;
  final String usageLabel;
  final String imageUrl;
  final String folder;

  const MasterMediaAsset({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.usageLabel,
    required this.imageUrl,
    required this.folder,
  });
}

class MasterOfferItem {
  final String id;
  final String title;
  final String code;
  final String discountType;
  final String discountValue;
  final String validUntil;
  final String status;
  final int usageCount;

  const MasterOfferItem({
    required this.id,
    required this.title,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.validUntil,
    required this.status,
    required this.usageCount,
  });
}

class MasterSupplierItem {
  final String id;
  final String name;
  final String category;
  final String contactPerson;
  final String phone;
  final String email;
  final String city;
  final String rating;
  final String status;

  const MasterSupplierItem({
    required this.id,
    required this.name,
    required this.category,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.city,
    required this.rating,
    required this.status,
  });
}

class MasterPurchaseOrder {
  final String poNumber;
  final String supplierName;
  final String orderDate;
  final String expectedDelivery;
  final double totalAmount;
  final String status;
  final int itemsCount;

  const MasterPurchaseOrder({
    required this.poNumber,
    required this.supplierName,
    required this.orderDate,
    required this.expectedDelivery,
    required this.totalAmount,
    required this.status,
    required this.itemsCount,
  });
}

class MasterCatalogData {
  static const List<MasterDishItem> sampleDishes = [
    MasterDishItem(
      id: 'dish-1',
      name: 'Paneer Butter Masala',
      category: 'MAIN COURSE',
      sellingPrice: 340.0,
      foodCost: 102.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy'],
      kitchenStation: 'North Indian Curry Counter',
      status: 'Active',
      sku: 'IN-PBM-009',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish-2',
      name: 'Gulab Jamun (2 pcs)',
      category: 'DESSERTS',
      sellingPrice: 120.0,
      foodCost: 24.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'Dine-In Only'],
      kitchenStation: 'Dessert Counter',
      status: 'Active',
      sku: 'IN-GJ-012',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish-3',
      name: 'Chicken Tikka Masala',
      category: 'MAIN COURSE',
      sellingPrice: 380.0,
      foodCost: 114.0,
      marginPercent: 70.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy'],
      kitchenStation: 'North Indian Curry Counter',
      status: 'Active',
      sku: 'IN-CTM-018',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=500',
      isVeg: false,
      isNonVeg: true,
    ),
    MasterDishItem(
      id: 'dish-4',
      name: 'Mango Lassi (V3)',
      category: 'BEVERAGES',
      sellingPrice: 180.0,
      foodCost: 36.0,
      marginPercent: 80.0,
      availability: 'Seasonal',
      channels: ['POS', 'App', 'Web'],
      kitchenStation: 'Beverage Bar',
      status: 'Active',
      sku: 'IN-DR-042',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1553787499-6f9133860278?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish-5',
      name: 'Palak Paneer',
      category: 'MAIN COURSE',
      sellingPrice: 310.0,
      foodCost: 96.0,
      marginPercent: 69.0,
      availability: 'In Stock',
      channels: ['POS', 'Zomato', 'Swiggy'],
      kitchenStation: 'North Indian Curry Counter',
      status: 'Active',
      sku: 'IN-PP-022',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish-6',
      name: 'Garlic Naan',
      category: 'BREADS',
      sellingPrice: 140.0,
      foodCost: 28.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'Dine-In'],
      kitchenStation: 'Tandoor Counter',
      status: 'Active',
      sku: 'IN-BR-031',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=500',
      isVeg: true,
    ),
    MasterDishItem(
      id: 'dish-7',
      name: 'Jalebi (2 pcs)',
      category: 'DESSERTS',
      sellingPrice: 90.0,
      foodCost: 18.0,
      marginPercent: 80.0,
      availability: 'In Stock',
      channels: ['POS', 'Dine-In'],
      kitchenStation: 'Salad & Dessert Bar',
      status: 'Active',
      sku: 'IN-SD-048',
      hsn: '21069099',
      imageUrl:
          'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=500',
      isVeg: true,
    ),
  ];

  static const List<MasterMediaAsset> sampleMedia = [
    MasterMediaAsset(
      id: 'media-1',
      fileName: 'paneer_raw.png',
      fileType: 'PNG Image',
      fileSize: '2.4 MB',
      usageLabel: 'Paneer Butter Masala',
      imageUrl:
          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=500',
      folder: 'Covers & Dishes',
    ),
    MasterMediaAsset(
      id: 'media-2',
      fileName: 'lassi_glass.jpg',
      fileType: 'JPG Image',
      fileSize: '1.8 MB',
      usageLabel: 'Mango Lassi (V3)',
      imageUrl:
          'https://images.unsplash.com/photo-1553787499-6f9133860278?w=500',
      folder: 'Drinks & Beverages',
    ),
    MasterMediaAsset(
      id: 'media-3',
      fileName: 'latur_kitchen.mp4',
      fileType: 'MP4 Video',
      fileSize: '45.0 MB',
      usageLabel: 'Hygiene Standard',
      imageUrl:
          'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=500',
      folder: 'Kitchen Prep Tutorials',
    ),
    MasterMediaAsset(
      id: 'media-4',
      fileName: 'garlic_naan.jpg',
      fileType: 'JPG Image',
      fileSize: '1.1 MB',
      usageLabel: 'Garlic Naan',
      imageUrl:
          'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=500',
      folder: 'Covers & Dishes',
    ),
  ];

  static const List<MasterOfferItem> sampleOffers = [
    MasterOfferItem(
      id: 'off-1',
      title: 'Flat 20% Off on Main Course',
      code: 'FEAST20',
      discountType: 'Percentage',
      discountValue: '20%',
      validUntil: '31 Oct 2026',
      status: 'Active',
      usageCount: 142,
    ),
    MasterOfferItem(
      id: 'off-2',
      title: 'Free Mango Lassi on orders > ₹500',
      code: 'FREEDRINK',
      discountType: 'Free Item',
      discountValue: 'Mango Lassi',
      validUntil: '15 Nov 2026',
      status: 'Active',
      usageCount: 89,
    ),
    MasterOfferItem(
      id: 'off-3',
      title: 'Weekend Dine-In Fest ₹100 Flat',
      code: 'WEEKEND100',
      discountType: 'Flat Amount',
      discountValue: '₹100',
      validUntil: '05 Dec 2026',
      status: 'Scheduled',
      usageCount: 0,
    ),
  ];

  static const List<MasterSupplierItem> sampleSuppliers = [
    MasterSupplierItem(
      id: 'sup-1',
      name: 'Amul Dairy Co-op',
      category: 'Dairy & Milk Products',
      contactPerson: 'Suresh Patel',
      phone: '+91 98230 11223',
      email: 'suresh@amuldairy.com',
      city: 'Anand / Latur',
      rating: '4.9 ★',
      status: 'Verified',
    ),
    MasterSupplierItem(
      id: 'sup-2',
      name: 'National Spice Traders',
      category: 'Spices & Condiments',
      contactPerson: 'Ramesh Verma',
      phone: '+91 98765 43210',
      email: 'sales@nationalspices.in',
      city: 'Mumbai',
      rating: '4.7 ★',
      status: 'Verified',
    ),
    MasterSupplierItem(
      id: 'sup-3',
      name: 'Fresh Farm Agro Produce',
      category: 'Fresh Vegetables & Herbs',
      contactPerson: 'Karan Deshmukh',
      phone: '+91 94221 88990',
      email: 'karan@freshfarm.co.in',
      city: 'Pune',
      rating: '4.8 ★',
      status: 'Verified',
    ),
  ];

  static const List<MasterPurchaseOrder> samplePurchaseOrders = [
    MasterPurchaseOrder(
      poNumber: 'PO-2026-0891',
      supplierName: 'Amul Dairy Co-op',
      orderDate: '24 Sep 2026',
      expectedDelivery: '27 Sep 2026',
      totalAmount: 24500.0,
      status: 'In Transit',
      itemsCount: 8,
    ),
    MasterPurchaseOrder(
      poNumber: 'PO-2026-0890',
      supplierName: 'National Spice Traders',
      orderDate: '22 Sep 2026',
      expectedDelivery: '25 Sep 2026',
      totalAmount: 14200.0,
      status: 'Delivered',
      itemsCount: 15,
    ),
    MasterPurchaseOrder(
      poNumber: 'PO-2026-0889',
      supplierName: 'Fresh Farm Agro Produce',
      orderDate: '26 Sep 2026',
      expectedDelivery: '28 Sep 2026',
      totalAmount: 8900.0,
      status: 'Approved',
      itemsCount: 12,
    ),
  ];
}
