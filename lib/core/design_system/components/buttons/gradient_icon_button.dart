import 'package:flutter/material.dart';

class GradientIconButton
    extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  State<GradientIconButton>
      createState() =>
          _GradientIconButtonState();
}

class _GradientIconButtonState
    extends State<GradientIconButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },

      onTapUp: (_) {
        setState(() {
          pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedScale(
        scale: pressed ? .90 : 1,

        duration:
            const Duration(
                milliseconds: 180),

        child: Container(
          width: 56,
          height: 56,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

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
                    .withOpacity(.25),

                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),

          child: Icon(
            widget.icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}