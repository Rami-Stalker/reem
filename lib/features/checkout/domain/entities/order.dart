import 'package:equatable/equatable.dart';

class OrderItemLine extends Equatable {
  final String id;
  final String productId;
  final String title;
  final String? image;
  final String? variantName;
  final int quantity;
  final double price;
  final double lineTotal;

  const OrderItemLine({
    required this.id,
    required this.productId,
    required this.title,
    this.image,
    this.variantName,
    required this.quantity,
    required this.price,
    required this.lineTotal,
  });

  @override
  List<Object?> get props => [id, productId, variantName, quantity, lineTotal];
}

class OrderPayment extends Equatable {
  final String id;
  final String method; // visa | sham_cash | bemo | cod
  final String status; // pending | paid | failed | refunded
  final double amount;
  final String? transactionRef;
  final DateTime? paidAt;

  const OrderPayment({
    required this.id,
    required this.method,
    required this.status,
    required this.amount,
    this.transactionRef,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  @override
  List<Object?> get props => [id, method, status, amount, paidAt];
}

class OrderEvent extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;

  const OrderEvent({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, description, createdAt];
}

class OrderShipping extends Equatable {
  final String recipientName;
  final String recipientPhone;
  final String governorate;
  final String city;
  final String addressLine;
  final String? landmark;

  const OrderShipping({
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.landmark,
  });

  @override
  List<Object?> get props =>
      [recipientName, recipientPhone, governorate, city, addressLine, landmark];
}

class OrderSummary extends Equatable {
  final String id;
  final String number;
  final String status;
  final String deliveryStatus;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final int itemsCount;
  final DateTime createdAt;

  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.deliveryStatus,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.total,
    required this.itemsCount,
    required this.createdAt,
  });

  bool get isCancellable =>
      status == 'pending_payment' || status == 'paid' || status == 'processing';

  @override
  List<Object?> get props => [id, number, status, deliveryStatus, total];
}

class OrderDetail extends OrderSummary {
  final String? couponCode;
  final String? notes;
  final String? deliveryInstructions;
  final DateTime? estimatedDeliveryAt;
  final OrderShipping shipping;
  final List<OrderItemLine> items;
  final OrderPayment? payment;
  final List<OrderEvent> timeline;

  const OrderDetail({
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
    this.couponCode,
    this.notes,
    this.deliveryInstructions,
    this.estimatedDeliveryAt,
    required this.shipping,
    this.items = const [],
    this.payment,
    this.timeline = const [],
  });

  @override
  List<Object?> get props => [...super.props, items, payment, timeline];
}
