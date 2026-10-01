/// Operations domain (restaurant admin → Operations). These are *views*
/// over the same records the POS already writes — restaurant_tables,
/// orders/order_lines, kitchen_tickets, payments — plus the few things the
/// POS has no record for yet (deliveries, reservations, QR ordering).
/// Nothing here duplicates POS data: a table seated in Dine In, an order
/// taken in Captain Orders, its KOT on the kitchen screen and the bill
/// settled in POS Billing are the same rows end to end.
library;

import 'order_audit.dart';
import 'payment.dart';

export 'order_audit.dart' show OrderAuditEntry;
export 'payment.dart' show OrderPaymentState;

/// Table states shown on the floor plan. `billing` is the POS's
/// "payment pending" flag layered over an occupied table.
enum OpsTableStatus { available, occupied, reserved, billing, cleaning }

extension OpsTableStatusLabel on OpsTableStatus {
  String get label => switch (this) {
        OpsTableStatus.available => 'Available',
        OpsTableStatus.occupied => 'Occupied',
        OpsTableStatus.reserved => 'Reserved',
        OpsTableStatus.billing => 'Payment Pending',
        OpsTableStatus.cleaning => 'Cleaning',
      };
}

class OpsTable {
  const OpsTable({
    required this.id,
    required this.label,
    required this.seats,
    required this.floor,
    required this.status,
    this.shape = 'square',
    this.guests,
    this.serverName = '',
    this.seatedAt,
    this.currentOrderId,
    this.reservedByName,
    this.reservedAt,
    this.lastCleanedAt,
  });
  final String id;
  final String label;
  final int seats;
  final DateTime? lastCleanedAt;
  final String floor;
  final OpsTableStatus status;
  final String shape; // 'square' | 'round'
  final int? guests;
  final String serverName;
  final DateTime? seatedAt;
  final String? currentOrderId;
  final String? reservedByName;
  final DateTime? reservedAt;

  int? elapsedMinutes(DateTime now) =>
      seatedAt == null ? null : now.difference(seatedAt!).inMinutes;
}

/// Where an order came from / how it is served.
enum OpsChannel { dineIn, takeaway, delivery }

extension OpsChannelLabel on OpsChannel {
  String get label => switch (this) {
        OpsChannel.dineIn => 'Dine-In',
        OpsChannel.takeaway => 'Takeaway',
        OpsChannel.delivery => 'Delivery',
      };
}

/// Operational lifecycle of an order (separate from the sync status the
/// POS keeps in orders.status).
enum OpsOrderStatus { open, billed, settled, cancelled }

extension OpsOrderStatusLabel on OpsOrderStatus {
  /// The status in words people use (All Orders shows a settled order
  /// as Completed).
  String get label => switch (this) {
        OpsOrderStatus.open => 'Open',
        OpsOrderStatus.billed => 'Billed',
        OpsOrderStatus.settled => 'Completed',
        OpsOrderStatus.cancelled => 'Cancelled',
      };
}

class OpsOrderLine {
  const OpsOrderLine({
    required this.itemId,
    required this.name,
    required this.unitMinor,
    required this.quantity,
    this.station = 'Main Kitchen',
    this.isVeg = true,
    this.done = false,
  });
  final String itemId;
  final String name;
  final int unitMinor;
  final int quantity;
  final String station;
  final bool isVeg;

  /// Marked prepared on the kitchen display.
  final bool done;

  int get totalMinor => unitMinor * quantity;

  OpsOrderLine copyWith({int? quantity, bool? done}) => OpsOrderLine(
      itemId: itemId,
      name: name,
      unitMinor: unitMinor,
      quantity: quantity ?? this.quantity,
      station: station,
      isVeg: isVeg,
      done: done ?? this.done);
}

/// The payment row recorded against an order (POS `payments` table — one
/// row per order; never overwritten).
class OpsPaymentRecord {
  const OpsPaymentRecord({
    required this.paymentId,
    required this.method,
    required this.amountMinor,
    required this.receivedMinor,
    required this.recordedAt,
  });
  final String paymentId;

