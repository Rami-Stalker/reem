import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';
import 'package:reem/features/trends/presentation/widgets/trend_pieces.dart';

/// The panels of the market intelligence page.
///
/// Split out of the screen so the screen reads as an argument about order —
/// opportunities, then demand, then the ends of the curve — rather than as
/// a thousand lines of chart code with a narrative buried in it.

/// The chart panels of the market page: the opportunity cards at the
/// top, the three-line demand view, and the shape of the catalogue
/// across the curve.

// ── Opportunity ──────────────────────────────────────────────────────────

class AdminTrendOpportunityCard extends StatelessWidget {
  const AdminTrendOpportunityCard({super.key, required this.opportunity});

  final MarketOpportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    final (icon, label) = switch (opportunity.kind) {
      'CATEGORY_GAP' => (Icons.category_rounded, l10n.trendsGapCategory),
      'UNMET_SEARCH' => (Icons.search_off_rounded, l10n.trendsGapSearch),
      _ => (Icons.sell_rounded, l10n.trendsGapPrice),
    };

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
            Container(
              padding: const EdgeInsets.all(DsSpacing.xs),
              decoration: BoxDecoration(
                color: palette.goldSoft,
                borderRadius: DsRadius.borderSm,
              ),
              child: Icon(icon, size: 16, color: palette.gold),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opportunity.titleAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.body.bold.tint(palette.ink),
                        ),
                      ),
                      Text(
                        label,
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ],
                  ),
                  if (opportunity.detailAr.isNotEmpty) ...[
                    DsGaps.vXxxs,
                    Text(
                      opportunity.detailAr,
                      style: context.dsText.bodySmall.tint(palette.muted).copyWith(height: 1.6),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Demand chart ─────────────────────────────────────────────────────────

/// Views, cart adds and units on one panel — but on **three separate
/// sparklines**, not one axis.
///
/// They are quantities of different kinds and wildly different magnitudes; a
/// shared axis would flatten units into a straight line along the bottom and
/// make the funnel look empty on a day it was not.
class AdminTrendDemandChart extends StatelessWidget {
  const AdminTrendDemandChart({super.key, required this.series});

  final List<TrendSeriesPoint> series;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        child: Column(
          children: [
            _SparkRow(
              label: l10n.trendViews,
              values: [for (final point in series) point.views.toDouble()],
              colour: palette.primary,
            ),
            const SizedBox(height: DsSpacing.sm),
            _SparkRow(
              label: l10n.trendCartAdds,
              values: [for (final point in series) point.cartAdds.toDouble()],
              colour: palette.gold,
            ),
            const SizedBox(height: DsSpacing.sm),
            _SparkRow(
              label: l10n.trendUnits,
              values: [for (final point in series) point.units.toDouble()],
              colour: palette.positive,
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkRow extends StatelessWidget {
  const _SparkRow({
    required this.label,
    required this.values,
    required this.colour,
  });

  final String label;
  final List<double> values;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final total = values.fold<double>(0, (sum, value) => sum + value);

    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.dsText.caption.tint(palette.muted),
              ),
              Text(
                formatCount(total),
                style: context.dsText.bodySmall.bold.tint(palette.ink),
              ),
            ],
          ),
        ),
        Expanded(
          child: TrendSparkline(values: values, colour: colour, height: 36),
        ),
      ],
    );
  }
}

/// How the catalogue is spread across the curve.
class AdminTrendStageDistribution extends StatelessWidget {
  const AdminTrendStageDistribution({super.key, required this.stages});

  final Map<String, int> stages;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final total = stages.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return const SizedBox.shrink();

    // Dormant is excluded from the bar: on any real catalogue it is most of
    // the rows, and including it would crush every other segment to a sliver.
    const ordered = [
      'EMERGING',
      'RISING',
      'PEAKING',
      'STEADY',
      'COOLING',
      'DECLINING',
    ];
    final live = {
      for (final key in ordered)
        if ((stages[key] ?? 0) > 0) key: stages[key]!,
    };
    if (live.isEmpty) return const SizedBox.shrink();
    final liveTotal = live.values.fold<int>(0, (sum, count) => sum + count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trendsStageDistribution,
              style: context.dsText.tileTitle.bold.tint(palette.ink),
            ),
            const SizedBox(height: DsSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.xs),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final entry in live.entries)
                      Expanded(
                        flex: entry.value,
                        child: ColoredBox(
                          color: stageColour(
                            context,
                            TrendStage.fromWire(entry.key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              spacing: DsSpacing.md,
              runSpacing: DsSpacing.xs,
              children: [
                for (final entry in live.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: stageColour(
                            context,
                            TrendStage.fromWire(entry.key),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      DsGaps.hXxs,
                      Text(
                        '${entry.value}',
                        style: context.dsText.caption.bold.tint(palette.ink),
                      ),
                      DsGaps.hXxs,
                      Text(
                        _label(context, entry.key),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              l10n.trendsStageScored(liveTotal, total),
              style: context.dsText.caption.tint(palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  String _label(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'EMERGING' => l10n.trendStageEmerging,
      'RISING' => l10n.trendStageRising,
      'PEAKING' => l10n.trendStagePeaking,
      'STEADY' => l10n.trendStageSteady,
      'COOLING' => l10n.trendStageCooling,
      'DECLINING' => l10n.trendStageDeclining,
      _ => l10n.trendStageDormant,
    };
  }
}

class AdminTrendPlatformForecast extends StatelessWidget {
  const AdminTrendPlatformForecast({super.key, required this.forecast});

  final TrendForecast forecast;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trendsForecastUnitsLabel(forecast.horizonDays),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                      Text(
                        formatUnits(forecast.totalUnits),
                        style: context.dsText.screenTitle.bold.tint(palette.ink),
                      ),
                      if (forecast.totalRevenue != null)
                        Text(
                          forecast.totalRevenue!.format(),
                          style: context.dsText.labelMedium.semibold.tint(palette.gold),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TrendSparkline(
                    values: [for (final point in forecast.points) point.units],
                    colour: palette.primary,
                    height: 48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            // The method is shown because the three fallbacks mean genuinely
            // different things, and a seasonal-naive line should not be read
            // with the confidence of a fitted trend.
            Text(
              l10n.trendsForecastMethod(
                forecast.method ?? '—',
                (forecast.confidence * 100).round(),
              ),
              style: context.dsText.caption.tint(palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
