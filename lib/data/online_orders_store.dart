import 'dart:async';

import 'local_online_orders_catalog.dart';

export 'local_online_orders_catalog.dart' show OnlineOrderRow;

enum OrdersLoadStatus {
  loading,
  success,
  error,
}

class OnlineOrdersState {
  const OnlineOrdersState({
    required this.status,
    required this.orders,
    this.errorMessage,
  });

  const OnlineOrdersState.loading()
      : status = OrdersLoadStatus.loading,
        orders = const [],
        errorMessage = null;

  const OnlineOrdersState.success(this.orders)
      : status = OrdersLoadStatus.success,
        errorMessage = null;

  const OnlineOrdersState.error(this.errorMessage)
      : status = OrdersLoadStatus.error,
        orders = const [];

  final OrdersLoadStatus status;
  final List<OnlineOrderRow> orders;
  final String? errorMessage;

  bool get isLoading => status == OrdersLoadStatus.loading;
  bool get isSuccess => status == OrdersLoadStatus.success;
  bool get isError => status == OrdersLoadStatus.error;
  bool get isEmpty => isSuccess && orders.isEmpty;
}

abstract class OnlineOrdersStore {
  OnlineOrdersState get state;
  Stream<OnlineOrdersState> watchState();
  Stream<List<OnlineOrderRow>> watchOrders();
  Future<List<OnlineOrderRow>> getOrders();

  /// Saves a new order and returns the row as stored — with the reference
  /// people read ([OnlineOrderRow.displayId]) that the store assigned.
  Future<OnlineOrderRow> insertOrder(OnlineOrderRow order);
  Future<void> updateStatus(
      String orderId, String newStatus, String newActionLabel);
  Future<void> deleteOrder(String orderId);
  Future<void> refresh();
}

/// In-memory implementation used for hermetic testing without Supabase credentials.
/// Never seeds dummy data; starts with whatever list is provided (default empty).
class InMemoryOnlineOrdersStore implements OnlineOrdersStore {
  InMemoryOnlineOrdersStore({List<OnlineOrderRow>? initialOrders}) {
    if (initialOrders != null) {
      for (final o in initialOrders) {
        _ordersById[o.orderId] = o;
      }
    }
    _emit();
  }

  final Map<String, OnlineOrderRow> _ordersById = {};
  final _stateController = StreamController<OnlineOrdersState>.broadcast();

  @override
  OnlineOrdersState get state =>
      OnlineOrdersState.success(_ordersById.values.toList());

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Stream<OnlineOrdersState> watchState() async* {
    yield state;
    yield* _stateController.stream;
  }

  @override
  Stream<List<OnlineOrderRow>> watchOrders() async* {
    yield _ordersById.values.toList();
    yield* _stateController.stream.map((s) => s.orders);
  }

  @override
  Future<List<OnlineOrderRow>> getOrders() async {
    return _ordersById.values.toList();
  }

  /// An order without an [OnlineOrderRow.orderId] gets a readable local
  /// reference (e.g. `ZOM-1001`); the platform is always stored by its full
  /// name ('Zomato', not 'Z').
  @override
  Future<OnlineOrderRow> insertOrder(OnlineOrderRow order) async {
    var row = order.copyWith(
        platform: OnlineOrderRow.normalizePlatform(order.platform));
    if (row.orderId.trim().isEmpty) {
      final ref = _nextLocalRef(row.platformName);
      row = row.copyWith(orderId: ref, displayId: ref);
    }
    _ordersById[row.orderId] = row;
    _emit();
    return row;
  }

  int _localSeq = 1000;

  String _nextLocalRef(String platform) {
    const prefixes = {
      'Zomato': 'ZOM',
      'Swiggy': 'SWG',
      'Website': 'WEB',
      'One Latur': 'OL',
    };
    final prefix = prefixes[platform] ?? 'ONL';
    String ref;
    do {
      _localSeq++;
      ref = '$prefix-$_localSeq';
    } while (_ordersById.containsKey(ref));
    return ref;
  }

  @override
  Future<void> updateStatus(
      String orderId, String newStatus, String newActionLabel) async {
    final existing = _ordersById[orderId];
    if (existing != null) {
      _ordersById[orderId] = existing.copyWith(
        status: newStatus,
        actionLabel: newActionLabel,
      );
      _emit();
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    _ordersById.remove(orderId);
    _emit();
  }

  @override
  Future<void> refresh() async {
    _emit();
  }

  void dispose() {
    _stateController.close();
  }
}
