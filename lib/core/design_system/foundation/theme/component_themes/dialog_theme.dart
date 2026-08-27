import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_elevations.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

DialogThemeData dsDialogTheme(DsThemeExtension ds) {
  final c = ds.colors;
  return DialogThemeData(
    backgroundColor: c.surfaceElevated,
    surfaceTintColor: c.surfaceElevated,
    elevation: DsElevations.modal,
    shadowColor: c.shadow,
    barrierColor: c.overlay,
    insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsRadius.sheet),
    ),
    titleTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamilyDisplay,
      fontFamilyFallback: DsTypography.displayFallback,
      fontSize: DsTypography.titleLarge,
      fontWeight: DsTypography.bold,
      color: c.onSurface,
    ),
    contentTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      fontSize: DsTypography.bodyMedium,
      height: 1.5,
      color: c.onSurfaceVariant,
    ),
  );
}
