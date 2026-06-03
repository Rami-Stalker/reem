import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/theme/extensions/shadow_extension.dart';
import 'button_sizes.dart';

class DsButtonStyle {
  const DsButtonStyle({
    this.background,
    required this.foreground,
    this.gradient,
    this.border,
    this.shadow,
  });

  final Color? background;
  final Color foreground;
  final Gradient? gradient;
  final BorderSide? border;
  final List<BoxShadow>? shadow;

  static DsButtonStyle primary(BuildContext context, DsButtonSize size) {
    return DsButtonStyle(
      gradient: context.primaryGradient,
      foreground: context.dsColors.onPrimary,
      shadow: context.luxuryShadow,
    );
  }

  static DsButtonStyle secondary(BuildContext context, DsButtonSize size) {
    return DsButtonStyle(
      background: context.dsColors.surfaceVariant,
      foreground: context.dsColors.primary,
      border: BorderSide(color: context.dsColors.primary, width: 1.5),
    );
  }

  static DsButtonStyle ghost(BuildContext context) {
    return DsButtonStyle(
      background: Colors.transparent,
      foreground: context.dsColors.primary,
    );
  }
}
