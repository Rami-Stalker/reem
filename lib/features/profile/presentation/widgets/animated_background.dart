import 'package:flutter/material.dart';

import '../../../../core/shared/wedgets/backgrounds/animated_gradient_background.dart';

/// Profile screen background — uses shared animated gradient.
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) => const AnimatedGradientBackground();
}
