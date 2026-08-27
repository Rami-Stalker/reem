import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String);

/// Money arrives as `{amount, currency}`.
///
/// The previous helper was `double _d(v) => (v as num?)?.toDouble() ?? 0`,
/// which turned every decimal-string amount into a silent **zero** — an order
/// screen that shows 0 ل.س rather than an error anyone would notice.
Money _money(dynamic v, {Currency fallback = Currency.syp}) =>
    Money.fromJson(v, fallback: fallback);

class OrderItemLineModel extends OrderItemLine {
  const OrderItemLineModel({
    required super.id,
    required super.title,
    required super.sellerName,
    required super.quantity,
    required super.unitPrice,
    required super.lineTotal,
    super.offerId,
    super.productId,
    super.image,
    super.variantName,
  });

  factory OrderItemLineModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return OrderItemLineModel(
      id: json['id'] as String,
      offerId: json['offer_id'] as String?,
      productId: json['product_id'] as String?,
      title: json['title'] as String? ?? '',
      image: json['image'] as String?,
      variantName: json['variant_name'] as String?,
      sellerName: json['seller_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: _money(json['unit_price'], fallback: currency),
      lineTotal: _money(json['line_total'], fallback: currency),
    );
  }
}

class OrderShipmentModel extends OrderShipment {
  const OrderShipmentModel({
    required super.id,
    required super.trackingCode,
    required super.status,
    super.scheduledFor,
    super.deliveredAt,
    super.proofImageUrl,
    super.failureReason,
    super.attemptCount,
    super.codAmount,
  });

  factory OrderShipmentModel.fromJson(Map<String, dynamic> json) {
    return OrderShipmentModel(
      id: json['id'] as String,
      trackingCode: json['tracking_code'] as String? ?? '',
      status: json['status'] as String? ?? 'created',
      scheduledFor: _dt(json['scheduled_for']),
      deliveredAt: _dt(json['delivered_at']),
      proofImageUrl: json['proof_image_url'] as String?,
      failureReason: json['failure_reason'] as String?,
      attemptCount: json['attempt_count'] as int? ?? 0,
      codAmount: Money.tryFromJson(json['cod_amount']),
    );
  }
}

class SellerOrderModel extends SellerOrder {
  const SellerOrderModel({
    required super.id,
    required super.number,
    required super.sellerId,
    required super.sellerName,
    required super.status,
    required super.itemsSubtotal,
    required super.discountTotal,
    required super.shippingCost,
    super.sellerImageUrl,
    super.fulfilmentMode,
    super.confirmedAt,
    super.shippedAt,
    super.deliveredAt,
    super.cancellationReason,
    super.items,
    super.shipment,
    super.timeline,
  });

