import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/shipment_tracking/domain/entities/shipment_tracking.dart';

/// Q37/Q55 — why a delivery could not be completed.
enum DeliveryFailureReason {
  noAnswer,
  wrongAddress,
  customerRefused,
  postponed,
  unreachableArea,
  other;

  String get wire => switch (this) {
    DeliveryFailureReason.noAnswer => 'NO_ANSWER',
    DeliveryFailureReason.wrongAddress => 'WRONG_ADDRESS',
    DeliveryFailureReason.customerRefused => 'CUSTOMER_REFUSED',
    DeliveryFailureReason.postponed => 'POSTPONED',
    DeliveryFailureReason.unreachableArea => 'UNREACHABLE_AREA',
    DeliveryFailureReason.other => 'OTHER',
  };
}

class CourierRecipient extends Equatable {
  const CourierRecipient({required this.name, required this.phone});

  final String name;

  /// The number to ring. May be a proxy when the order is masked (Q44) —
  /// either way it is what the courier dials.
  final String phone;

  @override
  List<Object?> get props => [name, phone];
}

class CourierAddress extends Equatable {
  const CourierAddress({
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.landmark,
  });

  final String governorate;
  final String city;
  final String addressLine;
  final String? landmark;

  String get oneLine =>
      [addressLine, city, governorate].where((p) => p.isNotEmpty).join('، ');

  @override
  List<Object?> get props => [governorate, city, addressLine, landmark];
}

/// One parcel on the courier's round (Q55).
class CourierAssignment extends Equatable {
  const CourierAssignment({
    required this.id,
    required this.trackingCode,
    required this.orderNumber,
    required this.stage,
    required this.recipient,
    required this.address,
    required this.attemptCount,
    this.codAmount,
    this.collectedAmount,
    this.deliveryInstructions,
    this.isExpress = false,
    this.scheduledFor,
    this.deliveredAt,
  });

  final String id;
  final String trackingCode;
  final String orderNumber;
  final ShipmentStage stage;

  final CourierRecipient recipient;
  final CourierAddress address;

  /// What to collect at the door. Null on a prepaid parcel — and that
  /// distinction matters: a courier shown an amount will try to collect it.
  final Money? codAmount;
  final Money? collectedAmount;

  /// Q55 «يرى ملاحظات التوصيل مثل اتصل قبل الوصول».
  final String? deliveryInstructions;

  final bool isExpress;
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final int attemptCount;

  bool get isCod => codAmount != null && !codAmount!.isZero;
  bool get isClosed => stage.isTerminal;
  bool get hasFailedAttempt => attemptCount > 0;

  /// What the courier can do next, given where the parcel is.
  ///
  /// Driven by the stage rather than by which buttons a screen felt like
  /// showing, so the app cannot offer an action the backend will refuse.
  bool get canPickUp => stage == ShipmentStage.assigned;
  bool get canStartDelivery =>
      stage == ShipmentStage.pickedUp ||
      stage == ShipmentStage.inTransit ||
      stage == ShipmentStage.failed;
  bool get canComplete => stage == ShipmentStage.outForDelivery;

  @override
  List<Object?> get props => [id, trackingCode, stage, attemptCount];
}