  /// 'cash', 'card', 'upi' or a split text ('split: cash ₹120 + upi ₹80').
  final String method;
  final int amountMinor;
  final int receivedMinor;
  final DateTime recordedAt;

  bool get needsVerification => tenderNeedsVerification(method);
}

/// Where the kitchen is with an order, from its KOTs.
enum OpsKitchenState {
  /// Not sent to the kitchen yet (a held order).
  notSent,

  /// A KOT is waiting for the kitchen to start.
  queued,
  preparing,
  ready,

  /// Every KOT served / handed over.
  served,
}

extension OpsKitchenStateLabel on OpsKitchenState {
  String get label => switch (this) {
        OpsKitchenState.notSent => 'Not sent',
        OpsKitchenState.queued => 'Waiting for kitchen',
        OpsKitchenState.preparing => 'Preparing',
        OpsKitchenState.ready => 'Ready',
        OpsKitchenState.served => 'Served',
      };
}

final _databaseId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false);

/// True for a server database id (a UUID), which means nothing to people.
bool isDatabaseId(String s) => _databaseId.hasMatch(s);

/// "ORD-248" (the server's number) or the device key; a database id falls
/// back to a short reference until the number arrives.
String orderNumberLabel(String id, String? displayNo) {
  final n = displayNo?.trim() ?? '';
  if (n.isNotEmpty && !isDatabaseId(n)) return n;
  if (!isDatabaseId(id)) return id;
  return 'Order ${id.substring(0, 6).toUpperCase()}';
}

/// "KOT #37" (the server's number) or the device key; a database id falls
/// back to a short reference until the number arrives.
String kotNumberLabel(String ticketId, int? kotNo) {
  if (kotNo != null) return 'KOT #$kotNo';
  if (!isDatabaseId(ticketId)) return ticketId;
  return 'KOT ${ticketId.substring(0, 6).toUpperCase()}';
}

class OpsOrder {
  const OpsOrder({
    required this.id,
    required this.channel,
    required this.status,
    required this.createdAt,
    required this.lines,
    this.tableLabel,
    this.guests,
    this.serverName = '',
    this.source = 'POS',
    this.notes = '',
    this.discountPct = 0,
    this.taxPct = 5,
    this.billNo,
    this.paymentMethod,
    this.settledAt,
    this.customerName = '',
    this.payment,
    this.kotStatuses = const [],
    this.auditLog = const [],
    this.syncStatus = '',
    this.syncNeedsReview = false,
    this.displayNo,
  });
  final String id;

  /// The order's number on the server ("ORD-248"), set by sync.
  final String? displayNo;

  /// The order number people see: the server's number once synced, else
  /// this device's own key ("ORD-A1B2-7"). A database id is never shown.
  String get number => orderNumberLabel(id, displayNo);
  final String customerName;
  final OpsChannel channel;
  final OpsOrderStatus status;
  final DateTime createdAt;
  final List<OpsOrderLine> lines;
  final String? tableLabel;
  final int? guests;
  final String serverName;
  final String source; // POS, Captain, QR, Online

  /// Kitchen / guest notes as typed. Correction audit lines stored in the
  /// same column are split off into [auditLog].
  final String notes;
  final double discountPct;

  /// GST % stored on the order (orders.tax_pct, default 5). Tax is
  /// computed on the discounted subtotal; no other tax rules are applied.
  final double taxPct;
  final int? billNo;
  final String? paymentMethod;
  final DateTime? settledAt;

  /// The recorded payment, if any.
  final OpsPaymentRecord? payment;

  /// Statuses of this order's KOTs, oldest first (empty = not sent).
  final List<OpsKotStatus> kotStatuses;

  /// Corrections (cancel, void, discount, verification, reprint), oldest
  /// first — see order_audit.dart.
  final List<OrderAuditEntry> auditLog;

  /// The POS's own sync status (orders.status): pendingUpload,
  /// synchronized or needsReview.
  final String syncStatus;

  /// The backend refused the last upload of this order (conflict /
  /// rejected) — it needs a person to look at it.
  final bool syncNeedsReview;

