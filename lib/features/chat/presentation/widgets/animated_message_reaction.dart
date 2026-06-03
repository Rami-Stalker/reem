import 'package:flutter/material.dart';

class AnimatedMessageReaction
    extends StatefulWidget {

  final String emoji;

  const AnimatedMessageReaction({
    super.key,
    required this.emoji,
  });

  @override
  State<AnimatedMessageReaction>
      createState() =>
          _AnimatedMessageReactionState();
}

class _AnimatedMessageReactionState
    extends State<
        AnimatedMessageReaction>

    with
        SingleTickerProviderStateMixin {

  late AnimationController
      controller;

  late Animation<double>
      scale;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(

      vsync: this,

      duration:
          const Duration(
        milliseconds: 500,
      ),
    );

    scale = Tween<double>(
      begin: .6,
      end: 1,
    ).animate(

      CurvedAnimation(

        parent: controller,

        curve:
            Curves.elasticOut,
      ),
    );

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(

      scale: scale,

      child: Container(

        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),

        decoration:
            BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            24,
          ),

          boxShadow: [

            BoxShadow(

              color: Colors.black
                  .withOpacity(.06),

              blurRadius: 16,
            ),
          ],
        ),

        child: Text(

          widget.emoji,

          style: const TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}