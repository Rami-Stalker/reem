import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../curves/ds_curves.dart';

abstract final class DsSlideAnimations {
  static Widget slideUp({
    required Widget child,
    Duration duration = DsMotion.normal,
    double offset = 24,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: Offset(0, offset), end: Offset.zero),
      duration: duration,
      curve: DsCurves.emphasized,
      builder: (context, value, child) =>
          Transform.translate(offset: value, child: child),
      child: child,
    );
  }
}
