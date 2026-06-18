import 'package:flutter/material.dart';

/// Raw color palette for Reem — a premium, feminine social-commerce brand.
///
/// The mood: blush-rose elegance, mauve depth, champagne-gold luxury and warm,
/// soft, rose-tinted neutrals. These are *raw* swatches; UI code should never
/// read them directly — consume the semantic [DsColorScheme] via `context.dsColors`
/// so light/dark and accessibility variants resolve automatically.
abstract final class DsColors {
  // ---------------------------------------------------------------------------
  // Brand — Blush Rose (primary). Warm, refined, never neon.
  // ---------------------------------------------------------------------------
  static const Color primary50 = Color(0xFFFFF5F8);
  static const Color primary100 = Color(0xFFFFE7EF);
  static const Color primary200 = Color(0xFFFBCEDD);
  static const Color primary300 = Color(0xFFF7AAC5);
  static const Color primary400 = Color(0xFFF084A8);
  static const Color primary500 = Color(0xFFE85A8A); // brand identity rose
  static const Color primary600 = Color(0xFFD43E73); // interactive fills
  static const Color primary700 = Color(0xFFB62E5E);
  static const Color primary800 = Color(0xFF8C2549);
  static const Color primary900 = Color(0xFF6B1C38);
  static const Color primary950 = Color(0xFF451223);

  // ---------------------------------------------------------------------------
  // Mauve / Plum — secondary. Adds quiet luxury and depth.
  // ---------------------------------------------------------------------------
  static const Color mauve50 = Color(0xFFF8F3F8);
  static const Color mauve100 = Color(0xFFEFE2F0);
  static const Color mauve200 = Color(0xFFDFC6E1);
  static const Color mauve300 = Color(0xFFC8A1CD);
  static const Color mauve400 = Color(0xFFAC7CB4);
  static const Color mauve500 = Color(0xFF8F5C99);
  static const Color mauve600 = Color(0xFF75487E);
  static const Color mauve700 = Color(0xFF5B3864);
  static const Color mauve800 = Color(0xFF43294A);
  static const Color mauve900 = Color(0xFF2D1B32);

  // ---------------------------------------------------------------------------
  // Lavender / Orchid — tertiary feminine support (kept for legacy usage).
  // ---------------------------------------------------------------------------
  static const Color lavender50 = Color(0xFFFAF5FF);
  static const Color lavender100 = Color(0xFFF1E5FF);
  static const Color lavender200 = Color(0xFFE2CCFB);
  static const Color lavender400 = Color(0xFFB98BE8);
  static const Color lavender500 = Color(0xFF9D5FD8);

  // ---------------------------------------------------------------------------
  // Champagne Gold — accent. Premium, occasion-led (gifts, perfume, flowers).
  // ---------------------------------------------------------------------------
  static const Color gold50 = Color(0xFFFCF7EC);
  static const Color gold100 = Color(0xFFF8ECCF);
  static const Color gold200 = Color(0xFFF0D9A0);
  static const Color gold300 = Color(0xFFE6C277); // champagne
  static const Color gold400 = Color(0xFFD9A94F);
  static const Color gold500 = Color(0xFFC28E36);
  static const Color gold600 = Color(0xFF9E7129);
  static const Color gold700 = Color(0xFF79551F);

  // Coral — warm secondary accent (sale energy / warmth).
  static const Color coral300 = Color(0xFFFFB3A3);
  static const Color coral400 = Color(0xFFFF8A7A);
  static const Color coral500 = Color(0xFFF56B59);

  // ---------------------------------------------------------------------------
  // Sage — botanical success / nature touch (flowers, fresh, calm).
  // ---------------------------------------------------------------------------
  static const Color accent50 = Color(0xFFEAF6EF);
  static const Color accent100 = Color(0xFFCBE8D6);
  static const Color accent400 = Color(0xFF4FA877);
  static const Color accent500 = Color(0xFF3E9163);
  static const Color accent600 = Color(0xFF2F7A4F);

  // ---------------------------------------------------------------------------
  // Neutrals — warm, rosé-tinted greys (softness + warmth, never cold).
  // ---------------------------------------------------------------------------
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFBF7F9);
  static const Color neutral100 = Color(0xFFF5EEF1);
  static const Color neutral200 = Color(0xFFECE1E6);
  static const Color neutral300 = Color(0xFFDACED3);
  static const Color neutral400 = Color(0xFFB4A4AB);
  static const Color neutral500 = Color(0xFF897680);
  static const Color neutral600 = Color(0xFF695761);
  static const Color neutral700 = Color(0xFF4C3E45);
  static const Color neutral800 = Color(0xFF34292F);
  static const Color neutral900 = Color(0xFF221A1F);
  static const Color neutral950 = Color(0xFF140F13);

  // ---------------------------------------------------------------------------
  // Semantic base — harmonized with the palette (softer than stock Material).
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF3FA86F);
  static const Color warning = Color(0xFFE0A23C);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF5B8DEF);

  // ---------------------------------------------------------------------------
  // Surfaces (light) — blush whites.
  // ---------------------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFFFF8FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFFCF0F5);
  static const Color cardLight = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Surfaces (dark) — deep aubergine / plum, never flat black.
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF150F1A);
  static const Color surfaceDark = Color(0xFF1F1726);
  static const Color surfaceVariantDark = Color(0xFF2C2233);
  static const Color cardDark = Color(0xFF261D2E);

  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  /// Material [ColorScheme] seed for light mode.
  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: primary500,
        primary: primary600,
        secondary: mauve500,
        tertiary: gold400,
        surface: surfaceLight,
        error: error,
        brightness: Brightness.light,
      );

  /// Material [ColorScheme] seed for dark mode.
  static ColorScheme get darkScheme => ColorScheme.fromSeed(
        seedColor: primary400,
        primary: const Color(0xFFFF87B0),
        secondary: mauve300,
        tertiary: gold300,
        surface: surfaceDark,
        error: const Color(0xFFFF7A85),
        brightness: Brightness.dark,
      );
}

