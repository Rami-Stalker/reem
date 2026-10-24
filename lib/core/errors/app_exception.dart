import 'package:ohara/core/errors/failure.dart';

sealed class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.statusCode,
    this.details,
    this.cause,
    this.stackTrace,
    this.isRetryable = false,
  });

  final String message;
  final String? code;
  final int? statusCode;

  /// See [Failure.details] — the structured half of the refusal.
  final Map<String, dynamic>? details;
  final Object? cause;
  final StackTrace? stackTrace;
  final bool isRetryable;

  Failure toFailure({StackTrace? stackTrace});

  StackTrace? mergeStackTrace(StackTrace? fallback) => stackTrace ?? fallback;

  @override
  String toString() => '$runtimeType($message)';
}

final class ServerException extends AppException {
  const ServerException(
    super.message, {
    super.code,
    super.statusCode,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => ServerFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(
    super.message, {
    super.code,
    super.statusCode = 401,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => UnauthorizedFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class ForbiddenException extends AppException {
  const ForbiddenException(
    super.message, {
    super.code,
    super.statusCode = 403,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => ForbiddenFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.statusCode,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => NetworkFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code,
    super.statusCode = 422,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => ValidationFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class ConflictException extends AppException {
  const ConflictException(
    super.message, {
    super.code,
    super.statusCode = 409,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => ConflictFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class NotFoundException extends AppException {
  const NotFoundException(
    super.message, {
    super.code,
    super.statusCode = 404,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => NotFoundFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class RateLimitException extends AppException {
  const RateLimitException(
    super.message, {
    super.code,
    super.statusCode = 429,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => RateLimitFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}

final class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.code,
    super.statusCode,
    super.details,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
  });

  @override
  Failure toFailure({StackTrace? stackTrace}) => CacheFailure(
    message,
    code: code,
    statusCode: statusCode,
    details: details,
    cause: cause,
    stackTrace: mergeStackTrace(stackTrace),
    isRetryable: isRetryable,
  );
}
