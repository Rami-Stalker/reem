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

  /// For a bank transfer or hawala: who to pay, as finance wrote it. The
  /// server only offers a transfer rail once this is set.
  final String? instructions;

  const PaymentMethodOption({
    required this.method,
    required this.label,
    required this.requiresOnlineConfirmation,
    this.instructions,
  });

  @override
  List<Object?> get props => [
    method,
    label,
    requiresOnlineConfirmation,
    instructions,
  ];
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

/// A cash order the platform is holding until she reads back a code.
///
/// Present only when the trust engine asked for one. The customer is never
/// shown a score or a reason code — [message] is the whole explanation she
/// gets, and it is written by the server so that support reads the same
/// sentence she does.
class CodAssurance extends Equatable {
  /// Only `order_confirmation` reaches the app today: the prepayment tier is
  /// refused at checkout instead, so no order exists to carry it.
  final String required;
  final String? message;

  /// Which number the code went to, already masked by the server.
  final String? maskedDestination;

  /// The two digits also printed in the message. If they differ, the message
  /// did not come from this checkout — the same defence the login flow uses
  /// against "this is Reem support, read me your code".
  final String? matchCode;

  final DateTime? expiresAt;
  final DateTime? resendAfter;

  /// The code could not be sent. The order is still held; she needs a resend.
  final bool dispatchFailed;

  const CodAssurance({
    required this.required,
    this.message,
    this.maskedDestination,
    this.matchCode,
    this.expiresAt,
    this.resendAfter,
    this.dispatchFailed = false,
  });

  @override
  List<Object?> get props => [
        required,
        message,
        maskedDestination,
        matchCode,
        expiresAt,
        resendAfter,
        dispatchFailed,
      ];
}

/// Result of placing an order — the order plus any required next payment step.
class PlacedOrder extends Equatable {
  final OrderDetail order;
  final String? redirectUrl;
  final bool requiresOnlineConfirmation;

  /// Set when the order is held for a cash-on-delivery confirmation code.
  final CodAssurance? codAssurance;

  const PlacedOrder({
    required this.order,
    this.redirectUrl,
    required this.requiresOnlineConfirmation,
    this.codAssurance,
  });

  /// She has placed it, but nobody is preparing it until the code is in.
  bool get awaitsCodConfirmation => codAssurance != null;

  @override
  List<Object?> get props =>
      [order, redirectUrl, requiresOnlineConfirmation, codAssurance];
}
