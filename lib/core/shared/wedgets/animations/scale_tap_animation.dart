import 'package:flutter/material.dart';

class ScaleTapAnimation
    extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ScaleTapAnimation({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<ScaleTapAnimation>
      createState() =>
          _ScaleTapAnimationState();
}

class _ScaleTapAnimationState
    extends State<ScaleTapAnimation> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },

      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },

      onTapUp: (_) {
        setState(() {
          pressed = false;
        });

        widget.onTap?.call();
      },

      child: AnimatedScale(
        scale: pressed ? .96 : 1,

        duration:
            const Duration(
                milliseconds: 150),

        curve: Curves.easeOut,

        child: widget.child,
      ),
    );
  }
}