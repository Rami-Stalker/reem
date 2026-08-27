import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/theme/theme_factory.dart';

/// Light theme preset.
abstract final class DsLightTheme {
  static DsThemeExtension get extension => DsThemeExtension.light;

  static ThemeData get data => DsThemeFactory.create(ds: extension);
}
