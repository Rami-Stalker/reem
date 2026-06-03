import 'package:flutter/material.dart';

import '../../foundation/motion/animations/scale_animations.dart';
import '../../foundation/tokens/ds_motion.dart';
import '../../foundation/tokens/ds_typography.dart';
import 'button_sizes.dart';
import 'button_states.dart';
import 'button_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = DsButtonSize.lg,
    this.isLoading = false,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DsButtonSize size;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final state = isLoading
        ? DsButtonState.loading
        : onPressed == null
            ? DsButtonState.disabled
            : DsButtonState.enabled;

    final style = DsButtonStyle.primary(context, size);
    final child = _ButtonContent(
      label: label,
      icon: icon,
      foreground: style.foreground,
      size: size,
      isLoading: state.isLoading,
    );

    final button = DsScaleAnimations.tapScale(
      onTap: state.isInteractive ? onPressed! : () {},
      child: AnimatedContainer(
        duration: DsMotion.moderate,
        height: size.height,
        padding: size.padding,
        decoration: BoxDecoration(
          gradient: style.gradient,
          color: style.background,
          borderRadius: size.borderRadius,
          border: style.border != null ? Border.fromBorderSide(style.border!) : null,
          boxShadow: state.isDisabled ? null : style.shadow,
        ),
        child: child,
      ),
    );

    if (!isExpanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.foreground,
    required this.size,
    required this.isLoading,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final DsButtonSize size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: foreground,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: size.fontSize,
            fontWeight: DsTypography.semiBold,
            color: foreground,
          ),
        ),
      ],
    );
  }
}
