import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/checkout.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/checkout_remote_datasource.dart';

class CheckoutRepositoryImpl
    with RepositoryHandler
    implements CheckoutRepository {
  const CheckoutRepositoryImpl(this.remote);

  final CheckoutRemoteDataSource remote;

  @override
  Future<Result<List<Governorate>>> getGovernorates() =>
      guard<List<Governorate>>(() => remote.getGovernorates());

  @override
  Future<Result<DeliveryQuote>> getDeliveryQuote({
    required String governorate,
    double subtotal = 0,
  }) =>
      guard(() => remote.getDeliveryQuote(governorate, subtotal));

  @override
  Future<Result<List<PaymentMethodOption>>> getPaymentMethods() =>
      guard<List<PaymentMethodOption>>(() => remote.getPaymentMethods());

  @override
  Future<Result<PlacedOrder>> placeOrder({
    required ShippingInput shipping,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  }) =>
      guard(() => remote.placeOrder(
            shipping: shipping,
            paymentMethod: paymentMethod,
            couponCode: couponCode,
            deliveryInstructions: deliveryInstructions,
            notes: notes,
          ));

  @override
  Future<Result<OrderPayment>> verifyPayment(String paymentId) =>
      guard(() => remote.verifyPayment(paymentId));

  @override
  Future<Result<List<OrderSummary>>> getOrders({int page = 1, int limit = 20}) =>
      guard<List<OrderSummary>>(() => remote.getOrders(page: page, limit: limit));

  @override
  Future<Result<OrderDetail>> getOrder(String id) =>
      guard(() => remote.getOrder(id));

  @override
  Future<Result<OrderDetail>> cancelOrder(String id) =>
      guard(() => remote.cancelOrder(id));
}
