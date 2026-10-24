import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ohara/core/config/app_env.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/interceptors/device_proof_interceptor.dart';
import 'package:ohara/core/security/device_identity_service.dart';
import 'package:ohara/core/security/device_proof_signer.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';

/// Attaches the access token to every request and transparently refreshes it on
/// a 401 — the client never sees an expired-token failure for a still-valid
/// session. Concurrent 401s are coalesced into a single refresh (single-flight).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {Dio? refreshClient})
      : _client = refreshClient ?? _buildBareClient(_storage);

  final SecureStorageService _storage;

  /// A Dio of its own, used for both the refresh call and the retried
  /// request, so neither re-enters this interceptor (no infinite loop). It
  /// still signs device proofs — see [_buildBareClient].
  final Dio _client;

  /// Shared in-flight refresh, so N parallel 401s trigger exactly one refresh.
  static Future<bool>? _inFlightRefresh;

  /// Whether the last failed refresh was a rejection (session really is gone)
  /// or a transport failure (session is probably fine, the network is not).
  static bool _refreshWasRejected = false;

  static const _retriedFlag = '__retried__';

  /// The internal client: no auth interceptor (that is the recursion guard),
  /// but it *does* carry the device-proof interceptor.
  ///
  /// It used to carry nothing at all, and that quietly ended every session.
  /// A refresh token is bound to the handset that was issued it, so
  /// `POST /auth/refresh-token` is refused without a proof — and this is the
  /// only client that ever sends one. So the refresh always failed with
  /// `refresh_without_device_proof`, and roughly fifteen minutes after signing
  /// in, every screen started answering "Unauthorized" while the app still
  /// believed it was signed in. The retried request needs it for the same
  /// reason: replaying a step-up route without its proof gets it refused.
  static Dio _buildBareClient(SecureStorageService storage) {
    final client = Dio(
      BaseOptions(
        baseUrl: AppEnv.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    client.interceptors.add(
      DeviceProofInterceptor(
        DeviceProofSigner(DeviceIdentityService(storage)),
      ),
    );
    return client;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _attachDeviceHeaders(options);

    // Refresh *before* the token dies rather than after. The reactive path
    // costs a wasted request, a 401, a refresh and a replay — three sequential
    // round-trips, which at Syrian latencies is seconds of dead UI at a random
    // moment. `_isAuthRoute` is excluded so the refresh call cannot recurse.
    if (!_isAuthRoute(options.path) && await _accessTokenIsStale()) {
      await _refreshOnce();
    }

    final token = await _storage.read(SecureStorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// True once the access token is inside the last 20% of its life.
  Future<bool> _accessTokenIsStale() async {
    final raw = await _storage.read(SecureStorageKeys.accessTokenExpiresAt);
    if (raw == null) return false;
    final expiry = DateTime.tryParse(raw);
    if (expiry == null) return false;
    // 15-minute tokens mean this fires with ~3 minutes to spare, which is
    // ample even on a slow connection.
    return DateTime.now().isAfter(
      expiry.subtract(const Duration(minutes: 3)),
    );
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
      // Clear only when the server actually rejected the refresh token.
      if (_refreshWasRejected) await _clearSession();
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
      await _persistLifetimes(tokens);
      return true;
    } on DioException catch (error) {
      // Only a definitive rejection means the session is gone. A timeout or a
      // dropped connection — routine on a Syrian mobile network — used to
      // delete the refresh token and strand a perfectly valid session behind a
      // UI that still believed it was signed in.
      final status = error.response?.statusCode;
      _refreshWasRejected = status == 401 || status == 403;
      return false;
    } catch (_) {
      _refreshWasRejected = false;
      return false;
    }
  }

  Future<void> _persistLifetimes(Map<dynamic, dynamic> tokens) async {
    final expiresIn = tokens['expires_in'];
    if (expiresIn is num) {
      await _storage.write(
        SecureStorageKeys.accessTokenExpiresAt,
        DateTime.now()
            .add(Duration(seconds: expiresIn.toInt()))
            .toIso8601String(),
      );
    }
    final refreshExpiresAt = tokens['refresh_expires_at'];
    if (refreshExpiresAt is String) {
      await _storage.write(
        SecureStorageKeys.refreshTokenExpiresAt,
        refreshExpiresAt,
      );
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(SecureStorageKeys.accessToken);
    await _storage.delete(SecureStorageKeys.refreshToken);
    await _storage.delete(SecureStorageKeys.accessTokenExpiresAt);
    await _storage.delete(SecureStorageKeys.refreshTokenExpiresAt);
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
    final guestToken = await _storage.read(SecureStorageKeys.guestToken);
    return {
      'X-Reem-Device-Id': deviceId,
      'X-Reem-Device-Fingerprint': deviceId,
      'X-Reem-Device-Name': 'Ohara ${defaultTargetPlatform.name}',
      'X-Reem-Platform': defaultTargetPlatform.name,
      if (guestToken != null && guestToken.isNotEmpty)
        'X-Reem-Guest-Token': guestToken,
    };
  }
}
