import 'package:flutter/animation.dart';

import 'package:ohara/core/design_system/foundation/theme/accessibility/reduced_motion_theme.dart';

export 'package:ohara/core/design_system/foundation/tokens/ds_motion.dart';

extension DsMotionContext on Object {
  Duration dsDuration(Duration preferred) => DsReducedMotion.duration(preferred);
  Curve dsCurve(Curve preferred) => DsReducedMotion.curve(preferred);
}
