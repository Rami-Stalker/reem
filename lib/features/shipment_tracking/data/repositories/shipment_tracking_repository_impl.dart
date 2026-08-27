import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/shipment_tracking.dart';
import '../../domain/repositories/shipment_tracking_repository.dart';
import '../datasources/shipment_tracking_remote_datasource.dart';

class ShipmentTrackingRepositoryImpl
    with RepositoryHandler
    implements ShipmentTrackingRepository {
  const ShipmentTrackingRepositoryImpl(this.remote);

  final ShipmentTrackingRemoteDataSource remote;

  @override
  Future<Result<ShipmentTracking>> track(String trackingCode) =>
      guard(() => remote.track(trackingCode));
}
