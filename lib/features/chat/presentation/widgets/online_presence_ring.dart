import 'package:flutter/material.dart';

class OnlinePresenceRing
    extends StatefulWidget {

  final Widget child;

  const OnlinePresenceRing({
    super.key,
    required this.child,
  });

  @override
  State<OnlinePresenceRing>
      createState() =>
          _OnlinePresenceRingState();
}

class _OnlinePresenceRingState
    extends State<
        OnlinePresenceRing>

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
        milliseconds: 1800,
      ),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: controller,

      builder:
          (_, __) {

        return Container(

          padding:
              const EdgeInsets.all(
            4,
          ),

          decoration:
              BoxDecoration(

            shape:
                BoxShape.circle,

            boxShadow: [

              BoxShadow(

                color: Colors.green
                    .withOpacity(

                  .2 +
                      controller
                              .value *
                          .4,
                ),

                blurRadius:
                    20 +
                        controller
                                .value *
                            20,
              ),
            ],

            border: Border.all(

              color: Colors.green
                  .withOpacity(.7),

              width: 2,
            ),
          ),

          child: widget.child,
        );
      },
    );
  }
}