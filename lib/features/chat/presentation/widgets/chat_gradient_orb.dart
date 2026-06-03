import 'dart:math';

import 'package:flutter/material.dart';

class ChatGradientOrb
    extends StatefulWidget {

  const ChatGradientOrb({
    super.key,
  });

  @override
  State<ChatGradientOrb>
      createState() =>
          _ChatGradientOrbState();
}

class _ChatGradientOrbState
    extends State<ChatGradientOrb>

    with
        SingleTickerProviderStateMixin {

  late AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(

      vsync: this,

      duration:
          const Duration(
        seconds: 12,
      ),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: controller,

      builder:
          (_, __) {

        return Transform.translate(

          offset: Offset(

            sin(controller.value *
                    pi *
                    2) *
                30,

            cos(controller.value *
                    pi *
                    2) *
                20,
          ),

          child: Container(

            width: 240,
            height: 240,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              gradient:
                  RadialGradient(

                colors: [

                  const Color(
                    0xffFF5C8A,
                  ).withOpacity(.22),

                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}