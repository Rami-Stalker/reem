import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/shipment_tracking/data/datasources/shipment_tracking_remote_datasource.dart';
import 'package:ohara/features/shipment_tracking/domain/entities/shipment_tracking.dart';
import 'package:ohara/features/shipment_tracking/domain/repositories/shipment_tracking_repository.dart';

class ShipmentTrackingRepositoryImpl
    with RepositoryHandler
    implements ShipmentTrackingRepository {
  const ShipmentTrackingRepositoryImpl(this.remote);

  final ShipmentTrackingRemoteDataSource remote;

  @override
  Future<Result<ShipmentTracking>> track(String trackingCode) =>
      guard(() => remote.track(trackingCode));
}
