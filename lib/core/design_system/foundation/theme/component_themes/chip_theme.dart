import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../ds_theme_extension.dart';

ChipThemeData dsChipTheme(DsThemeExtension ds) {
  return ChipThemeData(
    backgroundColor: ds.colors.surfaceVariant,
    selectedColor: ds.colors.primary.withValues(alpha: 0.2),
    disabledColor: ds.colors.disabled,
    labelStyle: TextStyle(color: ds.colors.onSurface, fontSize: 13),
    secondaryLabelStyle: TextStyle(color: ds.colors.onPrimary, fontSize: 13),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: DsRadius.borderFull),
    side: BorderSide(color: ds.colors.border),
  );
}
