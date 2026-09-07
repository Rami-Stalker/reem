import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// How a Reem list behaves under a finger.
///
/// Two things this fixes.
///
/// **The overscroll was iOS everywhere.** Pages hardcoded
/// `BouncingScrollPhysics`, so an Android phone rubber-banded at the end of
/// every list and never showed the stretch its owner expects — the single
/// loudest tell that a Flutter app was drawn for the other platform. Leaving
/// physics unset here and answering from [MaterialScrollBehavior] gives each
/// platform its own: bounce and a fast deceleration curve on iOS, clamp and a
/// stretch indicator on Android.
///
/// **Short pages could not be pulled.** Pull-to-refresh needs a scrollable
/// that accepts a drag even when its content fits, which is what
/// [AlwaysScrollableScrollPhysics] means. Applying it *over* the platform
/// physics rather than instead of them keeps both properties at once.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics().applyTo(
        super.getScrollPhysics(context),
      );

  /// A tablet with a keyboard case, and the desktop shells this repo also
  /// builds, drive lists with a trackpad or a mouse. The default set omits
  /// both, which is why a mouse drag did nothing on a product grid.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
