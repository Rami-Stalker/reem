import 'package:reem/core/errors/app_exception.dart';
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
/// Covers both shapes a provider can throw: a [FailureException] from a
/// repository, and a raw [AppException] from a data source a provider calls
/// straight through — `categoryTreeProvider` does exactly that. Falls back to
/// `toString()` for anything that is neither, which is no worse than what the
/// call sites did before.
String messageOf(Object error) => switch (error) {
  FailureException(:final message) => message,
  AppException(:final message) => message,
  _ => error.toString(),
};
