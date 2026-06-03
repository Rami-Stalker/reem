import 'package:flutter/material.dart';

class FloatingActionChip
    extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const FloatingActionChip({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<FloatingActionChip>
      createState() =>
          _FloatingActionChipState();
}

class _FloatingActionChipState
    extends State<FloatingActionChip> {
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
        scale: pressed ? .94 : 1,

        duration:
            const Duration(
                milliseconds: 180),

        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 16,
          ),

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
                    50),

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
                    .withOpacity(.22),

                blurRadius: 24,
                offset:
                    const Offset(0, 14),
              ),
            ],
          ),

          child: Row(
            mainAxisSize:
                MainAxisSize.min,

            children: [

              Icon(
                widget.icon,
                color: Colors.white,
                size: 20,
              ),

              const SizedBox(width: 10),

              Text(
                widget.title,

                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}