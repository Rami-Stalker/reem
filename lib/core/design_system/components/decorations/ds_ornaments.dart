import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/tokens/ds_spacing.dart';

/// A hairline **gradient ring** drawn around [child].
///
/// The couture detail the flat 1px border never gave us: a rose-to-champagne
/// thread that catches the eye at the edge of a card without shouting. Used by
/// the feed post card, the mosaic tiles and any surface that wants to read as
/// "the featured one" without a heavy fill.
class DsGradientBorder extends StatelessWidget {
  const DsGradientBorder({
    super.key,
    required this.child,
    required this.radius,
    this.gradient,
    this.width = 1.2,
    this.boxShadow,
    this.backgroundColor,
    this.clip = true,
  });

  final Widget child;
  final double radius;

  /// Defaults to the theme story-ring blend (rose → orchid → champagne).
  final Gradient? gradient;
  final double width;
  final List<BoxShadow>? boxShadow;

  /// The ground painted under [child] — the ring is only a thread, the inside
  /// still needs an opaque card colour so the page mesh does not bleed through.
  final Color? backgroundColor;

  /// Set false when the child paints its own clip (avoids a redundant layer).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final innerRadius = math.max(0.0, radius - width);
    final inner = ColoredBox(
      color: backgroundColor ?? context.dsColors.card,
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient ?? context.storyRingGradient,
        boxShadow: boxShadow,
      ),
      padding: EdgeInsets.all(width),
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: inner,
            )
          : inner,
    );
  }
}

/// A four-point couture sparkle — the little star that says *premium* without
/// a single word of copy. Drawn, not iconographic, so it scales cleanly and
/// tints from the theme.
class DsSparkle extends StatelessWidget {
  const DsSparkle({super.key, this.size = 12, this.color, this.opacity = 1});

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(
        color: (color ?? context.dsColors.accent).withValues(alpha: opacity),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    // The waist controls how needle-like the star reads; 0.14 is the sweet
    // spot between a plump diamond and an unreadable cross.
    final k = r * 0.14;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
      ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// An editorial divider: two fading hairlines meeting at a sparkle.
///
/// Where a plain `Divider` cuts the page, this closes a chapter — the visual
/// full stop between two sections of a magazine spread.
class DsOrnamentDivider extends StatelessWidget {
  const DsOrnamentDivider({
    super.key,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DsSpacing.xxxl,
      vertical: DsSpacing.md,
    ),
    this.color,
  });

  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.dsColors.primary;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: _Hairline(color: tint, fadeStart: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
            child: DsSparkle(size: 11, color: tint, opacity: 0.75),
          ),
          Expanded(child: _Hairline(color: tint, fadeStart: false)),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.color, required this.fadeStart});

  final Color color;
  final bool fadeStart;

  @override
  Widget build(BuildContext context) {
    final stops = [color.withValues(alpha: 0), color.withValues(alpha: 0.34)];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeStart ? stops : stops.reversed.toList(),
        ),
      ),
    );
  }
}
