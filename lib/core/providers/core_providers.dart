import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/cache_store.dart';
import '../data/cache/memory_cache_store.dart';
import '../data/sync/data_synchronizer.dart';
import '../data/sync/retry_policy.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../storage/secure_storage_service.dart';

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
