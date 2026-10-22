import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

ElevatedButtonThemeData dsElevatedButtonTheme(DsThemeExtension ds) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ds.colors.primary,
      foregroundColor: ds.colors.onPrimary,
      minimumSize: const Size(double.infinity, DsConstraints.buttonHeightMd),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: DsRadius.borderXxl),
      textStyle: TextStyle(
        fontFamily: DsTypography.fontFamily,
        fontWeight: DsTypography.semiBold,
        fontSize: DsTypography.titleSmall,
      ),
    ),
  );
}

OutlinedButtonThemeData dsOutlinedButtonTheme(DsThemeExtension ds) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ds.colors.primary,
      minimumSize: const Size(double.infinity, DsConstraints.buttonHeightMd),
      side: BorderSide(color: ds.colors.primary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: DsRadius.borderXxl),
      textStyle: TextStyle(
        fontFamily: DsTypography.fontFamily,
        fontWeight: DsTypography.semiBold,
        fontSize: DsTypography.titleSmall,
      ),
    ),
  );
}

TextButtonThemeData dsTextButtonTheme(DsThemeExtension ds) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ds.colors.primary,
      textStyle: TextStyle(
        fontFamily: DsTypography.fontFamily,
        fontWeight: DsTypography.medium,
        fontSize: DsTypography.bodyMedium,
      ),
    ),
  );
}

FloatingActionButtonThemeData dsFabTheme(DsThemeExtension ds) {
  return FloatingActionButtonThemeData(
    backgroundColor: ds.colors.primary,
    foregroundColor: ds.colors.onPrimary,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderXl),
  );
}

/// Filled buttons had no theme, so the nine in the app fell back to stock
/// Material — a squarer, shorter button in the scheme's primary — beside
/// elevated ones in the brand's shape. This gives them the same fill, radius
/// and type. Unlike the elevated theme it keeps its natural width: several
/// sit in rows, where a minimum of the full width would not lay out.
FilledButtonThemeData dsFilledButtonTheme(DsThemeExtension ds) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ds.colors.primary,
      foregroundColor: ds.colors.onPrimary,
      minimumSize: const Size(64, DsConstraints.buttonHeightMd),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: DsRadius.borderXxl),
      textStyle: TextStyle(
        fontFamily: DsTypography.fontFamily,
        fontWeight: DsTypography.semiBold,
        fontSize: DsTypography.titleSmall,
      ),
    ),
  );
}
