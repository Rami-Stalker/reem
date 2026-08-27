import 'package:reem/core/errors/app_exception.dart';

typedef RetryClassifier = bool Function(Object error);

final class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 2,
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 2),
    this.shouldRetry = defaultClassifier,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1.');

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final RetryClassifier shouldRetry;

  static bool defaultClassifier(Object error) {
    if (error is NetworkException) return true;
    if (error is ServerException) return error.isRetryable;
    return false;
  }

  Future<T> run<T>(Future<T> Function() action) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt >= maxAttempts || !shouldRetry(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await Future<void>.delayed(_delayFor(attempt));
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Duration _delayFor(int attempt) {
    final delayMs = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final cappedMs = delayMs > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : delayMs;
    return Duration(milliseconds: cappedMs);
  }
}
