import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../../../../core/shared/value_objects/money.dart';
import '../../../domain/entities/checkout.dart';
import '../../models/checkout_models.dart';
import '../../models/order_models.dart';
import '../checkout_remote_datasource.dart';

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
    Money? subtotal, {
    String? district,
    bool isRural = false,
  }) async {
    final json = await postJson(
      ApiEndpoints.deliveryQuote,
      body: {
        'governorate': governorate,
        // Q53 P2 — the two tiers. Without these every rural delivery was
        // quoted, charged and settled at the city-centre price.
        if (district != null && district.isNotEmpty) 'district': district,
        'is_rural': isRural,
        // The decimal string, not a float — see Money.
        if (subtotal != null) ...{
          'subtotal': subtotal.raw,
          'currency': subtotal.currency.wire,
        },
      },
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
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  }) async {
    final json = await postJson(
      ApiEndpoints.ordersCheckout,
      body: {
        if (addressId != null) 'address_id': addressId,
        if (saveAddress) 'save_address': true,
        if (shipping != null)
          'shipping': {
          'recipient_name': shipping.recipientName,
          'recipient_phone': shipping.recipientPhone,
          'governorate': shipping.governorate,
          if (shipping.district != null && shipping.district!.isNotEmpty)
            'district': shipping.district,
          'is_rural': shipping.isRural,
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
