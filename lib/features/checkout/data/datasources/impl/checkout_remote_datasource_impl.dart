import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ohara/features/checkout/data/models/checkout_models.dart';
import 'package:ohara/features/checkout/data/models/order_models.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';

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
        .map(
          (e) => PaymentMethodOptionModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<PlacedOrderModel> placeOrder({
    required String idempotencyKey,
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  }) async {
    final json = await postJson(
      ApiEndpoints.ordersCheckout,
      idempotencyKey: idempotencyKey,
      body: {
        'address_id': ?addressId,
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
            if (shipping.latitude != null && shipping.longitude != null) ...{
              'latitude': shipping.latitude,
              'longitude': shipping.longitude,
            },
          },
        // Backend expects the uppercase enum value.
        'payment_method': paymentMethod.toUpperCase(),
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        if (deliveryInstructions != null && deliveryInstructions.isNotEmpty)
          'delivery_instructions': deliveryInstructions,
        // Q44 — «أخفي اسمي عن البائعة». The server has taken this since
        // checkout was written and the app never sent it, so the privacy
        // promise was unreachable from the phone.
        if (privacyMask) 'privacy_mask': true,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return PlacedOrderModel.fromJson(json);
  }

  @override
  Future<OrderDetailModel> confirmCodOrder(String orderId, String code) async {
    final json = await postJson(
      ApiEndpoints.orderCodConfirmation(orderId),
      body: {'code': code},
    );
    return OrderDetailModel.fromJson(json['order'] as Map<String, dynamic>);
  }

  @override
  Future<CodAssuranceModel> resendCodConfirmation(String orderId) async {
    final json = await postJson(
      ApiEndpoints.orderCodConfirmationResend(orderId),
    );
    // The resend route answers with the challenge alone, so the shape it
    // carries is folded back into the same block checkout returned.
    return CodAssuranceModel.fromJson({
      'required': 'order_confirmation',
      ...json,
    });
  }

  @override
  Future<OrderPaymentModel> verifyPayment(String paymentId) async {
    final json = await postJson(ApiEndpoints.paymentVerify(paymentId));
    return OrderPaymentModel.fromJson(json);
  }

  /// Re-opens the gateway for a payment that has not gone through, and hands
  /// back the link to send her to.
  @override
  Future<PaymentAttempt> retryPayment(String paymentId) async {
    final json = await postJson(ApiEndpoints.paymentRetry(paymentId));
    return PaymentAttempt(
      payment: OrderPaymentModel.fromJson(
        (json['payment'] as Map).cast<String, dynamic>(),
      ),
      redirectUrl: json['redirect_url'] as String?,
    );
  }

  @override
  Future<OrderPaymentModel> submitPaymentReference(
    String paymentId,
    String reference,
  ) async {
    final json = await postJson(
      ApiEndpoints.paymentReference(paymentId),
      body: {'reference': reference},
    );
    return OrderPaymentModel.fromJson(json);
  }

  @override
  Future<List<OrderSummaryModel>> getOrders({
    int page = 1,
    int limit = 20,
    String? bucket,
  }) async {
    final json = await getJson(
      ApiEndpoints.orders,
      query: {'page': page, 'limit': limit, 'bucket': ?bucket},
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
