import 'package:flutter/material.dart';

class LuxuryChatFab
    extends StatefulWidget {

  final VoidCallback onTap;

  const LuxuryChatFab({
    super.key,
    required this.onTap,
  });

  @override
  State<LuxuryChatFab>
      createState() =>
          _LuxuryChatFabState();
}

class _LuxuryChatFabState
    extends State<
        LuxuryChatFab>

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
        seconds: 2,
      ),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: controller,

      builder:
          (_, child) {

        return Transform.translate(

          offset:
              Offset(
            0,
            controller.value * -8,
          ),

          child: child,
        );
      },

      child: GestureDetector(

        onTap: widget.onTap,

        child: Container(

          width: 78,
          height: 78,

          decoration:
              BoxDecoration(

            shape:
                BoxShape.circle,

            gradient:
                const LinearGradient(

              colors: [

                Color(0xffFF9EB5),
                Color(0xffFF5C8A),
              ],
            ),

            boxShadow: [

              BoxShadow(

                color: Colors.pink
                    .withOpacity(.35),

                blurRadius: 26,

                spreadRadius: 2,
              ),
            ],
          ),

          child: const Icon(

            Icons.edit_rounded,

            color: Colors.white,

            size: 34,
          ),
        ),
      ),
    );
  }
}