import 'dart:async';

import 'package:reem/core/data/cache/cache_policy.dart';
import 'package:reem/core/data/cache/cache_store.dart';
import 'package:reem/core/data/sync/retry_policy.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/network/network_info.dart';

enum DataOrigin { cache, remote }

final class DataSnapshot<T> {
  const DataSnapshot({
    required this.data,
    required this.origin,
    this.isStale = false,
  });

  final T data;
  final DataOrigin origin;
  final bool isStale;
}

final class DataSynchronizer {
  const DataSynchronizer({
    required this.cache,
    this.networkInfo,
    this.retryPolicy = const RetryPolicy(),
  });

  final CacheStore cache;
  final NetworkInfo? networkInfo;
  final RetryPolicy retryPolicy;

  Future<DataSnapshot<T>> resolve<T>({
    required String cacheKey,
    required Future<T> Function() remote,
    CachePolicy policy = CachePolicy.resilient,
  }) async {
    switch (policy.strategy) {
      case CacheStrategy.cacheOnly:
        return _readCache(cacheKey, includeExpired: true);
      case CacheStrategy.cacheFirst:
        final cached = await _readCacheOrNull<T>(cacheKey);
        if (cached != null) return cached;
        return _fetchAndCache(cacheKey, remote, policy);
      case CacheStrategy.networkOnly:
        return _fetchAndCache(cacheKey, remote, policy, writeCache: false);
      case CacheStrategy.networkFirst:
        return _networkFirst(cacheKey, remote, policy);
      case CacheStrategy.staleWhileRevalidate:
        return _staleWhileRevalidate(cacheKey, remote, policy);
    }
  }

  Future<DataSnapshot<T>> _networkFirst<T>(
    String cacheKey,
    Future<T> Function() remote,
    CachePolicy policy,
  ) async {
    final isOnline = await _isOnline();
    final stale = await _readCacheOrNull<T>(cacheKey, includeExpired: true);

    if (!isOnline && stale != null) return stale;
    if (!isOnline) {
      throw const NetworkException('No internet connection.');
    }

    try {
      return await _fetchAndCache(cacheKey, remote, policy);
    } catch (_) {
      if (policy.allowStaleOnFailure && stale != null) return stale;
      rethrow;
    }
  }

  Future<DataSnapshot<T>> _staleWhileRevalidate<T>(
    String cacheKey,
    Future<T> Function() remote,
    CachePolicy policy,
  ) async {
    final cached = await _readCacheOrNull<T>(cacheKey, includeExpired: true);
    if (cached != null) {
      unawaited(_refreshCache(cacheKey, remote, policy));
      return cached;
    }
    return _fetchAndCache(cacheKey, remote, policy);
  }

  Future<void> _refreshCache<T>(
    String cacheKey,
    Future<T> Function() remote,
    CachePolicy policy,
  ) async {
    try {
      await _fetchAndCache(cacheKey, remote, policy);
    } catch (_) {
      // Stale-while-revalidate keeps the current UI usable; callers can choose
      // explicit refresh when they need to surface background sync errors.
    }
  }

  Future<DataSnapshot<T>> _fetchAndCache<T>(
    String cacheKey,
    Future<T> Function() remote,
    CachePolicy policy, {
    bool writeCache = true,
  }) async {
    final data = await retryPolicy.run(remote);
    if (writeCache) {
      await cache.write(cacheKey, data, ttl: policy.ttl);
    }
    return DataSnapshot<T>(data: data, origin: DataOrigin.remote);
  }

  Future<DataSnapshot<T>> _readCache<T>(
    String cacheKey, {
    bool includeExpired = false,
  }) async {
    final cached = await _readCacheOrNull<T>(
      cacheKey,
      includeExpired: includeExpired,
    );
    if (cached == null) {
      throw CacheException('No cached data found for $cacheKey.');
    }
    return cached;
  }

  Future<DataSnapshot<T>?> _readCacheOrNull<T>(
    String cacheKey, {
    bool includeExpired = false,
  }) async {
    final entry = await cache.readEntry<T>(
      cacheKey,
      includeExpired: includeExpired,
    );
    if (entry == null) return null;
    return DataSnapshot<T>(
      data: entry.value,
      origin: DataOrigin.cache,
      isStale: entry.isExpired(DateTime.now()),
    );
  }

  Future<bool> _isOnline() async {
    if (networkInfo == null) return true;
    return networkInfo!.isConnected;
  }
}
