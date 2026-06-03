import 'package:flutter/material.dart';

class TypingIndicator
    extends StatefulWidget {

  const TypingIndicator({
    super.key,
  });

  @override
  State<TypingIndicator>
      createState() =>
          _TypingIndicatorState();
}

class _TypingIndicatorState
    extends State<TypingIndicator>

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

      children: [

        Container(

          padding:
              const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),

          decoration:
              BoxDecoration(

            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
              26,
            ),
          ),

          child: Row(

            children: List.generate(
              3,
              (index) {

                return AnimatedBuilder(

                  animation: controller,

                  builder:
                      (_, __) {

                    return Container(

                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 4,
                      ),

                      width: 10,
                      height: 10,

                      decoration:
                          BoxDecoration(

                        shape:
                            BoxShape.circle,

                        color: Colors
                            .pink
                            .withOpacity(

                          .3 +
                              ((controller.value +
                                              index *
                                                  .2) %
                                          1) *
                                  .7,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}