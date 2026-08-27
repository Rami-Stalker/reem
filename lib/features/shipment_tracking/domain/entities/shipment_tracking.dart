import 'package:equatable/equatable.dart';

/// The parcel's journey, as the customer sees it (Q64 «تتبع الشحنة للزبونة»).
enum ShipmentStage {
  created,
  assigned,
  pickedUp,
  inTransit,
  outForDelivery,
  delivered,
  failed,
  returning,
  returned,
  cancelled,
  unknown;

  static ShipmentStage fromWire(String? value) => switch (value) {
    'CREATED' => ShipmentStage.created,
    'ASSIGNED' => ShipmentStage.assigned,
    'PICKED_UP' => ShipmentStage.pickedUp,
    'IN_TRANSIT' => ShipmentStage.inTransit,
    'OUT_FOR_DELIVERY' => ShipmentStage.outForDelivery,
    'DELIVERED' => ShipmentStage.delivered,
    'FAILED' => ShipmentStage.failed,
    'RETURNING' => ShipmentStage.returning,
    'RETURNED' => ShipmentStage.returned,
    'CANCELLED' => ShipmentStage.cancelled,
    _ => ShipmentStage.unknown,
  };

  /// The journey is over, one way or another.
  bool get isTerminal =>
      this == ShipmentStage.delivered ||
      this == ShipmentStage.returned ||
      this == ShipmentStage.cancelled;

  /// Something went wrong and she should know without reading a timeline.
  bool get isTrouble =>
      this == ShipmentStage.failed ||
      this == ShipmentStage.returning ||
      this == ShipmentStage.returned ||
      this == ShipmentStage.cancelled;
}

/// The stages a parcel passes through on the happy path.
///
/// Shown as a fixed spine so she can see what is still to come, not only what
/// has happened — a timeline that only lists the past cannot answer "where is
/// it now" at a glance.
const kShipmentJourney = <ShipmentStage>[
  ShipmentStage.created,
  ShipmentStage.pickedUp,
  ShipmentStage.outForDelivery,
  ShipmentStage.delivered,
];

class ShipmentEvent extends Equatable {
  const ShipmentEvent({required this.stage, required this.at, this.note});

  final ShipmentStage stage;
  final DateTime at;
  final String? note;

  @override
  List<Object?> get props => [stage, at, note];
}

/// A parcel, tracked by its code.
class ShipmentTracking extends Equatable {
  const ShipmentTracking({
    required this.trackingCode,
    required this.orderNumber,
    required this.stage,
    required this.attemptCount,
    this.scheduledFor,
    this.deliveredAt,
    this.isExpress = false,
    this.events = const [],
  });

  final String trackingCode;
  final String orderNumber;
  final ShipmentStage stage;

  /// Q64 — she may have chosen a slot or deferred the date.
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final bool isExpress;

  /// Q37 «فشل التسليم» — more than one means the courier has been back.
  final int attemptCount;

  final List<ShipmentEvent> events;

  bool get isDelivered => stage == ShipmentStage.delivered;
  bool get hasFailedAttempt => attemptCount > 0;

  /// How far along the happy path she is, for the progress spine.
  ///
  /// A parcel in trouble has no position on it — showing one would suggest
  /// progress toward a delivery that is not coming.
  int? get journeyIndex {
    if (stage.isTrouble) return null;
    final index = kShipmentJourney.indexOf(stage);
    if (index >= 0) return index;
    // Stages that are real but not on the spine sit at the nearest one behind.
    return switch (stage) {
      ShipmentStage.assigned => 0,
      ShipmentStage.inTransit => 1,
      _ => null,
    };
  }

  @override
  List<Object?> get props => [trackingCode, stage, attemptCount, events];
}
