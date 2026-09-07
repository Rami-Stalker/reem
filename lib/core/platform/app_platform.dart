import 'package:flutter/foundation.dart';

/// The one place the app asks which phone it is running on.
///
/// Every adaptive decision in the client goes through this enum rather than
/// through `Platform.isIOS` scattered across widgets. Two reasons, and the
/// second is the one that bites: `dart:io` is unavailable on web, and a
/// widget test cannot fake `Platform` — so a `Platform.isIOS` branch is a
/// branch that can never be covered. [debugOverride] makes both halves of
/// every adaptive widget testable from a normal `flutter test` run.
enum AppPlatformKind {
  /// iOS and macOS — Apple's human interface conventions.
  apple,

  /// Android and everything else — Material conventions.
  material;

  bool get isApple => this == AppPlatformKind.apple;
  bool get isMaterial => this == AppPlatformKind.material;
}

abstract final class AppPlatform {
  /// Set by tests to exercise the branch the host machine is not.
  ///
  /// Production code never assigns it; it is asserted away in release.
  @visibleForTesting
  static AppPlatformKind? debugOverride;

  static AppPlatformKind get kind {
    AppPlatformKind? override;
    assert(() {
      override = debugOverride;
      return true;
    }());
    final pinned = override;
    if (pinned != null) return pinned;

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => AppPlatformKind.apple,
      _ => AppPlatformKind.material,
    };
  }

  static bool get isApple => kind.isApple;

  static bool get isMaterial => kind.isMaterial;

  /// Runs [body] with the platform pinned, then restores it.
  @visibleForTesting
  static T runAs<T>(AppPlatformKind kind, T Function() body) {
    final previous = debugOverride;
    debugOverride = kind;
    try {
      return body();
    } finally {
      debugOverride = previous;
    }
  }
}
