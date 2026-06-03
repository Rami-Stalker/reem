import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FadeSlideAnimation
    extends StatelessWidget {
  final Widget child;
  final int delay;

  const FadeSlideAnimation({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          delay:
              Duration(milliseconds: delay),
          duration: 700.ms,
        )
        .slideY(
          begin: .2,
          curve: Curves.easeOutExpo,
        );
  }
}