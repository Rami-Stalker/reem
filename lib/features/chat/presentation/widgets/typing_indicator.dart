import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

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
            horizontal: DsSpacing.xl,
            vertical: DsSpacing.lg,
          ),

          decoration:
              BoxDecoration(

            color: DsColors.onMedia,

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
                      (_, _) {

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

                        color: context.dsColors.primary.withValues(
                          alpha: .3 +
                              ((controller.value + index * .2) % 1) * .7,
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