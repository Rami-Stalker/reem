import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LuxuryMeshBackground
    extends StatelessWidget {
  const LuxuryMeshBackground({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        /// BASE
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:
                  Alignment.bottomRight,

              colors: [
                Color(0xffFFF5F8),
                Color(0xffFFE8F0),
                Color(0xffFFFDFE),
              ],
            ),
          ),
        ),

        /// PINK ORB
        Positioned(
          top: -140,
          left: -100,

          child: Container(
            width: 320,
            height: 320,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient:
                  RadialGradient(
                colors: [
                  Colors.pink
                      .withOpacity(.20),

                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate(
                onPlay:
                    (c) =>
                        c.repeat(
                            reverse:
                                true),
              )
              .moveY(
                begin: -20,
                end: 20,
                duration:
                    8.seconds,
              ),
        ),

        /// PURPLE ORB
        Positioned(
          bottom: -160,
          right: -100,

          child: Container(
            width: 360,
            height: 360,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient:
                  RadialGradient(
                colors: [
                  Colors.purple
                      .withOpacity(.15),

                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate(
                onPlay:
                    (c) =>
                        c.repeat(
                            reverse:
                                true),
              )
              .moveY(
                begin: 25,
                end: -15,
                duration:
                    10.seconds,
              ),
        ),
      ],
    );
  }
}