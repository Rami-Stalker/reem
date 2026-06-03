import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Vibrant feminine gradient presets for Reem.
abstract final class DsGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB7D5), Color(0xFFFF6B9D)],
  );

  static const LinearGradient primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9EC7), Color(0xFFFF4D8D)],
  );

  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB88C), Color(0xFFFF6B9D), Color(0xFFE879F9)],
  );

  static const LinearGradient lavenderBlush = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8D5F2), Color(0xFFFFB7D5), Color(0xFFFFF0F5)],
  );

  static const LinearGradient champagne = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF8E7), Color(0xFFFFD6E8), Color(0xFFFFB7D5)],
  );

  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.primary50, DsColors.lavender50],
  );

  /// Light mode page background.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8FB), Color(0xFFFFF0F5), Color(0xFFFDF5FF)],
  );

  /// Dark mode page background — deep plum blush.
  static const LinearGradient backgroundDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0A12), Color(0xFF1A1220), Color(0xFF120D16)],
  );

  static LinearGradient meshBackground({required bool isDark}) =>
      isDark ? backgroundDark : background;

  static const LinearGradient storyRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B9D), Color(0xFFE879F9), Color(0xFFFFB88C)],
  );

  static const LinearGradient storyRingDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8AB5), Color(0xFFD946EF), Color(0xFFFF9F7A)],
  );

  static LinearGradient storyRingFor({required bool isDark}) =>
      isDark ? storyRingDark : storyRing;

  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x45FFFFFF), Color(0x18FFFFFF)],
  );

  static const LinearGradient glassDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x28FFFFFF), Color(0x0CFFFFFF)],
  );

  static LinearGradient glassFor({required bool isDark}) =>
      isDark ? glassDark : glass;

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DsColors.lavender100, DsColors.lavender400],
  );

  static const LinearGradient rewards = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF6B9D), Color(0xFFC084FC)],
  );

  static const LinearGradient rewardsDark = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF4D8D), Color(0xFFA855F7)],
  );

  static LinearGradient rewardsFor({required bool isDark}) =>
      isDark ? rewardsDark : rewards;

  static LinearGradient shimmer({bool isDark = false}) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: isDark
            ? [const Color(0xFF2A2230), const Color(0xFF3A3040), const Color(0xFF2A2230)]
            : [const Color(0xFFFFE5F0), const Color(0xFFFFF5F8), const Color(0xFFFFE5F0)],
      );
}
