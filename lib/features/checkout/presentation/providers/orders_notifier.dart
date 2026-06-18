import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/order.dart';
import '../../domain/usecases/checkout_usecases.dart';

class OrdersState {
  const OrdersState({this.isLoading = false, this.orders = const [], this.error});

  final bool isLoading;
  final List<OrderSummary> orders;
  final String? error;

  bool get isEmpty => !isLoading && orders.isEmpty;

  OrdersState copyWith({
    bool? isLoading,
    List<OrderSummary>? orders,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier({required GetOrdersUseCase getOrders})
      : _getOrders = getOrders,
        super(const OrdersState());

  final GetOrdersUseCase _getOrders;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getOrders();
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, orders: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> refresh() => load();
}
