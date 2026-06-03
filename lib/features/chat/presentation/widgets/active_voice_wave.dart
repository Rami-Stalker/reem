import 'dart:math';

import 'package:flutter/material.dart';

class ActiveVoiceWave
    extends StatefulWidget {

  const ActiveVoiceWave({
    super.key,
  });

  @override
  State<ActiveVoiceWave>
      createState() =>
          _ActiveVoiceWaveState();
}

class _ActiveVoiceWaveState
    extends State<ActiveVoiceWave>

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
        milliseconds: 900,
      ),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Row(

      mainAxisAlignment:
          MainAxisAlignment.center,

      children: List.generate(
        20,
        (index) {

          return AnimatedBuilder(

            animation: controller,

            builder:
                (_, __) {

              final value =
                  sin(

                controller.value *
                        pi *
                        2 +
                    index,
              );

              return Container(

                margin:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 2,
                ),

                width: 5,

                height:
                    18 +
                        (value * 20),

                decoration:
                    BoxDecoration(

                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),

                  gradient:
                      const LinearGradient(

                    colors: [

                      Color(
                          0xffFF9EB5),

                      Color(
                          0xffFF5C8A),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}