import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/checkout.dart';
import 'order_models.dart';

class GovernorateDistrictModel extends GovernorateDistrict {
  const GovernorateDistrictModel({
    required super.name,
    required super.fee,
    required super.etaHoursMin,
    required super.etaHoursMax,
    super.isRural,
  });

  factory GovernorateDistrictModel.fromJson(Map<String, dynamic> json) {
    return GovernorateDistrictModel(
      name: json['name'] as String? ?? '',
      isRural: json['is_rural'] as bool? ?? false,
      fee: Money.fromJson(json['fee']),
      etaHoursMin: json['eta_hours_min'] as int? ?? 24,
      etaHoursMax: json['eta_hours_max'] as int? ?? 48,
    );
  }
}

class GovernorateModel extends Governorate {
  const GovernorateModel({
    required super.name,
    required super.fee,
    required super.etaHoursMin,
    required super.etaHoursMax,
    super.districts,
  });

  factory GovernorateModel.fromJson(Map<String, dynamic> json) {
    return GovernorateModel(
      name: json['governorate'] as String? ?? json['name'] as String? ?? '',
      fee: Money.fromJson(json['fee']),
      etaHoursMin: json['eta_hours_min'] as int? ?? 24,
      etaHoursMax: json['eta_hours_max'] as int? ?? 48,
      districts: (json['districts'] as List? ?? [])
          .map((e) =>
              GovernorateDistrictModel.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      label: json['label'] as String? ?? json['method'] as String,
      requiresOnlineConfirmation:
          json['requires_online_confirmation'] as bool? ?? false,
    );
  }
}

class DeliveryQuoteModel extends DeliveryQuote {
  const DeliveryQuoteModel({
    required super.deliveryFee,
    required super.freeShipping,
    required super.etaHoursMin,
    required super.etaHoursMax,
    super.estimatedDeliveryAt,
  });

  factory DeliveryQuoteModel.fromJson(Map<String, dynamic> json) {
    return DeliveryQuoteModel(
      deliveryFee: Money.fromJson(json['delivery_fee']),
      freeShipping: json['free_shipping'] as bool? ?? false,
      etaHoursMin: json['eta_hours_min'] as int? ?? 24,
      etaHoursMax: json['eta_hours_max'] as int? ?? 48,
      estimatedDeliveryAt: json['estimated_delivery_at'] == null
          ? null
          : DateTime.tryParse(json['estimated_delivery_at'] as String),
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
