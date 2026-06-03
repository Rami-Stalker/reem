import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

InputDecorationTheme dsInputDecorationTheme(DsThemeExtension ds) {
  final borderRadius = DsRadius.borderMd;
  return InputDecorationTheme(
    filled: true,
    fillColor: ds.colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: ds.colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: ds.colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: ds.colors.secondary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: ds.colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: ds.colors.error, width: 2),
    ),
    hintStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: ds.colors.onSurfaceVariant,
      fontSize: DsTypography.bodyMedium,
    ),
    labelStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: ds.colors.onSurfaceVariant,
    ),
  );
}
