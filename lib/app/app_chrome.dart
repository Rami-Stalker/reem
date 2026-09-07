import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/components/states/offline_banner.dart';
import 'package:reem/core/network/connection_status.dart';
import 'package:reem/core/platform/system_chrome_controller.dart';

/// The frame every route is drawn inside — one banner, one text scale, one
/// answer for the system bars.
///
/// It sits in `MaterialApp.builder`, above the navigator and below the theme,
/// which is the only place that can hold all three.
class AppChrome extends ConsumerWidget {
  const AppChrome({super.key, required this.child});

  final Widget child;

  /// The band of text sizes the layouts are drawn to survive.
  ///
  /// Reem's buyers include women running their phones at 150–200%, and the
  /// design system's controls are tested at 2×. Past that the app stops being
  /// a marketplace — a product card with a four-line price does not sell
  /// anything — so the scale is clamped rather than obeyed without limit. The
  /// floor exists for the opposite reason: a phone set to the smallest system
  /// text renders Arabic diacritics into mush.
  ///
  /// This is a ceiling on *this app's* rendering, not a refusal: the system
  /// setting still moves type across the whole range below it, and everything
  /// above it lands on the same generous size rather than on a broken screen.
  static const double _minTextScale = 0.85;
  static const double _maxTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Anything other than a delivered `false` counts as online — the same rule
    // the banner itself applies, so the two can never disagree about whether
    // the band is on screen.
    final online = switch (ref.watch(connectionStatusProvider)) {
      AsyncData(:final value) => value,
      _ => true,
    };

    final media = MediaQuery.of(context);
    final scaled = media.copyWith(
      textScaler: media.textScaler.clamp(
        minScaleFactor: _minTextScale,
        maxScaleFactor: _maxTextScale,
      ),
    );

    // The banner eats the status-bar inset — it carries its own `SafeArea`.
    // Handing the page below the *unmodified* padding was a real defect: every
    // screen then added a second status bar's worth of its own, so going
    // offline pushed the whole app down by ~50dp and left a bald strip under
    // the notch. Removing the top inset for the page, and only while the band
    // is up, keeps the two in step.
    final pageMedia = online ? scaled : scaled.removePadding(removeTop: true);

    return MediaQuery(
      data: scaled,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppSystemChrome.overlayStyleFor(Theme.of(context).brightness),
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: MediaQuery(data: pageMedia, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
