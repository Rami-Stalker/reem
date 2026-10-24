import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';

/// The brand's pin: a teardrop in the rose gradient with a pearl at its
/// heart. The tip — not the middle — is the point being chosen, so callers
/// place the widget's bottom edge on the spot.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.busy = false, this.scale = 1});

  static const double width = 46;
  static const double height = 58;

  /// While the address is being read the pearl turns, quietly.
  final bool busy;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final gradient = context.primaryGradient;
    return SizedBox(
      width: width * scale,
      height: height * scale,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            size: Size(width * scale, height * scale),
            painter: _PinPainter(colors: gradient.colors, glow: colors.primary),
          ),
          Positioned(
            top: (width / 2 - 9) * scale,
            child: SizedBox.square(
              dimension: 18 * scale,
              child: busy
                  ? CircularProgressIndicator(
                      strokeWidth: 2.4 * scale,
                      color: DsColors.onMedia,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DsColors.onMedia,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 6 * scale,
                          height: 6 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.colors, required this.glow});

  final List<Color> colors;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final tip = Offset(r, size.height);

    // The two points where straight sides leave the round head and meet at
    // the tip: tangents from the tip to the circle.
    final d = tip.dy - center.dy;
    final phi = math.acos(r / d);
    final start = math.pi / 2 + phi;
    final sweep = 2 * math.pi - 2 * phi;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(center.dx + r * math.cos(start), center.dy + r * math.sin(start))
      ..arcTo(Rect.fromCircle(center: center, radius: r), start, sweep, false)
      ..close();

    canvas
      ..drawShadow(path, Colors.black, 6, false)
      ..drawPath(
        path,
        Paint()
          ..color = glow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      )
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.length >= 2 ? colors : [glow, glow],
          ).createShader(Offset.zero & size),
      )
      // A highlight along the upper rim, as if lit from above.
      ..drawArc(
        Rect.fromCircle(center: center, radius: r - 3),
        math.pi * 1.1,
        math.pi * 0.55,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.45),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.9),
      );
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.colors != colors || old.glow != glow;
}

/// The shadow under a pin: tight and dark when it is down, wide and faint
/// while it hovers.
class PinGroundShadow extends StatelessWidget {
  const PinGroundShadow({super.key, required this.lift});

  /// 0 on the ground, 1 fully lifted.
  final double lift;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14 + 12 * lift,
      height: 5 + 3 * lift,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.elliptical(20, 8)),
        color: Colors.black.withValues(alpha: 0.32 - 0.18 * lift),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22 - 0.12 * lift),
            blurRadius: 4 + 4 * lift,
          ),
        ],
      ),
    );
  }
}

/// A ring that spreads from the tip when the pin lands.
class PinRipple extends StatelessWidget {
  const PinRipple({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(progress);
    final size = 12 + 76 * t;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size * 0.42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.elliptical(size / 2, size * 0.21),
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.7 * (1 - t)),
            width: 2.4 * (1 - t) + 0.6,
          ),
          color: color.withValues(alpha: 0.12 * (1 - t)),
        ),
      ),
    );
  }
}
