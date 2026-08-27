import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';

/// A delivery destination the platform serves.
///
/// Zones are split by governorate and, inside a governorate, by district and
/// city-centre-versus-rural (Q53), each with its own fee and ETA.
class Governorate extends Equatable {
  final String name;
  final Money fee;

  /// ETAs are in hours, not days: the client promised same-day delivery inside
  /// a city and one to two days between governorates (Q61/Q62), and "0 days"
  /// could not express that.
  final int etaHoursMin;
  final int etaHoursMax;

  final List<GovernorateDistrict> districts;

  const Governorate({
    required this.name,
    required this.fee,
    required this.etaHoursMin,
    required this.etaHoursMax,
    this.districts = const [],
  });

  String get etaLabel {
    if (etaHoursMax <= 12) return 'خلال اليوم';
    final days = (etaHoursMax / 24).ceil();
    return days <= 1 ? 'خلال يوم' : 'خلال $days أيام';
  }

  @override
  List<Object?> get props => [name, fee, etaHoursMin, etaHoursMax, districts];
}

class GovernorateDistrict extends Equatable {
  final String name;
  final bool isRural;
  final Money fee;
  final int etaHoursMin;
  final int etaHoursMax;

  const GovernorateDistrict({
    required this.name,
    required this.fee,
    required this.etaHoursMin,
    required this.etaHoursMax,
    this.isRural = false,
  });

  @override
  List<Object?> get props => [name, isRural, fee, etaHoursMin, etaHoursMax];
}

class PaymentMethodOption extends Equatable {
  /// cod | courier_collect | syriatel_cash | mtn_cash | sham_cash |
  /// bank_card | bank_transfer | hawala | platform_wallet
  final String method;
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
  final Money deliveryFee;
  final bool freeShipping;
  final int etaHoursMin;
  final int etaHoursMax;
  final DateTime? estimatedDeliveryAt;

  const DeliveryQuote({
    required this.deliveryFee,
    required this.freeShipping,
    required this.etaHoursMin,
    required this.etaHoursMax,
    this.estimatedDeliveryAt,
  });

  @override
  List<Object?> get props =>
      [deliveryFee, freeShipping, etaHoursMin, etaHoursMax];
}

/// Form payload captured during checkout.
class ShippingInput {
  final String recipientName;
  final String recipientPhone;
  final String governorate;
  final String city;
  final String addressLine;
  final String? district;
  final bool isRural;
  final String? landmark;

  const ShippingInput({
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.district,
    this.isRural = false,
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
