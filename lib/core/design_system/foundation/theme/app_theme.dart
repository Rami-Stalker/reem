import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/dark_theme.dart';
import 'package:ohara/core/design_system/foundation/theme/light_theme.dart';
import 'package:ohara/core/design_system/foundation/theme/theme_mode.dart';

export 'package:ohara/core/design_system/foundation/theme/dark_theme.dart';
export 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';
export 'package:ohara/core/design_system/foundation/theme/light_theme.dart';
export 'package:ohara/core/design_system/foundation/theme/theme_controller.dart';
export 'package:ohara/core/design_system/foundation/theme/theme_factory.dart';
export 'package:ohara/core/design_system/foundation/theme/theme_mode.dart';

/// Application theme entry point.
abstract final class AppTheme {
  static ThemeData get light => DsLightTheme.data;
  static ThemeData get dark => DsDarkTheme.data;

  static ThemeData forMode(DsAppThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      DsAppThemeMode.light => light,
      DsAppThemeMode.dark => dark,
      DsAppThemeMode.system => platformBrightness == Brightness.dark
          ? dark
          : light,
    };
  }
}
