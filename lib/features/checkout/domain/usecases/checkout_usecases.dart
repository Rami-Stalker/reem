import 'package:reem/core/result/result.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/domain/repositories/checkout_repository.dart';

class GetGovernoratesUseCase {
  const GetGovernoratesUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<Governorate>>> call() => _repo.getGovernorates();
}

class GetDeliveryQuoteUseCase {
  const GetDeliveryQuoteUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<DeliveryQuote>> call(
    String governorate,
    Money? subtotal, {
    String? district,
    bool isRural = false,
  }) => _repo.getDeliveryQuote(
    governorate: governorate,
    subtotal: subtotal,
    district: district,
    isRural: isRural,
  );
}

class GetPaymentMethodsUseCase {
  const GetPaymentMethodsUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<PaymentMethodOption>>> call() => _repo.getPaymentMethods();
}

class PlaceOrderUseCase {
  const PlaceOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<PlacedOrder>> call({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  }) =>
      _repo.placeOrder(
        shipping: shipping,
        addressId: addressId,
        saveAddress: saveAddress,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        deliveryInstructions: deliveryInstructions,
        notes: notes,
        privacyMask: privacyMask,
      );
}

/// Releases a cash order the trust engine held for a confirmation code.
class ConfirmCodOrderUseCase {
  const ConfirmCodOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderDetail>> call(String orderId, String code) =>
      _repo.confirmCodOrder(orderId, code);
}

class ResendCodConfirmationUseCase {
  const ResendCodConfirmationUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<CodAssurance>> call(String orderId) =>
      _repo.resendCodConfirmation(orderId);
}

class VerifyPaymentUseCase {
  const VerifyPaymentUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderPayment>> call(String paymentId) =>
      _repo.verifyPayment(paymentId);
}

class RetryPaymentUseCase {
  const RetryPaymentUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<PaymentAttempt>> call(String paymentId) =>
      _repo.retryPayment(paymentId);
}

class SubmitPaymentReferenceUseCase {
  const SubmitPaymentReferenceUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderPayment>> call(String paymentId, String reference) =>
      _repo.submitPaymentReference(paymentId, reference);
}

class GetOrdersUseCase {
  const GetOrdersUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<OrderSummary>>> call({
    int page = 1,
    int limit = 20,
    String? bucket,
  }) => _repo.getOrders(page: page, limit: limit, bucket: bucket);
}

class GetOrderUseCase {
  const GetOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderDetail>> call(String id) => _repo.getOrder(id);
}

class CancelOrderUseCase {
  const CancelOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderDetail>> call(String id) => _repo.cancelOrder(id);
}
