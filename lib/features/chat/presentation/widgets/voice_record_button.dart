import 'package:flutter/material.dart';

class VoiceRecordButton
    extends StatefulWidget {

  const VoiceRecordButton({
    super.key,
  });

  @override
  State<VoiceRecordButton>
      createState() =>
          _VoiceRecordButtonState();
}

class _VoiceRecordButtonState
    extends State<
        VoiceRecordButton>

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
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: controller,

      builder:
          (_, child) {

        return Transform.scale(

          scale:
              1 +
                  controller.value *
                      .08,

          child: child,
        );
      },

      child: Container(

        width: 58,
        height: 58,

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

              blurRadius: 24,
            ),
          ],
        ),

        child: const Icon(

          Icons.mic_rounded,

          color: Colors.white,
        ),
      ),
    );
  }
}