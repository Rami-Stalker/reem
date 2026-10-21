import 'package:dio/dio.dart';

import 'package:reem/core/data/pagination/paginated_response_mapper.dart';
import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/errors/error_mapper.dart';

/// Shared HTTP helpers with consistent Dio error mapping.
abstract base class BaseRemoteDataSource {
  const BaseRemoteDataSource(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.get<dynamic>(path, queryParameters: query);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<T> getDecoded<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic> json) decode,
  }) async {
    final json = await getJson(path, query: query);
    return decode(json);
  }

  Future<PaginatedData<T>> getPaginated<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic> json) itemFromJson,
  }) async {
    final json = await getJson(path, query: query);
    return PaginatedResponseMapper.fromJson<T>(
      json,
      itemFromJson: itemFromJson,
      fallbackPage: query?['page'] as int? ?? 1,
      fallbackLimit: query?['limit'] as int? ?? 20,
    );
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.get<dynamic>(path, queryParameters: query);
      final data = response.data;
      if (data is List) return data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return data['data'] as List;
      }
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// A POST, optionally protected against being sent twice.
  ///
  /// Pass [idempotencyKey] for anything that must not happen twice if she taps
  /// again or the connection drops mid-flight. The server answers the repeat
  /// from its record of the first instead of running it again — so a doubled
  /// checkout is one order rather than two, with one collection at her door.
  ///
  /// The key must be **generated once per intent, not per attempt**: a fresh
  /// key on every retry names a different request and defeats the whole
  /// mechanism. Callers hold it across retries; see `CheckoutController`.
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        path,
        data: body,
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// A write whose answer is a list rather than an object.
  ///
  /// Some write endpoints answer with the whole collection they just changed —
  /// the policy console does, because publishing one version archives another
  /// and a response describing only the row that was posted would leave the
  /// screen holding two current versions. Without these the caller has to
  /// reach past the base class for `dio`, and loses the error mapping every
  /// other call gets.
  Future<List<dynamic>> postList(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: body);
      return _asList(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<dynamic>> patchList(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.patch<dynamic>(path, data: body);
      return _asList(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<List<dynamic>> deleteList(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.delete<dynamic>(path, data: body);
      return _asList(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// A write that *replaces* rather than amends.
  ///
  /// Distinct from `patchJson` because the two mean different things and the
  /// API distinguishes them: a salon's whole week of opening hours is a PUT,
  /// since a partial timetable update is how a salon ends up open on a day it
  /// meant to close.
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.put<dynamic>(path, data: body);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.patch<dynamic>(path, data: body);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> deleteRequest(String path) async {
    try {
      await dio.delete<dynamic>(path);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.delete<dynamic>(path, data: body);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Mirrors `getList`: a bare array, or one wrapped in `data`.
  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ServerException('Invalid response format from server.');
  }
}
