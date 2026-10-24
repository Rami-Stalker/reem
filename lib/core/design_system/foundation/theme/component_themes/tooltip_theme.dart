import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_typography.dart';

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
