import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

/// Semantic tone of a [DsBadge].
enum DsBadgeTone { primary, accent, sale, success, info, warning, neutral }

/// A small pill label — "New", "Sale", "Best seller", counts, statuses.
class DsBadge extends StatelessWidget {
  const DsBadge({
    super.key,
    required this.label,
    this.tone = DsBadgeTone.primary,
    this.icon,
    this.solid = false,
  });

  /// Solid filled badge — high emphasis, sits on imagery.
  const DsBadge.solid({
    super.key,
    required this.label,
    this.tone = DsBadgeTone.sale,
    this.icon,
  }) : solid = true;

  final String label;
  final DsBadgeTone tone;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    final (fill, onFill, container, onContainer) = switch (tone) {
      DsBadgeTone.primary => (c.primary, c.onPrimary, c.primaryContainer, c.onPrimaryContainer),
      DsBadgeTone.accent => (c.accent, c.onAccent, c.accentContainer, c.onAccentContainer),
      DsBadgeTone.sale => (c.discount, c.onDiscount, c.errorContainer, c.errorInk),
      DsBadgeTone.success => (c.success, c.onSuccess, c.successContainer, c.successInk),
      DsBadgeTone.info => (c.info, c.onInfo, c.infoContainer, c.infoInk),
      DsBadgeTone.warning => (c.warning, c.onWarning, c.warningContainer, c.warningInk),
      DsBadgeTone.neutral => (c.onSurfaceVariant, c.surface, c.surfaceVariant, c.onSurface),
    };

    final bg = solid ? fill : container;
    final fg = solid ? onFill : onContainer;

    return Container(
      padding: DsSpacing.badgePadding,
      decoration: BoxDecoration(color: bg, borderRadius: DsRadius.borderSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DsSizes.iconXxs, color: fg),
            DsGaps.hXxs,
          ],
          Text(label, style: context.dsText.badge.tint(fg)),
        ],
      ),
    );
  }
}

/// A discount badge that formats a percentage off, e.g. "-30%".
class DsDiscountBadge extends StatelessWidget {
  const DsDiscountBadge({super.key, required this.percentOff});

  final int percentOff;

  @override
  Widget build(BuildContext context) {
    return DsBadge.solid(
      label: '-$percentOff%',
      tone: DsBadgeTone.sale,
    );
  }
}