  factory SellerOrderModel.fromJson(Map<String, dynamic> json) {
    final seller = (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {};
    final currency = Currency.fromWire(json['currency'] as String?);

    return SellerOrderModel(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      sellerId: seller['id'] as String? ?? '',
      sellerName: seller['name'] as String? ?? '',
      sellerImageUrl: seller['image_url'] as String?,
      status: SellerOrderStatus.fromWire(json['status'] as String?),
      fulfilmentMode:
          json['fulfilment_mode'] as String? ?? 'platform_courier',
      itemsSubtotal: _money(json['items_subtotal'], fallback: currency),
      discountTotal: _money(json['discount_total'], fallback: currency),
      shippingCost: _money(json['shipping_cost'], fallback: currency),
      confirmedAt: _dt(json['confirmed_at']),
      shippedAt: _dt(json['shipped_at']),
      deliveredAt: _dt(json['delivered_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItemLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      shipment: json['shipment'] is Map<String, dynamic>
          ? OrderShipmentModel.fromJson(
              json['shipment'] as Map<String, dynamic>)
          : null,
      timeline: (json['timeline'] as List? ?? [])
          .map((e) => OrderEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderPaymentModel extends OrderPayment {
  const OrderPaymentModel({
    required super.id,
    required super.method,
    required super.status,
    required super.amount,
    required super.capturedAmount,
    required super.refundedAmount,
    super.transactionRef,
    super.paidAt,
  });

  factory OrderPaymentModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return OrderPaymentModel(
      id: json['id'] as String,
      method: json['method'] as String? ?? 'cod',
      status: json['status'] as String? ?? 'pending',
      amount: _money(json['amount'], fallback: currency),
      capturedAmount: _money(json['captured_amount'], fallback: currency),
      refundedAmount: _money(json['refunded_amount'], fallback: currency),
      transactionRef: json['transaction_ref'] as String?,
      paidAt: _dt(json['paid_at']),
    );
  }
}

class OrderEventModel extends OrderEvent {
  const OrderEventModel({
    required super.id,
    required super.title,
    required super.createdAt,
    super.description,
    super.fromStatus,
    super.toStatus,
    super.actorRole,
  });

  factory OrderEventModel.fromJson(Map<String, dynamic> json) {
    return OrderEventModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      actorRole: json['actor_role'] as String?,
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
    );
  }
}

class OrderShippingModel extends OrderShipping {
  const OrderShippingModel({
    required super.recipientName,
    required super.recipientPhone,
    required super.governorate,
    required super.city,
    required super.addressLine,
    super.district,
    super.landmark,
  });

  factory OrderShippingModel.fromJson(Map<String, dynamic> json) {
    return OrderShippingModel(
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      governorate: json['governorate'] as String? ?? '',
      district: json['district'] as String?,
      city: json['city'] as String? ?? '',
      addressLine: json['address_line'] as String? ?? '',
      landmark: json['landmark'] as String?,
    );
  }
}

class OrderSummaryModel extends OrderSummary {
  const OrderSummaryModel({
    required super.id,
    required super.number,
    required super.status,
    required super.itemsSubtotal,
    required super.discountTotal,
    required super.shippingTotal,
    required super.walletApplied,
    required super.grandTotal,
    required super.fxRate,
    required super.fxFrozenAt,
    required super.sellersCount,
    required super.itemsCount,
    required super.createdAt,
  });

  factory OrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return OrderSummaryModel(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      status: OrderStatus.fromWire(json['status'] as String?),
      itemsSubtotal: _money(json['items_subtotal'], fallback: currency),
      discountTotal: _money(json['discount_total'], fallback: currency),
      shippingTotal: _money(json['shipping_total'], fallback: currency),
      walletApplied: _money(json['wallet_applied'], fallback: currency),
      grandTotal: _money(json['grand_total'], fallback: currency),
      fxRate: json['fx_rate'] as String? ?? '1',
      fxFrozenAt: _dt(json['fx_frozen_at']) ?? DateTime.now(),
      sellersCount: json['sellers_count'] as int? ?? 1,
      itemsCount: json['items_count'] as int? ?? 0,
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
    );
  }
}

class OrderDetailModel extends OrderDetail {
  const OrderDetailModel({
    required super.id,
    required super.number,
    required super.status,
    required super.itemsSubtotal,
    required super.discountTotal,
    required super.shippingTotal,
    required super.walletApplied,
    required super.grandTotal,
    required super.fxRate,
    required super.fxFrozenAt,
    required super.sellersCount,
    required super.itemsCount,
    required super.createdAt,
    required super.shipping,
    super.couponCode,
    super.notes,
    super.deliveryInstructions,
    super.privacyMaskEnabled,
    super.sellerOrders,
    super.payment,
    super.timeline,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final summary = OrderSummaryModel.fromJson(json);
    return OrderDetailModel(
      id: summary.id,
      number: summary.number,
      status: summary.status,
      itemsSubtotal: summary.itemsSubtotal,
      discountTotal: summary.discountTotal,
      shippingTotal: summary.shippingTotal,
      walletApplied: summary.walletApplied,
      grandTotal: summary.grandTotal,
      fxRate: summary.fxRate,
      fxFrozenAt: summary.fxFrozenAt,
      sellersCount: summary.sellersCount,
      itemsCount: summary.itemsCount,
      createdAt: summary.createdAt,
      couponCode: json['coupon_code'] as String?,
      notes: json['notes'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      privacyMaskEnabled: json['privacy_mask_enabled'] as bool? ?? false,
      shipping: OrderShippingModel.fromJson(
        (json['shipping'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      sellerOrders: (json['seller_orders'] as List? ?? [])
          .map((e) => SellerOrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      payment: json['payment'] is Map<String, dynamic>
          ? OrderPaymentModel.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      timeline: (json['timeline'] as List? ?? [])
          .map((e) => OrderEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