  /// Amounts in integer paise. Discount and tax are each rounded to the
  /// nearest paisa: discount = subtotal × discount% ; tax = (subtotal −
  /// discount) × tax%.
  int get subtotalMinor => lines.fold(0, (s, l) => s + l.totalMinor);
  int get discountMinor => (subtotalMinor * discountPct / 100).round();
  int get taxMinor => ((subtotalMinor - discountMinor) * taxPct / 100).round();
  int get grandTotalMinor => subtotalMinor - discountMinor + taxMinor;
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);

  bool get sentToKitchen => kotStatuses.isNotEmpty;

  /// An open order that was saved without a KOT ("Save & Hold").
  bool get isHeld => status == OpsOrderStatus.open && !sentToKitchen;

  bool get isActive =>
      status == OpsOrderStatus.open || status == OpsOrderStatus.billed;

  OpsKitchenState get kitchenState {
    if (kotStatuses.isEmpty) return OpsKitchenState.notSent;
    if (kotStatuses.contains(OpsKotStatus.newTicket)) {
      return kotStatuses.contains(OpsKotStatus.preparing)
          ? OpsKitchenState.preparing
          : OpsKitchenState.queued;
    }
    if (kotStatuses.contains(OpsKotStatus.preparing)) {
      return OpsKitchenState.preparing;
    }
    if (kotStatuses.contains(OpsKotStatus.ready)) return OpsKitchenState.ready;
    return OpsKitchenState.served;
  }

  OrderPaymentState get paymentState => derivePaymentState(
      settled: status == OpsOrderStatus.settled,
      recordedMethod: payment?.method);

  /// "Unpaid", "Paid · Cash", "UPI · pending verification", …
  String get paymentLabel {
    final m = payment?.method ?? paymentMethod;
    final method = m == null ? null : paymentMethodLabel(m);
    return switch (paymentState) {
      OrderPaymentState.unpaid =>
        status == OpsOrderStatus.cancelled ? 'No payment' : 'Unpaid',
      OrderPaymentState.pendingVerification =>
        '${method ?? 'Payment'} · pending verification',
      OrderPaymentState.paid => method == null ? 'Paid' : 'Paid · $method',
    };
  }

  /// "Table 4", the customer name, or the channel.
  String get displayName {
    if (tableLabel != null && channel == OpsChannel.dineIn) {
      return customerName.isEmpty ? tableLabel! : '$tableLabel · $customerName';
    }
    return customerName.isEmpty
        ? (channel == OpsChannel.takeaway ? 'Walk-in' : channel.label)
        : customerName;
  }
}

/// Kitchen ticket states — same vocabulary as the POS's
/// KitchenTicketStatus (newTicket → preparing → ready → completed).
enum OpsKotStatus { newTicket, preparing, ready, completed }

extension OpsKotStatusLabel on OpsKotStatus {
  String get label => switch (this) {
        OpsKotStatus.newTicket => 'New',
        OpsKotStatus.preparing => 'Preparing',
        OpsKotStatus.ready => 'Ready',
        OpsKotStatus.completed => 'Served',
      };
}

class OpsKot {
  const OpsKot({
    required this.ticketId,
    required this.order,
    required this.status,
    required this.createdAt,
    this.notes = '',
    this.urgent = false,
    this.kotNo,
  });
  final String ticketId;

  /// The KOT number the server gave this ticket, set by sync.
  final int? kotNo;

  /// The ticket's name for people: "KOT #37" once the server has numbered
  /// it, else this device's own key ("KOT-A1B2-3").
  String get label => kotNumberLabel(ticketId, kotNo);
  final OpsOrder order;
  final OpsKotStatus status;
  final DateTime createdAt;
  final String notes;
  final bool urgent;

  int ageMinutes(DateTime now) => now.difference(createdAt).inMinutes;

  /// A ticket not yet ready after this long is shown as Delayed.
  static const delayedAfterMinutes = 20;
  bool isDelayed(DateTime now) =>
      (status == OpsKotStatus.newTicket || status == OpsKotStatus.preparing) &&
      ageMinutes(now) >= delayedAfterMinutes;

  int get doneCount => order.lines.where((l) => l.done).length;

