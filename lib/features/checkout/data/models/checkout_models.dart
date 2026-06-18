import '../../domain/entities/checkout.dart';
import 'order_models.dart';

class GovernorateModel extends Governorate {
  const GovernorateModel({
    required super.name,
    required super.fee,
    required super.etaDays,
  });

  factory GovernorateModel.fromJson(Map<String, dynamic> json) {
    return GovernorateModel(
      name: json['name'] as String,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      etaDays: json['eta_days'] as int? ?? 3,
    );
  }
}

class PaymentMethodOptionModel extends PaymentMethodOption {
  const PaymentMethodOptionModel({
    required super.method,
    required super.label,
    required super.requiresOnlineConfirmation,
  });

  factory PaymentMethodOptionModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOptionModel(
      method: json['method'] as String,
      label: json['label'] as String,
      requiresOnlineConfirmation:
          json['requires_online_confirmation'] as bool? ?? false,
    );
  }
}

class DeliveryQuoteModel extends DeliveryQuote {
  const DeliveryQuoteModel({
    required super.deliveryFee,
    required super.freeShipping,
    required super.estimatedDays,
  });

  factory DeliveryQuoteModel.fromJson(Map<String, dynamic> json) {
    return DeliveryQuoteModel(
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      freeShipping: json['free_shipping'] as bool? ?? false,
      estimatedDays: json['estimated_days'] as int? ?? 3,
    );
  }
}

class PlacedOrderModel extends PlacedOrder {
  const PlacedOrderModel({
    required super.order,
    super.redirectUrl,
    required super.requiresOnlineConfirmation,
  });

  factory PlacedOrderModel.fromJson(Map<String, dynamic> json) {
    return PlacedOrderModel(
      order: OrderDetailModel.fromJson(json['order'] as Map<String, dynamic>),
      redirectUrl: json['redirect_url'] as String?,
      requiresOnlineConfirmation:
          json['requires_online_confirmation'] as bool? ?? false,
    );
  }
}
