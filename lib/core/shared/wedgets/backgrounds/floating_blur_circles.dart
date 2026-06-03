import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FloatingBlurCircles
    extends StatelessWidget {
  const FloatingBlurCircles({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        Positioned(
          top: -80,
          left: -40,

          child: Container(
            width: 220,
            height: 220,

            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.pink
                  .withOpacity(.15),
            ),
          )
              .animate(
                onPlay:
                    (controller) =>
                        controller.repeat(
                            reverse:
                                true),
              )
              .moveY(
                begin: -10,
                end: 20,
                duration:
                    5.seconds,
              ),
        ),

        Positioned(
          bottom: -100,
          right: -50,

          child: Container(
            width: 260,
            height: 260,

            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple
                  .withOpacity(.08),
            ),
          )
              .animate(
                onPlay:
                    (controller) =>
                        controller.repeat(
                            reverse:
                                true),
              )
              .moveY(
                begin: 20,
                end: -20,
                duration:
                    7.seconds,
              ),
        ),
      ],
    );
  }
}