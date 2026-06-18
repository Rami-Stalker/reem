enum CacheStrategy {
  networkOnly,
  cacheOnly,
  cacheFirst,
  networkFirst,
  staleWhileRevalidate,
}

final class CachePolicy {
  const CachePolicy({
    this.strategy = CacheStrategy.networkFirst,
    this.ttl = const Duration(minutes: 5),
    this.allowStaleOnFailure = true,
  });

  final CacheStrategy strategy;
  final Duration ttl;
  final bool allowStaleOnFailure;

  static const realtime = CachePolicy(
    strategy: CacheStrategy.networkOnly,
    allowStaleOnFailure: false,
  );

  static const resilient = CachePolicy(
    strategy: CacheStrategy.networkFirst,
    ttl: Duration(minutes: 10),
  );

  static const offlineFirst = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    ttl: Duration(hours: 6),
  );
}
