import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/checkout/data/models/order_models.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';

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
    super.instructions,
    super.walletBalances,
    super.walletFrozen,
  });

  factory PaymentMethodOptionModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOptionModel(
      method: json['method'] as String,
      label: json['label'] as String? ?? json['method'] as String,
      requiresOnlineConfirmation:
          json['requires_online_confirmation'] as bool? ?? false,
      instructions: json['instructions'] as String?,
      walletBalances: [
        for (final item in (json['balances'] as List?) ?? const [])
          ?Money.tryFromJson(item),
      ],
      walletFrozen: json['frozen'] as bool? ?? false,
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

class CodAssuranceModel extends CodAssurance {
  const CodAssuranceModel({
    required super.required,
    super.message,
    super.maskedDestination,
    super.matchCode,
    super.expiresAt,
    super.resendAfter,
    super.dispatchFailed,
  });

  factory CodAssuranceModel.fromJson(Map<String, dynamic> json) {
    return CodAssuranceModel(
      required: json['required'] as String? ?? 'order_confirmation',
      message: json['message'] as String?,
      maskedDestination: json['masked_destination'] as String?,
      matchCode: json['match_code'] as String?,
      expiresAt: _parseDate(json['expires_at']),
      resendAfter: _parseDate(json['resend_after']),
      dispatchFailed: json['dispatch_failed'] as bool? ?? false,
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class PlacedOrderModel extends PlacedOrder {
  const PlacedOrderModel({
    required super.order,
    super.redirectUrl,
    required super.requiresOnlineConfirmation,
    super.codAssurance,
  });

  factory PlacedOrderModel.fromJson(Map<String, dynamic> json) {
    final assurance = json['cod_assurance'];
    return PlacedOrderModel(
      order: OrderDetailModel.fromJson(json['order'] as Map<String, dynamic>),
      redirectUrl: json['redirect_url'] as String?,
      requiresOnlineConfirmation:
          json['requires_online_confirmation'] as bool? ?? false,
      codAssurance: assurance is Map<String, dynamic>
          ? CodAssuranceModel.fromJson(assurance)
          : null,
    );
  }
}
