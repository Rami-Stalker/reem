import '../../../../core/shared/value_objects/money.dart';
import '../../../shipment_tracking/domain/entities/shipment_tracking.dart';
import '../../domain/entities/courier_assignment.dart';

class CourierAssignmentModel extends CourierAssignment {
  const CourierAssignmentModel({
    required super.id,
    required super.trackingCode,
    required super.orderNumber,
    required super.stage,
    required super.recipient,
    required super.address,
    required super.attemptCount,
    super.codAmount,
    super.collectedAmount,
    super.deliveryInstructions,
    super.isExpress,
    super.scheduledFor,
    super.deliveredAt,
  });

  factory CourierAssignmentModel.fromJson(Map<String, dynamic> json) {
    final recipient = json['recipient'] as Map<String, dynamic>? ?? const {};
    final address = json['address'] as Map<String, dynamic>? ?? const {};

    return CourierAssignmentModel(
      id: json['id'] as String? ?? '',
      trackingCode: json['tracking_code'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      stage: ShipmentStage.fromWire(json['status'] as String?),
      recipient: CourierRecipient(
        name: recipient['name'] as String? ?? '',
        phone: recipient['phone'] as String? ?? '',
      ),
      address: CourierAddress(
        governorate: address['governorate'] as String? ?? '',
        city: address['city'] as String? ?? '',
        addressLine: address['address_line'] as String? ?? '',
        landmark: address['landmark'] as String?,
      ),
      // Absent means prepaid — deliberately not coerced to zero, because a
      // zero amount and "nothing to collect" read differently to a courier.
      codAmount: json['cod_amount'] == null
          ? null
          : Money.fromJson(json['cod_amount']),
      collectedAmount: json['collected_amount'] == null
          ? null
          : Money.fromJson(json['collected_amount']),
      deliveryInstructions: json['delivery_instructions'] as String?,
      isExpress: json['is_express'] as bool? ?? false,
      scheduledFor: _date(json['scheduled_for']),
      deliveredAt: _date(json['delivered_at']),
      attemptCount: json['attempt_count'] as int? ?? 0,
    );
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
