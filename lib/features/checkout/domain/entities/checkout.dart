import 'package:equatable/equatable.dart';

import 'order.dart';

class Governorate extends Equatable {
  final String name;
  final double fee;
  final int etaDays;

  const Governorate({
    required this.name,
    required this.fee,
    required this.etaDays,
  });

  @override
  List<Object?> get props => [name, fee, etaDays];
}

class PaymentMethodOption extends Equatable {
  final String method; // visa | sham_cash | bemo | cod
  final String label;
  final bool requiresOnlineConfirmation;

  const PaymentMethodOption({
    required this.method,
    required this.label,
    required this.requiresOnlineConfirmation,
  });

  @override
  List<Object?> get props => [method, label, requiresOnlineConfirmation];
}

class DeliveryQuote extends Equatable {
  final double deliveryFee;
  final bool freeShipping;
  final int estimatedDays;

  const DeliveryQuote({
    required this.deliveryFee,
    required this.freeShipping,
    required this.estimatedDays,
  });

  @override
  List<Object?> get props => [deliveryFee, freeShipping, estimatedDays];
}

/// Form payload captured during checkout.
class ShippingInput {
  final String recipientName;
  final String recipientPhone;
  final String governorate;
  final String city;
  final String addressLine;
  final String? landmark;

  const ShippingInput({
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.landmark,
  });
}

/// Result of placing an order — the order plus any required next payment step.
class PlacedOrder extends Equatable {
  final OrderDetail order;
  final String? redirectUrl;
  final bool requiresOnlineConfirmation;

  const PlacedOrder({
    required this.order,
    this.redirectUrl,
    required this.requiresOnlineConfirmation,
  });

  @override
  List<Object?> get props => [order, redirectUrl, requiresOnlineConfirmation];
}
