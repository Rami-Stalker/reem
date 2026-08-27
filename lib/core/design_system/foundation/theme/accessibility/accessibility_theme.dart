import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/accessibility/contrast_profiles.dart';
export 'package:reem/core/design_system/foundation/theme/accessibility/contrast_profiles.dart';
export 'package:reem/core/design_system/foundation/theme/accessibility/reduced_motion_theme.dart';

/// Accessibility configuration bundle for theme factory.
@immutable
class DsAccessibilityConfig {
  const DsAccessibilityConfig({
    this.highContrast = false,
    this.boldText = false,
  });

  final bool highContrast;
  final bool boldText;

  ColorScheme applyTo(ColorScheme scheme, {required bool isDark}) {
    if (!highContrast) return scheme;
    return isDark
        ? DsContrastProfiles.highContrastDark(scheme)
        : DsContrastProfiles.highContrastLight(scheme);
  }

  TextTheme applyBold(TextTheme textTheme) {
    if (!boldText) return textTheme;
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
