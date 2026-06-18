import 'package:flutter/material.dart';

import '../../tokens/ds_colors.dart';
import '../ds_theme_extension.dart';

export '../../tokens/ds_colors.dart' show DsColorScheme;

/// Semantic color accessors on [BuildContext].
///
/// Always read color through these (or `context.dsColors.*`) — never reference
/// raw [DsColors] swatches in feature/UI code.
extension DsColorContext on BuildContext {
  DsThemeExtension get ds =>
      Theme.of(this).extension<DsThemeExtension>() ?? DsThemeExtension.light;

  DsColorScheme get dsColors => ds.colors;

  // Common shortcuts.
  Color get primaryColor => dsColors.primary;
  Color get onPrimaryColor => dsColors.onPrimary;
  Color get secondaryColor => dsColors.secondary;
  Color get accentColor => dsColors.accent;
  Color get backgroundColor => dsColors.background;
  Color get surfaceColor => dsColors.surface;
  Color get cardColor => dsColors.card;
  Color get onSurfaceColor => dsColors.onSurface;
  Color get onSurfaceVariantColor => dsColors.onSurfaceVariant;
  Color get borderColor => dsColors.border;
  Color get dividerColor => dsColors.divider;
  Color get errorColor => dsColors.error;
  Color get successColor => dsColors.success;
  Color get warningColor => dsColors.warning;
  Color get infoColor => dsColors.info;
}
