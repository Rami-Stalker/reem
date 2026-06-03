import 'package:flutter/material.dart';

class FloatingWidget
    extends StatefulWidget {
  final Widget child;

  const FloatingWidget({
    super.key,
    required this.child,
  });

  @override
  State<FloatingWidget>
      createState() =>
          _FloatingWidgetState();
}

class _FloatingWidgetState
    extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 3),
      lowerBound: -8,
      upperBound: 8,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,

      builder: (context, child) {
        return Transform.translate(
          offset:
              Offset(0, controller.value),

          child: child,
        );
      },

      child: widget.child,
    );
  }
}