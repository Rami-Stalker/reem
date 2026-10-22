import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:reem/features/checkout/data/datasources/impl/checkout_remote_datasource_impl.dart';
import 'package:reem/features/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:reem/features/checkout/domain/usecases/checkout_usecases.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_controller.dart';
import 'package:reem/features/checkout/presentation/providers/order_detail_notifier.dart';
import 'package:reem/features/checkout/presentation/providers/orders_notifier.dart';

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
/// The rails on offer, with the transfer instructions finance set — read by
/// the payment card on an order so she sees who to pay after placing it too.
final paymentMethodsCatalogProvider =
    FutureProvider.autoDispose<List<PaymentMethodOption>>((ref) async {
      final result = await ref
          .watch(checkoutRepositoryProvider)
          .getPaymentMethods();
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });
final placeOrderUseCaseProvider =
    Provider((ref) => PlaceOrderUseCase(ref.watch(checkoutRepositoryProvider)));
final confirmCodOrderUseCaseProvider =
    Provider((ref) => ConfirmCodOrderUseCase(ref.watch(checkoutRepositoryProvider)));
final resendCodConfirmationUseCaseProvider = Provider(
  (ref) => ResendCodConfirmationUseCase(ref.watch(checkoutRepositoryProvider)),
);
final retryPaymentUseCaseProvider = Provider(
  (ref) => RetryPaymentUseCase(ref.watch(checkoutRepositoryProvider)),
);

final submitPaymentReferenceUseCaseProvider = Provider(
  (ref) => SubmitPaymentReferenceUseCase(ref.watch(checkoutRepositoryProvider)),
);

final verifyPaymentUseCaseProvider =
    Provider((ref) => VerifyPaymentUseCase(ref.watch(checkoutRepositoryProvider)));
final getOrdersUseCaseProvider =
    Provider((ref) => GetOrdersUseCase(ref.watch(checkoutRepositoryProvider)));
final getOrderUseCaseProvider =
    Provider((ref) => GetOrderUseCase(ref.watch(checkoutRepositoryProvider)));
final cancelOrderUseCaseProvider =
    Provider((ref) => CancelOrderUseCase(ref.watch(checkoutRepositoryProvider)));

/// Her orders, filtered to one pile — or to all of them when the family key is
/// null. Keyed so opening «ملغاة» from the profile does not disturb the
/// unfiltered list behind it.
final ordersNotifierProvider = StateNotifierProvider.autoDispose
    .family<OrdersNotifier, OrdersState, OrderBucket?>(
      (ref, bucket) => OrdersNotifier(
        getOrders: ref.watch(getOrdersUseCaseProvider),
        bucket: bucket,
      )..load(),
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
