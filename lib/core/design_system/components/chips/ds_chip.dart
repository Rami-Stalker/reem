import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_icons.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_strokes.dart';

/// A premium selectable chip — filters, categories, tags, choices.
///
/// Fully custom (not Material [Chip]) so selection animates and theming stays
/// consistent. Use [onDeleted] for removable chips.
///
/// A chip with [enabled] false — a size the boutique has run out of, a filter
/// that would return nothing — is dimmed and struck through rather than merely
/// inert, because a control that looks tappable and does nothing reads as a
/// broken app rather than as an unavailable option.
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.icon,
    this.avatar,
    this.count,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;

  /// False renders the unavailable treatment. Defaults to whether [onTap] was
  /// given, so an existing caller that passes a null handler still reads right.
  final bool enabled;

  final IconData? icon;
  final Widget? avatar;
  final int? count;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  bool get _live => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final text = context.dsText;
    final off = !_live && onTap == null;
    final fg = off
        ? c.onDisabled
        : selected
            ? c.onPrimaryContainer
            : c.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      enabled: _live,
      child: GestureDetector(
        onTap: _live ? onTap : null,
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
            color: off
                ? c.surfaceVariant.withValues(alpha: 0.5)
                : selected
                    ? c.primaryContainer
                    : c.surfaceVariant,
            borderRadius: DsRadius.borderChip,
            border: Border.all(
              color: off
                  ? c.disabled
                  : selected
                      ? c.primary
                      : c.border,
              width: selected ? DsStrokes.regular : DsStrokes.thin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[
                avatar!,
                DsGaps.hXs,
              ] else if (icon != null) ...[
                Icon(icon, size: DsSizes.iconXs, color: fg),
                DsGaps.hXxs,
              ],
              // Flexible, because the label is the only part that can give.
              // At 200% text a fixed chip overflowed its row by 170px — a
              // failure invisible at 100% and unavoidable for anyone who
              // runs their phone large.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (selected
                          ? text.labelStrong.tint(fg)
                          : text.label.medium.tint(fg))
                      .copyWith(
                    decoration: off ? TextDecoration.lineThrough : null,
                    decorationColor: off ? c.onDisabled : null,
                  ),
                ),
              ),
              if (count != null) ...[
                DsGaps.hXxs,
                Text(
                  '$count',
                  style: text.label.tint(
                    selected
                        ? c.onPrimaryContainer.withValues(alpha: 0.7)
                        : c.onSurfaceVariant,
                  ),
                ),
              ],
              if (onDeleted != null) ...[
                DsGaps.hXxs,
                GestureDetector(
                  onTap: onDeleted,
                  child: Icon(DsIcons.close, size: DsSizes.iconXs, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
