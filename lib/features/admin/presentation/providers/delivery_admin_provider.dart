import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/admin/data/datasources/impl/delivery_admin_remote_datasource_impl.dart';
import 'package:reem/features/admin/domain/entities/delivery_provider.dart';

final deliveryAdminDataSourceProvider = Provider<DeliveryAdminRemoteDataSource>(
  (ref) => DeliveryAdminRemoteDataSource(ref.watch(dioProvider)),
);

/// The carriers the platform can dispatch to.
final deliveryProvidersProvider =
    FutureProvider.autoDispose<List<DeliveryProviderAccount>>(
      (ref) => ref.watch(deliveryAdminDataSourceProvider).providers(),
    );

/// Parcels a carrier never accepted — the queue an operator works through.
///
/// Deliberately the failed ones rather than everything: a list of every parcel
/// with every carrier is a report, and this screen exists to answer "is
/// anything stuck".
final failedDispatchesProvider =
    FutureProvider.autoDispose<List<DeliveryDispatchRow>>(
      (ref) => ref
          .watch(deliveryAdminDataSourceProvider)
          .dispatches(failedOnly: true, limit: 25),
    );
