import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

TooltipThemeData dsTooltipTheme(DsThemeExtension ds) {
  return TooltipThemeData(
    decoration: BoxDecoration(
      color: ds.colors.onSurface,
      borderRadius: DsRadius.borderSm,
    ),
    textStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: ds.colors.surface,
      fontSize: DsTypography.labelSmall,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    waitDuration: const Duration(milliseconds: 500),
  );
}
