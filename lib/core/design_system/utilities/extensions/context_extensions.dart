import 'package:flutter/material.dart';

export '../../foundation/theme/extensions/color_extension.dart';
export '../../foundation/theme/extensions/spacing_extension.dart';
export '../../foundation/layout/responsive/screen_size.dart';

/// Unified context extensions for the design system.
extension DsContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => theme.brightness == Brightness.dark;
}
