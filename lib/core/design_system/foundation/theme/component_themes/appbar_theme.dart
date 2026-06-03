import 'package:flutter/material.dart';

import '../../tokens/ds_typography.dart';
import '../ds_theme_extension.dart';

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
