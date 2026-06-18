import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_env.dart';
import '../../storage/secure_storage_service.dart';
import '../api_endpoints.dart';

/// Attaches the access token to every request and transparently refreshes it on
/// a 401 — the client never sees an expired-token failure for a still-valid
/// session. Concurrent 401s are coalesced into a single refresh (single-flight).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {Dio? refreshClient})
      : _client = refreshClient ?? _buildBareClient();

  final SecureStorageService _storage;

  /// A dependency-free Dio used for both the refresh call and the retried
  /// request, so neither re-enters this interceptor (no infinite loop).
  final Dio _client;

  /// Shared in-flight refresh, so N parallel 401s trigger exactly one refresh.
  static Future<bool>? _inFlightRefresh;

  static const _retriedFlag = '__retried__';

  static Dio _buildBareClient() => Dio(
        BaseOptions(
          baseUrl: AppEnv.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Accept': 'application/json'},
        ),
      );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _attachDeviceHeaders(options);
    final token = await _storage.read(SecureStorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = request.extra[_retriedFlag] == true;

    if (!is401 || alreadyRetried || _isAuthRoute(request.path)) {
      return handler.next(err);
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _clearSession();
      return handler.next(err);
    }

    try {
      final token = await _storage.read(SecureStorageKeys.accessToken);
      await _attachDeviceHeaders(request);
      request.headers['Authorization'] = 'Bearer $token';
      request.extra[_retriedFlag] = true;
      final response = await _client.fetch<dynamic>(request);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isAuthRoute(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh-token') ||
      path.contains('/auth/logout');

  Future<bool> _refreshOnce() {
    return _inFlightRefresh ??=
        _performRefresh().whenComplete(() => _inFlightRefresh = null);
  }

  Future<bool> _performRefresh() async {
    final refresh = await _storage.read(SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _client.post<dynamic>(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refresh},
        options: Options(headers: await _deviceHeaders()),
      );
      final data = res.data;
      if (data is! Map) return false;
      final tokens = data['tokens'];
      if (tokens is! Map) return false;
      await _storage.write(
        SecureStorageKeys.accessToken,
        tokens['access_token'] as String,
      );
      await _storage.write(
        SecureStorageKeys.refreshToken,
        tokens['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(SecureStorageKeys.accessToken);
    await _storage.delete(SecureStorageKeys.refreshToken);
  }

  Future<void> _attachDeviceHeaders(RequestOptions options) async {
    options.headers.addAll(await _deviceHeaders());
  }

  Future<Map<String, String>> _deviceHeaders() async {
    var deviceId = await _storage.read(SecureStorageKeys.deviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'reem-${DateTime.now().microsecondsSinceEpoch}';
      await _storage.write(SecureStorageKeys.deviceId, deviceId);
    }
    return {
      'X-Reem-Device-Id': deviceId,
      'X-Reem-Device-Fingerprint': deviceId,
      'X-Reem-Device-Name': 'Reem ${defaultTargetPlatform.name}',
      'X-Reem-Platform': defaultTargetPlatform.name,
    };
  }
}