/// Semantic colors resolved per theme brightness.
///
/// This is the single source UI components read (via `context.dsColors`).
/// Tinted elements should prefer the *container* / *on-container* pairs so
/// contrast stays accessible in both light and dark.
@immutable
class DsColorScheme {
  const DsColorScheme({
    // Brand
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    // Surfaces
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.surfaceElevated,
    required this.card,
    required this.inverseSurface,
    required this.onInverseSurface,
    // Lines
    required this.border,
    required this.outline,
    required this.divider,
    // Status
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    // State / utility
    required this.disabled,
    required this.onDisabled,
    required this.shadow,
    required this.overlay,
    required this.glass,
    required this.glassBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
    // Commerce / social semantics
    required this.favorite,
    required this.rating,
    required this.price,
    required this.discount,
    required this.online,
  });

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  // Surfaces
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color surfaceElevated;
  final Color card;
  final Color inverseSurface;
  final Color onInverseSurface;

  // Lines
  final Color border;
  final Color outline;
  final Color divider;

  // Status
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;

  // State / utility
  final Color disabled;
  final Color onDisabled;
  final Color shadow;
  final Color overlay;
  final Color glass;
  final Color glassBorder;
  final Color shimmerBase;
  final Color shimmerHighlight;

  // Commerce / social semantics
  final Color favorite;
  final Color rating;
  final Color price;
  final Color discount;
  final Color online;

  static const DsColorScheme light = DsColorScheme(
    primary: DsColors.primary600,
    onPrimary: DsColors.white,
    primaryContainer: DsColors.primary100,
    onPrimaryContainer: DsColors.primary800,
    secondary: DsColors.mauve500,
    onSecondary: DsColors.white,
    secondaryContainer: DsColors.mauve100,
    onSecondaryContainer: DsColors.mauve700,
    accent: DsColors.gold500,
    onAccent: Color(0xFF3A2A06),
    accentContainer: DsColors.gold100,
    onAccentContainer: DsColors.gold700,
    background: DsColors.backgroundLight,
    onBackground: DsColors.neutral800,
    surface: DsColors.surfaceLight,
    onSurface: DsColors.neutral800,
    surfaceVariant: DsColors.surfaceVariantLight,
    onSurfaceVariant: DsColors.neutral500,
    surfaceBright: DsColors.white,
    surfaceDim: Color(0xFFF6E9EF),
    surfaceElevated: DsColors.white,
    card: DsColors.cardLight,
    inverseSurface: DsColors.neutral900,
    onInverseSurface: Color(0xFFFCEFF4),
    border: DsColors.primary200,
    outline: Color(0xFFE3CAD4),
    divider: DsColors.neutral200,
    success: DsColors.success,
    onSuccess: DsColors.white,
    successContainer: DsColors.accent50,
    warning: DsColors.warning,
    onWarning: DsColors.neutral900,
    warningContainer: DsColors.gold50,
    error: DsColors.error,
    onError: DsColors.white,
    errorContainer: Color(0xFFFDECEC),
    info: DsColors.info,
    onInfo: DsColors.white,
    infoContainer: Color(0xFFEAF1FE),
    disabled: DsColors.neutral300,
    onDisabled: DsColors.neutral400,
    shadow: Color(0x26C9356A),
    overlay: Color(0x593A1024),
    glass: Color(0x3DFFFFFF),
    glassBorder: Color(0x59FFFFFF),
    shimmerBase: Color(0xFFF3E3EA),
    shimmerHighlight: Color(0xFFFFF7FB),
    favorite: Color(0xFFF43F6E),
    rating: DsColors.gold400,
    price: DsColors.primary700,
    discount: DsColors.coral500,
    online: DsColors.success,
  );

