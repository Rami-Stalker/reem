import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// A premium selectable chip — filters, categories, tags, choices.
///
/// Fully custom (not Material [Chip]) so selection animates and theming stays
/// consistent. Use [onDeleted] for removable chips.
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.avatar,
    this.count,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Widget? avatar;
  final int? count;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final fg = selected ? c.onPrimaryContainer : c.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DsMotion.fast,
        curve: DsMotion.gentle,
        padding: EdgeInsets.fromLTRB(
          avatar != null ? DsSpacing.xxs : DsSpacing.sm,
          DsSpacing.xs,
          onDeleted != null ? DsSpacing.xs : DsSpacing.sm,
          DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surfaceVariant,
          borderRadius: DsRadius.borderChip,
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: DsSpacing.xs),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: DsSpacing.xxs),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.labelLarge,
                fontWeight:
                    selected ? DsTypography.semiBold : DsTypography.medium,
                letterSpacing: DsTypography.letterSpacingWide,
                color: fg,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: DsSpacing.xxs),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.labelMedium,
                  fontWeight: DsTypography.medium,
                  color: selected
                      ? c.onPrimaryContainer.withValues(alpha: 0.7)
                      : c.onSurfaceVariant,
                ),
              ),
            ],
            if (onDeleted != null) ...[
              const SizedBox(width: DsSpacing.xxs),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close_rounded, size: 16, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
