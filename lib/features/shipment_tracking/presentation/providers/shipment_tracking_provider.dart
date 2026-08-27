import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import '../../data/datasources/impl/shipment_tracking_remote_datasource_impl.dart';
import '../../data/datasources/shipment_tracking_remote_datasource.dart';
import '../../data/repositories/shipment_tracking_repository_impl.dart';
import '../../domain/entities/shipment_tracking.dart';
import '../../domain/repositories/shipment_tracking_repository.dart';

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
        Error(:final failure) => throw Exception(failure.message),
      };
    });
