import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/data/models/checkout_models.dart';
import 'package:reem/features/checkout/data/models/order_models.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';

abstract interface class CheckoutRemoteDataSource {
  Future<List<GovernorateModel>> getGovernorates();
  Future<DeliveryQuoteModel> getDeliveryQuote(String governorate, Money? subtotal);
  Future<List<PaymentMethodOptionModel>> getPaymentMethods();

  Future<PlacedOrderModel> placeOrder({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  });
  Future<OrderPaymentModel> verifyPayment(String paymentId);

  Future<PaymentAttempt> retryPayment(String paymentId);

  Future<OrderPaymentModel> submitPaymentReference(
    String paymentId,
    String reference,
  );

  /// Reads back the code that releases a held cash order.
  Future<OrderDetailModel> confirmCodOrder(String orderId, String code);

  /// Sends the code again, and returns the fresh challenge metadata.
  Future<CodAssuranceModel> resendCodConfirmation(String orderId);

  Future<List<OrderSummaryModel>> getOrders({int page, int limit, String? bucket});
  Future<OrderDetailModel> getOrder(String id);
  Future<OrderDetailModel> cancelOrder(String id);
}
