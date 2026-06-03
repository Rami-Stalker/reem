import 'failure.dart';

sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  Failure toFailure();
}

final class ServerException extends AppException {
  const ServerException(super.message);
  @override
  Failure toFailure() => ServerFailure(message);
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message);
  @override
  Failure toFailure() => UnauthorizedFailure(message);
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
  @override
  Failure toFailure() => NetworkFailure(message);
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
  @override
  Failure toFailure() => ValidationFailure(message);
}

final class NotFoundException extends AppException {
  const NotFoundException(super.message);
  @override
  Failure toFailure() => NotFoundFailure(message);
}

final class CacheException extends AppException {
  const CacheException(super.message);
  @override
  Failure toFailure() => CacheFailure(message);
}
