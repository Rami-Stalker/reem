import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_shadows.dart';

/// Theme-aware shadow accessors. All resolve their color from the active
/// theme (`dsColors.shadow`) so light (warm rose tint) and dark read correctly.
extension DsShadowContext on BuildContext {
  /// Pre-resolved presets carried on the theme extension.
  List<BoxShadow> get luxuryShadow => ds.luxuryShadow;
  List<BoxShadow> get softShadow => ds.softShadow;

  /// On-demand tiers computed from the theme shadow color.
  List<BoxShadow> get shadowXs => DsShadows.xs(dsColors.shadow);
  List<BoxShadow> get shadowSoft => DsShadows.soft(dsColors.shadow);
  List<BoxShadow> get shadowMedium => DsShadows.medium(dsColors.shadow);
  List<BoxShadow> get shadowLuxury => DsShadows.luxury(dsColors.shadow);
  List<BoxShadow> get shadowOverlay => DsShadows.overlay(dsColors.shadow);

  /// Colored glow around a given color (CTAs, story rings, accents).
  List<BoxShadow> glowShadow(Color color, {double blur = 24, double alpha = 0.35}) =>
      DsShadows.glow(color, blur: blur, alpha: alpha);

  /// Glow tuned to the brand primary.
  List<BoxShadow> get primaryGlow =>
      DsShadows.glow(dsColors.primary, blur: 26, alpha: ds.isDark ? 0.30 : 0.34);
}
