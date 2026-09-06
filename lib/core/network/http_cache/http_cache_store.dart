import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:reem/core/network/http_cache/http_cache_entry.dart';

/// Where cached responses live.
abstract interface class HttpCacheStore {
  Future<HttpCacheEntry?> read(String key);

  Future<void> write(String key, HttpCacheEntry entry);

  /// Drops every entry whose key satisfies [test]. Used after a write to
  /// retire the reads that write invalidates.
  Future<void> invalidateWhere(bool Function(String key) test);

  Future<void> clear();
}

/// The fast tier. Bounded, least-recently-used.
final class MemoryHttpCacheStore implements HttpCacheStore {
  MemoryHttpCacheStore({this.maximumEntries = 200});

  final int maximumEntries;

  /// A `LinkedHashMap` preserves insertion order, so evicting the first key
  /// evicts the least recently *touched* — reads re-insert to the back.
  final LinkedHashMap<String, HttpCacheEntry> _entries = LinkedHashMap();

  @override
  Future<HttpCacheEntry?> read(String key) async {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry;
  }

  @override
  Future<void> write(String key, HttpCacheEntry entry) async {
    _entries
      ..remove(key)
      ..[key] = entry;
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<void> invalidateWhere(bool Function(String key) test) async {
    _entries.keys.where(test).toList(growable: false).forEach(_entries.remove);
  }

  @override
  Future<void> clear() async => _entries.clear();
}

/// The durable tier: one small JSON file per entry under the app's cache
/// directory.
///
/// A file per entry rather than one index file, because the alternative is
/// rewriting the whole cache on every response — which on a mid-range handset
/// is exactly the stutter this is meant to remove.
final class FileHttpCacheStore implements HttpCacheStore {
  FileHttpCacheStore({Directory? directory, this.maximumEntries = 400})
      : _directory = directory;

  static const _folder = 'reem_http_cache';

  Directory? _directory;
  final int maximumEntries;
  Future<Directory>? _pending;

  /// The key -> filename map, so `invalidateWhere` can test real keys rather
  /// than the hashes they are stored under. Rebuilt lazily from disk.
  final Map<String, String> _index = {};
  bool _indexLoaded = false;

  Future<Directory> _resolveDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    return _pending ??= () async {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, _folder));
      if (!dir.existsSync()) await dir.create(recursive: true);
      _directory = dir;
      return dir;
    }();
  }

  static String _fileNameFor(String key) =>
      '${sha1.convert(utf8.encode(key))}.json';

  Future<void> _loadIndex(Directory dir) async {
    if (_indexLoaded) return;
    _indexLoaded = true;
    final indexFile = File(p.join(dir.path, '_index.json'));
    if (!indexFile.existsSync()) return;
    try {
      final raw = jsonDecode(await indexFile.readAsString());
      if (raw is Map) {
        _index.addAll(raw.map((k, v) => MapEntry('$k', '$v')));
      }
    } on Object {
      // A corrupt index costs a cold cache, nothing more.
      _index.clear();
    }
  }

  Future<void> _saveIndex(Directory dir) async {
    final indexFile = File(p.join(dir.path, '_index.json'));
    try {
      await indexFile.writeAsString(jsonEncode(_index), flush: false);
    } on FileSystemException {
      // Out of space or a sandboxed directory: the cache simply does not
      // survive this launch.
    }
  }

  @override
  Future<HttpCacheEntry?> read(String key) async {
    try {
      final dir = await _resolveDirectory();
      await _loadIndex(dir);
      final file = File(p.join(dir.path, _fileNameFor(key)));
      if (!file.existsSync()) return null;
      return HttpCacheEntry.tryDecode(await file.readAsString());
    } on Object catch (error) {
      debugPrint('http cache read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(String key, HttpCacheEntry entry) async {
    try {
      final dir = await _resolveDirectory();
      await _loadIndex(dir);
      final name = _fileNameFor(key);
      await File(p.join(dir.path, name)).writeAsString(entry.encode());
      _index[key] = name;
      await _evictOverflow(dir);
      await _saveIndex(dir);
    } on Object catch (error) {
      debugPrint('http cache write failed: $error');
    }
  }

  /// Oldest-first eviction, by file modification time.
  Future<void> _evictOverflow(Directory dir) async {
    if (_index.length <= maximumEntries) return;
    final byAge = _index.entries.toList()
      ..sort((a, b) {
        final fa = File(p.join(dir.path, a.value));
        final fb = File(p.join(dir.path, b.value));
        final ta = fa.existsSync()
            ? fa.statSync().modified
            : DateTime.fromMillisecondsSinceEpoch(0);
        final tb = fb.existsSync()
            ? fb.statSync().modified
            : DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
    for (final entry in byAge.take(_index.length - maximumEntries)) {
      final file = File(p.join(dir.path, entry.value));
      if (file.existsSync()) await file.delete();
      _index.remove(entry.key);
    }
  }

  @override
  Future<void> invalidateWhere(bool Function(String key) test) async {
    try {
      final dir = await _resolveDirectory();
      await _loadIndex(dir);
      final doomed = _index.keys.where(test).toList(growable: false);
      for (final key in doomed) {
        final name = _index.remove(key);
        if (name == null) continue;
        final file = File(p.join(dir.path, name));
        if (file.existsSync()) await file.delete();
      }
      if (doomed.isNotEmpty) await _saveIndex(dir);
    } on Object catch (error) {
      debugPrint('http cache invalidation failed: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await _resolveDirectory();
      _index.clear();
      _indexLoaded = true;
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } on Object catch (error) {
      debugPrint('http cache clear failed: $error');
    }
  }
}

/// Memory in front of disk.
///
/// Reads try memory first and promote a disk hit into it, so a screen visited
/// twice in one session never touches the filesystem. Writes go to both, but
/// the disk write is not awaited: a response must not wait on IO to reach the
/// widget that asked for it.
final class TieredHttpCacheStore implements HttpCacheStore {
  TieredHttpCacheStore({required this.fast, required this.durable});

  final HttpCacheStore fast;
  final HttpCacheStore durable;

  @override
  Future<HttpCacheEntry?> read(String key) async {
    final hot = await fast.read(key);
    if (hot != null) return hot;
    final cold = await durable.read(key);
    if (cold != null) await fast.write(key, cold);
    return cold;
  }

  @override
  Future<void> write(String key, HttpCacheEntry entry) async {
    await fast.write(key, entry);
    unawaited(durable.write(key, entry));
  }

  @override
  Future<void> invalidateWhere(bool Function(String key) test) async {
    await fast.invalidateWhere(test);
    await durable.invalidateWhere(test);
  }

  @override
  Future<void> clear() async {
    await fast.clear();
    await durable.clear();
  }
}