  static const DsColorScheme dark = DsColorScheme(
    primary: Color(0xFFFF87B0),
    onPrimary: Color(0xFF3A0E1F),
    primaryContainer: Color(0xFF5A2540),
    onPrimaryContainer: Color(0xFFFFD7E4),
    secondary: DsColors.mauve300,
    onSecondary: Color(0xFF2A1530),
    secondaryContainer: Color(0xFF463050),
    onSecondaryContainer: Color(0xFFEBD6F0),
    accent: DsColors.gold300,
    onAccent: Color(0xFF3A2A06),
    accentContainer: Color(0xFF4A3A14),
    onAccentContainer: Color(0xFFF6E4B8),
    background: DsColors.backgroundDark,
    onBackground: Color(0xFFF4ECF1),
    surface: DsColors.surfaceDark,
    onSurface: Color(0xFFF6EFF3),
    surfaceVariant: DsColors.surfaceVariantDark,
    onSurfaceVariant: Color(0xFFB9A7B4),
    surfaceBright: Color(0xFF2A2032),
    surfaceDim: Color(0xFF120C17),
    surfaceElevated: Color(0xFF2C2235),
    card: DsColors.cardDark,
    inverseSurface: Color(0xFFF4ECF1),
    onInverseSurface: Color(0xFF2A1F30),
    border: Color(0xFF3D3047),
    outline: Color(0xFF4A3B54),
    divider: Color(0xFF2E2336),
    success: Color(0xFF52C28A),
    onSuccess: Color(0xFF06281A),
    successContainer: Color(0xFF1E4434),
    warning: Color(0xFFEDBA63),
    onWarning: Color(0xFF36280A),
    warningContainer: Color(0xFF45350F),
    error: Color(0xFFFF7A85),
    onError: Color(0xFF40060B),
    errorContainer: Color(0xFF53202A),
    info: Color(0xFF93B7FB),
    onInfo: Color(0xFF09244A),
    infoContainer: Color(0xFF243B5E),
    disabled: Color(0xFF584C5E),
    onDisabled: Color(0xFF8A7C90),
    shadow: Color(0x80000000),
    overlay: Color(0x8C0A060E),
    glass: Color(0x24FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    shimmerBase: Color(0xFF2A2032),
    shimmerHighlight: Color(0xFF3A2E44),
    favorite: Color(0xFFFF6F94),
    rating: DsColors.gold300,
    price: Color(0xFFFFB3CC),
    discount: DsColors.coral400,
    online: Color(0xFF52C28A),
  );

  DsColorScheme copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? surfaceBright,
    Color? surfaceDim,
    Color? surfaceElevated,
    Color? card,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? border,
    Color? outline,
    Color? divider,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? disabled,
    Color? onDisabled,
    Color? shadow,
    Color? overlay,
    Color? glass,
    Color? glassBorder,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? favorite,
    Color? rating,
    Color? price,
    Color? discount,
    Color? online,
  }) {
    return DsColorScheme(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      border: border ?? this.border,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      disabled: disabled ?? this.disabled,
      onDisabled: onDisabled ?? this.onDisabled,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      favorite: favorite ?? this.favorite,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      online: online ?? this.online,
    );
  }

  DsColorScheme lerp(DsColorScheme other, double t) => DsColorScheme(
        primary: Color.lerp(primary, other.primary, t)!,
        onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
        primaryContainer:
            Color.lerp(primaryContainer, other.primaryContainer, t)!,
        onPrimaryContainer:
            Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
        secondary: Color.lerp(secondary, other.secondary, t)!,
        onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
        secondaryContainer:
            Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
        onSecondaryContainer:
            Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
        accent: Color.lerp(accent, other.accent, t)!,
        onAccent: Color.lerp(onAccent, other.onAccent, t)!,
        accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
        onAccentContainer:
            Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
        background: Color.lerp(background, other.background, t)!,
        onBackground: Color.lerp(onBackground, other.onBackground, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        onSurface: Color.lerp(onSurface, other.onSurface, t)!,
        surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
        onSurfaceVariant:
            Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
        surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
        surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
        surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
        card: Color.lerp(card, other.card, t)!,
        inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
        onInverseSurface:
            Color.lerp(onInverseSurface, other.onInverseSurface, t)!,
        border: Color.lerp(border, other.border, t)!,
        outline: Color.lerp(outline, other.outline, t)!,
        divider: Color.lerp(divider, other.divider, t)!,
        success: Color.lerp(success, other.success, t)!,
        onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
        successContainer:
            Color.lerp(successContainer, other.successContainer, t)!,
        warning: Color.lerp(warning, other.warning, t)!,
        onWarning: Color.lerp(onWarning, other.onWarning, t)!,
        warningContainer:
            Color.lerp(warningContainer, other.warningContainer, t)!,
        error: Color.lerp(error, other.error, t)!,
        onError: Color.lerp(onError, other.onError, t)!,
        errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
        info: Color.lerp(info, other.info, t)!,
        onInfo: Color.lerp(onInfo, other.onInfo, t)!,
        infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
        disabled: Color.lerp(disabled, other.disabled, t)!,
        onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
        shadow: Color.lerp(shadow, other.shadow, t)!,
        overlay: Color.lerp(overlay, other.overlay, t)!,
        glass: Color.lerp(glass, other.glass, t)!,
        glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
        shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
        shimmerHighlight:
            Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
        favorite: Color.lerp(favorite, other.favorite, t)!,
        rating: Color.lerp(rating, other.rating, t)!,
        price: Color.lerp(price, other.price, t)!,
        discount: Color.lerp(discount, other.discount, t)!,
        online: Color.lerp(online, other.online, t)!,
      );
}
