import 'package:flutter/material.dart';

import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import 'accessibility/accessibility_theme.dart';
import 'component_themes/appbar_theme.dart';
import 'component_themes/bottom_sheet_theme.dart';
import 'component_themes/button_theme.dart';
import 'component_themes/card_theme.dart';
import 'component_themes/chip_theme.dart';
import 'component_themes/dialog_theme.dart';
import 'component_themes/input_theme.dart';
import 'component_themes/navigation_theme.dart';
import 'component_themes/progress_indicator_theme.dart';
import 'component_themes/snack_bar_theme.dart';
import 'component_themes/tooltip_theme.dart';
import 'ds_theme_extension.dart';

/// Builds complete [ThemeData] from design tokens.
abstract final class DsThemeFactory {
  static ThemeData create({
    required DsThemeExtension ds,
    DsAccessibilityConfig accessibility = const DsAccessibilityConfig(),
  }) {
    final isDark = ds.isDark;
    var colorScheme = isDark ? DsColors.darkScheme : DsColors.lightScheme;
    colorScheme = accessibility.applyTo(colorScheme, isDark: isDark);

    var textTheme = DsTypography.textTheme(
      onSurface: ds.colors.onSurface,
      onSurfaceVariant: ds.colors.onSurfaceVariant,
    );
    textTheme = accessibility.applyBold(textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ds.colors.background,
      fontFamily: DsTypography.fontFamily,
      textTheme: textTheme,
      extensions: [ds],
      appBarTheme: dsAppBarTheme(ds),
      elevatedButtonTheme: dsElevatedButtonTheme(ds),
      outlinedButtonTheme: dsOutlinedButtonTheme(ds),
      textButtonTheme: dsTextButtonTheme(ds),
      floatingActionButtonTheme: dsFabTheme(ds),
      inputDecorationTheme: dsInputDecorationTheme(ds),
      cardTheme: dsCardTheme(ds),
      navigationBarTheme: dsNavigationBarTheme(ds),
      bottomNavigationBarTheme: dsBottomNavTheme(ds),
      dialogTheme: dsDialogTheme(ds),
      bottomSheetTheme: dsBottomSheetTheme(ds),
      chipTheme: dsChipTheme(ds),
      snackBarTheme: dsSnackBarTheme(ds),
      progressIndicatorTheme: dsProgressIndicatorTheme(ds),
      tooltipTheme: dsTooltipTheme(ds),
      dividerTheme: DividerThemeData(color: ds.colors.divider, thickness: 1),
      iconTheme: IconThemeData(color: ds.colors.onSurface),
    );
  }
}
