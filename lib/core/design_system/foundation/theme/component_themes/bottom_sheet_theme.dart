import 'package:flutter/material.dart';

import '../../tokens/ds_elevations.dart';
import '../../tokens/ds_radius.dart';
import '../ds_theme_extension.dart';

BottomSheetThemeData dsBottomSheetTheme(DsThemeExtension ds) {
  final c = ds.colors;
  return BottomSheetThemeData(
    backgroundColor: c.surfaceElevated,
    surfaceTintColor: c.surfaceElevated,
    modalBackgroundColor: c.surfaceElevated,
    elevation: DsElevations.modal,
    modalElevation: DsElevations.modal,
    shadowColor: c.shadow,
    modalBarrierColor: c.overlay,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: DsRadius.borderSheet),
    dragHandleColor: c.onSurfaceVariant.withValues(alpha: 0.35),
    dragHandleSize: const Size(40, 4),
    showDragHandle: true,
  );
}
