// A retry is only ever as good as the list of things it refuses to retry.
//
// The dangerous half of this feature is not the backoff, it is the judgement:
// repeat a lost `GET` and the worst case is a wasted round trip, repeat a lost
// `POST /orders` and a woman is charged twice for one dress. So most of what is
// pinned here is the refusals.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/network/interceptors/retry_interceptor.dart';

/// A transport that fails a fixed number of times, then succeeds.
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({this.failures = 0, this.failure = _timeout});

  /// How many of the first attempts fail before one is allowed through.
  int failures;

  /// How the failing attempts fail.
  DioException Function(RequestOptions) failure;

  int calls = 0;
  final List<String> methods = [];

  static DioException _timeout(RequestOptions options) =>
      DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: options,
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    methods.add(options.method);
    if (calls <= failures) throw failure(options);
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_FlakyAdapter adapter, {int maxAttempts = 3}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  // Zero delay and a fixed seed: these tests are about which requests repeat,
  // not about how long the app waits, and a real backoff would make the suite
  // slow for no added confidence.
  final retry = RetryInterceptor(
    maxAttempts: maxAttempts,
    baseDelay: Duration.zero,
    maxDelay: Duration.zero,
    random: Random(1),
  );
  dio.interceptors.add(retry);
  retry.client = dio;
  return dio;
}

void main() {
  group('what is retried', () {
    test('a GET that timed out is asked again, and the caller never sees it',
        () async {
      final adapter = _FlakyAdapter(failures: 2);
      final response = await _client(adapter).get<dynamic>('/products');

      expect(adapter.calls, 3, reason: 'one attempt plus two retries');
      expect(response.statusCode, 200);
    });

    test('a connection error is her network, so it is retried', () async {
      final adapter = _FlakyAdapter(
        failures: 1,
        failure: (options) => DioException.connectionError(
          requestOptions: options,
          reason: 'no route to host',
        ),
      );
      await _client(adapter).get<dynamic>('/products');
      expect(adapter.calls, 2);
    });

    test('503 from a restarting process is retried', () async {
      final adapter = _FlakyAdapter(
        failures: 1,
        failure: (options) => DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 503),
        ),
      );
      await _client(adapter).get<dynamic>('/products');
      expect(adapter.calls, 2);
    });

    test('a write carrying an Idempotency-Key may be repeated', () async {
      // This is the checkout case. The API claims the key and replays its first
      // answer, so asking again cannot place a second order — and giving up
      // after one lost response would leave her not knowing whether it worked.
      final adapter = _FlakyAdapter(failures: 1);
      await _client(adapter).post<dynamic>(
        '/orders',
        options: Options(headers: {'Idempotency-Key': 'intent-1'}),
      );
      expect(adapter.calls, 2);
      expect(adapter.methods, ['POST', 'POST']);
    });
  });

  group('what is refused', () {
    test('a bare POST is never repeated', () async {
      // The whole reason this interceptor is careful. Without an idempotency
      // key a repeated write is a second effect, and no backoff makes that safe.
      final adapter = _FlakyAdapter(failures: 1);

      await expectLater(
        _client(adapter).post<dynamic>('/posts', data: {'content': 'مرحبا'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
    });

    test('a PATCH without a key is not repeated either', () async {
      final adapter = _FlakyAdapter(failures: 1);
      await expectLater(
        _client(adapter).patch<dynamic>('/users/me', data: {'name': 'ريم'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
    });

    test('a 4xx is the server answering, not failing', () async {
      final adapter = _FlakyAdapter(
        failures: 1,
        failure: (options) => DioException.badResponse(
          statusCode: 422,
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 422),
        ),
      );
      await expectLater(
        _client(adapter).get<dynamic>('/products'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
    });

    test('429 is not retried — that would tighten the loop it is throttling',
        () async {
      final adapter = _FlakyAdapter(
        failures: 1,
        failure: (options) => DioException.badResponse(
          statusCode: 429,
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 429),
        ),
      );
      await expectLater(
        _client(adapter).get<dynamic>('/auth/otp/request'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
    });

    test('a cancelled request stays cancelled', () async {
      final adapter = _FlakyAdapter(
        failures: 1,
        failure: (options) =>
            DioException.requestCancelled(requestOptions: options, reason: null),
      );
      await expectLater(
        _client(adapter).get<dynamic>('/products'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
    });
  });

  test('it gives up, rather than retrying forever', () async {
    final adapter = _FlakyAdapter(failures: 99);

    await expectLater(
      _client(adapter, maxAttempts: 3).get<dynamic>('/products'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 3, reason: 'maxAttempts counts the first try');
  });

  test('the failure the caller receives is the last one, with its status',
      () async {
    final adapter = _FlakyAdapter(
      failures: 99,
      failure: (options) => DioException.badResponse(
        statusCode: 504,
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 504),
      ),
    );

    try {
      await _client(adapter).get<dynamic>('/products');
      fail('should have thrown');
    } on DioException catch (error) {
      expect(error.response?.statusCode, 504);
    }
  });
}
