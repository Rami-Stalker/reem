import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// Semantic text roles for Reem.
///
/// The design system carried a *size* scale (`DsTypography.titleSmall` and
/// friends) but no *role* scale, so every screen assembled its own
/// `TextStyle(fontSize: ..., fontWeight: ..., color: ...)`. Five hundred of
/// those had accumulated, each one dropping the line height and letter
/// spacing baked into the text theme, and each one picking its own weight for
/// the same job. That is the mechanical reason two screens that use the same
/// palette still fail to look like the same app.
///
/// [DsTextStyles] closes it. Every style here is **non-nullable**, already
/// coloured against the active scheme, and named for what the text *is* rather
/// than how big it is. UI code asks for `context.dsText.cardTitle`, never for a
/// font size.
///
/// Roles fall into five families:
///
/// * **Page chrome** — [hero], [pageTitle], [screenTitle], [sectionTitle],
///   [sectionSubtitle], [overline].
/// * **Surfaces** — [cardTitle], [cardSubtitle], [tileTitle], [tileValue].
/// * **Prose** — [bodyLarge], [body], [bodyStrong], [bodySmall], [caption],
///   [captionStrong].
/// * **Controls** — [button], [buttonSmall], [label], [labelStrong], [badge],
///   [link], [tab].
/// * **Commerce & data** — [priceHero], [price], [priceSmall], [priceStruck],
///   [metric], [metricSmall], [metricLabel], [numeric].
@immutable
class DsTextStyles {
  const DsTextStyles({
    required TextTheme text,
    required DsColorScheme colors,
  })  : _text = text,
        _colors = colors;

  /// Resolves the roles against the active theme, so text scaling,
  /// high-contrast profiles and dark mode all flow through untouched.
  factory DsTextStyles.of(BuildContext context) => DsTextStyles(
        text: Theme.of(context).textTheme,
        colors: context.dsColors,
      );

  final TextTheme _text;
  final DsColorScheme _colors;

  Color get _ink => _colors.onSurface;
  Color get _muted => _colors.onSurfaceVariant;

  // ---------------------------------------------------------------------------
  // Page chrome
  // ---------------------------------------------------------------------------

  /// Marketing-scale statement, used once per surface at most.
  TextStyle get hero => _text.displaySmall!.copyWith(color: _ink);

  /// The name of a full screen, in the display serif.
  TextStyle get pageTitle => _text.headlineMedium!.copyWith(color: _ink);

  /// A screen title that shares its row with other chrome (app bars, sheets).
  TextStyle get screenTitle => _text.headlineSmall!.copyWith(color: _ink);

  /// Heading over a band of content inside a page.
  TextStyle get sectionTitle => _text.titleLarge!.copyWith(color: _ink);

  /// The supporting line under a [sectionTitle].
  TextStyle get sectionSubtitle => _text.bodySmall!.copyWith(color: _muted);

  /// Small, spaced eyebrow above a title. Pair with uppercase copy.
  TextStyle get overline => _text.labelSmall!.copyWith(
        color: _muted,
        fontWeight: DsTypography.semiBold,
        letterSpacing: 0.8,
      );

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Heading inside a card, sheet or dialog.
  TextStyle get cardTitle => _text.titleMedium!.copyWith(color: _ink);

  /// Secondary line inside a card — vendor name, timestamp, short summary.
  TextStyle get cardSubtitle => _text.bodySmall!.copyWith(color: _muted);

  /// Label of a compact tile in a grid of stats or settings.
  TextStyle get tileTitle => _text.titleSmall!.copyWith(color: _ink);

  /// The figure a tile exists to show.
  TextStyle get tileValue => _text.titleLarge!.copyWith(
        color: _ink,
        fontWeight: DsTypography.bold,
      );

  // ---------------------------------------------------------------------------
  // Prose
  // ---------------------------------------------------------------------------

  TextStyle get bodyLarge => _text.bodyLarge!.copyWith(color: _ink);

  TextStyle get body => _text.bodyMedium!.copyWith(color: _ink);

  TextStyle get bodyStrong =>
      _text.bodyMedium!.copyWith(color: _ink, fontWeight: DsTypography.semiBold);

  TextStyle get bodyMuted => _text.bodyMedium!.copyWith(color: _muted);

  TextStyle get bodySmall => _text.bodySmall!.copyWith(color: _ink);

  /// Quiet metadata — counts, timestamps, helper lines.
  TextStyle get caption => _text.labelSmall!.copyWith(color: _muted);

  TextStyle get captionStrong => _text.labelSmall!.copyWith(
        color: _ink,
        fontWeight: DsTypography.semiBold,
      );

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------

  /// Text inside a full-size button. Colour it with the button's foreground.
  TextStyle get button => _text.labelLarge!.copyWith(
        color: _ink,
        fontWeight: DsTypography.bold,
      );

  TextStyle get buttonSmall => _text.labelMedium!.copyWith(
        color: _ink,
        fontWeight: DsTypography.semiBold,
      );

  /// Form field label, chip text, filter name.
  TextStyle get label => _text.labelMedium!.copyWith(color: _muted);

