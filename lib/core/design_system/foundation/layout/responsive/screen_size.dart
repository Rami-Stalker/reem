import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_breakpoints.dart';

enum ScreenSize { compact, medium, expanded, large }

extension ScreenSizeContext on BuildContext {
  ScreenSize get screenSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= DsBreakpoints.large) return ScreenSize.large;
    if (width >= DsBreakpoints.expanded) return ScreenSize.expanded;
    if (width >= DsBreakpoints.medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMediumOrLarger => screenSize != ScreenSize.compact;
}
