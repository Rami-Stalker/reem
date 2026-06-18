import '../errors/failure.dart';

/// Functional result type for repository and use-case boundaries.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isError => this is Error<T>;

  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Error<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Error<T>(:final failure) => failure,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) => switch (this) {
    Success<T>(:final data) => success(data),
    Error<T>(:final failure) => error(failure),
  };

  R fold<R>(
    R Function(Failure failure) onError,
    R Function(T data) onSuccess,
  ) => switch (this) {
    Success<T>(:final data) => onSuccess(data),
    Error<T>(:final failure) => onError(failure),
  };

  Result<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(:final data) => Success(transform(data)),
    Error<T>(:final failure) => Error(failure),
  };

  Future<Result<R>> mapAsync<R>(Future<R> Function(T data) transform) async =>
      switch (this) {
        Success<T>(:final data) => Success(await transform(data)),
        Error<T>(:final failure) => Error(failure),
      };

  Result<R> flatMap<R>(Result<R> Function(T data) transform) => switch (this) {
    Success<T>(:final data) => transform(data),
    Error<T>(:final failure) => Error(failure),
  };

  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T data) transform,
  ) async => switch (this) {
    Success<T>(:final data) => transform(data),
    Error<T>(:final failure) => Error(failure),
  };

  T getOrElse(T Function(Failure failure) fallback) => switch (this) {
    Success<T>(:final data) => data,
    Error<T>(:final failure) => fallback(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
