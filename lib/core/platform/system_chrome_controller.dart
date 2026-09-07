import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_breakpoints.dart';
import 'package:reem/core/platform/app_platform.dart';

/// Everything the app tells the operating system about its own window.
///
/// Two responsibilities, both of which were simply absent before: the app
/// never called [SystemChrome] at all.
abstract final class AppSystemChrome {
  /// Draw behind the status and navigation bars.
  ///
  /// Android 15 (target SDK 35) removed the choice: the system draws every app
  /// edge-to-edge and the old opaque-navigation-bar contract is gone. An app
  /// that has not opted in gets it anyway, with whatever colour the OEM
  /// picked showing through — so this asks for it explicitly and paints both
  /// bars transparent, which is the only combination that looks deliberate on
  /// 12 through 16.
  ///
  /// `edgeToEdge` is a no-op on iOS, where an app has always drawn under the
  /// notch and the home indicator. The safe-area insets that make this
  /// survivable arrive through `MediaQuery.padding` on both.
  static Future<void> configure() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Which way the phone may be held.
  ///
  /// Reem's 100-odd screens are drawn as single-column portrait pages — a feed,
  /// a product, a checkout. On a phone, landscape would be a wide column of
  /// stretched cards with nothing to fill the sides, so it is refused; on a
  /// tablet, where a 10-inch landscape canvas is the *normal* way to hold the
  /// device, everything is allowed and the layouts cap their content width
  /// instead.
  ///
  /// The decision is taken from the shortest side of the window rather than
  /// from a device name, so a foldable opened flat gets the tablet answer.
  static Future<void> applyOrientationFor(Size windowSize) {
    final isTablet = windowSize.shortestSide >= DsBreakpoints.medium;
    return SystemChrome.setPreferredOrientations(
      isTablet
          ? DeviceOrientation.values
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  /// Status-bar and navigation-bar icon colours for a given app brightness.
  ///
  /// Transparent bars only work if the icons drawn on them contrast with the
  /// page underneath: dark glyphs over a light theme, light glyphs over a dark
  /// one. Android needs both bars named; iOS only understands the status bar,
  /// and reads the *opposite* field — `statusBarBrightness` is the brightness
  /// of the background there, while `statusBarIconBrightness` is the glyph.
  /// Getting that pair backwards is how a light-theme iOS app ends up with an
  /// invisible white clock, so both are set from one place.
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// True when the phone is driven by a gesture bar rather than three buttons.
  ///
  /// Useful for deciding how much room a floating bar owes the bottom of the
  /// screen: a gesture handle needs a sliver, a button bar needs all of it.
  static bool hasGestureNavigation(BuildContext context) {
    if (AppPlatform.isApple) {
      return MediaQuery.paddingOf(context).bottom > 0;
    }
    // Android reports a ~24dp inset for the gesture pill and ~48dp for the
    // classic three-button bar.
    return MediaQuery.paddingOf(context).bottom < 40;
  }
}
