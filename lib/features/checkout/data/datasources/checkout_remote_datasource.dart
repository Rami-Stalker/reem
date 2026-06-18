import '../../domain/entities/checkout.dart';
import '../models/checkout_models.dart';
import '../models/order_models.dart';

abstract interface class CheckoutRemoteDataSource {
  Future<List<GovernorateModel>> getGovernorates();
  Future<DeliveryQuoteModel> getDeliveryQuote(String governorate, double subtotal);
  Future<List<PaymentMethodOptionModel>> getPaymentMethods();

  Future<PlacedOrderModel> placeOrder({
    required ShippingInput shipping,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  });
  Future<OrderPaymentModel> verifyPayment(String paymentId);

  Future<List<OrderSummaryModel>> getOrders({int page, int limit});
  Future<OrderDetailModel> getOrder(String id);
  Future<OrderDetailModel> cancelOrder(String id);
}
