import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Box shadow presets for luxury UI depth.
abstract final class DsShadows {
  static List<BoxShadow> none = const [];

  static List<BoxShadow> soft(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> medium(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> luxury(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.18),
          blurRadius: 30,
          spreadRadius: 4,
          offset: const Offset(0, 18),
        ),
      ];

  static List<BoxShadow> glow(Color color, {double blur = 24}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> inner(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 8,
          spreadRadius: -2,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> forTheme({required bool isDark}) => isDark
      ? medium(DsColors.black)
      : luxury(DsColors.primary500);
}
