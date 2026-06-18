enum FailureSeverity { info, warning, recoverable, fatal }

sealed class Failure {
  const Failure(
    this.message, {
    this.code,
    this.statusCode,
    this.cause,
    this.stackTrace,
    this.isRetryable = false,
    this.severity = FailureSeverity.recoverable,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;
  final bool isRetryable;
  final FailureSeverity severity;

  bool get isAuthenticationFailure => this is UnauthorizedFailure;
  bool get isPermissionFailure => this is ForbiddenFailure;
  bool get isConnectivityFailure => this is NetworkFailure;
  bool get isConflictFailure => this is ConflictFailure;
  bool get isRateLimitFailure => this is RateLimitFailure;

  String get displayMessage => message;

  String get debugLabel {
    final parts = [
      runtimeType.toString(),
      if (code != null) code,
      if (statusCode != null) statusCode,
    ];
    return parts.join(':');
  }
}

final class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.code,
    super.statusCode,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
    super.severity = FailureSeverity.recoverable,
  });
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
    super.message, {
    super.code,
    super.statusCode = 401,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.fatal,
  });
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure(
    super.message, {
    super.code,
    super.statusCode = 403,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.warning,
  });
}

final class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code,
    super.statusCode,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
    super.severity = FailureSeverity.recoverable,
  });
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code,
    super.statusCode = 422,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.warning,
  });
}

final class ConflictFailure extends Failure {
  const ConflictFailure(
    super.message, {
    super.code,
    super.statusCode = 409,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.warning,
  });
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    super.code,
    super.statusCode = 404,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.warning,
  });
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure(
    super.message, {
    super.code,
    super.statusCode = 429,
    super.cause,
    super.stackTrace,
    super.isRetryable = true,
    super.severity = FailureSeverity.recoverable,
  });
}

final class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.code,
    super.statusCode,
    super.cause,
    super.stackTrace,
    super.isRetryable = false,
    super.severity = FailureSeverity.recoverable,
  });
}
