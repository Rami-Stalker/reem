import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

SnackBarThemeData dsSnackBarTheme(DsThemeExtension ds) {
  return SnackBarThemeData(
    backgroundColor: ds.colors.onSurface,
    contentTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: ds.colors.surface,
      fontSize: DsTypography.bodyMedium,
    ),
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderMd),
    behavior: SnackBarBehavior.floating,
    elevation: 4,
  );
}
