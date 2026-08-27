import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

AppBarTheme dsAppBarTheme(DsThemeExtension ds) {
  return AppBarTheme(
    backgroundColor: ds.colors.surface,
    foregroundColor: ds.colors.onSurface,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      fontSize: DsTypography.titleLarge,
      fontWeight: DsTypography.semiBold,
      color: ds.colors.onSurface,
    ),
    iconTheme: IconThemeData(color: ds.colors.onSurface),
  );
}
