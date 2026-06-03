import 'package:flutter/material.dart';

import '../../tokens/ds_colors.dart';
import '../ds_theme_extension.dart';

export '../../tokens/ds_colors.dart' show DsColorScheme;

/// Semantic color accessors on [BuildContext].
extension DsColorContext on BuildContext {
  DsThemeExtension get ds =>
      Theme.of(this).extension<DsThemeExtension>() ?? DsThemeExtension.light;

  DsColorScheme get dsColors => ds.colors;

  Color get primaryColor => dsColors.primary;
  Color get backgroundColor => dsColors.background;
  Color get surfaceColor => dsColors.surface;
  Color get onSurfaceColor => dsColors.onSurface;
  Color get errorColor => dsColors.error;
}
