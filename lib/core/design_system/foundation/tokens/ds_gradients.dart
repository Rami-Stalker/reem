import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// Feminine gradient presets for Ohara — blush rose, mauve and champagne gold.
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
    colors: [Color(0xFFF7AAC5), Color(0xFFE85A8A)],
  );

  static const LinearGradient primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF98FB6), Color(0xFFD43E73)],
  );

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9DBE), Color(0xFFE85A8A)],
  );

  static LinearGradient primaryFor({required bool isDark}) =>
      isDark ? primaryDark : primarySoft;

  // ---------------------------------------------------------------------------
  // Mauve / plum — secondary depth.
  // ---------------------------------------------------------------------------
  static const LinearGradient mauve = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC8A1CD), Color(0xFF8F5C99)],
  );

  // ---------------------------------------------------------------------------
  // Champagne gold — premium / occasions.
  // ---------------------------------------------------------------------------
  static const LinearGradient champagne = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCF1D8), Color(0xFFE6C277), Color(0xFFD9A94F)],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6C277), Color(0xFFC28E36)],
  );

  // ---------------------------------------------------------------------------
  // Expressive blends.
  // ---------------------------------------------------------------------------
  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC1A0), Color(0xFFF06DA0), Color(0xFFB98BE8)],
  );

  static const LinearGradient lavenderBlush = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAD7F2), Color(0xFFFAC9DC), Color(0xFFFFF1F6)],
  );

  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary50, DsColors.lavender50],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.lavender100, DsColors.mauve400],
  );

  // ---------------------------------------------------------------------------
  // Page backgrounds.
  // ---------------------------------------------------------------------------
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8FB), Color(0xFFFEEFF5), Color(0xFFFAF3FF)],
  );

  static const LinearGradient backgroundDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF150F1A), Color(0xFF1E1426), Color(0xFF18101D)],
  );

  static LinearGradient meshBackground({required bool isDark}) =>
      isDark ? backgroundDark : background;

  // ---------------------------------------------------------------------------
  // Story ring — instagram-style vibrant feminine ring.
  // ---------------------------------------------------------------------------
  static const LinearGradient storyRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE85A8A), Color(0xFFB98BE8), Color(0xFFE6C277)],
  );

  static const LinearGradient storyRingDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF87B0), Color(0xFFC9A0E0), Color(0xFFE6C277)],
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
    colors: [Color(0xFFE85A8A), Color(0xFF9D5FD8)],
  );

  static const LinearGradient rewardsDark = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF87B0), Color(0xFFB98BE8)],
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
            ? const [Color(0xFF2A2032), Color(0xFF3A2E44), Color(0xFF2A2032)]
            : const [Color(0xFFF3E3EA), Color(0xFFFFF7FB), Color(0xFFF3E3EA)],
      );
}
