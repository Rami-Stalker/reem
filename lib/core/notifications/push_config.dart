import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Which Firebase project this build talks to.
///
/// ## Why this is a dart-define and not `firebase_options.dart`
///
/// The FlutterFire CLI generates a `firebase_options.dart` with the project's
/// identifiers baked in, and expects `google-services.json` and
/// `GoogleService-Info.plist` checked into the repository beside it. That is
/// fine for one project and wrong here for two reasons:
///
///  - Reem has local, staging and production builds, and the config file
///    approach ties a build to whichever project's file is on disk at compile
///    time. A `--dart-define` picks it per build, the same way every other
///    environment fact in this app is picked (see `AppEnv`).
///  - The repository has no Firebase project in it yet. With the generated
///    approach, a tree without the config files does not compile; with this
///    one, it compiles and runs and simply has no push — which is what a
///    developer running the app against a local API actually wants.
///
/// The config files still work if they are present: [options] returns null
/// when nothing is defined, and `Firebase.initializeApp()` then falls back to
/// reading them the platform-native way. Neither is an error.
///
/// ## Setting it up
///
/// From the Firebase console, register an Android app with the applicationId
/// in `android/app/build.gradle.kts` and an iOS app with the same bundle id,
/// then read the values off the generated config files:
///
/// ```
/// flutter build apk --release \
///   --dart-define=FIREBASE_PROJECT_ID=reem-prod \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=000000000000 \
///   --dart-define=FIREBASE_ANDROID_API_KEY=AIza... \
///   --dart-define=FIREBASE_ANDROID_APP_ID=1:000000000000:android:abc \
///   --dart-define=FIREBASE_IOS_API_KEY=AIza... \
///   --dart-define=FIREBASE_IOS_APP_ID=1:000000000000:ios:abc \
///   --dart-define=FIREBASE_IOS_BUNDLE_ID=shop.reem.app
/// ```
///
/// The same Firebase project must be the one whose service-account key the API
/// holds in `FCM_SERVICE_ACCOUNT_JSON`. A mismatch is the failure that looks
/// most like a bug in this code and is not: FCM answers `SENDER_ID_MISMATCH`,
/// the server retires the token as dead, and she is quietly unsubscribed.
abstract final class PushConfig {
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');

  static const String _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: '');

  static const String _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');

  static const String _iosApiKey =
      String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: '');

  static const String _iosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');

  static const String _iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');

  /// The storage bucket. Not used — Reem's media lives in Supabase Storage —
  /// but some Firebase SDK paths read it, so it is derivable rather than
  /// another define nobody will remember to pass.
  static String get _bucket =>
      projectId.isEmpty ? '' : '$projectId.appspot.com';

  /// Whether this build was given a project at compile time.
  ///
  /// False is a perfectly good answer. It means push is off for this build and
  /// every other part of the app carries on: the in-app inbox still fills, the
  /// preferences screen still saves, and nothing throws.
  static bool get isConfigured {
    if (projectId.isEmpty || messagingSenderId.isEmpty) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidApiKey.isNotEmpty && _androidAppId.isNotEmpty,
      TargetPlatform.iOS => _iosApiKey.isNotEmpty && _iosAppId.isNotEmpty,
      // macOS, Windows, Linux and web: the seller console runs on desktop and
      // has no push story, and adding one would be a different feature.
      _ => false,
    };
  }

  /// Explicit options for this platform, or null to let the native config
  /// files answer.
  static FirebaseOptions? get options {
    if (!isConfigured) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => FirebaseOptions(
          apiKey: _androidApiKey,
          appId: _androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: _bucket,
        ),
      TargetPlatform.iOS => FirebaseOptions(
          apiKey: _iosApiKey,
          appId: _iosAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: _bucket,
          iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
        ),
      _ => null,
    };
  }

  /// Whether push is worth attempting at all on this platform.
  ///
  /// Android and iOS only. Not because the others could not be made to work,
  /// but because a notification that reaches a closed app is a phone feature,
  /// and the desktop builds of this app are a seller's console that is either
  /// open or not running.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
