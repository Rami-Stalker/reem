import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Typography scale for Reem.
///
/// Two family tokens are exposed: [fontFamily] (Cairo) for body/UI and Arabic/
/// RTL, and [fontFamilyDisplay] (Playfair Display) — an elegant high-contrast
/// serif applied to every display and headline style. Playfair is Latin-only,
/// so [displayFallback] routes Arabic glyphs back to Cairo. Both families are
/// bundled as variable fonts in `pubspec.yaml` (assets/fonts/).
abstract final class DsTypography {
  static const String fontFamily = 'Cairo';
  static const String fontFamilyDisplay = 'PlayfairDisplay';

  /// Display fallback — Playfair Display is Latin-only, so Arabic (and any
  /// glyph it lacks) falls back to [fontFamily]. Applied to every display /
  /// headline style.
  static const List<String> displayFallback = [fontFamily];

  static const double scaleFactor = 1.0;

  // Display
  static const double displayLarge = 57;
  static const double displayMedium = 45;
  static const double displaySmall = 36;

  // Headline
  static const double headlineLarge = 32;
  static const double headlineMedium = 28;
  static const double headlineSmall = 24;

  // Title
  static const double titleLarge = 22;
  static const double titleMedium = 18;
  static const double titleSmall = 16;

  // Body
  static const double bodyLarge = 16;
  static const double bodyMedium = 14;
  static const double bodySmall = 12;

  // Label
  static const double labelLarge = 14;
  static const double labelMedium = 12;
  static const double labelSmall = 11;

  // Weights
  static const FontWeight thin = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // Letter spacing stays neutral so text remains crisp in compact mobile UI.
  static const double letterSpacingTighter = 0;
  static const double letterSpacingTight = 0;
  static const double letterSpacingSnug = 0;
  static const double letterSpacingNormal = 0;
  static const double letterSpacingWide = 0;
  static const double letterSpacingWider = 0;
  static const double letterSpacingWidest = 0;

  static TextTheme textTheme({
    required Color onSurface,
    Color? onSurfaceVariant,
  }) {
    final variant = onSurfaceVariant ?? DsColors.neutral500;
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: displayLarge,
        fontWeight: bold,
        letterSpacing: letterSpacingTight,
        color: onSurface,
        height: 1.10,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: displayMedium,
        fontWeight: bold,
        letterSpacing: letterSpacingTight,
        color: onSurface,
        height: 1.14,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: displaySmall,
        fontWeight: bold,
        letterSpacing: letterSpacingTight,
        color: onSurface,
        height: 1.20,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: headlineLarge,
        fontWeight: bold,
        letterSpacing: letterSpacingSnug,
        color: onSurface,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: headlineMedium,
        fontWeight: semiBold,
        letterSpacing: letterSpacingSnug,
        color: onSurface,
        height: 1.28,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontFamilyFallback: displayFallback,
        fontSize: headlineSmall,
        fontWeight: semiBold,
        color: onSurface,
        height: 1.33,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleLarge,
        fontWeight: semiBold,
        color: onSurface,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleMedium,
        fontWeight: semiBold,
        letterSpacing: letterSpacingWide,
        color: onSurface,
        height: 1.45,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleSmall,
        fontWeight: medium,
        letterSpacing: letterSpacingWide,
        color: onSurface,
        height: 1.43,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyLarge,
        fontWeight: regular,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyMedium,
        fontWeight: regular,
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodySmall,
        fontWeight: regular,
        color: variant,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelLarge,
        fontWeight: semiBold,
        letterSpacing: letterSpacingWide,
        color: onSurface,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelMedium,
        fontWeight: medium,
        letterSpacing: letterSpacingWide,
        color: variant,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelSmall,
        fontWeight: medium,
        letterSpacing: letterSpacingWider,
        color: variant,
        height: 1.45,
      ),
    );
  }

  /// Eyebrow / overline style — uppercase, airy tracking. Premium section labels.
  static TextStyle overline(Color color) => TextStyle(
        fontFamily: fontFamily,
        fontSize: labelSmall,
        fontWeight: semiBold,
        letterSpacing: letterSpacingWidest,
        color: color,
        height: 1.4,
      );

  /// Price emphasis style — tabular-leaning, confident.
  static TextStyle price(Color color, {double size = titleMedium}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: bold,
        letterSpacing: letterSpacingSnug,
        color: color,
        height: 1.2,
      );

  /// Strikethrough compare-at price.
  static TextStyle priceStrike(Color color, {double size = bodySmall}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: regular,
        color: color,
        height: 1.2,
        decoration: TextDecoration.lineThrough,
        decorationColor: color,
      );
}
