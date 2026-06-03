import 'package:flutter/material.dart';

import 'ds_theme_extension.dart';
import 'theme_factory.dart';

/// Dark theme preset.
abstract final class DsDarkTheme {
  static DsThemeExtension get extension => DsThemeExtension.dark;

  static ThemeData get data => DsThemeFactory.create(ds: extension);
}
