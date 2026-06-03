import 'package:flutter/material.dart';

class FloatingFAB
    extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;

  const FloatingFAB({
    super.key,
    required this.onTap,
    required this.icon,
  });

  @override
  State<FloatingFAB> createState() =>
      _FloatingFABState();
}

class _FloatingFABState
    extends State<FloatingFAB> {
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
        duration:
            const Duration(
                milliseconds: 180),

        scale: pressed ? .88 : 1,

        child: AnimatedContainer(
          duration:
              const Duration(
                  milliseconds: 350),

          width: 72,
          height: 72,

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
                    .withOpacity(.4),

                blurRadius: 30,
                spreadRadius: 4,
                offset:
                    const Offset(0, 18),
              ),
            ],
          ),

          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}