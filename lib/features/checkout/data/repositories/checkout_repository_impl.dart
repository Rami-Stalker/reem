import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/features/checkout/domain/repositories/checkout_repository.dart';

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
    required String idempotencyKey,
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  }) =>
      // `addressId` and `saveAddress` are forwarded, not swallowed. They used
      // to stop here: the parameters were accepted and then simply left out of
      // the call, so choosing a saved address posted `{payment_method}` alone
      // and the server answered "choose a saved address or enter a delivery
      // address" for an address the screen was already showing as chosen.
      // Every order placed from the address book failed.
      guard(() => remote.placeOrder(
            idempotencyKey: idempotencyKey,
            shipping: shipping,
            addressId: addressId,
            saveAddress: saveAddress,
            paymentMethod: paymentMethod,
            couponCode: couponCode,
            deliveryInstructions: deliveryInstructions,
            notes: notes,
            privacyMask: privacyMask,
          ));

  @override
  Future<Result<OrderPayment>> verifyPayment(String paymentId) =>
      guard(() => remote.verifyPayment(paymentId));

  @override
  Future<Result<PaymentAttempt>> retryPayment(String paymentId) =>
      guard(() => remote.retryPayment(paymentId));

  @override
  Future<Result<OrderPayment>> submitPaymentReference(
    String paymentId,
    String reference,
  ) => guard(() => remote.submitPaymentReference(paymentId, reference));

  @override
  Future<Result<OrderDetail>> confirmCodOrder(String orderId, String code) =>
      guard(() => remote.confirmCodOrder(orderId, code));

  @override
  Future<Result<CodAssurance>> resendCodConfirmation(String orderId) =>
      guard(() => remote.resendCodConfirmation(orderId));

  @override
  Future<Result<List<OrderSummary>>> getOrders({
    int page = 1,
    int limit = 20,
    String? bucket,
  }) => guard<List<OrderSummary>>(
    () => remote.getOrders(page: page, limit: limit, bucket: bucket),
  );

  @override
  Future<Result<OrderDetail>> getOrder(String id) =>
      guard(() => remote.getOrder(id));

  @override
  Future<Result<OrderDetail>> cancelOrder(String id) =>
      guard(() => remote.cancelOrder(id));
}
