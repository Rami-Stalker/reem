import 'package:reem/core/errors/failure.dart';

/// A [Failure] thrown out of a `FutureProvider`, carrying its own words.
///
/// Riverpod's `AsyncValue.error` hands the screen an `Object`, and a dozen
/// providers used to wrap the failure in a bare `Exception(failure.message)`.
/// Every screen that renders `error.toString()` then showed the operator —
/// or the shopper — a sentence with `Exception: ` bolted onto the front of it,
/// in front of Arabic copy written for her.
///
/// This keeps the whole [Failure] reachable, so a screen can offer a retry
/// when the failure says it is retryable, and prints as the message alone when
/// it is stringified.
class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  String get message => failure.message;

  bool get isRetryable => failure.isRetryable;

  @override
  String toString() => failure.message;
}

/// The message behind any error an `AsyncValue` surfaced.
///
/// Falls back to `toString()` for anything that is not one of ours, which is
/// no worse than what the call site did before and is never reached for a
/// failure that came through a repository.
String messageOf(Object error) =>
    error is FailureException ? error.message : error.toString();
