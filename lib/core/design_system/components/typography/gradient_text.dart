import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/gradient_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_colors.dart';

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
    // Defaults to the section-title role in the UI family: a gradient is a
    // shader over text, not a licence for a bespoke size.
    final effectiveStyle = style ?? context.dsText.sectionTitle.uiFamily.bold;

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          (gradient ?? context.primaryGradient).createShader(bounds),
      child: Text(text, style: effectiveStyle.copyWith(color: DsColors.onMedia)),
    );
  }
}
