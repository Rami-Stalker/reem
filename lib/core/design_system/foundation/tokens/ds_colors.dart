import 'package:flutter/material.dart';

/// Raw color palette — use semantic tokens via [DsColorScheme] in theme context.
abstract final class DsColors {
  // Brand — rose / pink luxury palette
  static const Color primary50 = Color(0xFFFFF5F7);
  static const Color primary100 = Color(0xFFFFE5EC);
  static const Color primary200 = Color(0xFFF8BBD0);
  static const Color primary300 = Color(0xFFF4A4BC);
  static const Color primary400 = Color(0xFFEE9AB5);
  static const Color primary500 = Color(0xFFE89AAE);
  static const Color primary600 = Color(0xFFD76C80);
  static const Color primary700 = Color(0xFFC45A6E);
  static const Color primary800 = Color(0xFFA84858);
  static const Color primary900 = Color(0xFF8A3848);

  // Lavender — feminine secondary
  static const Color lavender50 = Color(0xFFFDF5FF);
  static const Color lavender100 = Color(0xFFF3E8FF);
  static const Color lavender200 = Color(0xFFE9D5FF);
  static const Color lavender400 = Color(0xFFC084FC);
  static const Color lavender500 = Color(0xFFA855F7);

  // Coral & gold accents
  static const Color coral400 = Color(0xFFFF8A7A);
  static const Color gold300 = Color(0xFFFFD6A8);
  static const Color gold400 = Color(0xFFF4C4A0);

  // Accent — sage (success / nature touch)
  static const Color accent50 = Color(0xFFE8F5EE);
  static const Color accent100 = Color(0xFFC8E6D4);
  static const Color accent400 = Color(0xFF4CA572);
  static const Color accent500 = Color(0xFF3D8F5F);
  static const Color accent600 = Color(0xFF2E7A4D);

  // Neutrals
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE8E8E8);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF777777);
  static const Color neutral600 = Color(0xFF5C5C5C);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF2D2D2D);
  static const Color neutral900 = Color(0xFF1A1A1A);
  static const Color neutral950 = Color(0xFF0D0D0D);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Surfaces (light)
  static const Color backgroundLight = Color(0xFFFFF8FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFFFF0F5);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Surfaces (dark) — plum-tinted premium
  static const Color backgroundDark = Color(0xFF0F0A12);
  static const Color surfaceDark = Color(0xFF1A141F);
  static const Color surfaceVariantDark = Color(0xFF261F2A);
  static const Color cardDark = Color(0xFF211A24);

  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  /// Material [ColorScheme] seed for light mode.
  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: primary500,
        primary: primary500,
        secondary: accent400,
        surface: surfaceLight,
        error: error,
        brightness: Brightness.light,
      );

  /// Material [ColorScheme] seed for dark mode.
  static ColorScheme get darkScheme => ColorScheme.fromSeed(
        seedColor: primary400,
        primary: primary400,
        secondary: accent400,
        surface: surfaceDark,
        error: error,
        brightness: Brightness.dark,
      );
}

/// Semantic colors resolved per theme brightness.
@immutable
class DsColorScheme {
  const DsColorScheme({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.card,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabled,
    required this.shadow,
    required this.glass,
    required this.glassBorder,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color card;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;
  final Color shadow;
  final Color glass;
  final Color glassBorder;

  static const DsColorScheme light = DsColorScheme(
    primary: DsColors.primary500,
    onPrimary: DsColors.white,
    secondary: DsColors.accent400,
    onSecondary: DsColors.white,
    background: DsColors.backgroundLight,
    onBackground: DsColors.neutral800,
    surface: DsColors.surfaceLight,
    onSurface: DsColors.neutral800,
    surfaceVariant: DsColors.surfaceVariantLight,
    onSurfaceVariant: DsColors.neutral500,
    card: DsColors.cardLight,
    border: DsColors.primary200,
    divider: DsColors.neutral200,
    success: DsColors.success,
    warning: DsColors.warning,
    error: DsColors.error,
    info: DsColors.info,
    disabled: DsColors.neutral300,
    shadow: Color(0x29E89AAE),
    glass: Color(0x38FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
  );

  static const DsColorScheme dark = DsColorScheme(
    primary: Color(0xFFFF8AB5),
    onPrimary: Color(0xFF1A0A12),
    secondary: DsColors.lavender400,
    onSecondary: DsColors.neutral950,
    background: DsColors.backgroundDark,
    onBackground: Color(0xFFF5EFF3),
    surface: DsColors.surfaceDark,
    onSurface: Color(0xFFF8F2F5),
    surfaceVariant: DsColors.surfaceVariantDark,
    onSurfaceVariant: Color(0xFFB8A8B5),
    card: DsColors.cardDark,
    border: Color(0xFF3D3245),
    divider: Color(0xFF332A38),
    success: DsColors.success,
    warning: DsColors.warning,
    error: Color(0xFFFF6B7A),
    info: Color(0xFF93C5FD),
    disabled: Color(0xFF5C4F58),
    shadow: Color(0x66000000),
    glass: Color(0x24FFFFFF),
    glassBorder: Color(0x1FFFFFFF),
  );

  DsColorScheme lerp(DsColorScheme other, double t) => DsColorScheme(
        primary: Color.lerp(primary, other.primary, t)!,
        onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
        secondary: Color.lerp(secondary, other.secondary, t)!,
        onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
        background: Color.lerp(background, other.background, t)!,
        onBackground: Color.lerp(onBackground, other.onBackground, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        onSurface: Color.lerp(onSurface, other.onSurface, t)!,
        surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
        onSurfaceVariant:
            Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
        card: Color.lerp(card, other.card, t)!,
        border: Color.lerp(border, other.border, t)!,
        divider: Color.lerp(divider, other.divider, t)!,
        success: Color.lerp(success, other.success, t)!,
        warning: Color.lerp(warning, other.warning, t)!,
        error: Color.lerp(error, other.error, t)!,
        info: Color.lerp(info, other.info, t)!,
        disabled: Color.lerp(disabled, other.disabled, t)!,
        shadow: Color.lerp(shadow, other.shadow, t)!,
        glass: Color.lerp(glass, other.glass, t)!,
        glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      );
}
