import 'package:flutter/animation.dart';

/// Standard animation durations for UI motion.
abstract final class DsMotion {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration moderate = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 700);
  static const Duration slowest = Duration(milliseconds: 1000);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve accelerate = Curves.easeIn;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;

  /// Soft signature easings (mirror [DsCurves]).
  static const Curve gentle = Cubic(0.33, 1.0, 0.68, 1.0);
  static const Curve softSpring = Cubic(0.34, 1.3, 0.64, 1.0);
  static const Curve silk = Cubic(0.65, 0.0, 0.35, 1.0);

  /// Tap feedback scale target for pressable surfaces.
  static const double pressedScale = 0.97;
}
