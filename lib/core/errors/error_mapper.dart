import 'package:dio/dio.dart';

import 'app_exception.dart';

abstract final class ErrorMapper {
  static AppException fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException('Connection failed. Check your network.');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.cancel:
        return const ServerException('Request was cancelled.');
      default:
        return ServerException(error.message ?? 'Unexpected network error.');
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final message = _extractMessage(response?.data) ?? 'Request failed ($status)';

    return switch (status) {
      401 || 403 => UnauthorizedException(message),
      404 => NotFoundException(message),
      422 => ValidationException(message),
      >= 500 => ServerException(message),
      _ => ServerException(message),
    };
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }
    if (data is String) return data;
    return null;
  }
}
