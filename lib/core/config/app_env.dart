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
  ///
  /// A release build gets no such fallback. Without one it would ship pointing
  /// at `10.0.2.2` — an emulator's view of its host — over cleartext, which
  /// Android has refused by default since API 28. The app would not merely
  /// talk to the wrong server; every request would fail and it would present
  /// as dead, on a store listing, to everyone. Forgetting one `--dart-define`
  /// should not be able to do that quietly, so it stops the build instead.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      // `throw`, not `assert`. An assertion is compiled out of a release build,
      // so the one check that mattered — is production talking over TLS? — was
      // absent from exactly the build it was written to guard. A production
      // bundle pointed at `http://` would have shipped every access token and
      // every OTP over cleartext, and the debug run that "passed" would have
      // proved nothing about it.
      if (isProduction && !configured.startsWith('https://')) {
        throw StateError(
          'APP_ENV=production requires an https API_BASE_URL; got '
          '"$configured". Cleartext would put every access token and one-time '
          'code on the wire in the clear.',
        );
      }
      return configured;
    }

    if (kReleaseMode || isProduction) {
      throw StateError(
        'API_BASE_URL was not set for this build.\n'
        'A release build has no sensible localhost fallback — pass the real '
        'host, e.g.\n'
        '  flutter build apk --release '
        '--dart-define=APP_ENV=production '
        '--dart-define=API_BASE_URL=https://api.reem.shop',
      );
    }

    if (kIsWeb) return 'http://localhost:3000';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3000',
      _ => 'http://localhost:3000',
    };
  }

  static const String _configuredShareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: '',
  );

  /// Where a shared link points.
  ///
  /// Separate from [baseUrl]: that one is the API, which is often a LAN address
  /// or a private host, and a link she sends to a friend has to survive leaving
  /// the phone. Defaults to the app's own domain — the same one its bundle id
  /// (`shop.reem.app`) is derived from — and is overridable per build with
  /// `--dart-define=SHARE_BASE_URL=…`.
  static String get shareBaseUrl {
    final configured = _configuredShareBaseUrl.trim();
    final resolved = configured.isNotEmpty ? configured : 'https://reem.shop';
    return resolved.endsWith('/')
        ? resolved.substring(0, resolved.length - 1)
        : resolved;
  }

  /// Where support reaches a human, as an address and a number.
  ///
  /// Both default to empty **on purpose**: the profile used to print
  /// `support@reem.shop` and a Saudi landline that belonged to nobody, and an
  /// inert row of invented contact details is worse than no row. Whichever of
  /// these is left unset simply does not appear.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '',
  );

  static const String supportPhone = String.fromEnvironment(
    'SUPPORT_PHONE',
    defaultValue: '',
  );

  static bool get hasSupportContact =>
      supportEmail.trim().isNotEmpty || supportPhone.trim().isNotEmpty;

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
