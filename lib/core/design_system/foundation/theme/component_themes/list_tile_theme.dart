import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// List rows — settings, devices, picker options — in the design system's
/// row padding and ink, with the rounded corners its cards use, rather than
/// stock Material's square, tighter rows.
ListTileThemeData dsListTileTheme(DsThemeExtension ds) {
  return ListTileThemeData(
    contentPadding: DsSpacing.listRowPadding,
    iconColor: ds.colors.onSurfaceVariant,
    textColor: ds.colors.onSurface,
    selectedColor: ds.colors.primary,
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderLg),
  );
}
