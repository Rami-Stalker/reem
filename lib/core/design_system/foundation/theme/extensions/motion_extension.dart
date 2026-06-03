import 'package:flutter/animation.dart';

import '../accessibility/reduced_motion_theme.dart';

export '../../tokens/ds_motion.dart';

extension DsMotionContext on Object {
  Duration dsDuration(Duration preferred) => DsReducedMotion.duration(preferred);
  Curve dsCurve(Curve preferred) => DsReducedMotion.curve(preferred);
}
