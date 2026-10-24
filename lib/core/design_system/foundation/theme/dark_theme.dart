import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:ohara/core/design_system/foundation/theme/theme_factory.dart';

/// Dark theme preset.
abstract final class DsDarkTheme {
  static DsThemeExtension get extension => DsThemeExtension.dark;

  static ThemeData get data => DsThemeFactory.create(ds: extension);
}
