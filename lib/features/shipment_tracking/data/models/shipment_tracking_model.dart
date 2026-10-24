import 'package:ohara/features/shipment_tracking/domain/entities/shipment_tracking.dart';

class ShipmentTrackingModel extends ShipmentTracking {
  const ShipmentTrackingModel({
    required super.trackingCode,
    required super.orderNumber,
    required super.stage,
    required super.attemptCount,
    super.scheduledFor,
    super.deliveredAt,
    super.isExpress,
    super.events,
    super.carrier,
  });

  factory ShipmentTrackingModel.fromJson(Map<String, dynamic> json) {
    return ShipmentTrackingModel(
      trackingCode: json['tracking_code'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      stage: ShipmentStage.fromWire(json['status'] as String?),
      attemptCount: json['attempt_count'] as int? ?? 0,
      scheduledFor: _date(json['scheduled_for']),
      deliveredAt: _date(json['delivered_at']),
      isExpress: json['is_express'] as bool? ?? false,
      events: (json['events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => ShipmentEvent(
              stage: ShipmentStage.fromWire(row['status'] as String?),
              at: _date(row['at']) ?? DateTime.now(),
              note: row['note'] as String?,
            ),
          )
          .toList(growable: false),
      carrier: json['carrier'] is Map<String, dynamic>
          ? _carrier(json['carrier'] as Map<String, dynamic>)
          : null,
    );
  }

  static TrackingCarrier _carrier(Map<String, dynamic> json) => TrackingCarrier(
    name: json['name'] as String? ?? '',
    stage: ShipmentStage.fromWire(json['status'] as String?),
    trackingNumber: json['tracking_number'] as String?,
    trackingUrl: json['tracking_url'] as String?,
  );

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
