import 'dart:ui';

import 'package:flutter/material.dart';

class LuxuryBlurredBackground
    extends StatefulWidget {

  final Widget child;

  const LuxuryBlurredBackground({
    super.key,
    required this.child,
  });

  @override
  State<LuxuryBlurredBackground>
      createState() =>
          _LuxuryBlurredBackgroundState();
}

class _LuxuryBlurredBackgroundState
    extends State<
        LuxuryBlurredBackground>

    with
        TickerProviderStateMixin {

  late AnimationController
      orbController;

  late AnimationController
      glowController;

  @override
  void initState() {
    super.initState();

    orbController =
        AnimationController(

      vsync: this,

      duration:
          const Duration(
        seconds: 12,
      ),
    )..repeat(reverse: true);

    glowController =
        AnimationController(

      vsync: this,

      duration:
          const Duration(
        seconds: 6,
      ),
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
    return AnimatedBuilder(

      animation:
          Listenable.merge([
        orbController,
        glowController,
      ]),

      builder:
          (_, __) {

        return Container(

          decoration:
              const BoxDecoration(

            gradient:
                LinearGradient(

              begin:
                  Alignment.topLeft,

              end:
                  Alignment.bottomRight,

              colors: [

                Color(0xffFFF7FA),

                Color(0xffFFF0F6),

                Color(0xffFFE8F1),
              ],
            ),
          ),

          child: Stack(

            children: [

              /// TOP ORB
              Positioned(

                top:
                    -120 +
                        orbController
                                .value *
                            40,

                right:
                    -90 +
                        orbController
                                .value *
                            30,

                child:
                    _orb(

                  size: 320,

                  colors: [

                    const Color(
                      0xffFF9EB5,
                    ).withOpacity(.35),

                    const Color(
                      0xffFF5C8A,
                    ).withOpacity(.12),
                  ],
                ),
              ),

              /// BOTTOM ORB
              Positioned(

                bottom:
                    -150 +
                        orbController
                                .value *
                            40,

                left:
                    -100 +
                        orbController
                                .value *
                            30,

                child:
                    _orb(

                  size: 340,

                  colors: [

                    const Color(
                      0xffFFD3E0,
                    ).withOpacity(.35),

                    const Color(
                      0xffFFC1D6,
                    ).withOpacity(.12),
                  ],
                ),
              ),

              /// CENTER LIGHT
              Positioned.fill(

                child: Center(

                  child: Container(

                    width:
                        500 +
                            glowController
                                    .value *
                                50,

                    height:
                        500 +
                            glowController
                                    .value *
                                50,

                    decoration:
                        BoxDecoration(

                      shape:
                          BoxShape.circle,

                      gradient:
                          RadialGradient(

                        colors: [

                          Colors.white
                              .withOpacity(
                                  .32),

                          Colors.white
                              .withOpacity(
                                  .02),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              /// BLUR LAYER
              Positioned.fill(

                child: BackdropFilter(

                  filter:
                      ImageFilter.blur(

                    sigmaX: 50,
                    sigmaY: 50,
                  ),

                  child:
                      Container(
                    color: Colors
                        .transparent,
                  ),
                ),
              ),

              /// NOISE OVERLAY
              Positioned.fill(

                child: Container(

                  decoration:
                      BoxDecoration(

                    gradient:
                        LinearGradient(

                      begin:
                          Alignment
                              .topCenter,

                      end:
                          Alignment
                              .bottomCenter,

                      colors: [

                        Colors.white
                            .withOpacity(
                                .06),

                        Colors.transparent,

                        Colors.white
                            .withOpacity(
                                .03),
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

  Widget _orb({
    required double size,
    required List<Color> colors,
  }) {
    return Container(

      width: size,
      height: size,

      decoration:
          BoxDecoration(

        shape:
            BoxShape.circle,

        gradient:
            RadialGradient(
          colors: colors,
        ),

        boxShadow: [

          BoxShadow(

            color:
                colors.first,

            blurRadius: 120,

            spreadRadius: 40,
          ),
        ],
      ),
    );
  }
}