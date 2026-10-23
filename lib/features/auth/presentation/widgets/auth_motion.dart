import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The sign-in screens' entrance: each block rises a little and fades in, one
/// after another, so the page assembles itself instead of appearing at once.
extension AuthEnter on Widget {
  /// [order] staggers the block behind the ones before it.
  Widget authEnter(int order) {
    final delay = Duration(milliseconds: 90 * order);
    return animate()
        .fadeIn(delay: delay, duration: DsMotion.slow)
        .slideY(
          begin: 0.12,
          end: 0,
          delay: delay,
          duration: DsMotion.slower,
          curve: DsMotion.gentle,
        );
  }
}
