import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The shapes a shelf of products can take, and the control that swaps them.
///
/// This began life on the home page as `HomeShowcaseShape`, with the switcher
/// living inside the showcase widget. That made the client's ask — *the same
/// pieces, browsable in more than one rhythm* — true of exactly one section:
/// every department page and every "see all" put the shopper back into a fixed
/// two-column grid with no say in it. The shape belongs to the catalogue, not
/// to the home page, so it lives here with the layouts it chooses between.
enum DsProductShape {
  /// The hero shape: one piece told as a full-bleed editorial card with a
  /// gallery, the boutique above it and a "shop this" plate at its foot.
  posts,

  /// The magazine spread: a tall hero tile beside two companions, mirrored
  /// down the page.
  mosaic,

  /// The catalogue: two even columns, fastest to scan when she is hunting
  /// rather than browsing.
  grid,
}

extension DsProductShapeX on DsProductShape {
  IconData get icon => switch (this) {
    DsProductShape.posts => Icons.auto_awesome_motion_rounded,
    DsProductShape.mosaic => Icons.dashboard_rounded,
    DsProductShape.grid => Icons.grid_view_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    DsProductShape.posts => l10n.homeShapePosts,
    DsProductShape.mosaic => l10n.homeShapeMosaic,
    DsProductShape.grid => l10n.homeShapeGrid,
  };
}

/// The segmented pill that swaps shapes — a rose capsule gliding under three
/// labels. Deliberately the only control on the page with this much colour:
/// it is the one thing she is meant to notice she can change.
class ShapeSwitcher extends StatelessWidget {
  const ShapeSwitcher({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final DsProductShape selected;
  final ValueChanged<DsProductShape> onSelect;

  static const double _inset = 4;
  static const double _height = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    const shapes = DsProductShape.values;
    final index = shapes.indexOf(selected);

    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: c.surfaceElevated.withValues(alpha: 0.9),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
        boxShadow: context.shadowXs,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final segment = box.maxWidth / shapes.length;
          // Expand, so the sliding capsule inherits the pill's full height
          // rather than collapsing to the height of a label.
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositionedDirectional(
                duration: DsMotion.moderate,
                curve: DsMotion.silk,
                start: segment * index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    borderRadius: DsRadius.borderPill,
                    boxShadow: context.glowShadow(
                      c.primary,
                      blur: 16,
                      alpha: 0.34,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final shape in shapes)
                    Expanded(
                      child: _Segment(
                        label: shape.label(l10n),
                        icon: shape.icon,
                        selected: shape == selected,
                        onTap: () => onSelect(shape),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final fg = selected ? c.onPrimary : c.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: DsSpacing.xxs),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: DsMotion.fast,
                style: context.dsText.labelMedium
                    .tint(fg)
                    .copyWith(
                      fontWeight: selected
                          ? DsTypography.bold
                          : DsTypography.semiBold,
                    ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
