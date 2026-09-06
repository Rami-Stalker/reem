import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:reem/core/data/cache/cache_policy.dart';
import 'package:reem/core/network/http_cache/http_cache_entry.dart';
import 'package:reem/core/network/http_cache/http_cache_rules.dart';
import 'package:reem/core/network/http_cache/http_cache_store.dart';

/// Whose cache this is.
///
/// Entries are keyed by scope so one account can never be served another's
/// reads — a real risk on a shared handset, which is the common case here. The
/// scope is a *stable* identifier (the user id), not the access token, because
/// the token rotates every fifteen minutes and would throw the cache away with
/// it. Sign-out clears everything as well; the scope is the belt, the clear is
/// the braces.
abstract final class HttpCacheScope {
  static const guest = 'guest';

  static String _current = guest;

  static String get current => _current;

  /// Called by the auth notifier on sign-in, sign-out and session restore.
  static void set(String? userId) {
    _current = (userId == null || userId.isEmpty) ? guest : userId;
  }
}

/// A read-through HTTP cache for GET requests.
///
/// Three jobs, all of which the app was doing without:
///
/// * **Remembering.** A screen revisited inside its TTL paints from the last
///   response instead of showing a spinner and asking again. With the disk
///   tier behind it, that survives a cold start too.
/// * **Coalescing.** Two widgets that mount together and want the same URL
///   make one request, not two.
/// * **Surviving.** When the network fails and a stale entry exists, the stale
///   entry is served rather than an error state. That is the whole of the
///   app's offline story today, and it costs nothing extra.
///
/// What it will not do: cache a write, cache anything not named in
/// [HttpCacheRules], or serve an entry across accounts.
class CacheInterceptor extends Interceptor {
  CacheInterceptor(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final HttpCacheStore _store;
  final DateTime Function() _now;

  /// The client this interceptor is installed on, used to revalidate in the
  /// background. Set by [ApiClient] straight after construction — it cannot be
  /// a constructor argument, because the Dio does not exist until its
  /// interceptors do.
  Dio? client;

  /// In-flight GETs, so identical concurrent requests share one round trip.
  final Map<String, Completer<Response<dynamic>>> _inFlight = {};

  /// Set on a request a revalidation started, so it goes straight to the
  /// network and its response is stored rather than delivered.
  static const _revalidationFlag = '__cache_revalidation__';

  /// Per-request override, for the rare caller that must bypass the rules.
  static const policyExtraKey = '__cache_policy__';

  /// Marks a response that came from the cache, and how old it is. A screen
  /// can read these to say "as of 12 minutes ago" instead of implying live.
  static const fromCacheHeader = 'x-reem-cache';
  static const ageHeader = 'x-reem-cache-age-seconds';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_revalidationFlag] == true) {
      return handler.next(options);
    }

    final policy = _policyFor(options);
    if (policy == null) return handler.next(options);

    final key = _keyFor(options);

    // Someone is already asking for exactly this. Wait for their answer.
    final pending = _inFlight[key];
    if (pending != null) {
      try {
        final shared = await pending.future;
        return handler.resolve(
          _replay(options, shared.data, shared.statusCode),
        );
      } on Object {
        // The shared request failed. Fall through and try on our own, which
        // also gives this request its own shot at the stale fallback.
      }
    }

    final entry = await _store.read(key);
    final now = _now();

    if (entry != null) {
      final fresh = entry.isFresh(now);

      if (policy.strategy == CacheStrategy.cacheOnly ||
          (fresh && policy.strategy != CacheStrategy.networkOnly)) {
        return handler.resolve(_fromEntry(options, entry, now));
      }

      if (policy.strategy == CacheStrategy.staleWhileRevalidate) {
        // Paint now, correct in a moment.
        unawaited(_revalidate(options, key, policy));
        return handler.resolve(_fromEntry(options, entry, now));
      }
    }

    _track(key);
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final policy = _policyFor(options);

    if (policy != null &&
        policy.strategy != CacheStrategy.networkOnly &&
        _isCacheableResponse(response)) {
      final now = _now();
      await _store.write(
        _keyFor(options),
        HttpCacheEntry(
          body: response.data,
          statusCode: response.statusCode ?? 200,
          storedAt: now,
          expiresAt: now.add(policy.ttl),
        ),
      );
    }

    // A successful write retires the reads it makes untrue.
    if (_isWrite(options.method)) {
      await _invalidateFor(options.path);
    }

    _complete(_keyFor(options), response);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final key = _keyFor(options);
    _completeError(key, err);

    final policy = _policyFor(options);
    if (policy == null || !policy.allowStaleOnFailure) return handler.next(err);
    if (!_isRecoverable(err)) return handler.next(err);

    final entry = await _store.read(key);
    if (entry == null) return handler.next(err);

    // The network is gone and we have this morning's answer. This morning's
    // answer is a far better screen than an error card.
    handler.resolve(_fromEntry(options, entry, _now()));
  }

  // ── Internals ──────────────────────────────────────────────────────────

  CachePolicy? _policyFor(RequestOptions options) {
    final override = options.extra[policyExtraKey];
    if (override is CachePolicy) return override;
    if (options.method.toUpperCase() != 'GET') return null;
    return HttpCacheRules.policyFor(options.path);
  }

  /// `scope|METHOD|path|sorted query`. The scope keeps accounts apart; the
  /// sorted query keeps `?a=1&b=2` and `?b=2&a=1` on one entry.
  String _keyFor(RequestOptions options) {
    final query = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    return '${HttpCacheScope.current}|${options.method.toUpperCase()}'
        '|${options.path}|${query.join('&')}';
  }

  bool _isWrite(String method) =>
      const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method.toUpperCase());

  bool _isCacheableResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return false;
    return response.data is Map || response.data is List;
  }

  /// Timeouts and connection failures are the network being unavailable. A
  /// 404 or a 422 is the server being clear, and must not be papered over
  /// with a stale success.
  bool _isRecoverable(DioException err) => switch (err.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        DioExceptionType.unknown => err.response == null,
        _ => false,
      };

  Future<void> _invalidateFor(String path) async {
    final prefixes = HttpCacheRules.invalidationPrefixesFor(path);
    if (prefixes.isEmpty) return;
    await _store.invalidateWhere((key) {
      final parts = key.split('|');
      if (parts.length < 3) return false;
      final cachedPath = parts[2];
      return prefixes.any(
        (prefix) => cachedPath == prefix || cachedPath.startsWith(prefix),
      );
    });
  }

  /// Refreshes an entry behind a stale paint, on the same client so the
  /// request still carries its auth and device headers.
  Future<void> _revalidate(
    RequestOptions options,
    String key,
    CachePolicy policy,
  ) async {
    final dio = client;
    if (dio == null) return;
    try {
      final response = await dio.fetch<dynamic>(
        options.copyWith(extra: {...options.extra, _revalidationFlag: true}),
      );
      if (!_isCacheableResponse(response)) return;
      final now = _now();
      await _store.write(
        key,
        HttpCacheEntry(
          body: response.data,
          statusCode: response.statusCode ?? 200,
          storedAt: now,
          expiresAt: now.add(policy.ttl),
        ),
      );
    } on Object catch (error) {
      // A failed refresh is not a failure: the entry she is looking at stays,
      // and the next read tries again.
      debugPrint('cache revalidation failed for ${options.path}: $error');
    }
  }

  void _track(String key) {
    final completer = Completer<Response<dynamic>>();
    // Marks the future as handled, so a failure with no coalesced waiter is
    // not reported as an unhandled async error. A later `await` still sees it.
    completer.future.ignore();
    _inFlight[key] = completer;
  }

  void _complete(String key, Response<dynamic> response) {
    final completer = _inFlight.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _completeError(String key, Object error) {
    final completer = _inFlight.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  Response<dynamic> _fromEntry(
    RequestOptions options,
    HttpCacheEntry entry,
    DateTime now,
  ) {
    return Response<dynamic>(
      requestOptions: options,
      data: entry.body,
      statusCode: entry.statusCode,
      headers: Headers.fromMap({
        fromCacheHeader: const ['1'],
        ageHeader: ['${entry.age(now).inSeconds}'],
      }),
    );
  }

  Response<dynamic> _replay(
    RequestOptions options,
    dynamic data,
    int? statusCode,
  ) {
    return Response<dynamic>(
      requestOptions: options,
      data: data,
      statusCode: statusCode ?? 200,
      headers: Headers.fromMap({
        fromCacheHeader: const ['coalesced'],
      }),
    );
  }
}
