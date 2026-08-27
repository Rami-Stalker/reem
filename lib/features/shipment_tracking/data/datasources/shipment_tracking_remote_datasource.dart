import '../models/shipment_tracking_model.dart';

abstract interface class ShipmentTrackingRemoteDataSource {
  Future<ShipmentTrackingModel> track(String trackingCode);
}
