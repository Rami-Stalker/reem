import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gradients.dart';

/// Gradient accessors. Theme-aware ones come off the theme extension; the
/// mode-agnostic brand blends are exposed directly from [DsGradients].
extension DsGradientContext on BuildContext {
  // Theme-aware (light/dark differ).
  LinearGradient get primaryGradient => ds.primaryGradient;
  LinearGradient get softGradient => ds.softGradient;
  LinearGradient get glassGradient => ds.glassGradient;
  LinearGradient get meshGradient => ds.meshGradient;
  LinearGradient get storyRingGradient => ds.storyRingGradient;
  LinearGradient get rewardsGradient => ds.rewardsGradient;

  // Brand blends (same in both modes).
  LinearGradient get champagneGradient => DsGradients.champagne;
  LinearGradient get goldGradient => DsGradients.gold;
  LinearGradient get mauveGradient => DsGradients.mauve;
  LinearGradient get sunsetGradient => DsGradients.sunset;
  LinearGradient get accentGradient => DsGradients.accent;

  // Scrims for legible text over imagery.
  LinearGradient get imageScrim => DsGradients.imageScrim;
  LinearGradient get imageScrimTop => DsGradients.imageScrimTop;
}
