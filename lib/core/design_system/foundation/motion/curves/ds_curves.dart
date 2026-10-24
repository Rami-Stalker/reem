import 'package:flutter/animation.dart';

/// Design-system animation curves.
abstract final class DsCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve accelerate = Curves.easeIn;
  static const Curve emphasizedDecelerate = Curves.easeOutQuart;
  static const Curve emphasizedAccelerate = Curves.easeInQuart;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve linear = Curves.linear;

  /// Soft, gentle settle — the signature Ohara feel for entrances and taps.
  static const Curve gentle = Cubic(0.33, 1.0, 0.68, 1.0); // easeOutCubic-ish, softer
  static const Curve gentleIn = Cubic(0.32, 0.0, 0.67, 0.0);

  /// Refined overshoot — playful but elegant (cards, sheets, dialogs in).
  static const Curve softSpring = Cubic(0.34, 1.3, 0.64, 1.0);

  /// Smooth, expressive in/out for theme + page transitions.
  static const Curve silk = Cubic(0.65, 0.0, 0.35, 1.0);
}
