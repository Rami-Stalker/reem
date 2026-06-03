import 'package:flutter/material.dart';

class AnimatedOnlineIndicator
    extends StatefulWidget {

  const AnimatedOnlineIndicator({
    super.key,
  });

  @override
  State<
          AnimatedOnlineIndicator>
      createState() =>
          _AnimatedOnlineIndicatorState();
}

class _AnimatedOnlineIndicatorState
    extends State<
        AnimatedOnlineIndicator>

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
        milliseconds: 1200,
      ),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: controller,

      builder:
          (_, __) {

        return Stack(

          alignment:
              Alignment.center,

          children: [

            Container(

              width:
                  22 +
                      controller
                              .value *
                          10,

              height:
                  22 +
                      controller
                              .value *
                          10,

              decoration:
                  BoxDecoration(

                shape:
                    BoxShape.circle,

                color: Colors.green
                    .withOpacity(

                  .3 -
                      controller
                              .value *
                          .3,
                ),
              ),
            ),

            Container(

              width: 18,
              height: 18,

              decoration:
                  BoxDecoration(

                shape:
                    BoxShape.circle,

                color:
                    Colors.green,

                border:
                    Border.all(

                  color:
                      Colors.white,

                  width: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}