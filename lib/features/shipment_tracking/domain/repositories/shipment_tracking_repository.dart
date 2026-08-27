import '../../../../core/result/result.dart';
import '../entities/shipment_tracking.dart';

abstract interface class ShipmentTrackingRepository {
  Future<Result<ShipmentTracking>> track(String trackingCode);
}
