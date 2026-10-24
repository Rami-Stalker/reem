import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/components/buttons/button_sizes.dart';
import 'package:ohara/core/design_system/components/buttons/button_states.dart';
import 'package:ohara/core/design_system/components/buttons/button_styles.dart';
import 'package:ohara/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_typography.dart';

/// The Ohara button — one widget, every variant, fully token-driven.
///
/// ```dart
/// DsButton(label: 'Add to bag', icon: Icons.shopping_bag_outlined, onPressed: ...)
/// DsButton(label: 'Gift wrap', variant: DsButtonVariant.accent, onPressed: ...)
/// DsButton(label: 'Remove', variant: DsButtonVariant.danger, onPressed: ...)
/// ```
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final state = isLoading
        ? DsButtonState.loading
        : onPressed == null
            ? DsButtonState.disabled
            : DsButtonState.enabled;

    final style = DsButtonStyle.resolve(context, variant);
    final disabled = state.isDisabled;
    final c = context.dsColors;

    final content = AnimatedSwitcher(
      duration: DsMotion.fast,
      child: state.isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              height: size.iconSize,
              width: size.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: style.foreground,
              ),
            )
          : _Content(
              key: const ValueKey('label'),
              label: label,
              icon: icon,
              trailingIcon: trailingIcon,
              foreground:
                  disabled ? c.onDisabled : style.foreground,
              size: size,
            ),
    );

    final button = AnimatedContainer(
      duration: DsMotion.normal,
      curve: DsMotion.gentle,
      height: size.height,
      padding: size.padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: disabled ? null : style.gradient,
        color: disabled
            ? c.disabled
            : (style.gradient == null ? style.background : null),
        borderRadius: size.borderRadius,
        border: !disabled && style.border != null
            ? Border.fromBorderSide(style.border!)
            : null,
        boxShadow: disabled ? null : style.shadow,
      ),
      child: content,
    );

    final wrapped = DsScaleAnimations.tapScale(
      pressedScale: DsMotion.pressedScale,
      onTap: state.isInteractive ? onPressed! : () {},
      // A disabled button still announces itself, so she is told the control
      // exists and is unavailable rather than finding nothing there.
      enabled: state.isInteractive,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: button,
    );

    if (!isExpanded) return wrapped;
    return SizedBox(width: double.infinity, child: wrapped);
  }
}

class _Content extends StatelessWidget {
  const _Content({
    super.key,
    required this.label,
    required this.foreground,
    required this.size,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color foreground;
  final DsButtonSize size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: size.iconSize),
          const SizedBox(width: DsSpacing.xs),
        ],
        // A call to action shrinks before it truncates. Cutting the label is
        // the one thing a button must not do — «أضيفي إلى السلة» came out as
        // «أضيفي إلى ا…» on the product page, which stops being an
        // instruction. `scaleDown` only ever reduces, so a label that already
        // fits is untouched; the ellipsis stays as the last resort.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: size.fontSize,
                fontWeight: DsTypography.semiBold,
                letterSpacing: DsTypography.letterSpacingWide,
                color: foreground,
              ),
            ),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: DsSpacing.xs),
          Icon(trailingIcon, color: foreground, size: size.iconSize),
        ],
      ],
    );
  }
}
