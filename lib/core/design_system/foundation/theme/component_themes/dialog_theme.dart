import 'package:flutter/material.dart';

import '../../tokens/ds_elevations.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

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
