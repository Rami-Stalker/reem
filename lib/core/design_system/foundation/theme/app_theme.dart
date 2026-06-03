import 'package:flutter/material.dart';

import 'dark_theme.dart';
import 'light_theme.dart';
import 'theme_mode.dart';

export 'dark_theme.dart';
export 'ds_theme_extension.dart';
export 'light_theme.dart';
export 'theme_controller.dart';
export 'theme_factory.dart';
export 'theme_mode.dart';

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