  /// The order was cancelled after this ticket was sent. The ticket keeps
  /// its status (the backend's KOT statuses have no "cancelled"), but it
  /// is out of the kitchen queue and shown as "Order cancelled".
  bool get orderCancelled => order.status == OpsOrderStatus.cancelled;

  /// When the order was cancelled (from its audit trail), if known.
  DateTime? get cancelledAt {
    for (final e in order.auditLog.reversed) {
      if (e.text.startsWith('Cancelled')) return e.at;
    }
    return null;
  }
}

/// A table on the POS Dine In board: the floor status layered with where
/// its current order is (kitchen, bill).
enum DineInBoardStatus {
  available,
  reserved,

  /// Guests seated, no order yet.
  seated,

  /// Order taken but not sent, or its KOT not started by the kitchen.
  waitingKot,
  preparing,

  /// Food ready to serve.
  ready,

  /// Everything served; guests eating.
  served,

  /// Bill generated, waiting for payment.
  paymentPending,
  cleaning,
}

extension DineInBoardStatusLabel on DineInBoardStatus {
  String get label => switch (this) {
        DineInBoardStatus.available => 'Available',
        DineInBoardStatus.reserved => 'Reserved',
        DineInBoardStatus.seated => 'Seated',
        DineInBoardStatus.waitingKot => 'Waiting KOT',
        DineInBoardStatus.preparing => 'Preparing',
        DineInBoardStatus.ready => 'Ready',
        DineInBoardStatus.served => 'Served',
        DineInBoardStatus.paymentPending => 'Payment Pending',
        DineInBoardStatus.cleaning => 'Cleaning',
      };
}

/// [order] is the table's current order (restaurant_tables.current_order_id),
/// null when it has none.
DineInBoardStatus deriveDineInBoardStatus(
    OpsTableStatus tableStatus, OpsOrder? order) {
  if (order == null || !order.isActive) {
    return switch (tableStatus) {
      OpsTableStatus.available => DineInBoardStatus.available,
      OpsTableStatus.reserved => DineInBoardStatus.reserved,
      OpsTableStatus.cleaning => DineInBoardStatus.cleaning,
      OpsTableStatus.billing => DineInBoardStatus.paymentPending,
      OpsTableStatus.occupied => DineInBoardStatus.seated,
    };
  }
  if (order.status == OpsOrderStatus.billed ||
      tableStatus == OpsTableStatus.billing) {
    return DineInBoardStatus.paymentPending;
  }
  return switch (order.kitchenState) {
    OpsKitchenState.notSent ||
    OpsKitchenState.queued =>
      DineInBoardStatus.waitingKot,
    OpsKitchenState.preparing => DineInBoardStatus.preparing,
    OpsKitchenState.ready => DineInBoardStatus.ready,
    OpsKitchenState.served => DineInBoardStatus.served,
  };
}

enum DeliveryStatus {
  unassigned,
  assigned,
  pickedUp,
  inTransit,
  delivered,
  failed
}

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.unassigned => 'Unassigned',
        DeliveryStatus.assigned => 'Assigned',
        DeliveryStatus.pickedUp => 'Picked Up',
        DeliveryStatus.inTransit => 'In Transit',
        DeliveryStatus.delivered => 'Delivered',
        DeliveryStatus.failed => 'Failed',
      };
}

class OpsDelivery {
  const OpsDelivery({
    required this.id,
    required this.orderId,
    required this.merchant,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.riderName,
    this.etaMinutes,
    this.distanceKm = 0,
    this.customerName = '',
    this.address = '',
    this.promisedAt,
  });
  final String id;
  final String orderId;
  final String merchant;
  final DeliveryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? riderName;
  final int? etaMinutes;
  final double distanceKm;
  final String customerName;
  final String address;

  /// Promised delivery time; past it while still open = Delayed.
  final DateTime? promisedAt;

  bool get isOpen =>
      status != DeliveryStatus.delivered && status != DeliveryStatus.failed;
  bool isDelayed(DateTime now) =>
      isOpen && promisedAt != null && now.isAfter(promisedAt!);
  int delayMinutes(DateTime now) =>
      promisedAt == null ? 0 : now.difference(promisedAt!).inMinutes;
}

