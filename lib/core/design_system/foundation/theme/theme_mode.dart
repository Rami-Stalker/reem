import 'package:flutter/material.dart';

/// App theme mode — maps to Flutter [ThemeMode] via [DsThemeModeExtension].
enum DsAppThemeMode {
  system,
  light,
  dark;

  bool get isLight => this == DsAppThemeMode.light;
  bool get isDark => this == DsAppThemeMode.dark;
  bool get followsSystem => this == DsAppThemeMode.system;
}

extension DsThemeModeExtension on DsAppThemeMode {
  ThemeMode toFlutterThemeMode() => switch (this) {
        DsAppThemeMode.system => ThemeMode.system,
        DsAppThemeMode.light => ThemeMode.light,
        DsAppThemeMode.dark => ThemeMode.dark,
      };

  static DsAppThemeMode fromFlutter(ThemeMode mode) => switch (mode) {
        ThemeMode.system => DsAppThemeMode.system,
        ThemeMode.light => DsAppThemeMode.light,
        ThemeMode.dark => DsAppThemeMode.dark,
      };
}
