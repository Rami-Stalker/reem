import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

DialogThemeData dsDialogTheme(DsThemeExtension ds) {
  return DialogThemeData(
    backgroundColor: ds.colors.surface,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderXl),
    titleTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      fontSize: DsTypography.titleLarge,
      fontWeight: DsTypography.semiBold,
      color: ds.colors.onSurface,
    ),
    contentTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      fontSize: DsTypography.bodyMedium,
      color: ds.colors.onSurfaceVariant,
    ),
  );
}