enum ReservationStatus {
  pending,
  confirmed,
  seated,
  completed,
  noShow,
  cancelled
}

extension ReservationStatusLabel on ReservationStatus {
  String get label => switch (this) {
        ReservationStatus.pending => 'Pending',
        ReservationStatus.confirmed => 'Confirmed',
        ReservationStatus.seated => 'Seated',
        ReservationStatus.completed => 'Completed',
        ReservationStatus.noShow => 'No-show',
        ReservationStatus.cancelled => 'Cancelled',
      };
}

class OpsReservation {
  const OpsReservation({
    required this.id,
    required this.guestName,
    required this.phone,
    required this.guests,
    required this.dateTime,
    required this.status,
    this.email = '',
    this.tableId,
    this.notes = '',
  });
  final String id;
  final String guestName;
  final String phone;
  final String email;
  final int guests;
  final DateTime dateTime;
  final ReservationStatus status;
  final String? tableId;
  final String notes;

  /// "+91 98765 *****" — phone numbers are masked in lists.
  String get maskedPhone {
    final digits = phone.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (digits.length <= 6) return digits;
    return '${digits.substring(0, digits.length - 5)}*****';
  }

  String get initials {
    final parts = guestName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}

class QrTableCode {
  const QrTableCode({
    required this.tableId,
    required this.tableLabel,
    required this.enabled,
    required this.token,
    this.lastScannedAt,
  });
  final String tableId;
  final String tableLabel;
  final bool enabled;

  /// Changes when codes are regenerated (old printed codes stop working).
  final String token;
  final DateTime? lastScannedAt;
}

enum QrSessionStatus { browsing, ordering, paymentPending, completed, closed }

extension QrSessionStatusLabel on QrSessionStatus {
  String get label => switch (this) {
        QrSessionStatus.browsing => 'Browsing',
        QrSessionStatus.ordering => 'Ordering',
        QrSessionStatus.paymentPending => 'Payment Pending',
        QrSessionStatus.completed => 'Completed',
        QrSessionStatus.closed => 'Closed',
      };
}

class QrSession {
  const QrSession({
    required this.id,
    required this.tableLabel,
    required this.guests,
    required this.startedAt,
    required this.status,
    this.orderId,
    this.itemCount = 0,
    this.totalMinor = 0,
  });
  final String id;
  final String tableLabel;
  final int guests;
  final DateTime startedAt;
  final QrSessionStatus status;
  final String? orderId;
  final int itemCount;
  final int totalMinor;
}

/// "12:15 PM"
String formatClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "5 min ago", "2h ago", "3.8h ago" style relative time.
String formatAgo(DateTime then, DateTime now) {
  final mins = now.difference(then).inMinutes;
  if (mins < 1) return 'just now';
  if (mins < 60) return '$mins min ago';
  final hours = mins / 60;
  return hours == hours.roundToDouble()
      ? '${hours.round()}h ago'
      : '${hours.toStringAsFixed(1)}h ago';
}

/// Kitchen stations shown on the KDS, in display order.
const kitchenStations = ['Tandoor', 'Main Kitchen', 'Beverages', 'Desserts'];

/// Routes a menu item to a kitchen station from its Master kitchen
/// station / category (e.g. "Tandoor Counter" → Tandoor, BEVERAGES →
/// Beverages). Unknown items go to Main Kitchen.
String stationForDish(String category, String kitchenStation) {
  final s = '$kitchenStation $category'.toLowerCase();
  if (s.contains('tandoor') || s.contains('bread')) return 'Tandoor';
  if (s.contains('beverage') || s.contains('drink') || s.contains('bar')) {
    return 'Beverages';
  }
  if (s.contains('dessert') || s.contains('sweet')) return 'Desserts';
  return 'Main Kitchen';
}

/// A kitchen station as configured in the KDS "Kitchen Stations" dialog.
class KitchenStation {
  const KitchenStation({
    required this.name,
    this.targetMinutes = 15,
    this.colorValue = 0xFF76EC00,
    this.active = true,
  });
  final String name;

  /// SLA: tickets older than this are Delayed on this station.
  final int targetMinutes;
  final int colorValue;
  final bool active;

