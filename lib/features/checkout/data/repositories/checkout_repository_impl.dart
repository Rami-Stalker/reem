import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/domain/repositories/checkout_repository.dart';

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
    Money? subtotal,
    String? district,
    bool isRural = false,
  }) =>
      guard(() => remote.getDeliveryQuote(governorate, subtotal));

  @override
  Future<Result<List<PaymentMethodOption>>> getPaymentMethods() =>
      guard<List<PaymentMethodOption>>(() => remote.getPaymentMethods());

  @override
  Future<Result<PlacedOrder>> placeOrder({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
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
