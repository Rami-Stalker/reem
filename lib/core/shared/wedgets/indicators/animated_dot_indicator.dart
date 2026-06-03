import 'package:flutter/material.dart';

class AnimatedDotIndicator
    extends StatelessWidget {
  final bool active;

  const AnimatedDotIndicator({
    super.key,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration:
          const Duration(
              milliseconds: 350),

      margin:
          const EdgeInsets.symmetric(
        horizontal: 4,
      ),

      width: active ? 28 : 10,
      height: 10,

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(30),

        gradient: active
            ? const LinearGradient(
                colors: [
                  Color(0xffFF9EB5),
                  Color(0xffFF5C8A),
                ],
              )
            : null,

        color:
            active ? null : Colors.grey,
      ),
    );
  }
}