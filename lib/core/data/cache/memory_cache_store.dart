import 'package:ohara/core/data/cache/cache_store.dart';

typedef DateTimeReader = DateTime Function();

final class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({this.maximumEntries = 250, DateTimeReader? now})
    : _now = now ?? DateTime.now;

  final int maximumEntries;
  final DateTimeReader _now;
  final Map<String, CacheEntry<Object?>> _entries = {};

  @override
  Future<T?> read<T>(String key, {bool includeExpired = false}) async {
    final entry = await readEntry<T>(key, includeExpired: includeExpired);
    return entry?.value;
  }

  @override
  Future<CacheEntry<T>?> readEntry<T>(
    String key, {
    bool includeExpired = false,
  }) async {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;

    final now = _now();
    if (!includeExpired && entry.isExpired(now)) {
      _entries.remove(key);
      return null;
    }

    final value = entry.value;
    if (value is! T) return null;

    return CacheEntry<T>(
      value: value,
      createdAt: entry.createdAt,
      expiresAt: entry.expiresAt,
    );
  }

  @override
  Future<void> write<T>(String key, T value, {required Duration ttl}) async {
    final now = _now();
    _entries.remove(key);
    _entries[key] = CacheEntry<Object?>(
      value: value,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
    _evictOverflow();
  }

  @override
  Future<void> invalidate(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  void _evictOverflow() {
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}
