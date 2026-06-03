import 'package:flutter/material.dart';

class ChatBackground
    extends StatelessWidget {

  final Widget child;

  const ChatBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(

      children: [

        Container(

          decoration:
              const BoxDecoration(

            gradient:
                LinearGradient(

              begin:
                  Alignment.topLeft,

              end:
                  Alignment.bottomRight,

              colors: [

                Color(0xffFFF6FA),
                Color(0xffFFFDFE),
              ],
            ),
          ),
        ),

        Positioned(

          top: -120,
          right: -80,

          child: Container(

            width: 280,
            height: 280,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: const Color(
                0xffFF5C8A,
              ).withOpacity(.12),
            ),
          ),
        ),

        Positioned(

          bottom: -120,
          left: -60,

          child: Container(

            width: 240,
            height: 240,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: const Color(
                0xffFF9EB5,
              ).withOpacity(.18),
            ),
          ),
        ),

        child,
      ],
    );
  }
}