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
}
