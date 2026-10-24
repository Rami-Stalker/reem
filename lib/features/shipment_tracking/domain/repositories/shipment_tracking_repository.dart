import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/shipment_tracking/domain/entities/shipment_tracking.dart';

abstract interface class ShipmentTrackingRepository {
  Future<Result<ShipmentTracking>> track(String trackingCode);
}
