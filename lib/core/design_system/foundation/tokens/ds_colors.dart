import 'package:flutter/material.dart';

/// Raw color palette for Ohara — a premium, feminine fashion & beauty brand.
///
/// The mood: soft rose for interaction, warm cream for grounds, mauve for
/// variety and champagne gold used sparingly as a luxury touch. These are
/// *raw* swatches; UI code should prefer the semantic [DsColorScheme] via
/// `context.dsColors` so light/dark and accessibility variants resolve
/// automatically.
abstract final class DsColors {
  // ---------------------------------------------------------------------------
  // Primary — Rose. Buttons, links, selection and every interactive state.
  // ---------------------------------------------------------------------------
  static const Color primary50 = Color(0xFFFFF5F8);
  static const Color primary100 = Color(0xFFFCE7EF);
  static const Color primary200 = Color(0xFFF8C9DA);
  static const Color primary300 = Color(0xFFF3A6C2);
  static const Color primary400 = Color(0xFFED7FA7);
  static const Color primary500 = Color(0xFFE85A8A); // brand identity rose
  static const Color primary600 = Color(0xFFD43E73); // interactive fills
  static const Color primary700 = Color(0xFFB82D60);
  static const Color primary800 = Color(0xFF96244F);
  static const Color primary900 = Color(0xFF761D40);

  // ---------------------------------------------------------------------------
  // Secondary — Mauve. Variety, depth and the seller / admin workspaces.
  // ---------------------------------------------------------------------------
  static const Color secondary50 = Color(0xFFF8F3FA);
  static const Color secondary100 = Color(0xFFEDE3F1);
  static const Color secondary200 = Color(0xFFD8C1D9);
  static const Color secondary300 = Color(0xFFC5A4C9);
  static const Color secondary400 = Color(0xFFAD8BB5);
  static const Color secondary500 = Color(0xFF9B7BA5);
  static const Color secondary600 = Color(0xFF84628E);
  static const Color secondary700 = Color(0xFF6C4F76);
  static const Color secondary800 = Color(0xFF543D5D);
  static const Color secondary900 = Color(0xFF3D2D45);

  // ---------------------------------------------------------------------------
  // Supporting colors.
  // ---------------------------------------------------------------------------
  static const Color champagneGold = Color(0xFFC9A878);
  static const Color softGold = Color(0xFFE5D0A8);
  static const Color rosewood = Color(0xFFB76E79);
  static const Color warmBeige = Color(0xFFEADBC8);
  static const Color peachCream = Color(0xFFF1D6B8);
  static const Color sageGreen = Color(0xFFA8B9A0);

  // ---------------------------------------------------------------------------
  // Gold scale — built around [softGold] and [champagneGold]. Use sparingly:
  // ratings, premium badges, hairline flourishes.
  // ---------------------------------------------------------------------------
  static const Color gold50 = Color(0xFFFBF7F0);
  static const Color gold100 = Color(0xFFF5EDDD);
  static const Color gold200 = softGold;
  static const Color gold300 = Color(0xFFD7BC90);
  static const Color gold400 = champagneGold;
  static const Color gold500 = Color(0xFFB08D5B);
  static const Color gold600 = Color(0xFF8C6E44);
  static const Color gold700 = Color(0xFF6A5232);

