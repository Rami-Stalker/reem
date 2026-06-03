import 'package:flutter/material.dart';

import 'ds_theme_extension.dart';
import 'theme_factory.dart';

/// Light theme preset.
abstract final class DsLightTheme {
  static DsThemeExtension get extension => DsThemeExtension.light;

  static ThemeData get data => DsThemeFactory.create(ds: extension);
}
