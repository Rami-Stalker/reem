import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';
import 'package:reem/features/trends/presentation/widgets/trend_pieces.dart';
import 'package:reem/features/trends/presentation/widgets/trend_text_action.dart';

// ── Admin cards ──────────────────────────────────────────────────────────

class AdminTrendProductTile extends StatelessWidget {
  const AdminTrendProductTile({super.key, required this.product});

  final AdminTrendProduct product;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrendScoreDial(
              score: product.score,
              confidence: product.confidence,
              stage: product.stage.stage,
              size: 52,
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.bodySmall.semibold.tint(palette.ink),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    product.categoryNameAr,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                  const SizedBox(height: DsSpacing.xs),
                  Wrap(
                    spacing: DsSpacing.sm,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TrendStageChip(product.stage, compact: true),
                      _Inline(
                        label: l10n.trendViews,
                        value: formatCount(product.views),
                        delta: product.viewsGrowthPct,
                      ),
                      _Inline(
                        label: l10n.trendUnits,
                        value: formatCount(product.units),
                        delta: product.unitsGrowthPct,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inline extends StatelessWidget {
  const _Inline({required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: context.dsText.caption.tint(palette.muted),
        ),
        Text(
          value,
          style: context.dsText.caption.bold.tint(palette.ink),
        ),
        if (delta != null) ...[
          DsGaps.hXxxs,
          TrendDelta(
            value: delta!,
            suffix: '%',
            fontSize: DsTypography.labelSmall,
          ),
        ],
      ],
    );
  }
}

/// A question the catalogue could not answer.
///
/// The miss rate is given the loudest treatment on the card because it is what
/// separates "a popular search" from "a hole in the assortment", and only the
/// second one is a buying decision.
class UnmetDemandCard extends StatelessWidget {
  const UnmetDemandCard({super.key, required this.signal, this.onReview});

  final UnmetDemand signal;
  final ValueChanged<UnmetDemandStatus>? onReview;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search_off_rounded, size: 16, color: palette.gold),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Text(
                    '«${signal.display}»',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.bold.tint(palette.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.sm,
                    vertical: DsSpacing.xxxs,
                  ),
                  decoration: BoxDecoration(
                    color: palette.gold.withValues(alpha: 0.16),
                    borderRadius: DsRadius.borderSm,
                  ),
                  child: Text(
                    signal.demandScore.round().toString(),
                    style: context.dsText.labelMedium.bold.tint(palette.gold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              l10n.trendUnmetSummary(
                signal.searches,
                (signal.missRate * 100).round(),
              ),
              style: context.dsText.labelMedium.tint(palette.muted),
            ),
            if (signal.suggestionAr != null) ...[
              const SizedBox(height: DsSpacing.sm),
              Text(
                signal.suggestionAr!,
                style: context.dsText.bodySmall.tint(palette.ink).copyWith(height: 1.6),
              ),
            ],
            if (signal.suggestedCategoryNameAr != null) ...[
              const SizedBox(height: DsSpacing.xs),
              Row(
                children: [
                  Icon(Icons.category_rounded, size: 13, color: palette.muted),
                  const SizedBox(width: DsSpacing.xs),
                  Text(
                    signal.suggestedCategoryNameAr!,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ),
            ],
            if (onReview != null &&
                signal.status == UnmetDemandStatus.open) ...[
              const SizedBox(height: DsSpacing.sm),
              Row(
                children: [
                  TrendTextAction(
                    label: l10n.trendUnmetSourcing,
                    icon: Icons.shopping_bag_rounded,
                    onTap: () => onReview!(UnmetDemandStatus.sourcing),
                  ),
                  const SizedBox(width: DsSpacing.md),
                  TrendTextAction(
                    label: l10n.trendDismiss,
                    icon: Icons.close_rounded,
                    tone: palette.muted,
                    onTap: () => onReview!(UnmetDemandStatus.dismissed),
                  ),
                ],
              ),
            ] else if (signal.status != UnmetDemandStatus.open) ...[
              const SizedBox(height: DsSpacing.xs),
              SellerStatusPill(label: _statusLabel(context, signal.status)),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, UnmetDemandStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      UnmetDemandStatus.open => l10n.trendUnmetOpen,
      UnmetDemandStatus.acknowledged => l10n.trendUnmetAcknowledged,
      UnmetDemandStatus.sourcing => l10n.trendUnmetSourcing,
      UnmetDemandStatus.addressed => l10n.trendUnmetAddressed,
      UnmetDemandStatus.dismissed => l10n.trendUnmetDismissed,
    };
  }
}
