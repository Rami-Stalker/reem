import 'package:reem/core/result/result.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';

abstract interface class CheckoutRepository {
  // Checkout options
  Future<Result<List<Governorate>>> getGovernorates();
  Future<Result<DeliveryQuote>> getDeliveryQuote({
    required String governorate,
    Money? subtotal,
    String? district,
    bool isRural,
  });
  Future<Result<List<PaymentMethodOption>>> getPaymentMethods();

  // Placing + paying
  Future<Result<PlacedOrder>> placeOrder({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  });
  Future<Result<OrderPayment>> verifyPayment(String paymentId);

  /// Re-opens the gateway and returns the link to send her to.
  Future<Result<PaymentAttempt>> retryPayment(String paymentId);

  /// Records the transfer reference for a bank or hawala payment.
  Future<Result<OrderPayment>> submitPaymentReference(
    String paymentId,
    String reference,
  );

  // Cash-on-delivery confirmation
  Future<Result<OrderDetail>> confirmCodOrder(String orderId, String code);
  Future<Result<CodAssurance>> resendCodConfirmation(String orderId);

  // Orders
  Future<Result<List<OrderSummary>>> getOrders({int page, int limit, String? bucket});
  Future<Result<OrderDetail>> getOrder(String id);
  Future<Result<OrderDetail>> cancelOrder(String id);
}
