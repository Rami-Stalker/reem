import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_gradients.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_shadows.dart';

/// Central design-system theme extension — access via `context.ds`.
@immutable
class DsThemeExtension extends ThemeExtension<DsThemeExtension> {
  const DsThemeExtension({
    required this.colors,
    required this.isDark,
    required this.primaryGradient,
    required this.softGradient,
    required this.glassGradient,
    required this.meshGradient,
    required this.storyRingGradient,
    required this.rewardsGradient,
    required this.luxuryShadow,
    required this.softShadow,
  });

  final DsColorScheme colors;
  final bool isDark;
  final LinearGradient primaryGradient;
  final LinearGradient softGradient;
  final LinearGradient glassGradient;
  final LinearGradient meshGradient;
  final LinearGradient storyRingGradient;
  final LinearGradient rewardsGradient;
  final List<BoxShadow> luxuryShadow;
  final List<BoxShadow> softShadow;

  static final DsThemeExtension light = DsThemeExtension(
    colors: DsColorScheme.light,
    isDark: false,
    primaryGradient: DsGradients.primarySoft,
    softGradient: DsGradients.roseMauveBlush,
    glassGradient: DsGradients.glass,
    meshGradient: DsGradients.background,
    storyRingGradient: DsGradients.storyRing,
    rewardsGradient: DsGradients.rewards,
    luxuryShadow: DsShadows.luxury(DsColors.primary500),
    softShadow: DsShadows.soft(DsColors.neutral800),
  );

  static final DsThemeExtension dark = DsThemeExtension(
    colors: DsColorScheme.dark,
    isDark: true,
    primaryGradient: DsGradients.primaryDark,
    softGradient: DsGradients.backgroundDark,
    glassGradient: DsGradients.glassDark,
    meshGradient: DsGradients.backgroundDark,
    storyRingGradient: DsGradients.storyRingDark,
    rewardsGradient: DsGradients.rewardsDark,
    luxuryShadow: DsShadows.glow(DsColors.secondary400, blur: 28),
    softShadow: DsShadows.soft(DsColors.black),
  );

  @override
  DsThemeExtension copyWith({
    DsColorScheme? colors,
    bool? isDark,
    LinearGradient? primaryGradient,
    LinearGradient? softGradient,
    LinearGradient? glassGradient,
    LinearGradient? meshGradient,
    LinearGradient? storyRingGradient,
    LinearGradient? rewardsGradient,
    List<BoxShadow>? luxuryShadow,
    List<BoxShadow>? softShadow,
  }) {
    return DsThemeExtension(
      colors: colors ?? this.colors,
      isDark: isDark ?? this.isDark,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      softGradient: softGradient ?? this.softGradient,
      glassGradient: glassGradient ?? this.glassGradient,
      meshGradient: meshGradient ?? this.meshGradient,
      storyRingGradient: storyRingGradient ?? this.storyRingGradient,
      rewardsGradient: rewardsGradient ?? this.rewardsGradient,
      luxuryShadow: luxuryShadow ?? this.luxuryShadow,
      softShadow: softShadow ?? this.softShadow,
    );
  }

  @override
  DsThemeExtension lerp(ThemeExtension<DsThemeExtension>? other, double t) {
    if (other is! DsThemeExtension) return this;
    return DsThemeExtension(
      colors: colors.lerp(other.colors, t),
      isDark: t < 0.5 ? isDark : other.isDark,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      softGradient: LinearGradient.lerp(softGradient, other.softGradient, t)!,
      glassGradient:
          LinearGradient.lerp(glassGradient, other.glassGradient, t)!,
      meshGradient:
          LinearGradient.lerp(meshGradient, other.meshGradient, t)!,
      storyRingGradient: LinearGradient.lerp(
        storyRingGradient,
        other.storyRingGradient,
        t,
      )!,
      rewardsGradient:
          LinearGradient.lerp(rewardsGradient, other.rewardsGradient, t)!,
      luxuryShadow: luxuryShadow,
      softShadow: softShadow,
    );
  }
}
