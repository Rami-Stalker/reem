import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/domain/usecases/checkout_usecases.dart';

/// The four piles a shopper thinks in, mirroring the server's `ORDER_BUCKETS`.
///
/// The profile screen counts orders into these; the wire name is what
/// `GET /orders?bucket=` expects, so the tile she taps and the list she lands
/// on are filtered by the same rule.
enum OrderBucket {
  pending,
  processing,
  delivered,
  cancelled;

  String get wire => name;

  static OrderBucket? fromWire(String? value) {
    for (final bucket in OrderBucket.values) {
      if (bucket.wire == value) return bucket;
    }
    return null;
  }
}

class OrdersState {
  const OrdersState({
    this.isLoading = false,
    this.orders = const [],
    this.error,
    this.bucket,
  });

  final bool isLoading;
  final List<OrderSummary> orders;
  final String? error;

  /// Null means every order.
  final OrderBucket? bucket;

  bool get isEmpty => !isLoading && orders.isEmpty;

  OrdersState copyWith({
    bool? isLoading,
    List<OrderSummary>? orders,
    String? error,
    OrderBucket? bucket,
    bool clearError = false,
    bool clearBucket = false,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      error: clearError ? null : (error ?? this.error),
      bucket: clearBucket ? null : (bucket ?? this.bucket),
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier({required GetOrdersUseCase getOrders, OrderBucket? bucket})
    : _getOrders = getOrders,
      super(OrdersState(bucket: bucket));

  final GetOrdersUseCase _getOrders;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getOrders(bucket: state.bucket?.wire);
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, orders: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  /// Switches pile — «قيد التنفيذ», «مكتملة», … — and reloads.
  Future<void> select(OrderBucket? bucket) async {
    if (bucket == state.bucket) return;
    state = state.copyWith(bucket: bucket, clearBucket: bucket == null);
    await load();
  }

  Future<void> refresh() => load();
}
