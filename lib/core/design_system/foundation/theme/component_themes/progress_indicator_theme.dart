import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';

ProgressIndicatorThemeData dsProgressIndicatorTheme(DsThemeExtension ds) {
  return ProgressIndicatorThemeData(
    color: ds.colors.primary,
    linearTrackColor: ds.colors.surfaceVariant,
    circularTrackColor: ds.colors.surfaceVariant,
  );
}
