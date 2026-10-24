import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

class LuxuryBlurredBackground extends StatefulWidget {
  final Widget child;

  const LuxuryBlurredBackground({super.key, required this.child});

  @override
  State<LuxuryBlurredBackground> createState() =>
      _LuxuryBlurredBackgroundState();
}

class _LuxuryBlurredBackgroundState extends State<LuxuryBlurredBackground>
    with TickerProviderStateMixin {
  late AnimationController orbController;

  late AnimationController glowController;

  @override
  void initState() {
    super.initState();

    orbController = AnimationController(
      vsync: this,

      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    glowController = AnimationController(
      vsync: this,

      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    orbController.dispose();
    glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read once, outside the builder: the backdrop is repainted on every
    // animation tick and re-resolving the theme each time is wasted work.
    final c = context.dsColors;

    return AnimatedBuilder(
      animation: Listenable.merge([orbController, glowController]),

      builder: (_, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [c.background, c.surfaceVariant, c.primaryContainer],
            ),
          ),

          child: Stack(
            children: [
              /// TOP ORB
              Positioned(
                top: -120 + orbController.value * 40,

                right: -90 + orbController.value * 30,

                child: _orb(
                  size: 320,

                  colors: [
                    c.primary.withValues(alpha: .35),
                    c.primary.withValues(alpha: .12),
                  ],
                ),
              ),

              /// BOTTOM ORB
              Positioned(
                bottom: -150 + orbController.value * 40,

                left: -100 + orbController.value * 30,

                child: _orb(
                  size: 340,

                  colors: [
                    c.accent.withValues(alpha: .35),
                    c.accent.withValues(alpha: .12),
                  ],
                ),
              ),

              /// CENTER LIGHT
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 500 + glowController.value * 50,

                    height: 500 + glowController.value * 50,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      gradient: RadialGradient(
                        colors: [
                          DsColors.onMedia.withValues(alpha: .32),

                          DsColors.onMedia.withValues(alpha: .02),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              /// BLUR LAYER
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),

                  child: Container(color: Colors.transparent),
                ),
              ),

              /// NOISE OVERLAY
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,

                      end: Alignment.bottomCenter,

                      colors: [
                        DsColors.onMedia.withValues(alpha: .06),

                        Colors.transparent,

                        DsColors.onMedia.withValues(alpha: .03),
                      ],
                    ),
                  ),
                ),
              ),

              /// CONTENT
              widget.child,
            ],
          ),
        );
      },
    );
  }

  Widget _orb({required double size, required List<Color> colors}) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        gradient: RadialGradient(colors: colors),

        boxShadow: [
          BoxShadow(color: colors.first, blurRadius: 120, spreadRadius: 40),
        ],
      ),
    );
  }
}