  // ---------------------------------------------------------------------------
  // Neutrals — warm, rose-tinted greys anchored on the text and line colors.
  // ---------------------------------------------------------------------------
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFBF8F9);
  static const Color neutral100 = Color(0xFFF0E8EC); // divider
  static const Color neutral200 = Color(0xFFE9DFE4); // border
  static const Color neutral300 = Color(0xFFD6C9D0);
  static const Color neutral400 = Color(0xFFA99AA4);
  static const Color neutral500 = Color(0xFF8A7C87);
  static const Color neutral600 = Color(0xFF766873); // text secondary
  static const Color neutral700 = Color(0xFF544853);
  static const Color neutral800 = Color(0xFF2F2630); // text primary
  static const Color neutral900 = Color(0xFF221B23);
  static const Color neutral950 = Color(0xFF151016);

  // ---------------------------------------------------------------------------
  // Grounds, text and lines (light).
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF8F5F2); // cream
  static const Color backgroundPink = primary50;
  static const Color surfaceVariantLight = Color(0xFFF4E7EC);
  static const Color textPrimary = neutral800;
  static const Color textSecondary = neutral600;
  static const Color border = neutral200;
  static const Color divider = neutral100;

  // ---------------------------------------------------------------------------
  // Status.
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF388E65);
  static const Color error = Color(0xFFD94355);
  static const Color warning = Color(0xFFD99A35);
  static const Color info = Color(0xFF5485C5);

  // Tints of [success] for fills and charts.
  static const Color success50 = Color(0xFFEAF4EE);
  static const Color success100 = Color(0xFFCFE5D8);
  static const Color success400 = Color(0xFF55A57E);
  static const Color success600 = Color(0xFF2C7352);

  // Deep "ink" shades of each status hue. The status colors above are for
  // icons, dots, bars and fills; these are for status *text*, which needs
  // 4.5:1 on white, cream and on the status container.
  static const Color successDeep = success600;
  static const Color warningDeep = Color(0xFF8A5A12);
  static const Color errorDeep = Color(0xFFB8303F);
  static const Color infoDeep = Color(0xFF3D6BA8);

  /// [rosewood] deepened for sale badges and sale text (5.1:1 with white).
  static const Color rosewoodDeep = Color(0xFF9E5A65);

  // ---------------------------------------------------------------------------
  // Surfaces (dark) — deep plum drawn from [secondary900], never flat black.
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF171219);
  static const Color surfaceDark = Color(0xFF201922);
  static const Color surfaceVariantDark = Color(0xFF2D2430);
  static const Color cardDark = Color(0xFF261E29);
  static const Color surfaceDimDark = Color(0xFF120E14);

  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // ---------------------------------------------------------------------------
  // Over media.
  //
  // Content laid on a photograph, a video or a brand gradient does not sit on
  // the page ground, so it must not follow the theme: white stays white in
  // both modes because the thing behind it is the image. These names exist so
  // that intent is legible — a `Colors.white` in feature code is a bug until
  // proven otherwise, while [onMedia] says "this is over a picture".
  // ---------------------------------------------------------------------------

  /// Primary foreground over imagery — titles, icons, controls.
  static const Color onMedia = white;

  /// Secondary foreground over imagery — timestamps, captions, inactive rails.
  static const Color onMediaMuted = Color(0xB3FFFFFF);

  /// Hairlines and inactive tracks over imagery.
  static const Color onMediaFaint = Color(0x3DFFFFFF);

  /// A tinted plate under content that has to stay legible over any photo.
  static const Color mediaPlate = Color(0x1FFFFFFF);

  /// The darkening wash between a photograph and the copy over it.
  static const Color mediaScrim = Color(0x66000000);

  /// The ground of a full-bleed media surface — a story, a lightbox, a call.
  /// Near-black rather than pure black so it reads as depth, not a hole.
  static const Color mediaGround = Color(0xFF0E0A10);

  /// Ink on the champagne wash. Like [onMedia] this is deliberately
  /// mode-independent: the champagne gradient is a fixed brand blend, so the
  /// text on it must not follow the theme or it inverts into illegibility.
  static const Color onChampagne = gold700;

  /// Ink on the gold gradient — the smaller type on "new in" ribbons.
  static const Color onGold = textPrimary;

  /// Material [ColorScheme] for light mode, derived from [DsColorScheme.light]
  /// so Material widgets and Ohara components read the same values.
  static ColorScheme get lightScheme =>
      _materialScheme(DsColorScheme.light, Brightness.light);

  /// Material [ColorScheme] for dark mode.
  static ColorScheme get darkScheme =>
      _materialScheme(DsColorScheme.dark, Brightness.dark);

  static ColorScheme _materialScheme(DsColorScheme c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.accent,
      onTertiary: c.onAccent,
      tertiaryContainer: c.accentContainer,
      onTertiaryContainer: c.onAccentContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.errorInk,
      surface: c.surface,
      onSurface: c.onSurface,
      surfaceDim: c.surfaceDim,
      surfaceBright: c.surfaceBright,
      surfaceContainerLowest: isDark ? backgroundDark : white,
      surfaceContainerLow: isDark ? surfaceDark : backgroundPink,
      surfaceContainer: isDark ? cardDark : backgroundSecondary,
      surfaceContainerHigh: isDark ? surfaceVariantDark : primary100,
      surfaceContainerHighest: c.surfaceVariant,
      onSurfaceVariant: c.onSurfaceVariant,
      outline: c.outline,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: black,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
      inversePrimary: isDark ? primary600 : primary300,
      surfaceTint: c.primary,
    );
  }
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
    required this.successInk,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.warningInk,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.errorInk,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.infoInk,
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
    required this.onDiscount,
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
  /// Status *text* — a deeper shade of [success] that holds 4.5:1 on the
  /// page, on cards and on [successContainer]. Keep [success] for icons,
  /// dots, bars and fills; use the ink for words.
  final Color successInk;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color warningInk;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color errorInk;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color infoInk;

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
  /// Text on a [discount] fill — a sale badge.
  final Color onDiscount;
  final Color online;

  static const DsColorScheme light = DsColorScheme(
    primary: DsColors.primary600,
    onPrimary: DsColors.white,
    primaryContainer: DsColors.primary100,
    onPrimaryContainer: DsColors.primary800,
    secondary: DsColors.secondary600,
    onSecondary: DsColors.white,
    secondaryContainer: DsColors.secondary100,
    onSecondaryContainer: DsColors.secondary800,
    accent: DsColors.champagneGold,
    onAccent: DsColors.textPrimary,
    accentContainer: DsColors.gold100,
    onAccentContainer: DsColors.gold700,
    background: DsColors.backgroundSecondary,
    onBackground: DsColors.textPrimary,
    surface: DsColors.background,
    onSurface: DsColors.textPrimary,
    surfaceVariant: DsColors.surfaceVariantLight,
    onSurfaceVariant: DsColors.textSecondary,
    surfaceBright: DsColors.white,
    surfaceDim: DsColors.warmBeige,
    surfaceElevated: DsColors.white,
    card: DsColors.background,
    inverseSurface: DsColors.textPrimary,
    onInverseSurface: DsColors.primary50,
    border: DsColors.border,
    outline: DsColors.neutral300,
    divider: DsColors.divider,
    success: DsColors.success,
    onSuccess: DsColors.white,
    successContainer: DsColors.success50,
    successInk: DsColors.successDeep,
    warning: DsColors.warning,
    onWarning: DsColors.textPrimary,
    warningContainer: Color(0xFFFBF1E0),
    warningInk: DsColors.warningDeep,
    error: DsColors.error,
    onError: DsColors.white,
    errorContainer: Color(0xFFFCE9EB),
    errorInk: DsColors.errorDeep,
    info: DsColors.info,
    onInfo: DsColors.white,
    infoContainer: Color(0xFFEAF1F9),
    infoInk: DsColors.infoDeep,
    disabled: DsColors.neutral300,
    onDisabled: DsColors.neutral400,
    shadow: Color(0x1F96244F),
    overlay: Color(0x592F2630),
    glass: Color(0x3DFFFFFF),
    glassBorder: Color(0x59FFFFFF),
    shimmerBase: DsColors.surfaceVariantLight,
    shimmerHighlight: DsColors.backgroundPink,
    favorite: DsColors.primary500,
    rating: DsColors.gold500,
    price: DsColors.primary700,
    discount: DsColors.rosewoodDeep,
    onDiscount: DsColors.white,
    online: DsColors.success,
  );

  static const DsColorScheme dark = DsColorScheme(
    primary: DsColors.primary300,
    onPrimary: DsColors.primary900,
    primaryContainer: Color(0xFF5A1F38),
    onPrimaryContainer: DsColors.primary100,
    secondary: DsColors.secondary300,
    onSecondary: DsColors.secondary900,
    secondaryContainer: DsColors.secondary800,
    onSecondaryContainer: DsColors.secondary100,
    accent: DsColors.softGold,
    onAccent: DsColors.textPrimary,
    accentContainer: Color(0xFF4A3C26),
    onAccentContainer: DsColors.gold100,
    background: DsColors.backgroundDark,
    onBackground: Color(0xFFF4ECF1),
    surface: DsColors.surfaceDark,
    onSurface: Color(0xFFF6EFF3),
    surfaceVariant: DsColors.surfaceVariantDark,
    onSurfaceVariant: Color(0xFFBBAAB6),
    surfaceBright: Color(0xFF2B222E),
    surfaceDim: DsColors.surfaceDimDark,
    surfaceElevated: Color(0xFF2D2430),
    card: DsColors.cardDark,
    inverseSurface: Color(0xFFF4ECF1),
    onInverseSurface: DsColors.textPrimary,
    border: Color(0xFF3E3342),
    outline: Color(0xFF4C404F),
    divider: Color(0xFF2F2632),
    success: Color(0xFF6BBE93),
    onSuccess: Color(0xFF0B2A1B),
    successContainer: Color(0xFF1F4031),
    successInk: Color(0xFF8FD1AE),
    warning: Color(0xFFE8B565),
    onWarning: Color(0xFF35260B),
    warningContainer: Color(0xFF45351A),
    warningInk: Color(0xFFF0C77E),
    error: Color(0xFFF07A86),
    onError: Color(0xFF3F0910),
    errorContainer: Color(0xFF55222A),
    errorInk: Color(0xFFF6A0A8),
    info: Color(0xFF93B2E0),
    onInfo: Color(0xFF0D2442),
    infoContainer: Color(0xFF253A57),
    infoInk: Color(0xFFA9C4EC),
    disabled: Color(0xFF594D5C),
    onDisabled: Color(0xFF8B7E8D),
    shadow: Color(0x80000000),
    overlay: Color(0x8C0B080D),
    glass: Color(0x24FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    shimmerBase: Color(0xFF2B222E),
    shimmerHighlight: Color(0xFF3A2F3E),
    favorite: DsColors.primary400,
    rating: DsColors.softGold,
    price: DsColors.primary200,
    discount: Color(0xFFD9A0A8),
    onDiscount: Color(0xFF3A1A20),
    online: Color(0xFF6BBE93),
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
    Color? successInk,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? warningInk,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? errorInk,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? infoInk,
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
    Color? onDiscount,
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
      successInk: successInk ?? this.successInk,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      warningInk: warningInk ?? this.warningInk,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      errorInk: errorInk ?? this.errorInk,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      infoInk: infoInk ?? this.infoInk,
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
      onDiscount: onDiscount ?? this.onDiscount,
      online: online ?? this.online,
    );
  }

  DsColorScheme lerp(DsColorScheme other, double t) => DsColorScheme(
    primary: Color.lerp(primary, other.primary, t)!,
    onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
    onPrimaryContainer: Color.lerp(
      onPrimaryContainer,
      other.onPrimaryContainer,
      t,
    )!,
    secondary: Color.lerp(secondary, other.secondary, t)!,
    onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
    secondaryContainer: Color.lerp(
      secondaryContainer,
      other.secondaryContainer,
      t,
    )!,
    onSecondaryContainer: Color.lerp(
      onSecondaryContainer,
      other.onSecondaryContainer,
      t,
    )!,
    accent: Color.lerp(accent, other.accent, t)!,
    onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
    onAccentContainer: Color.lerp(
      onAccentContainer,
      other.onAccentContainer,
      t,
    )!,
    background: Color.lerp(background, other.background, t)!,
    onBackground: Color.lerp(onBackground, other.onBackground, t)!,
    surface: Color.lerp(surface, other.surface, t)!,
    onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
    onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
    surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
    surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
    surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
    card: Color.lerp(card, other.card, t)!,
    inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
    onInverseSurface: Color.lerp(onInverseSurface, other.onInverseSurface, t)!,
    border: Color.lerp(border, other.border, t)!,
    outline: Color.lerp(outline, other.outline, t)!,
    divider: Color.lerp(divider, other.divider, t)!,
    success: Color.lerp(success, other.success, t)!,
    onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    successContainer: Color.lerp(successContainer, other.successContainer, t)!,
    successInk: Color.lerp(successInk, other.successInk, t)!,
    warning: Color.lerp(warning, other.warning, t)!,
    onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
    warningInk: Color.lerp(warningInk, other.warningInk, t)!,
    error: Color.lerp(error, other.error, t)!,
    onError: Color.lerp(onError, other.onError, t)!,
    errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
    errorInk: Color.lerp(errorInk, other.errorInk, t)!,
    info: Color.lerp(info, other.info, t)!,
    onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    infoInk: Color.lerp(infoInk, other.infoInk, t)!,
    disabled: Color.lerp(disabled, other.disabled, t)!,
    onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
    shadow: Color.lerp(shadow, other.shadow, t)!,
    overlay: Color.lerp(overlay, other.overlay, t)!,
    glass: Color.lerp(glass, other.glass, t)!,
    glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
    shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    favorite: Color.lerp(favorite, other.favorite, t)!,
    rating: Color.lerp(rating, other.rating, t)!,
    price: Color.lerp(price, other.price, t)!,
    discount: Color.lerp(discount, other.discount, t)!,
    onDiscount: Color.lerp(onDiscount, other.onDiscount, t)!,
    online: Color.lerp(online, other.online, t)!,
  );
}
