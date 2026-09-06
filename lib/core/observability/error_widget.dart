import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// What a release build draws where a widget failed to build.
///
/// Flutter already contains the damage: when a `build` throws, the framework
/// swaps *that widget* for an `ErrorWidget` and the rest of the page carries
/// on. What it does not do is make the substitute presentable — in release it
/// is a flat grey rectangle, which reads as her phone being broken rather than
/// one card in a grid having a bug.
///
/// So this replaces the rectangle, and nothing more. The failure itself is
/// already reported through `FlutterError.onError`, which fires before this is
/// ever built; reporting again here would double-count every one.
class ReemErrorWidget extends StatelessWidget {
  const ReemErrorWidget({super.key, required this.details});

  final FlutterErrorDetails details;

  /// Below this, there is no room for anything but a tinted block — a broken
  /// avatar in a chat row must not try to draw an apology.
  static const double _roomForAMessage = 160;

  /// Installs this app-wide. Debug keeps Flutter's red box, which names the
  /// widget and the constraint that failed and is worth far more to a
  /// developer than anything friendly.
  static void install() {
    if (kDebugMode) return;
    ErrorWidget.builder = (details) => ReemErrorWidget(details: details);
  }

  @override
  Widget build(BuildContext context) {
    // This draws in place of something that just failed, so it may not assume
    // a Theme, a Directionality or a localisation is above it — the thing that
    // failed could be any of them. Everything here is self-supplied.
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxHeight >= _roomForAMessage &&
            constraints.maxWidth >= _roomForAMessage;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ColoredBox(
            color: DsColorScheme.light.surfaceVariant,
            child: roomy ? const _Explained() : const _Quiet(),
          ),
        );
      },
    );
  }
}

/// The small case: a tinted block with a hairline icon. It occupies the slot
/// and says "not this one", which is all a 40px square can say.
class _Quiet extends StatelessWidget {
  const _Quiet();

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: DsSizes.iconXs,
          color: DsColorScheme.light.onSurfaceVariant,
        ),
      );
}

class _Explained extends StatelessWidget {
  const _Explained();

  /// Not localised: the localisation delegate is itself something that can
  /// fail, and a widget that exists to survive failure must not depend on it.
  /// Arabic, because the interface is Arabic-first.
  static const _message = 'تعذّر عرض هذا الجزء.';

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: DsSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sentiment_dissatisfied_rounded,
                size: DsSizes.iconLg,
                color: DsColorScheme.light.primary,
              ),
              const SizedBox(height: DsSpacing.sm),
              const Text(
                _message,
                textAlign: TextAlign.center,
                // ds-ignore: no-hand-rolled-text-styles -- drawn where the
                // theme may be the thing that failed, so it carries its own.
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.bodySmall,
                  color: Color(0xFF7A6470),
                ),
              ),
            ],
          ),
        ),
      );
}
