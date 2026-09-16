import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/notifications/push_notification_service.dart';
import 'package:reem/core/storage/secure_storage_service.dart';

/// Tells the server where this handset can be reached, and when to stop.
///
/// Small on purpose, and separate from [PushNotificationService], because the
/// two answer different questions. The service knows how to talk to the phone;
/// this knows how to talk to Reem. Keeping them apart is what lets the service
/// be tested without a network and this be tested without a phone.
///
/// ## The three moments a token has to be registered
///
/// Missing any one of them produces the same symptom — notifications that work
/// for some women and not others, with nothing in the logs — so all three are
/// here rather than scattered through whichever screen noticed first:
///
///  - **She signs in.** The obvious one.
///  - **The app starts and she is already signed in.** A token can be reissued
///    while the app is closed, and the server would be holding the old one.
///  - **The provider rotates the token mid-session.** Rare, and the one nobody
///    remembers; `onTokenRefresh` is why the service exposes a stream.
class PushRegistrar {
  PushRegistrar({
    required Dio dio,
    required PushNotificationService push,
    required SecureStorageService storage,
    String appVersion = _fallbackVersion,
  })  : _dio = dio,
        _push = push,
        _storage = storage,
        _appVersion = appVersion;

  /// Kept in step with `version:` in pubspec.yaml. A constant rather than
  /// `package_info_plus`, which would be a whole plugin, a platform channel
  /// and an iOS privacy manifest for one string.
  static const String _fallbackVersion = '1.0.0';

  final Dio _dio;
  final PushNotificationService _push;
  final SecureStorageService _storage;
  final String _appVersion;

  /// The token last successfully registered, so a repeat start does not send
  /// the same value again on every launch.
  String? _registered;

  StreamSubscription<String>? _refreshSubscription;

  /// Begins keeping the server up to date for the signed-in account.
  ///
  /// Idempotent: calling it twice for the same account sends nothing the
  /// second time.
  Future<void> attach({required String locale}) async {
    if (!_push.isAvailable) return;

    _refreshSubscription ??= _push.onTokenRefreshed.listen((token) {
      // A rotation is the one case where the value genuinely changed, so the
      // "already registered" guard has to be cleared before re-sending.
      _registered = null;
      unawaited(_send(token, locale));
    });

    final token = await _push.token();
    // Null is normal on iOS for a few seconds after launch — the FCM token is
    // only issued once APNs has answered — and permanent in the simulator.
    // `onTokenRefresh` delivers it if it arrives late.
    if (token == null) return;
    await _send(token, locale);
  }

  /// This account is done with this handset.
  ///
  /// Called on sign-out. The server is told *before* the token is deleted
  /// locally: deleting first would leave the server holding an address it
  /// keeps pushing to, and the next woman to sign in on this phone would
  /// receive the previous one's notifications — which, on a handset shared
  /// between sisters, is a privacy failure rather than a glitch.
  Future<void> detach() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    final token = _registered ?? await _push.token();
    _registered = null;
    if (token == null) return;

    try {
      await _dio.post<dynamic>(
        ApiEndpoints.pushTokenUnregister,
        data: {'token': token},
      );
    } catch (error) {
      // Signing out must never fail because the server could not be told. The
      // token dies on its own when the app is reinstalled, and the server
      // retires it the first time a push to it is refused.
      if (kDebugMode) debugPrint('Push unregister failed: $error');
    }

    await _push.deleteToken();
  }

  Future<void> _send(String token, String locale) async {
    if (_registered == token) return;
    try {
      await _dio.post<dynamic>(
        ApiEndpoints.pushTokens,
        data: {
          'token': token,
          'provider': 'fcm',
          'platform': _platform,
          // Without this the server cannot tell a reinstall from a second
          // phone, and she ends up with both rows and two of every
          // notification. Reuses the identity the auth layer already keeps,
          // rather than minting a second one that would disagree with it.
          'device_id': await _storage.read(SecureStorageKeys.deviceId),
          'app_version': _appVersion,
          'locale': locale,
        },
      );
      _registered = token;
    } catch (error) {
      // Not fatal and not retried here: the next app start tries again, and
      // the alternative — a retry loop around a request that needs a session —
      // fires hardest exactly when the session is the thing that is broken.
      if (kDebugMode) debugPrint('Push registration failed: $error');
    }
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
