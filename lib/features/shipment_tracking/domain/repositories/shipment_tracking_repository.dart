import 'package:reem/core/result/result.dart';
import 'package:reem/features/shipment_tracking/domain/entities/shipment_tracking.dart';

abstract interface class ShipmentTrackingRepository {
  Future<Result<ShipmentTracking>> track(String trackingCode);
}
