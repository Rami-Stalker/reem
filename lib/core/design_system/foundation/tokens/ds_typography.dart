import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Typography scale — pairs with `fontFamily: 'Cairo'` in theme.
abstract final class DsTypography {
  static const String fontFamily = 'Cairo';
  static const String fontFamilyDisplay = 'Cairo';

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

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0;
  static const double letterSpacingWide = 0.5;

  static TextTheme textTheme({required Color onSurface, Color? onSurfaceVariant}) {
    final variant = onSurfaceVariant ?? DsColors.neutral500;
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: displayLarge,
        fontWeight: bold,
        letterSpacing: letterSpacingTight,
        color: onSurface,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: displayMedium,
        fontWeight: bold,
        color: onSurface,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: displaySmall,
        fontWeight: semiBold,
        color: onSurface,
        height: 1.22,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: headlineLarge,
        fontWeight: bold,
        color: onSurface,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: headlineMedium,
        fontWeight: semiBold,
        color: onSurface,
        height: 1.28,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
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
        fontWeight: medium,
        color: onSurface,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: titleSmall,
        fontWeight: medium,
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
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodySmall,
        fontWeight: regular,
        color: variant,
        height: 1.33,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelLarge,
        fontWeight: medium,
        color: onSurface,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelMedium,
        fontWeight: medium,
        color: variant,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: labelSmall,
        fontWeight: medium,
        color: variant,
        height: 1.45,
      ),
    );
  }
}
