import 'package:flutter/foundation.dart';

/// Compile-time environment configuration for API endpoints and OAuth clients.
///
/// Local physical-device runs must pass the backend machine LAN address:
///
/// `flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://192.168.1.50:3000`
enum AppFlavor {
  local,
  staging,
  production;

  static AppFlavor fromWire(String value) => switch (value) {
    'staging' => AppFlavor.staging,
    'production' || 'prod' => AppFlavor.production,
    _ => AppFlavor.local,
  };
}

abstract final class AppEnv {
  static const String _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  static AppFlavor get flavor => AppFlavor.fromWire(_environment);

  static bool get isProduction => flavor == AppFlavor.production;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Node.js REST API base URL.
  ///
  /// If API_BASE_URL is not provided, desktop, web, and iOS simulator builds use
  /// localhost. Android emulators must use 10.0.2.2 because localhost points to
  /// the emulator itself. Physical phones still need the computer LAN IPv4
  /// address via --dart-define.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:3000';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3000',
      _ => 'http://localhost:3000',
    };
  }

  /// Google OAuth client ID used by platforms that require a client identifier.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  /// Web/server OAuth client ID. Google Sign-In uses this to issue an ID token
  /// whose audience the backend verifies via GOOGLE_CLIENT_IDS.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Apple Services ID and redirect URI for Android/web Apple Sign-In.
  static const String appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: '',
  );

  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: '',
  );
}
