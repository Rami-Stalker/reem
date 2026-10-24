import 'package:flutter/material.dart';

export 'package:ohara/core/design_system/foundation/layout/responsive/screen_size.dart';
export 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
export 'package:ohara/core/design_system/foundation/theme/extensions/spacing_extension.dart';

/// Unified context extensions for the design system.
extension DsContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => theme.brightness == Brightness.dark;
}
