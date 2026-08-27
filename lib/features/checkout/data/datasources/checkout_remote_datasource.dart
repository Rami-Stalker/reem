import '../../domain/entities/checkout.dart';
import '../models/checkout_models.dart';
import '../models/order_models.dart';
import '../../../../core/shared/value_objects/money.dart';

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
  });
  Future<OrderPaymentModel> verifyPayment(String paymentId);

  Future<List<OrderSummaryModel>> getOrders({int page, int limit});
  Future<OrderDetailModel> getOrder(String id);
  Future<OrderDetailModel> cancelOrder(String id);
}
