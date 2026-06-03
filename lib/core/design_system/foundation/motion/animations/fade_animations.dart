import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../curves/ds_curves.dart';

abstract final class DsFadeAnimations {
  static Widget fadeIn({
    required Widget child,
    Duration duration = DsMotion.normal,
    Curve curve = DsCurves.standard,
    double begin = 0,
    double end = 1,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  static Animation<double> animation(AnimationController controller) {
    return CurvedAnimation(parent: controller, curve: DsCurves.standard);
  }
}
