import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/ds_theme_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/platform/system_chrome_controller.dart';

AppBarTheme dsAppBarTheme(DsThemeExtension ds) {
  return AppBarTheme(
    backgroundColor: ds.colors.surface,
    foregroundColor: ds.colors.onSurface,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: true,
    // An app bar publishes its own overlay style and so overrides whatever the
    // app frame asked for. Left unset, Flutter guesses one from the bar's
    // colour and leaves the navigation bar to the OEM's default — which is how
    // a transparent-bar app ends up with a solid grey strip at the bottom on
    // some Androids and a white-on-white clock on others.
    systemOverlayStyle: AppSystemChrome.overlayStyleFor(
      ds.isDark ? Brightness.dark : Brightness.light,
    ),
    titleTextStyle: TextStyle(
      fontFamily: DsTypography.fontFamily,
      fontSize: DsTypography.titleLarge,
      fontWeight: DsTypography.semiBold,
      color: ds.colors.onSurface,
    ),
    iconTheme: IconThemeData(color: ds.colors.onSurface),
  );
}
