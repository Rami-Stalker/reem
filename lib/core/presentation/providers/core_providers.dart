import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/data/cache/cache_store.dart';
import 'package:ohara/core/data/cache/memory_cache_store.dart';
import 'package:ohara/core/data/sync/data_synchronizer.dart';
import 'package:ohara/core/data/sync/retry_policy.dart';
import 'package:ohara/core/network/api_client.dart';
import 'package:ohara/core/network/network_info.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfoImpl(ref.watch(connectivityProvider)),
);

final retryPolicyProvider = Provider<RetryPolicy>(
  (ref) => const RetryPolicy(maxAttempts: 3),
);

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => MemoryCacheStore(maximumEntries: 500),
);

final dataSynchronizerProvider = Provider<DataSynchronizer>(
  (ref) => DataSynchronizer(
    cache: ref.watch(cacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
    retryPolicy: ref.watch(retryPolicyProvider),
  ),
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  ApiClient.configure(storage: storage);
  return ApiClient.instance;
});
