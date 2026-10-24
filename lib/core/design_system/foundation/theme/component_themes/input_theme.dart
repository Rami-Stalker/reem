import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_typography.dart';

InputDecorationTheme dsInputDecorationTheme(DsThemeExtension ds) {
  const radius = DsRadius.borderField;
  final c = ds.colors;

  OutlineInputBorder border(Color color, [double width = 1.5]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecorationTheme(
    filled: true,
    fillColor: c.surfaceVariant,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: DsSpacing.md,
      vertical: DsSpacing.md,
    ),
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(c.primary, 2),
    errorBorder: border(c.error),
    focusedErrorBorder: border(c.error, 2),
    disabledBorder: border(c.divider),
    prefixIconColor: c.onSurfaceVariant,
    suffixIconColor: c.onSurfaceVariant,
    hintStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.onSurfaceVariant,
      fontSize: DsTypography.bodyMedium,
    ),
    labelStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.onSurfaceVariant,
      fontSize: DsTypography.bodyMedium,
    ),
    floatingLabelStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.primary,
      fontWeight: DsTypography.medium,
    ),
    errorStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.error,
      fontSize: DsTypography.labelMedium,
    ),
    helperStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.onSurfaceVariant,
      fontSize: DsTypography.labelMedium,
    ),
  );
}