  /// The raw label sizes, for the places that need the size without the
  /// muted/strong opinion baked into [label] and [labelStrong].
  TextStyle get labelLarge => _text.labelLarge!.copyWith(color: _ink);

  TextStyle get labelMedium => _text.labelMedium!.copyWith(color: _ink);

  TextStyle get labelStrong => _text.labelMedium!.copyWith(
        color: _ink,
        fontWeight: DsTypography.semiBold,
      );

  /// Text inside a pill/badge, sized to survive a 20px-tall container.
  TextStyle get badge => _text.labelSmall!.copyWith(
        color: _ink,
        fontWeight: DsTypography.bold,
        height: 1.1,
      );

  /// The smallest text in the system — a count on an avatar, a rank on a
  /// chart marker. Only for text inside a shape that cannot grow.
  TextStyle get micro => _text.labelSmall!.copyWith(
        color: _ink,
        fontSize: DsTypography.labelMicro,
        fontWeight: DsTypography.bold,
        height: 1.1,
      );

  /// Inline actionable text.
  TextStyle get link => _text.bodyMedium!.copyWith(
        color: _colors.primary,
        fontWeight: DsTypography.semiBold,
      );

  TextStyle get tab => _text.titleSmall!.copyWith(
        color: _ink,
        fontWeight: DsTypography.semiBold,
      );

  // ---------------------------------------------------------------------------
  // Commerce & data
  // ---------------------------------------------------------------------------

  /// The price on a product page.
  ///
  /// Figures in Reem are set in the display serif — it is what makes the
  /// wallet balance, the seller's revenue and this price read as the same
  /// editorial voice. Labels stay in the UI family; only the number is
  /// dressed up.
  TextStyle get priceHero => _text.headlineSmall!.copyWith(
        color: _colors.price,
        fontWeight: DsTypography.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The price on a card in a grid or rail.
  TextStyle get price => _text.titleSmall!.copyWith(
        color: _colors.price,
        fontWeight: DsTypography.bold,
      );

  TextStyle get priceSmall => _text.labelMedium!.copyWith(
        color: _colors.price,
        fontWeight: DsTypography.bold,
      );

  /// The crossed-out original next to a discounted [price].
  TextStyle get priceStruck => _text.labelMedium!.copyWith(
        color: _muted,
        decoration: TextDecoration.lineThrough,
        decorationColor: _muted,
      );

  /// A headline figure on a dashboard — same serif as [priceHero], so a
  /// balance and a total look like they came from one hand.
  TextStyle get metric => _text.headlineSmall!.copyWith(
        color: _ink,
        fontWeight: DsTypography.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get metricSmall => _text.titleMedium!.copyWith(
        color: _ink,
        fontWeight: DsTypography.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The caption under a [metric] saying what it counts.
  TextStyle get metricLabel => _text.labelSmall!.copyWith(color: _muted);

  /// Body text with tabular figures — for columns of numbers that must align.
  TextStyle get numeric => _text.bodyMedium!.copyWith(
        color: _ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DsTextStyles && other._text == _text && other._colors == _colors;

  @override
  int get hashCode => Object.hash(_text, _colors);
}

/// Typography accessors on [BuildContext].
///
/// `context.dsText` is the only sanctioned way to style text in feature code.
/// Reach for [TextTheme] directly only inside the design system itself.
extension DsTypographyContext on BuildContext {
  /// Semantic text roles resolved against the active theme.
  DsTextStyles get dsText => DsTextStyles.of(this);

  /// Raw Material text theme. Prefer [dsText] — this exists for the handful of
  /// places that must hand a `TextTheme` slot to a framework widget.
  TextTheme get textTheme => Theme.of(this).textTheme;
}

/// Small, composable adjustments so callers can tune a role without rebuilding
/// a `TextStyle` from scratch — which is how the drift started.
extension DsTextStyleTweaks on TextStyle {
  /// Recolour, keeping every other property of the role.
  TextStyle tint(Color color) => copyWith(color: color);

  /// Recolour at partial opacity — for de-emphasised copy on a coloured ground.
  TextStyle fade(double opacity) =>
      copyWith(color: (color ?? const Color(0xFF000000)).withValues(alpha: opacity));

  TextStyle get regular => copyWith(fontWeight: DsTypography.regular);
  TextStyle get medium => copyWith(fontWeight: DsTypography.medium);
  TextStyle get semibold => copyWith(fontWeight: DsTypography.semiBold);
  TextStyle get bold => copyWith(fontWeight: DsTypography.bold);

  /// Force the UI family — used when a display-serif role has to render
  /// numerals or Arabic that Playfair does not carry gracefully. The display
  /// fallback is already Cairo, so swapping the primary family is enough.
  TextStyle get uiFamily => copyWith(fontFamily: DsTypography.fontFamily);

  /// Tabular figures, so columns of numbers line up.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Switch a UI-family role to the display serif, keeping the Arabic
  /// fallback that Playfair cannot cover.
  TextStyle get displayFamily => copyWith(
        fontFamily: DsTypography.fontFamilyDisplay,
        fontFamilyFallback: DsTypography.displayFallback,
      );
}
