import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../checkout_remote_datasource.dart';
import '../../../domain/entities/checkout.dart';
import '../../models/checkout_models.dart';
import '../../models/order_models.dart';

final class CheckoutRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CheckoutRemoteDataSource {
  const CheckoutRemoteDataSourceImpl(super.dio);

  @override
  Future<List<GovernorateModel>> getGovernorates() async {
    final list = await getList(ApiEndpoints.deliveryGovernorates);
    return list
        .map((e) => GovernorateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DeliveryQuoteModel> getDeliveryQuote(
    String governorate,
    double subtotal,
  ) async {
    final json = await postJson(
      ApiEndpoints.deliveryQuote,
      body: {'governorate': governorate, 'subtotal': subtotal},
    );
    return DeliveryQuoteModel.fromJson(json);
  }

  @override
  Future<List<PaymentMethodOptionModel>> getPaymentMethods() async {
    final list = await getList(ApiEndpoints.paymentMethodsCatalog);
    return list
        .map((e) => PaymentMethodOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlacedOrderModel> placeOrder({
    required ShippingInput shipping,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  }) async {
    final json = await postJson(
      ApiEndpoints.ordersCheckout,
      body: {
        'shipping': {
          'recipient_name': shipping.recipientName,
          'recipient_phone': shipping.recipientPhone,
          'governorate': shipping.governorate,
          'city': shipping.city,
          'address_line': shipping.addressLine,
          if (shipping.landmark != null && shipping.landmark!.isNotEmpty)
            'landmark': shipping.landmark,
        },
        // Backend expects the uppercase enum value.
        'payment_method': paymentMethod.toUpperCase(),
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        if (deliveryInstructions != null && deliveryInstructions.isNotEmpty)
          'delivery_instructions': deliveryInstructions,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return PlacedOrderModel.fromJson(json);
  }

  @override
  Future<OrderPaymentModel> verifyPayment(String paymentId) async {
    final json = await postJson(ApiEndpoints.paymentVerify(paymentId));
    return OrderPaymentModel.fromJson(json);
  }

  @override
  Future<List<OrderSummaryModel>> getOrders({int page = 1, int limit = 20}) async {
    final json = await getJson(
      ApiEndpoints.orders,
      query: {'page': page, 'limit': limit},
    );
    return (json['data'] as List? ?? [])
        .map((e) => OrderSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderDetailModel> getOrder(String id) async {
    final json = await getJson(ApiEndpoints.orderById(id));
    return OrderDetailModel.fromJson(json);
  }

  @override
  Future<OrderDetailModel> cancelOrder(String id) async {
    final json = await postJson(ApiEndpoints.orderCancel(id));
    return OrderDetailModel.fromJson(json);
  }
}
