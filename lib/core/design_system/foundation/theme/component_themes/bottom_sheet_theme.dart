import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../ds_theme_extension.dart';

BottomSheetThemeData dsBottomSheetTheme(DsThemeExtension ds) {
  return BottomSheetThemeData(
    backgroundColor: ds.colors.surface,
    elevation: 8,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.xxxl)),
    ),
    dragHandleColor: ds.colors.onSurfaceVariant.withValues(alpha: 0.4),
    showDragHandle: true,
  );
}
