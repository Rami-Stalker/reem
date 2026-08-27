import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// Elevation level for [SurfaceCard].
enum DsCardElevation { flat, low, medium }

/// A clean, opaque content card — the workhorse container of the system.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = DsSpacing.cardPaddingLg,
    this.borderRadius = DsRadius.card,
    this.onTap,
    this.elevation = DsCardElevation.low,
    this.showBorder = true,
    this.color,
    // Backwards-compatible flag (maps to elevation).
    this.useLuxuryShadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final DsCardElevation elevation;
  final bool showBorder;
  final Color? color;
  final bool useLuxuryShadow;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final radius = BorderRadius.circular(borderRadius);

    final shadow = switch (elevation) {
      DsCardElevation.flat => null,
      DsCardElevation.low => context.shadowXs,
      DsCardElevation.medium => context.shadowSoft,
    };

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: c.border.withValues(alpha: 0.5))
            : null,
        boxShadow: useLuxuryShadow ? shadow : null,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return DsScaleAnimations.tapScale(
      pressedScale: 0.98,
      onTap: onTap!,
      child: card,
    );
  }
}
