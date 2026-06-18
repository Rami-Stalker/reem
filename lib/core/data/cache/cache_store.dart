final class CacheEntry<T> {
  const CacheEntry({
    required this.value,
    required this.createdAt,
    required this.expiresAt,
  });

  final T value;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
}

abstract interface class CacheStore {
  Future<T?> read<T>(String key, {bool includeExpired = false});

  Future<CacheEntry<T>?> readEntry<T>(
    String key, {
    bool includeExpired = false,
  });

  Future<void> write<T>(String key, T value, {required Duration ttl});

  Future<void> invalidate(String key);

  Future<void> clear();
}
