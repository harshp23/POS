class OnlineOrderRow {
  const OnlineOrderRow({
    required this.orderId,
    required this.platform,
    required this.customer,
    required this.itemsLabel,
    required this.amountMinor,
    required this.status,
    required this.time,
    required this.actionLabel,
    String? displayId,
  }) : _displayId = displayId;

  /// Internal reference (`ol:<uuid>` / `pos:<uuid>` from the backend). Used
  /// only for API calls and lookups — never shown to people; show
  /// [displayId] instead.
  final String orderId;
  final String platform;
  final String customer;
  final String itemsLabel;
  final String status;
  final String time;
  final String actionLabel;
  final int amountMinor;
  final String? _displayId;

  /// The order reference people read: the backend's `display_id`
  /// (e.g. `OL-1A2B3C4D` or the POS number `ORD-248`), or a short readable
  /// form of [orderId] — never the raw `ol:<uuid>`. Empty when there is no
  /// reference at all.
  String get displayId {
    final given = _displayId?.trim() ?? '';
    if (given.isNotEmpty) return readableOrderRef(given);
    return readableOrderRef(orderId);
  }

  /// [platform] as a full name ('Zomato', 'Swiggy', 'Website', 'One Latur'),
  /// tolerating old single-letter codes ('Z', 'S', 'W').
  String get platformName => normalizePlatform(platform);

  /// [status] as words ('out_for_delivery' → 'Out for delivery').
  String get statusLabel => humanStatus(status);

  OnlineOrderRow copyWith({
    String? orderId,
    String? platform,
    String? customer,
    String? itemsLabel,
    int? amountMinor,
    String? status,
    String? time,
    String? actionLabel,
    String? displayId,
  }) {
    return OnlineOrderRow(
      orderId: orderId ?? this.orderId,
      platform: platform ?? this.platform,
      customer: customer ?? this.customer,
      itemsLabel: itemsLabel ?? this.itemsLabel,
      amountMinor: amountMinor ?? this.amountMinor,
      status: status ?? this.status,
      time: time ?? this.time,
      actionLabel: actionLabel ?? this.actionLabel,
      displayId: displayId ?? _displayId,
    );
  }

  factory OnlineOrderRow.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount_minor'] ?? json['amountMinor'] ?? 0;
    final parsedAmount =
        rawAmount is int ? rawAmount : int.tryParse(rawAmount.toString()) ?? 0;
    final rawDisplay = json['display_id'] ?? json['displayId'];

    return OnlineOrderRow(
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      displayId: rawDisplay?.toString(),
      platform: normalizePlatform((json['platform'] ?? '').toString()),
      customer: humanCustomer((json['customer'] ?? '').toString()),
      itemsLabel: (json['items_label'] ?? json['itemsLabel'] ?? '').toString(),
      amountMinor: parsedAmount,
      status: uiStatus((json['status'] ?? 'Pending').toString()),
      time: (json['time'] ?? '').toString(),
      actionLabel:
          (json['action_label'] ?? json['actionLabel'] ?? 'Accept').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'display_id': displayId,
      'platform': platform,
      'customer': customer,
      'items_label': itemsLabel,
      'amount_minor': amountMinor,
      'status': status,
      'time': time,
      'action_label': actionLabel,
    };
  }

  static final _longHex = RegExp(r'^[0-9a-f]{16,}$', caseSensitive: false);
  static final _refPrefix = RegExp(r'^([a-z_]{1,12}):(.+)$', caseSensitive: false);

  /// A short, readable order reference for [ref]: strips an internal
  /// `ol:` / `pos:` prefix and turns a UUID / long hex into `OL-` + its
  /// first 8 characters in capitals (`ol:6f1c2b8e-…` → `OL-6F1C2B8E`).
  /// Readable references (`ORD-248`, `OL-1A2B3C4D`) come back unchanged.
  static String readableOrderRef(String ref) {
    var r = ref.trim();
    if (r.isEmpty) return '';
    final prefixed = _refPrefix.firstMatch(r);
    if (prefixed != null) r = prefixed.group(2)!.trim();
    final compact = r.replaceAll('-', '');
    if (_longHex.hasMatch(compact)) {
      return 'OL-${compact.substring(0, 8).toUpperCase()}';
    }
    return r;
  }

  /// Full platform names the backend accepts / sends. Old single-letter
  /// codes from local data ('Z', 'S', 'W') map to their names.
  static String normalizePlatform(String raw) {
    final p = raw.trim();
    switch (p.toLowerCase()) {
      case 'z':
      case 'zomato':
        return 'Zomato';
      case 's':
      case 'swiggy':
        return 'Swiggy';
      case 'w':
      case 'web':
      case 'website':
      case 'online':
        return 'Website';
      case 'ol':
      case 'one latur':
      case 'one_latur':
      case 'onelatur':
        return 'One Latur';
      case 'ondc':
        return 'ONDC';
      case 'whatsapp':
        return 'WhatsApp';
      case 'qr':
        return 'QR';
      case '':
        return 'Online';
    }
    return _words(p);
  }

  static const uiStatuses = [
    'Pending',
    'Accepted',
    'Preparing',
    'Ready',
    'Dispatched',
    'Delivered',
    'Archived',
    'Cancelled',
  ];

  /// Raw order status codes (One Latur / POS) and their inbox status —
  /// mirrors the backend's mapping so a raw code never reaches the screen.
  static const _rawToUi = <String, String>{
    'placed': 'Pending',
    'created': 'Pending',
    'new': 'Pending',
    'confirmed': 'Accepted',
    'in_billing': 'Accepted',
    'sent_to_kitchen': 'Preparing',
    'awaiting_payment': 'Ready',
    'picked_up': 'Dispatched',
    'out_for_delivery': 'Dispatched',
    'completed': 'Delivered',
    'paid': 'Delivered',
    'rejected': 'Cancelled',
    'canceled': 'Cancelled',
  };

  /// [raw] as one of [uiStatuses] when it is one (in any case) or a known
  /// raw code; otherwise the code in words.
  static String uiStatus(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Pending';
    final lower = s.toLowerCase();
    for (final ui in uiStatuses) {
      if (ui.toLowerCase() == lower) return ui;
    }
    return _rawToUi[lower] ?? _words(s);
  }

  /// A status for people: inbox statuses unchanged, anything else as words
  /// ('out_for_delivery' → 'Out for delivery').
  static String humanStatus(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Pending';
    if (uiStatuses.contains(s)) return s;
    return _words(s);
  }

  static final _hashLike = RegExp(r'^(?:[a-z0-9]{1,10}:)?[0-9a-f]{16,}$',
      caseSensitive: false);

  /// The customer's name, or 'Guest' when there is none or the value is a
  /// hash / UUID rather than a name.
  static String humanCustomer(String raw) {
    final c = raw.trim();
    if (c.isEmpty) return 'Guest';
    if (_hashLike.hasMatch(c.replaceAll('-', ''))) return 'Guest';
    return c;
  }

  /// 'out_for_delivery' → 'Out for delivery'; values that already read as
  /// words (with capitals or spaces) are kept.
  static String _words(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.contains('_') && !s.contains('-') && s != s.toLowerCase()) {
      return s;
    }
    if (s.contains(' ') && !s.contains('_')) return s;
    final spaced = s.replaceAll(RegExp(r'[_-]+'), ' ').trim().toLowerCase();
    if (spaced.isEmpty) return s;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class LocalOnlineOrdersCatalog {
  static const platforms = [
    'All Platforms',
    'Zomato',
    'Swiggy',
    'Website',
    'One Latur',
  ];

  /// Platforms an order can be entered for by hand — exactly the values
  /// the backend accepts (`POST v1/operations/online-orders`).
  static const newOrderPlatforms = ['Zomato', 'Swiggy', 'Website'];
}
