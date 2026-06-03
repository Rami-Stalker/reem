import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedPageWrapper
    extends StatelessWidget {
  final Widget child;

  const AnimatedPageWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          duration: 700.ms,
        )
        .slideY(
          begin: .08,
          curve: Curves.easeOutExpo,
        );
  }
}