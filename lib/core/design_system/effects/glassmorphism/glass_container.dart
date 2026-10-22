import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/gradient_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_blur.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_opacity.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 30,
    this.blur = DsBlur.medium,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    // The shadow is painted outside the card only. Drawn as a BoxDecoration
    // shadow it sat *under* the translucent glass, inside the clip, and its
    // downward offset showed through as a pale band along the top edge.
    return CustomPaint(
      painter: _OutsideShadowPainter(
        shadows: context.luxuryShadow,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: context.glassGradient,
              border: Border.all(
                color: context.dsColors.glassBorder.withValues(
                  alpha: DsOpacity.glassBorder,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OutsideShadowPainter extends CustomPainter {
  const _OutsideShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final card = borderRadius.toRRect(Offset.zero & size);
    final reach = shadows.fold<double>(0, (max, s) {
      final extent = s.blurRadius * 2 + s.spreadRadius + s.offset.distance;
      return extent > max ? extent : max;
    });
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(reach)),
          Path()..addRRect(card),
        ),
      );
    for (final shadow in shadows) {
      canvas.drawRRect(
        card.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.shadows != shadows || old.borderRadius != borderRadius;
}
