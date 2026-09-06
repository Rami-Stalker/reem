// The response cache is the one piece of infrastructure that can make the app
// *wrong* rather than merely slow, so its edges are pinned here: what it may
// keep, what it must never keep, whose it is, and what happens when the
// network dies mid-session.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/data/cache/cache_policy.dart';
import 'package:reem/core/network/api_client.dart';
import 'package:reem/core/network/http_cache/http_cache_entry.dart';
import 'package:reem/core/network/http_cache/http_cache_rules.dart';
import 'package:reem/core/network/http_cache/http_cache_store.dart';
import 'package:reem/core/network/interceptors/cache_interceptor.dart';

/// A stand-in transport: counts the calls it serves and can be told to fail.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.body);

  Object body;
  int calls = 0;
  bool offline = false;

  /// Held open until [release] is called, so concurrency can be observed.
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (gate != null) await gate!.future;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      '{"value":"$body"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_CountingAdapter adapter, HttpCacheStore store, {DateTime Function()? now}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  final interceptor = CacheInterceptor(store, now: now);
  dio.interceptors.add(interceptor);
  interceptor.client = dio;
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('what may be cached', () {
    test('the catalogue is cacheable; the cart never is', () {
      expect(HttpCacheRules.policyFor('/products'), isNotNull);
      expect(HttpCacheRules.policyFor('/products/abc'), isNotNull);
      expect(HttpCacheRules.policyFor('/categories'), isNotNull);

      // Money, stock and conversations must always come off the wire.
      expect(HttpCacheRules.policyFor('/cart'), isNull);
      expect(HttpCacheRules.policyFor('/orders/123'), isNull);
      expect(HttpCacheRules.policyFor('/chats/9/messages'), isNull);
      expect(HttpCacheRules.policyFor('/auth/me'), isNull);
      expect(HttpCacheRules.policyFor('/seller/orders'), isNull);
      expect(HttpCacheRules.policyFor('/wallet'), isNull);
    });

    test('the payments catalogue is allowed through the payments block', () {
      expect(HttpCacheRules.policyFor('/payments/methods'), isNotNull);
      expect(HttpCacheRules.policyFor('/payments/intents/42'), isNull);
    });

    test('an unlisted read is not cached', () {
      expect(HttpCacheRules.policyFor('/something/new'), isNull);
    });
  });

  group('reading', () {
    late _CountingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _CountingAdapter('first');
      dio = _client(adapter, MemoryHttpCacheStore());
    });

    test('a second read inside the TTL does not touch the network', () async {
      await dio.get<dynamic>('/products');
      final second = await dio.get<dynamic>('/products');

      expect(adapter.calls, 1);
      expect(second.data['value'], 'first');
      expect(second.headers.value(CacheInterceptor.fromCacheHeader), '1');
    });

    test('an uncacheable path always goes to the network', () async {
      await dio.get<dynamic>('/cart');
      await dio.get<dynamic>('/cart');

      expect(adapter.calls, 2);
    });

    test('different queries are different entries', () async {
      await dio.get<dynamic>('/products', queryParameters: {'page': 1});
      await dio.get<dynamic>('/products', queryParameters: {'page': 2});

      expect(adapter.calls, 2);
    });

    test('query order does not create a second entry', () async {
      await dio.get<dynamic>(
        '/products',
        queryParameters: {'a': 1, 'b': 2},
      );
      await dio.get<dynamic>(
        '/products',
        queryParameters: {'b': 2, 'a': 1},
      );

      expect(adapter.calls, 1);
    });
  });

  test('concurrent identical reads share one round trip', () async {
    final adapter = _CountingAdapter('first')..gate = Completer<void>();
    final dio = _client(adapter, MemoryHttpCacheStore());

    final both = Future.wait([
      dio.get<dynamic>('/products'),
      dio.get<dynamic>('/products'),
    ]);
    adapter.gate!.complete();
    final results = await both;

    expect(adapter.calls, 1, reason: 'the second caller waited for the first');
    expect(results.every((r) => r.data['value'] == 'first'), isTrue);
  });

  test('a stale entry is served when the network dies', () async {
    final adapter = _CountingAdapter('first');
    final store = MemoryHttpCacheStore();
    var clock = DateTime(2026, 9, 1, 12);
    final dio = _client(adapter, store, now: () => clock);

    await dio.get<dynamic>('/products');

    // Past the TTL, and the connection is gone.
    clock = clock.add(const Duration(hours: 2));
    adapter.offline = true;

    final response = await dio.get<dynamic>('/products');

    expect(response.statusCode, 200);
    expect(response.data['value'], 'first');
    expect(response.headers.value(CacheInterceptor.fromCacheHeader), '1');
    expect(
      int.parse(response.headers.value(CacheInterceptor.ageHeader)!),
      const Duration(hours: 2).inSeconds,
      reason: 'the screen must be able to say how old this is',
    );
  });

  test('a server error is reported, not papered over with a stale hit', () async {
    // The stale fallback exists for a dead *connection*. A server that
    // answers clearly — 404, 422 — is telling the truth, and serving
    // yesterday's success over it would be the cache lying on its behalf.
    const networkFirst = CachePolicy(ttl: Duration(minutes: 5));
    final options = Options(
      extra: {CacheInterceptor.policyExtraKey: networkFirst},
    );

    final adapter = _CountingAdapter('first');
    var clock = DateTime(2026, 9, 1, 12);
    final dio = _client(adapter, MemoryHttpCacheStore(), now: () => clock);
    await dio.get<dynamic>('/products', options: options);

    clock = clock.add(const Duration(hours: 2));
    dio.httpClientAdapter = _NotFoundAdapter();

    await expectLater(
      dio.get<dynamic>('/products', options: options),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });

  test('a stale paint keeps serving while its refresh fails', () async {
    // Stale-while-revalidate promises a screen now. If the refresh behind it
    // fails, she keeps the screen — she does not get an error thrown at her
    // for something she never asked to wait for.
    final adapter = _CountingAdapter('first');
    var clock = DateTime(2026, 9, 1, 12);
    final dio = _client(adapter, MemoryHttpCacheStore(), now: () => clock);
    await dio.get<dynamic>('/products');

    clock = clock.add(const Duration(hours: 2));
    dio.httpClientAdapter = _NotFoundAdapter();

    final response = await dio.get<dynamic>('/products');
    expect(response.data['value'], 'first');
    expect(response.headers.value(CacheInterceptor.fromCacheHeader), '1');
  });

  test('a write retires the reads it makes untrue', () async {
    final adapter = _CountingAdapter('first');
    final dio = _client(adapter, MemoryHttpCacheStore());

    await dio.get<dynamic>('/products');
    expect(adapter.calls, 1);

    // Favouriting changes what `/products` says about `isLiked`.
    await dio.post<dynamic>('/favorites', data: {'id': 'p1'});

    await dio.get<dynamic>('/products');
    expect(adapter.calls, 3, reason: 'the product read was refetched');
  });

  test('one account is never served another account\'s reads', () async {
    final adapter = _CountingAdapter('leen');
    final dio = _client(adapter, MemoryHttpCacheStore());

    HttpCacheScope.set('user-leen');
    final leen = await dio.get<dynamic>('/products');
    expect(leen.data['value'], 'leen');

    adapter.body = 'nour';
    HttpCacheScope.set('user-nour');
    final nour = await dio.get<dynamic>('/products');

    expect(nour.data['value'], 'nour');
    expect(adapter.calls, 2);
    HttpCacheScope.set(null);
  });

  group('the disk tier', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('reem_cache_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('an entry survives a new store over the same folder', () async {
      final now = DateTime(2026, 9, 1, 12);
      final first = FileHttpCacheStore(directory: dir);
      await first.write(
        'guest|GET|/products|',
        HttpCacheEntry(
          body: {'value': 'kept'},
          statusCode: 200,
          storedAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
        ),
      );

      // A cold start: a brand new store, same folder.
      final second = FileHttpCacheStore(directory: dir);
      final entry = await second.read('guest|GET|/products|');

      expect(entry, isNotNull);
      expect((entry!.body as Map)['value'], 'kept');
    });

    test('a corrupt file degrades to a miss, not a crash', () async {
      final store = FileHttpCacheStore(directory: dir);
      await store.write(
        'guest|GET|/products|',
        HttpCacheEntry(
          body: const {'value': 'kept'},
          statusCode: 200,
          storedAt: DateTime(2026),
          expiresAt: DateTime(2027),
        ),
      );
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('_index.json')) {
          file.writeAsStringSync('} not json {');
        }
      }

      expect(await store.read('guest|GET|/products|'), isNull);
    });
  });

  test('memory eviction keeps the most recently read', () async {
    final store = MemoryHttpCacheStore(maximumEntries: 2);
    HttpCacheEntry entry(String v) => HttpCacheEntry(
          body: {'value': v},
          statusCode: 200,
          storedAt: DateTime(2026),
          expiresAt: DateTime(2027),
        );

    await store.write('a', entry('a'));
    await store.write('b', entry('b'));
    await store.read('a'); // touch a, so b becomes the oldest
    await store.write('c', entry('c'));

    expect(await store.read('a'), isNotNull);
    expect(await store.read('b'), isNull);
    expect(await store.read('c'), isNotNull);
  });

  test('a per-request policy overrides the rules table', () async {
    final adapter = _CountingAdapter('first');
    final dio = _client(adapter, MemoryHttpCacheStore());

    // `/cart` is never cacheable by rule; an explicit policy still governs.
    await dio.get<dynamic>(
      '/cart',
      options: Options(
        extra: {
          CacheInterceptor.policyExtraKey: const CachePolicy(
            ttl: Duration(minutes: 5),
          ),
        },
      ),
    );
    await dio.get<dynamic>(
      '/cart',
      options: Options(
        extra: {
          CacheInterceptor.policyExtraKey: const CachePolicy(
            ttl: Duration(minutes: 5),
          ),
        },
      ),
    );

    expect(adapter.calls, 1);
  });
  test('the real client ships with the cache installed', () async {
    // The unit tests above build their own Dio. This one proves the wiring:
    // a client from `ApiClient.create` caches, which is what the app gets.
    final adapter = _CountingAdapter('first');
    final dio = ApiClient.create(cache: MemoryHttpCacheStore());
    dio.httpClientAdapter = adapter;

    await dio.get<dynamic>('/products');
    await dio.get<dynamic>('/products');

    expect(adapter.calls, 1);
  });
}

class _NotFoundAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"message":"gone"}', 404, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
