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

  static ShipmentStage fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'created' => ShipmentStage.created,
        'assigned' => ShipmentStage.assigned,
        'picked_up' => ShipmentStage.pickedUp,
        'in_transit' => ShipmentStage.inTransit,
        'out_for_delivery' => ShipmentStage.outForDelivery,
        'delivered' => ShipmentStage.delivered,
        'failed' => ShipmentStage.failed,
        'returning' => ShipmentStage.returning,
        'returned' => ShipmentStage.returned,
        'cancelled' => ShipmentStage.cancelled,
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

/// The delivery company carrying a parcel.
///
/// Reem does not run drivers — a parcel past the boutique's door belongs to a
/// carrier — so a tracking page that cannot name the company is a page that
/// cannot answer "who do I ring". Nothing here is operational: no driver, no
/// route, no carrier endpoint. Those live on the server.
class TrackingCarrier extends Equatable {
  const TrackingCarrier({
    required this.name,
    required this.stage,
    this.trackingNumber,
    this.trackingUrl,
  });

  final String name;
  final ShipmentStage stage;

  /// The carrier's own number for this box, which is what their support desk
  /// asks for. Different from Reem's tracking code, and both are shown.
  final String? trackingNumber;
  final String? trackingUrl;

  @override
  List<Object?> get props => [name, stage, trackingNumber, trackingUrl];
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
    this.carrier,
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

  /// Set once the parcel has been handed to a delivery company.
  final TrackingCarrier? carrier;

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
  List<Object?> get props => [
    trackingCode,
    stage,
    attemptCount,
    events,
    carrier,
  ];
}
