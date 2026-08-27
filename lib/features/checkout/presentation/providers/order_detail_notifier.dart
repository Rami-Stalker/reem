import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/domain/usecases/checkout_usecases.dart';

class OrderDetailState {
  const OrderDetailState({
    this.isLoading = false,
    this.order,
    this.error,
    this.isActing = false,
  });

  final bool isLoading;
  final OrderDetail? order;
  final String? error;
  final bool isActing;

  OrderDetailState copyWith({
    bool? isLoading,
    OrderDetail? order,
    String? error,
    bool? isActing,
    bool clearError = false,
  }) {
    return OrderDetailState(
      isLoading: isLoading ?? this.isLoading,
      order: order ?? this.order,
      error: clearError ? null : (error ?? this.error),
      isActing: isActing ?? this.isActing,
    );
  }
}

class OrderDetailNotifier extends StateNotifier<OrderDetailState> {
  OrderDetailNotifier({
    required this.orderId,
    required GetOrderUseCase getOrder,
    required CancelOrderUseCase cancelOrder,
    required VerifyPaymentUseCase verifyPayment,
  })  : _getOrder = getOrder,
        _cancelOrder = cancelOrder,
        _verifyPayment = verifyPayment,
        super(const OrderDetailState());

  final String orderId;
  final GetOrderUseCase _getOrder;
  final CancelOrderUseCase _cancelOrder;
  final VerifyPaymentUseCase _verifyPayment;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getOrder(orderId);
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, order: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<bool> cancel() async {
    state = state.copyWith(isActing: true, clearError: true);
    final result = await _cancelOrder(orderId);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(isActing: false, order: data);
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isActing: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<bool> verifyPayment() async {
    final payment = state.order?.payment;
    if (payment == null) return false;
    state = state.copyWith(isActing: true, clearError: true);
    final result = await _verifyPayment(payment.id);
    if (result case Error(:final failure)) {
      state = state.copyWith(isActing: false, error: failure.message);
      return false;
    }
    await load();
    state = state.copyWith(isActing: false);
    return true;
  }
}
