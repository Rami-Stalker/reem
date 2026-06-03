import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredListAnimation
    extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          delay:
              Duration(
                milliseconds:
                    index * 120,
              ),

          duration: 700.ms,
        )
        .slideY(
          begin: .15,
          curve: Curves.easeOutExpo,
        );
  }
}