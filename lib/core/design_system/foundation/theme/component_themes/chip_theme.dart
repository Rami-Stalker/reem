import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

ChipThemeData dsChipTheme(DsThemeExtension ds) {
  final c = ds.colors;
  return ChipThemeData(
    backgroundColor: c.surfaceVariant,
    selectedColor: c.primaryContainer,
    secondarySelectedColor: c.primaryContainer,
    disabledColor: c.disabled,
    checkmarkColor: c.onPrimaryContainer,
    labelStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.onSurface,
      fontSize: DsTypography.labelLarge,
      fontWeight: DsTypography.medium,
      letterSpacing: DsTypography.letterSpacingWide,
    ),
    secondaryLabelStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      color: c.onPrimaryContainer,
      fontSize: DsTypography.labelLarge,
      fontWeight: DsTypography.semiBold,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: DsSpacing.sm,
      vertical: DsSpacing.xs,
    ),
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderChip),
    side: BorderSide(color: c.border),
    showCheckmark: false,
  );
}
