import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// Feminine gradient presets for Ohara — rose, mauve, cream and a touch of gold.
///
/// Prefer the theme-resolved accessors on `context` (`context.primaryGradient`
/// etc.) so dark variants are picked automatically.
abstract final class DsGradients {
  // ---------------------------------------------------------------------------
  // Primary — blush rose.
  // ---------------------------------------------------------------------------
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary300, DsColors.primary500],
  );

  static const LinearGradient primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary400, DsColors.primary600],
  );

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary300, DsColors.primary500],
  );

  static LinearGradient primaryFor({required bool isDark}) =>
      isDark ? primaryDark : primarySoft;

  // ---------------------------------------------------------------------------
  // Mauve / plum — secondary depth.
  // ---------------------------------------------------------------------------
  static const LinearGradient mauve = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.secondary300, DsColors.secondary600],
  );

  // ---------------------------------------------------------------------------
  // Champagne gold — premium / occasions.
  // ---------------------------------------------------------------------------
  static const LinearGradient champagne = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.gold50, DsColors.softGold, DsColors.champagneGold],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.softGold, DsColors.champagneGold],
  );

  // ---------------------------------------------------------------------------
  // Expressive blends.
  // ---------------------------------------------------------------------------
  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.peachCream, DsColors.primary400, DsColors.secondary400],
  );

  static const LinearGradient lavenderBlush = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.secondary100, DsColors.primary200, DsColors.primary50],
  );

  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.backgroundPink, DsColors.backgroundSecondary],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.secondary100, DsColors.secondary400],
  );

  // ---------------------------------------------------------------------------
  // Page backgrounds.
  // ---------------------------------------------------------------------------
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      DsColors.backgroundSecondary,
      DsColors.backgroundPink,
      DsColors.secondary50,
    ],
  );

  static const LinearGradient backgroundDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      DsColors.backgroundDark,
      DsColors.surfaceDark,
      DsColors.backgroundDark,
    ],
  );

  static LinearGradient meshBackground({required bool isDark}) =>
      isDark ? backgroundDark : background;

  // ---------------------------------------------------------------------------
  // Story ring — instagram-style vibrant feminine ring.
  // ---------------------------------------------------------------------------
  static const LinearGradient storyRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      DsColors.primary500,
      DsColors.secondary400,
      DsColors.champagneGold,
    ],
  );

  static const LinearGradient storyRingDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary300, DsColors.secondary300, DsColors.softGold],
  );

  static LinearGradient storyRingFor({required bool isDark}) =>
      isDark ? storyRingDark : storyRing;

  // ---------------------------------------------------------------------------
  // Glass overlays.
  // ---------------------------------------------------------------------------
  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x47FFFFFF), Color(0x1AFFFFFF)],
  );

  static const LinearGradient glassDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2EFFFFFF), Color(0x0EFFFFFF)],
  );

  static LinearGradient glassFor({required bool isDark}) =>
      isDark ? glassDark : glass;

  // ---------------------------------------------------------------------------
  // Rewards / loyalty — rose to mauve.
  // ---------------------------------------------------------------------------
  static const LinearGradient rewards = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [DsColors.primary500, DsColors.secondary600],
  );

  static const LinearGradient rewardsDark = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [DsColors.primary300, DsColors.secondary300],
  );

  static LinearGradient rewardsFor({required bool isDark}) =>
      isDark ? rewardsDark : rewards;

  // ---------------------------------------------------------------------------
  // Scrims — for legible text over imagery (product / story / post media).
  // ---------------------------------------------------------------------------
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x14000000), Color(0x99000000)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient imageScrimTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x73000000), Color(0x00000000)],
  );

  // ---------------------------------------------------------------------------
  // Shimmer (loading) — resolved by theme brightness.
  // ---------------------------------------------------------------------------
  static LinearGradient shimmer({bool isDark = false}) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: isDark
        ? const [Color(0xFF2B222E), Color(0xFF3A2F3E), Color(0xFF2B222E)]
        : const [
            DsColors.surfaceVariantLight,
            DsColors.backgroundPink,
            DsColors.surfaceVariantLight,
          ],
  );
}
