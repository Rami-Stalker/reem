import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// Layered box-shadow presets for soft, premium depth.
///
/// Real depth comes from *two* layers: a tight contact shadow plus a wide,
/// soft ambient one. Pass the theme's shadow color (`context.dsColors.shadow`)
/// so light (warm rose tint) and dark (deep) modes read correctly.
abstract final class DsShadows {
  static const List<BoxShadow> none = [];

  /// Tier 1 — resting cards, chips. Barely-there lift.
  static List<BoxShadow> xs(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  /// Tier 2 — default elevated surfaces.
  static List<BoxShadow> soft(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  /// Tier 3 — interactive / hover, raised cards.
  static List<BoxShadow> medium(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.10),
          blurRadius: 30,
          spreadRadius: -2,
          offset: const Offset(0, 16),
        ),
      ];

  /// Tier 4 — luxury / floating hero elements.
  static List<BoxShadow> luxury(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.10),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.14),
          blurRadius: 40,
          spreadRadius: 2,
          offset: const Offset(0, 22),
        ),
      ];

  /// Tier 5 — modals, bottom sheets, dialogs.
  static List<BoxShadow> overlay(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.16),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.20),
          blurRadius: 56,
          spreadRadius: 4,
          offset: const Offset(0, 28),
        ),
      ];

  /// Colored glow — for primary CTAs, story rings, accents.
  static List<BoxShadow> glow(Color color, {double blur = 24, double alpha = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: blur,
          spreadRadius: 1,
          offset: const Offset(0, 8),
        ),
      ];

  /// Soft inner-feeling shadow (use sparingly).
  static List<BoxShadow> inner(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 8,
          spreadRadius: -2,
          offset: const Offset(0, 2),
        ),
      ];

  /// Theme-aware default surface shadow.
  static List<BoxShadow> forTheme({required bool isDark, Color? color}) {
    final c = color ?? (isDark ? DsColors.black : DsColors.primary600);
    return isDark ? soft(c) : soft(c);
  }

  /// Theme-aware hero/floating shadow.
  static List<BoxShadow> floatingForTheme({required bool isDark, Color? color}) {
    if (isDark) return glow(color ?? DsColors.secondary400, blur: 30, alpha: 0.28);
    return luxury(color ?? DsColors.primary500);
  }
}
