import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/shipment_tracking/data/datasources/shipment_tracking_remote_datasource.dart';
import 'package:reem/features/shipment_tracking/data/models/shipment_tracking_model.dart';

final class ShipmentTrackingRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ShipmentTrackingRemoteDataSource {
  const ShipmentTrackingRemoteDataSourceImpl(super.dio);

  @override
  Future<ShipmentTrackingModel> track(String trackingCode) async {
    final json = await getJson(ApiEndpoints.shipmentTrack(trackingCode));
    return ShipmentTrackingModel.fromJson(json);
  }
}
