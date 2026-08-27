import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/gradient_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';

/// Background treatment for [DsIconButton].
enum DsIconButtonVariant { primary, tonal, surface, ghost, glass }

/// A circular, tappable icon button with feminine surface treatments.
class DsIconButton extends StatelessWidget {
  const DsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = DsIconButtonVariant.surface,
    this.size = DsConstraints.iconLg + 12, // 44 — comfortable touch target
    this.iconSize = DsConstraints.iconMd,
    this.color,
    this.tooltip,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final DsIconButtonVariant variant;
  final double size;
  final double iconSize;

  /// Overrides the resolved foreground color.
  final Color? color;
  final String? tooltip;

  /// When non-null and > 0, shows a small count badge.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final disabled = onPressed == null;

    final (bg, fg, gradient, border, shadow) = switch (variant) {
      DsIconButtonVariant.primary => (
          null,
          c.onPrimary,
          context.primaryGradient,
          null,
          context.glowShadow(c.primary, blur: 16, alpha: 0.28),
        ),
      DsIconButtonVariant.tonal => (
          c.primaryContainer,
          c.onPrimaryContainer,
          null,
          null,
          null,
        ),
      DsIconButtonVariant.surface => (
          c.surface,
          c.onSurface,
          null,
          Border.all(color: c.border),
          context.shadowXs,
        ),
      DsIconButtonVariant.ghost => (
          Colors.transparent,
          c.onSurface,
          null,
          null,
          null,
        ),
      DsIconButtonVariant.glass => (
          c.glass,
          c.onSurface,
          null,
          Border.all(color: c.glassBorder),
          null,
        ),
    };

    Widget button = AnimatedContainer(
      duration: DsMotion.fast,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: disabled ? c.disabled.withValues(alpha: 0.4) : bg,
        gradient: disabled ? null : gradient,
        shape: BoxShape.circle,
        border: border,
        boxShadow: disabled ? null : shadow,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: disabled ? c.onDisabled : (color ?? fg),
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: _CountBadge(count: badgeCount!),
          ),
        ],
      );
    }

    final tappable = DsScaleAnimations.tapScale(
      pressedScale: DsMotion.pressedScale,
      onTap: disabled ? () {} : onPressed!,
      child: button,
    );

    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip!, child: tappable);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: c.favorite,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: c.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