  Map<String, Object> toJson() => {
        'name': name,
        'targetMinutes': targetMinutes,
        'colorValue': colorValue,
        'active': active,
      };

  static KitchenStation fromJson(Map<String, dynamic> j) => KitchenStation(
        name: j['name'] as String,
        targetMinutes: (j['targetMinutes'] as num?)?.toInt() ?? 15,
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF76EC00,
        active: j['active'] as bool? ?? true,
      );
}

const defaultKitchenStations = [
  KitchenStation(name: 'Tandoor', targetMinutes: 5),
  KitchenStation(name: 'Main Kitchen', targetMinutes: 15),
  KitchenStation(name: 'Beverages', targetMinutes: 5),
  KitchenStation(name: 'Desserts', targetMinutes: 10),
];

/// KDS "Sound & Alerts" preferences.
class KdsAlertSettings {
  const KdsAlertSettings({
    this.soundsEnabled = true,
    this.volume = 0.8,
    this.newOrder = true,
    this.priority = true,
    this.delayed = true,
    this.ready = true,
  });
  final bool soundsEnabled;
  final double volume;
  final bool newOrder, priority, delayed, ready;

  KdsAlertSettings copyWith({
    bool? soundsEnabled,
    double? volume,
    bool? newOrder,
    bool? priority,
    bool? delayed,
    bool? ready,
  }) =>
      KdsAlertSettings(
        soundsEnabled: soundsEnabled ?? this.soundsEnabled,
        volume: volume ?? this.volume,
        newOrder: newOrder ?? this.newOrder,
        priority: priority ?? this.priority,
        delayed: delayed ?? this.delayed,
        ready: ready ?? this.ready,
      );

  Map<String, Object> toJson() => {
        'soundsEnabled': soundsEnabled,
        'volume': volume,
        'newOrder': newOrder,
        'priority': priority,
        'delayed': delayed,
        'ready': ready,
      };

  static KdsAlertSettings fromJson(Map<String, dynamic> j) => KdsAlertSettings(
        soundsEnabled: j['soundsEnabled'] as bool? ?? true,
        volume: (j['volume'] as num?)?.toDouble() ?? 0.8,
        newOrder: j['newOrder'] as bool? ?? true,
        priority: j['priority'] as bool? ?? true,
        delayed: j['delayed'] as bool? ?? true,
        ready: j['ready'] as bool? ?? true,
      );
}

/// People's names for the payment method keys the POS, the Operations
/// screens and the server use.
const _paymentMethodNames = {
  'cash': 'Cash',
  'card': 'Card',
  'upi': 'UPI',
  'split': 'Split',
  'wallet': 'Wallet',
  'due': 'Due (pay later)',
  'credit': 'Credit (pay later)',
  'other': 'Other',
  'online': 'Online',
  'netbanking': 'Net banking',
  'net_banking': 'Net banking',
  'bank_transfer': 'Bank transfer',
  'cheque': 'Cheque',
  'complimentary': 'Complimentary',
  'gpay': 'Google Pay',
  'google_pay': 'Google Pay',
  'phonepe': 'PhonePe',
  'paytm': 'Paytm',
  'unrecorded': 'Not recorded',
};

/// Display label for a stored payment method key ('cash', 'upi',
/// 'split: cash ₹x + upi ₹y' …). An unknown key is shown in words
/// ("bank_card" → "Bank card"), never as the raw code.
String paymentMethodLabel(String method) {
  final m = method.trim();
  final key = m.toLowerCase();
  final known = _paymentMethodNames[key];
  if (known != null) return known;
  if (key.startsWith('split')) {
    return 'Split${m.length > 5 ? m.substring(5) : ''}'.replaceAllMapped(
        RegExp(r'\b(cash|card|upi|wallet|due|other)\b', caseSensitive: false),
        (x) => _paymentMethodNames[x.group(1)!.toLowerCase()]!);
  }
  if (m.isEmpty) return 'Not recorded';
  final words = m.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return words.isEmpty
      ? 'Other'
      : '${words[0].toUpperCase()}${words.substring(1).toLowerCase()}';
}
