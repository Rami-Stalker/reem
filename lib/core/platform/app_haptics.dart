import 'package:flutter/services.dart';

import 'package:reem/core/platform/app_platform.dart';

/// Feedback named by what happened, not by how hard the phone should buzz.
///
/// The two platforms disagree about what a vibration means. `selectionClick`
/// is a real Taptic gesture on iOS and a no-op on most Android builds, where
/// the equivalent is `HapticFeedbackConstants.CLOCK_TICK` reached through
/// `vibrate`. `heavyImpact` on Android is a long, cheap buzz that reads as an
/// error even when the news was good. Call sites therefore say *selection*,
/// *confirm*, *warn* — and this decides what each one costs on the phone in
/// hand.
///
/// Every method is fire-and-forget on purpose: haptics are decoration, and a
/// screen must never wait on the vibrator, nor fail because a device has none.
abstract final class AppHaptics {
  static void _fire(Future<void> Function() effect) {
    // A device with no vibrator, or one where the user has switched haptics
    // off, rejects the channel call. That is not an app error.
    effect().catchError((_) {});
  }

  /// Moving between options — a chip, a tab, a size swatch.
  static void selection() {
    _fire(
      AppPlatform.isApple
          ? HapticFeedback.selectionClick
          : HapticFeedback.lightImpact,
    );
  }

  /// A tap that changed something small — a like, a bookmark.
  static void light() => _fire(HapticFeedback.lightImpact);

  /// A committed action — added to the bag, order placed, photo captured.
  static void confirm() => _fire(HapticFeedback.mediumImpact);

  /// Something the woman using the app should notice went wrong.
  ///
  /// Android's `heavyImpact` is the closest thing it has to iOS's notification
  /// feedback; on iOS a heavy thud reads as a slam, so the medium one is used
  /// and the error is carried by the message rather than the wrist.
  static void warn() {
    _fire(
      AppPlatform.isApple
          ? HapticFeedback.mediumImpact
          : HapticFeedback.heavyImpact,
    );
  }

  /// A long press that opened something.
  static void longPress() {
    _fire(
      AppPlatform.isApple
          ? HapticFeedback.mediumImpact
          : HapticFeedback.vibrate,
    );
  }
}
