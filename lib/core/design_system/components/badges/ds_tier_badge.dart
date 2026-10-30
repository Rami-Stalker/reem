import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_gradients.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

/// The paid plan a boutique carries. Free carries no badge at all.
enum DsTier { silver, gold, diamond }

extension DsTierLook on DsTier {
  LinearGradient get gradient => switch (this) {
    DsTier.silver => DsGradients.tierSilver,
    DsTier.gold => DsGradients.tierGold,
    DsTier.diamond => DsGradients.tierDiamond,
  };

  Color get ink => switch (this) {
    DsTier.silver => DsColors.onTierSilver,
    DsTier.gold => DsColors.onGold,
    DsTier.diamond => DsColors.onTierDiamond,
  };

  IconData get icon => switch (this) {
    DsTier.silver => Icons.workspace_premium_rounded,
    DsTier.gold => Icons.star_rounded,
    DsTier.diamond => Icons.diamond_rounded,
  };
}

/// «فضي · ذهبي · ماسي» — a boutique's advertising plan, as a jewel-toned pill.
///
/// Mode-independent on purpose: the gradients are fixed metal blends, so the
/// ink on them is fixed too, exactly like the gold "new in" ribbon.
class DsTierBadge extends StatelessWidget {
  const DsTierBadge({
    super.key,
    required this.tier,
    required this.label,
    this.compact = false,
  });

  /// Just the jewel, for a card too small for a word. [label] becomes its
  /// semantic label and tooltip.
  const DsTierBadge.compact({
    super.key,
    required this.tier,
    required this.label,
  }) : compact = true;

  final DsTier tier;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ink = tier.ink;
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: tier.gradient,
        borderRadius: DsRadius.borderFull,
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.all(DsSpacing.xxs)
            : DsSpacing.badgePadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tier.icon, size: DsSizes.iconXxs, color: ink),
            if (!compact) ...[
              DsGaps.hXxs,
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.badge.tint(ink),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: compact ? Tooltip(message: label, child: pill) : pill,
    );
  }
}
