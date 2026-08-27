import 'package:dio/dio.dart';

import 'package:reem/core/errors/app_exception.dart';

abstract final class ErrorMapper {
  static AppException fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(
          'Connection failed. Check your network.',
          code: error.type.name,
          cause: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.cancel:
        return ServerException(
          'Request was cancelled.',
          code: error.type.name,
          cause: error,
          stackTrace: error.stackTrace,
          isRetryable: false,
        );
      default:
        return ServerException(
          error.message ?? 'Unexpected network error.',
          code: error.type.name,
          cause: error,
          stackTrace: error.stackTrace,
        );
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final data = response?.data;
    final status = response?.statusCode ?? _extractStatusCode(data) ?? 0;
    final message = _extractMessage(data) ?? 'Request failed ($status)';
    final code = _extractCode(data) ?? _fallbackCode(status);
    final details = _extractDetails(data);

    return switch (status) {
      400 || 422 => ValidationException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      401 => UnauthorizedException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      403 => ForbiddenException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      404 => NotFoundException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      409 => ConflictException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      429 => RateLimitException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
      ),
      >= 500 => ServerException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
        isRetryable: true,
      ),
      _ => ServerException(
        message,
        code: code,
        statusCode: status,
        details: details,
        cause: response,
        isRetryable: false,
      ),
    };
  }

  static String? _extractMessage(dynamic data) {
    final map = _asMap(data);
    if (map != null) {
      final message = map['message'] ?? map['detail'] ?? map['error'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join('\n');
      }
    }
    if (data is String) return data;
    return null;
  }

  /// The server puts anything a handler deliberately attached to an error body
  /// under `details`. It is the difference between "confirm it is you" and
  /// knowing *which* action to confirm for.
  static Map<String, dynamic>? _extractDetails(dynamic data) {
    final details = _asMap(data)?['details'];
    if (details is Map) return Map<String, dynamic>.from(details);
    return null;
  }

  static String? _extractCode(dynamic data) {
    final map = _asMap(data);
    final code =
        map?['code'] ??
        map?['error_code'] ??
        map?['errorCode'] ??
        map?['error'];
    if (code is! String || code.trim().isEmpty) return null;
    return _normalizeCode(code);
  }

  static int? _extractStatusCode(dynamic data) {
    final status = _asMap(data)?['statusCode'];
    if (status is int) return status;
    if (status is String) return int.tryParse(status);
    return null;
  }

  static Map<dynamic, dynamic>? _asMap(dynamic data) =>
      data is Map ? data : null;

  static String _fallbackCode(int status) =>
      status > 0 ? 'HTTP_$status' : 'NETWORK_RESPONSE_ERROR';

  static String _normalizeCode(String value) {
    return value
        .trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toUpperCase();
  }
}
