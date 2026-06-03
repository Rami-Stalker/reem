import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../design_system/design_system.dart';

/// Soft mesh with floating orbs — adapts to light & dark theme.
class FeminineMeshBackground extends StatelessWidget {
  const FeminineMeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final colors = ds.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: BoxDecoration(gradient: ds.meshGradient)),
        Positioned(
          top: -160,
          left: -120,
          child: _orb(
            size: 340,
            color: colors.primary.withValues(alpha: ds.isDark ? 0.18 : 0.22),
            duration: 7,
          ),
        ),
        Positioned(
          top: 120,
          right: -100,
          child: _orb(
            size: 280,
            color: DsColors.lavender400.withValues(alpha: ds.isDark ? 0.12 : 0.16),
            duration: 8,
          ),
        ),
        Positioned(
          bottom: -100,
          left: 40,
          child: _orb(
            size: 260,
            color: DsColors.coral400.withValues(alpha: ds.isDark ? 0.08 : 0.12),
            duration: 6,
          ),
        ),
        if (ds.isDark)
          Positioned(
            bottom: 180,
            right: -80,
            child: _orb(
              size: 220,
              color: DsColors.lavender500.withValues(alpha: 0.1),
              duration: 9,
            ),
          )
        else
          Positioned(
            bottom: 200,
            right: -60,
            child: _orb(
              size: 200,
              color: DsColors.gold300.withValues(alpha: 0.14),
              duration: 9,
            ),
          ),
      ],
    );
  }

  Widget _orb({
    required double size,
    required Color color,
    required int duration,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -12, end: 12, duration: Duration(seconds: duration));
  }
}
