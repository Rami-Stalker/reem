import 'dart:math';

import 'package:dio/dio.dart';

/// Retries a request that failed for a reason a retry can actually fix.
///
/// The platform had a `RetryPolicy` and a `DataSynchronizer` built to use it,
/// and no repository ever called either — so nothing in the app retried
/// anything. On the connections this platform serves that is not a rare edge:
/// a woman walking between cells loses one request, and what she sees is an
/// error screen with a button that would have worked had it fired 400ms later.
///
/// Doing it at the transport layer rather than per repository is the point.
/// There is one place to read, one place to change, and no feature can forget.
///
/// **What is retried, and why that list is short.** A retry is only safe when
/// repeating the request cannot repeat its effect:
///
///  * `GET` and `HEAD` are safe by definition.
///  * A write that carries an `Idempotency-Key` is safe *because* of that
///    header — the API claims the key with `INSERT … ON CONFLICT DO NOTHING`
///    and replays the first response, which is exactly the contract a retry
///    needs. Checkout is the case that matters: losing the response to a
///    placed order and giving up is worse than asking again.
///  * Every other write is left alone. Retrying a bare `POST` whose response
///    was lost is how one tap becomes two orders, and no amount of backoff
///    makes that safe.
///
/// **What counts as retryable.** Timeouts and connection failures, because
/// those are the network. `502`, `503` and `504`, because those are a proxy or
/// a restarting process rather than a rejected request. Nothing else: a `4xx`
/// is the server answering correctly and asking again will not change its mind,
/// and a bare `500` is a fault that a second identical request will reproduce.
///
/// `429` is deliberately absent. The API answers it with a limit the caller has
/// genuinely exceeded, and quietly asking again is how a client turns its own
/// throttling into a tighter loop.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 3),
    Dio? client,
    Random? random,
  })  : _client = client,
        _random = random ?? Random();

  /// Total attempts including the first, so 3 means "try, then twice more".
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  final Dio? _client;
  final Random _random;

  /// Set by [ApiClient] after construction: the interceptor replays on the same
  /// client it is installed on, so a retry carries the same auth and device
  /// headers the original had.
  Dio? client;

  static const _attemptKey = 'reem.retry.attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final dio = client ?? _client;
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int? ?? 1);

    if (dio == null || attempt >= maxAttempts || !_isSafeToRepeat(options) ||
        !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_delayFor(attempt));

    try {
      final response = await dio.fetch<dynamic>(
        options..extra = {...options.extra, _attemptKey: attempt + 1},
      );
      handler.resolve(response);
    } on DioException catch (retried) {
      // The replay's own failure is the one worth reporting: it carries the
      // final status, and the interceptor chain has already seen the first.
      handler.next(retried);
    }
  }

  bool _isSafeToRepeat(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') return true;
    return options.headers.keys.any(
      (key) => key.toLowerCase() == 'idempotency-key',
    );
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        return status == 502 || status == 503 || status == 504;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  /// Exponential, capped, with full jitter.
  ///
  /// The jitter is not decoration. Without it every client that dropped a
  /// request during the same outage comes back at the same millisecond, and the
  /// retry storm finishes off whatever was recovering.
  Duration _delayFor(int attempt) {
    final exponential = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final capped = min(exponential, maxDelay.inMilliseconds);
    return Duration(milliseconds: _random.nextInt(capped + 1));
  }
}
