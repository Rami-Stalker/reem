import 'package:reem/core/result/result.dart';

import '../entities/checkout.dart';
import '../entities/order.dart';
import '../../../../core/shared/value_objects/money.dart';

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
  });
  Future<Result<OrderPayment>> verifyPayment(String paymentId);

  // Orders
  Future<Result<List<OrderSummary>>> getOrders({int page, int limit});
  Future<Result<OrderDetail>> getOrder(String id);
  Future<Result<OrderDetail>> cancelOrder(String id);
}
