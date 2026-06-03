import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/tokens/ds_typography.dart';

class DsGradientText extends StatelessWidget {
  const DsGradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
  });

  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ??
        TextStyle(
          fontFamily: DsTypography.fontFamily,
          fontSize: DsTypography.headlineSmall,
          fontWeight: DsTypography.bold,
        );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          (gradient ?? context.primaryGradient).createShader(bounds),
      child: Text(text, style: effectiveStyle.copyWith(color: Colors.white)),
    );
  }
}
