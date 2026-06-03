import 'package:flutter/material.dart';

class FloatingVoiceRecordOverlay
    extends StatefulWidget {

  const FloatingVoiceRecordOverlay({
    super.key,
  });

  @override
  State<
          FloatingVoiceRecordOverlay>
      createState() =>
          _FloatingVoiceRecordOverlayState();
}

class _FloatingVoiceRecordOverlayState
    extends State<
        FloatingVoiceRecordOverlay>

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
    return Center(

      child: AnimatedBuilder(

        animation: controller,

        builder:
            (_, __) {

          return Container(

            width:
                180 +
                    controller.value *
                        40,

            height:
                180 +
                    controller.value *
                        40,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: Colors.pink
                  .withOpacity(.08),
            ),

            child: Center(

              child: Container(

                width: 120,
                height: 120,

                decoration:
                    const BoxDecoration(

                  shape:
                      BoxShape.circle,

                  gradient:
                      LinearGradient(

                    colors: [

                      Color(
                          0xffFF9EB5),

                      Color(
                          0xffFF5C8A),
                    ],
                  ),
                ),

                child: const Icon(

                  Icons.mic_rounded,

                  color:
                      Colors.white,

                  size: 44,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}