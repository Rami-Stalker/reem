import 'package:flutter/material.dart';

class LuxuryLoadingIndicator
    extends StatefulWidget {
  const LuxuryLoadingIndicator({
    super.key,
  });

  @override
  State<LuxuryLoadingIndicator>
      createState() =>
          _LuxuryLoadingIndicatorState();
}

class _LuxuryLoadingIndicatorState
    extends State<LuxuryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: controller,

      child: Container(
        width: 70,
        height: 70,

        decoration: BoxDecoration(
          shape: BoxShape.circle,

          gradient:
              const SweepGradient(
            colors: [
              Color(0xffFF9EB5),
              Color(0xffFF5C8A),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}