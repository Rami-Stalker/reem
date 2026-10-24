import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// The buyer's visual identity: **the boutique**.
///
/// Ohara has three registers — the buyer's boutique, the seller's atelier
/// (`context.atelier`) and the operator's console (`context.console`). The
/// other two were already resolved from the live theme; this one was still a
/// wall of `const Color`s on `CustomerExperience`, so the buyer surfaces were
/// the only ones that could not follow dark mode. A rose eyebrow and near-black
/// ink stayed exactly where they were while the ground behind them turned
/// aubergine.
///
/// Same shape as its two siblings, so a widget that moves between roles reads
/// the same field names in each.
class CustomerBoutiquePalette {
  const CustomerBoutiquePalette({
    required this.ink,
    required this.muted,
    required this.background,
    required this.surface,
    required this.raised,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.gold,
    required this.goldSoft,
    required this.positive,
    required this.caution,
    required this.critical,
    required this.signatureGradient,
    required this.groundGradient,
    required this.shadow,
  });

  /// Primary text.
  final Color ink;

  /// Secondary text, captions, metadata.
  final Color muted;

  /// The page ground.
  final Color background;

  /// Panels sitting on the ground.
  final Color surface;

  /// Panels that lift off another panel.
  final Color raised;

  /// Hairlines and dividers.
  final Color line;

  /// The boutique accent — blush rose.
  final Color primary;
  final Color onPrimary;

  /// Rose at container strength, for tinted fills behind icons and chips.
  final Color primarySoft;

  /// Champagne, for occasions and rewards.
  final Color gold;
  final Color goldSoft;

  final Color positive;
  final Color caution;
  final Color critical;

  /// Rose into champagne — the brand signature, used for hero fills and the
  /// shader behind display titles. Reads on both grounds, so it is one value.
  final LinearGradient signatureGradient;

  /// The silk wash behind a buyer page.
  final LinearGradient groundGradient;

  final List<BoxShadow> shadow;

  static CustomerBoutiquePalette of(BuildContext context) {
    final c = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomerBoutiquePalette(
      ink: c.onSurface,
      muted: c.onSurfaceVariant,
      background: c.background,
      surface: c.surface,
      raised: c.surfaceElevated,
      line: c.border,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primarySoft: c.primaryContainer,
      gold: c.accent,
      goldSoft: c.accentContainer,
      positive: c.success,
      caution: c.warning,
      critical: c.error,
      signatureGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFFFF9DBE), Color(0xFFE0699A), Color(0xFFE6C277)]
            : const [Color(0xFFEF6C9B), Color(0xFFC84778), Color(0xFFEACB8D)],
        stops: const [0, .58, 1],
      ),
      groundGradient: isDark
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.background, c.surfaceDim, c.background],
              stops: const [0, .52, 1],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFBFD),
                Color(0xFFFFEEF5),
                Color(0xFFFFF8EA),
              ],
              stops: [0, .48, 1],
            ),
      shadow: [
        BoxShadow(
          color: c.shadow,
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: (isDark ? DsColors.gold300 : DsColors.gold500)
              .withValues(alpha: isDark ? 0.06 : 0.07),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

extension CustomerBoutiqueContext on BuildContext {
  /// The buyer palette for the active theme.
  CustomerBoutiquePalette get boutique => CustomerBoutiquePalette.of(this);
}
