import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/shipment_tracking/data/datasources/impl/shipment_tracking_remote_datasource_impl.dart';
import 'package:reem/features/shipment_tracking/data/datasources/shipment_tracking_remote_datasource.dart';
import 'package:reem/features/shipment_tracking/data/repositories/shipment_tracking_repository_impl.dart';
import 'package:reem/features/shipment_tracking/domain/entities/shipment_tracking.dart';
import 'package:reem/features/shipment_tracking/domain/repositories/shipment_tracking_repository.dart';

final shipmentTrackingRemoteDataSourceProvider =
    Provider<ShipmentTrackingRemoteDataSource>(
      (ref) => ShipmentTrackingRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final shipmentTrackingRepositoryProvider = Provider<ShipmentTrackingRepository>(
  (ref) => ShipmentTrackingRepositoryImpl(
    ref.watch(shipmentTrackingRemoteDataSourceProvider),
  ),
);

/// Q64 — «تتبع الشحنة للزبونة», by tracking code.
final shipmentTrackingProvider = FutureProvider.autoDispose
    .family<ShipmentTracking, String>((ref, trackingCode) async {
      final result = await ref
          .watch(shipmentTrackingRepositoryProvider)
          .track(trackingCode);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });
