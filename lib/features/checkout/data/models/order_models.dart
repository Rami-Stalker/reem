import '../../domain/entities/order.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

class OrderItemLineModel extends OrderItemLine {
  const OrderItemLineModel({
    required super.id,
    required super.productId,
    required super.title,
    super.image,
    super.variantName,
    required super.quantity,
    required super.price,
    required super.lineTotal,
  });

  factory OrderItemLineModel.fromJson(Map<String, dynamic> json) {
    return OrderItemLineModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      title: json['title'] as String? ?? '',
      image: json['image'] as String?,
      variantName: json['variant_name'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      price: _d(json['price']),
      lineTotal: _d(json['line_total']),
    );
  }
}

class OrderPaymentModel extends OrderPayment {
  const OrderPaymentModel({
    required super.id,
    required super.method,
    required super.status,
    required super.amount,
    super.transactionRef,
    super.paidAt,
  });

  factory OrderPaymentModel.fromJson(Map<String, dynamic> json) {
    return OrderPaymentModel(
      id: json['id'] as String,
      method: json['method'] as String? ?? 'cod',
      status: json['status'] as String? ?? 'pending',
      amount: _d(json['amount']),
      transactionRef: json['transaction_ref'] as String?,
      paidAt: _dt(json['paid_at']),
    );
  }
}

class OrderEventModel extends OrderEvent {
  const OrderEventModel({
    required super.id,
    required super.title,
    super.description,
    required super.createdAt,
  });

  factory OrderEventModel.fromJson(Map<String, dynamic> json) {
    return OrderEventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    super.landmark,
  });

  factory OrderShippingModel.fromJson(Map<String, dynamic> json) {
    return OrderShippingModel(
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      governorate: json['governorate'] as String? ?? '',
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
    required super.deliveryStatus,
    required super.subtotal,
    required super.discount,
    required super.deliveryFee,
    required super.total,
    required super.itemsCount,
    required super.createdAt,
  });

  factory OrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return OrderSummaryModel(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_payment',
      deliveryStatus: json['delivery_status'] as String? ?? 'created',
      subtotal: _d(json['subtotal']),
      discount: _d(json['discount']),
      deliveryFee: _d(json['delivery_fee']),
      total: _d(json['total']),
      itemsCount: json['items_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OrderDetailModel extends OrderDetail {
  const OrderDetailModel({
    required super.id,
    required super.number,
    required super.status,
    required super.deliveryStatus,
    required super.subtotal,
    required super.discount,
    required super.deliveryFee,
    required super.total,
    required super.itemsCount,
    required super.createdAt,
    super.couponCode,
    super.notes,
    super.deliveryInstructions,
    super.estimatedDeliveryAt,
    required super.shipping,
    super.items,
    super.payment,
    super.timeline,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'] as Map<String, dynamic>?;
    return OrderDetailModel(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_payment',
      deliveryStatus: json['delivery_status'] as String? ?? 'created',
      subtotal: _d(json['subtotal']),
      discount: _d(json['discount']),
      deliveryFee: _d(json['delivery_fee']),
      total: _d(json['total']),
      itemsCount: json['items_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      couponCode: json['coupon_code'] as String?,
      notes: json['notes'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      estimatedDeliveryAt: _dt(json['estimated_delivery_at']),
      shipping: OrderShippingModel.fromJson(
        json['shipping'] as Map<String, dynamic>? ?? const {},
      ),
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItemLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      payment:
          paymentJson != null ? OrderPaymentModel.fromJson(paymentJson) : null,
      timeline: (json['timeline'] as List? ?? [])
          .map((e) => OrderEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
