import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/presentation/providers/core_providers.dart';
import '../../data/datasources/checkout_remote_datasource.dart';
import '../../data/datasources/impl/checkout_remote_datasource_impl.dart';
import '../../data/repositories/checkout_repository_impl.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/usecases/checkout_usecases.dart';
import 'checkout_controller.dart';
import 'order_detail_notifier.dart';
import 'orders_notifier.dart';

final checkoutRemoteDataSourceProvider = Provider<CheckoutRemoteDataSource>(
  (ref) => CheckoutRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepositoryImpl(ref.watch(checkoutRemoteDataSourceProvider)),
);

final getGovernoratesUseCaseProvider =
    Provider((ref) => GetGovernoratesUseCase(ref.watch(checkoutRepositoryProvider)));
final getDeliveryQuoteUseCaseProvider =
    Provider((ref) => GetDeliveryQuoteUseCase(ref.watch(checkoutRepositoryProvider)));
final getPaymentMethodsUseCaseProvider =
    Provider((ref) => GetPaymentMethodsUseCase(ref.watch(checkoutRepositoryProvider)));
final placeOrderUseCaseProvider =
    Provider((ref) => PlaceOrderUseCase(ref.watch(checkoutRepositoryProvider)));
final verifyPaymentUseCaseProvider =
    Provider((ref) => VerifyPaymentUseCase(ref.watch(checkoutRepositoryProvider)));
final getOrdersUseCaseProvider =
    Provider((ref) => GetOrdersUseCase(ref.watch(checkoutRepositoryProvider)));
final getOrderUseCaseProvider =
    Provider((ref) => GetOrderUseCase(ref.watch(checkoutRepositoryProvider)));
final cancelOrderUseCaseProvider =
    Provider((ref) => CancelOrderUseCase(ref.watch(checkoutRepositoryProvider)));

final ordersNotifierProvider =
    StateNotifierProvider.autoDispose<OrdersNotifier, OrdersState>(
  (ref) => OrdersNotifier(getOrders: ref.watch(getOrdersUseCaseProvider))..load(),
);

final orderDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<OrderDetailNotifier, OrderDetailState, String>((ref, id) {
  return OrderDetailNotifier(
    orderId: id,
    getOrder: ref.watch(getOrderUseCaseProvider),
    cancelOrder: ref.watch(cancelOrderUseCaseProvider),
    verifyPayment: ref.watch(verifyPaymentUseCaseProvider),
  )..load();
});

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutState>((ref) {
  return CheckoutController(
    getGovernorates: ref.watch(getGovernoratesUseCaseProvider),
    getPaymentMethods: ref.watch(getPaymentMethodsUseCaseProvider),
    getDeliveryQuote: ref.watch(getDeliveryQuoteUseCaseProvider),
    placeOrder: ref.watch(placeOrderUseCaseProvider),
    verifyPayment: ref.watch(verifyPaymentUseCaseProvider),
  )..init();
});
