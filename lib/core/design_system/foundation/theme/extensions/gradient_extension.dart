import 'package:flutter/material.dart';

import 'color_extension.dart';

extension DsGradientContext on BuildContext {
  LinearGradient get primaryGradient => ds.primaryGradient;
  LinearGradient get softGradient => ds.softGradient;
  LinearGradient get glassGradient => ds.glassGradient;
  LinearGradient get meshGradient => ds.meshGradient;
  LinearGradient get storyRingGradient => ds.storyRingGradient;
  LinearGradient get rewardsGradient => ds.rewardsGradient;
}
