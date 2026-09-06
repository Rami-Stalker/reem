import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';
import 'package:reem/features/trends/presentation/widgets/trend_pieces.dart';

/// One of the seller's products, with its score and what is wrong with it.
///
/// The layout is an argument: the dial first, because the score is the reason
/// the row is here; then the title; then the *alerts*, because a product with
/// something wrong is why she opened the page at all; and only then the
/// figures. A card that led with the figures would be a spreadsheet row.
class SellerTrendProductCard extends StatelessWidget {
  const SellerTrendProductCard({super.key, required this.product, this.onTap});

  final SellerTrendProduct product;
  final VoidCallback? onTap;

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
        onTap: onTap,
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrendScoreDial(
                  score: product.score,
                  confidence: product.confidence,
                  stage: product.stage.stage,
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
                        style: context.dsText.body.semibold.tint(palette.ink),
                      ),
                      const SizedBox(height: DsSpacing.xs),
                      Wrap(
                        spacing: DsSpacing.xs,
                        runSpacing: DsSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TrendStageChip(product.stage, compact: true),
                          if (product.previousScore != null)
                            TrendDelta(
                              value: product.delta,
                              suffix: l10n.trendPointsSuffix,
                              fontSize: DsTypography.labelSmall,
                            ),
                          if (product.rank != null)
                            Text(
                              l10n.trendRankValue(product.rank!),
                              style: context.dsText.caption.tint(palette.muted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (product.alerts.any) ...[
              const SizedBox(height: DsSpacing.sm),
              _AlertRow(
                alerts: product.alerts,
                stockout: product.stockoutInDays,
              ),
            ],

            const SizedBox(height: DsSpacing.sm),
            Divider(height: 1, color: palette.line),
            const SizedBox(height: DsSpacing.sm),

            // Demand belongs to the product, sales belong to her. The labels
            // say so, because a seller reading "views" beside "your units" and
            // assuming both are hers would draw the wrong conclusion about a
            // product she shares with another shop.
            Row(
              children: [
                _Figure(
                  label: l10n.trendViews,
                  value: formatCount(product.demand.views),
                ),
                _Figure(
                  label: l10n.trendCartAdds,
                  value: formatCount(product.demand.cartAdds),
                ),
                _Figure(
                  label: l10n.trendMyUnits,
                  value: formatCount(product.mine.units),
                  tone: palette.primary,
                ),
                _Figure(
                  label: l10n.trendStock,
                  value: formatCount(product.mine.stockUnits),
                  tone: product.mine.stockUnits == 0 ? palette.critical : null,
                ),
              ],
            ),

            if (product.forecastUnits != null &&
                product.forecastHorizonDays != null) ...[
              const SizedBox(height: DsSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 14,
                    color: palette.muted,
                  ),
                  const SizedBox(width: DsSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.trendForecastLine(
                        product.forecastUnits!.round(),
                        product.forecastHorizonDays!,
                      ),
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alerts, required this.stockout});

  final TrendAlerts alerts;
  final double? stockout;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    final entries = <(String, Color, IconData)>[
      if (alerts.stockRisk)
        (
          stockout == null
              ? l10n.trendAlertStockRisk
              : l10n.trendAlertStockOutIn(stockout!.round()),
          palette.critical,
          Icons.inventory_2_rounded,
        ),
      if (alerts.soldOutWithDemand)
        (l10n.trendAlertSoldOut, palette.critical, Icons.remove_circle_rounded),
      if (alerts.lowConversion)
        (
          l10n.trendAlertLowConversion,
          palette.caution,
          Icons.visibility_off_rounded,
        ),
      if (alerts.weakCartThrough)
        (
          l10n.trendAlertCartAbandon,
          palette.caution,
          Icons.remove_shopping_cart_rounded,
        ),
      if (alerts.overstock)
        (l10n.trendAlertOverstock, palette.muted, Icons.warehouse_rounded),
    ];

    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final (label, colour, icon) in entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm,
              vertical: DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: colour),
                DsGaps.hXxs,
                Text(
                  label,
                  style: context.dsText.caption.semibold.tint(colour),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.tint(palette.muted),
          ),
          DsGaps.vXxxs,
          Text(
            value,
            style: context.dsText.bodySmall.bold.tint(tone ?? palette.ink),
          ),
        ],
      ),
    );
  }
}
