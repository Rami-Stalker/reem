import 'package:flutter/material.dart';

class FloatingMessageTime
    extends StatefulWidget {

  final String time;

  const FloatingMessageTime({
    super.key,
    required this.time,
  });

  @override
  State<FloatingMessageTime>
      createState() =>
          _FloatingMessageTimeState();
}

class _FloatingMessageTimeState
    extends State<
        FloatingMessageTime>

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
        milliseconds: 1600,
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

          offset: Offset(
            0,
            controller.value * -3,
          ),

          child: child,
        );
      },

      child: Container(

        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),

        decoration:
            BoxDecoration(

          color: Colors.black
              .withOpacity(.06),

          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),

        child: Text(

          widget.time,

          style: TextStyle(

            color:
                Colors.grey[700],

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),
    );
  }
}