import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';

CardThemeData dsCardTheme(DsThemeExtension ds) {
  return CardThemeData(
    color: ds.colors.card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: DsRadius.borderXl,
      side: BorderSide(color: ds.colors.border.withValues(alpha: 0.5)),
    ),
    margin: EdgeInsets.zero,
  );
}
