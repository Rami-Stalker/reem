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

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: body);
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

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ServerException('Invalid response format from server.');
  }
}
