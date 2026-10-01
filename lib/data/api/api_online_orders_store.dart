import 'dart:async';

import 'package:flutter/foundation.dart';

import '../online_orders_store.dart';
import 'api_client.dart';

/// Online orders through the Proviyaa backend
/// (GET/POST /v1/operations/online-orders). The backend merges One Latur
/// marketplace orders (ol_orders) with Swiggy / Zomato / website orders
/// (orders.channel) into one inbox. Status changes are written centrally;
/// "reject" cancels the order — a shared order is never deleted.
///
/// There is no realtime socket to the database from the app any more, so
/// the inbox refreshes by polling every [pollEvery].
class ApiOnlineOrdersStore implements OnlineOrdersStore {
  ApiOnlineOrdersStore(this.api,
      {this.pollEvery = const Duration(seconds: 15), bool autoStart = true}) {
    if (autoStart) init();
  }

  final ProviyaaApiClient api;
  final Duration pollEvery;
  final _controller = StreamController<OnlineOrdersState>.broadcast();
  final Map<String, OnlineOrderRow> _byId = {};
  Timer? _timer;
  bool _disposed = false;

  OnlineOrdersState _state = const OnlineOrdersState.loading();
  @override
  OnlineOrdersState get state => _state;

  void _emit(OnlineOrdersState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  List<OnlineOrderRow> get _rows => _byId.values.toList();

  Future<void> init() async {
    await _load(showLoading: true);
    _timer?.cancel();
    _timer = Timer.periodic(pollEvery, (_) => _load());
  }

  Future<void> _load({bool showLoading = false}) async {
    if (_disposed) return;
    if (showLoading) _emit(const OnlineOrdersState.loading());
    try {
      final data = await api.get('v1/operations/online-orders') as List;
      _byId
        ..clear()
        ..addEntries(data.map((raw) {
          final row =
              OnlineOrderRow.fromJson((raw as Map).cast<String, dynamic>());
          return MapEntry(row.orderId, row);
        }));
      _emit(OnlineOrdersState.success(_rows));
    } on ApiException catch (e) {
      debugPrint('Online orders refresh failed: $e');
      // Keep showing the last good list on a failed background refresh.
      if (showLoading || !_state.isSuccess) {
        _emit(OnlineOrdersState.error(e.isNetwork
            ? 'Cannot reach the Proviyaa server. Check the connection; orders will reload automatically.'
            : e.message));
      }
    } catch (e) {
      // An unexpected reply — never show its raw text to people.
      debugPrint('Online orders refresh failed: $e');
      if (showLoading || !_state.isSuccess) {
        _emit(const OnlineOrdersState.error(
            'Online orders could not be loaded — please try again.'));
      }
    }
  }

  @override
  Stream<OnlineOrdersState> watchState() async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Stream<List<OnlineOrderRow>> watchOrders() async* {
    yield _rows;
    yield* _controller.stream.map((s) => s.orders);
  }

  @override
  Future<List<OnlineOrderRow>> getOrders() async => _rows;

  /// Creates the order centrally and returns the server's row, whose
  /// [OnlineOrderRow.displayId] is the reference people see (e.g.
  /// `ORD-248`). The platform is sent by its full name ('Zomato',
  /// 'Swiggy', 'Website') — the only values the backend accepts.
  @override
  Future<OnlineOrderRow> insertOrder(OnlineOrderRow order) async {
    final res = await api.post('v1/operations/online-orders', {
      'platform': OnlineOrderRow.normalizePlatform(order.platform),
      'customer': order.customer,
      'items_label': order.itemsLabel,
      'amount_minor': order.amountMinor,
    });
    OnlineOrderRow? created;
    if (res is Map) {
      final json = res.cast<String, dynamic>();
      if (json['order_id'] != null) {
        created = OnlineOrderRow.fromJson(json);
      } else if (json['id'] != null) {
        // The backend sent the central order itself, not the inbox row.
        final displayNo = json['display_no'] ?? json['display_id'];
        created = order.copyWith(
          orderId: 'pos:${json['id']}',
          platform: OnlineOrderRow.normalizePlatform(order.platform),
          displayId: displayNo?.toString(),
        );
      }
    }
    await _load();
    if (created != null) return _byId[created.orderId] ?? created;
    return order.copyWith(
        platform: OnlineOrderRow.normalizePlatform(order.platform));
  }

  @override
  Future<void> updateStatus(
      String orderId, String newStatus, String newActionLabel) async {
    final row = await api.post(
        'v1/operations/online-orders/${Uri.encodeComponent(orderId)}/status',
        {'status': newStatus});
    if (row is Map) {
      final updated = OnlineOrderRow.fromJson(row.cast<String, dynamic>());
      _byId[updated.orderId] = updated;
      _emit(OnlineOrdersState.success(_rows));
    } else {
      await _load();
    }
  }

  /// Rejecting an online order cancels it centrally.
  @override
  Future<void> deleteOrder(String orderId) async {
    await api.delete(
        'v1/operations/online-orders/${Uri.encodeComponent(orderId)}');
    await _load();
  }

  @override
  Future<void> refresh() => _load();

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}
