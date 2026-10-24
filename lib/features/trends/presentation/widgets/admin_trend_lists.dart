import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_pieces.dart';

/// The panels of the market intelligence page.
///
/// Split out of the screen so the screen reads as an argument about order —
/// opportunities, then demand, then the ends of the curve — rather than as
/// a thousand lines of chart code with a narrative buried in it.

/// The tabular panels: categories, facet shares, search terms and
/// sellers — plus the two states the page can be in with no data.

// ── Lists ────────────────────────────────────────────────────────────────

class AdminTrendCategoryList extends StatelessWidget {
  const AdminTrendCategoryList({super.key, required this.categories});

  final List<CategoryTrend> categories;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.xs,
        ),
        child: Column(
          children: [
            for (var i = 0; i < categories.length; i += 1) ...[
              if (i > 0) Divider(height: 1, color: palette.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        categories[i].score.round().toString(),
                        style: context.dsText.tileTitle.displayFamily.bold.tint(stageColour(
                            context,
                            categories[i].stage.stage,
                          )),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categories[i].nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.bodySmall.semibold.tint(palette.ink),
                          ),
                          Text(
                            l10n.trendsCategorySupply(
                              categories[i].inStockProducts,
                              categories[i].liveProducts,
                            ),
                            style: context.dsText.caption.tint(categories[i].inStockRate < 0.6
                                  ? palette.caution
                                  : palette.muted),
                          ),
                        ],
                      ),
                    ),
                    TrendStageChip(categories[i].stage, compact: true),
                    const SizedBox(width: DsSpacing.xs),
                    TrendDelta(
                      value: categories[i].viewsGrowthPct,
                      suffix: '%',
                      fontSize: DsTypography.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminTrendShareList extends StatelessWidget {
  const AdminTrendShareList({super.key, required this.rows});

  final List<AttributeTrend> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final series = palette.series;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i += 1)
              TrendShareBar(
                label: rows[i].labelAr,
                sharePct: rows[i].sharePct,
                previousSharePct: rows[i].previousSharePct,
                colour: series[i % series.length],
              ),
          ],
        ),
      ),
    );
  }
}

class AdminTrendSearchList extends StatelessWidget {
  const AdminTrendSearchList({super.key, required this.terms});

  final List<SearchTermTrend> terms;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.xs,
        ),
        child: Column(
          children: [
            for (var i = 0; i < terms.length; i += 1) ...[
              if (i > 0) Divider(height: 1, color: palette.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            terms[i].display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.bodySmall.semibold.tint(palette.ink),
                          ),
                          if (terms[i].facetsAr.isNotEmpty)
                            Text(
                              terms[i].facetsAr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.caption.tint(palette.muted),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCount(terms[i].searches),
                          style: context.dsText.bodySmall.bold.tint(palette.ink),
                        ),
                        // The miss rate is what separates a popular search
                        // from a hole in the assortment.
                        Text(
                          l10n.trendsMissRate(
                            (terms[i].missRate * 100).round(),
                          ),
                          style: context.dsText.caption.tint(terms[i].missRate > 0.4
                                ? palette.critical
                                : palette.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminTrendSellerList extends StatelessWidget {
  const AdminTrendSellerList({super.key, required this.sellers});

  final List<SellerPerformanceRow> sellers;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.xs,
        ),
        child: Column(
          children: [
            for (var i = 0; i < sellers.length; i += 1) ...[
              if (i > 0) Divider(height: 1, color: palette.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellers[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.bodySmall.semibold.tint(palette.ink),
                          ),
                          // Cancellation and return rates sit beside the
                          // growth on purpose: doubling units while a fifth
                          // come back is not the same story as doubling
                          // cleanly, and a leaderboard that shows only the
                          // first number rewards the wrong behaviour.
                          Text(
                            l10n.trendsSellerQuality(
                              (sellers[i].cancelRate * 100).round(),
                              (sellers[i].returnRate * 100).round(),
                            ),
                            style: context.dsText.caption.tint(sellers[i].cancelRate > 0.12
                                  ? palette.caution
                                  : palette.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMoney(sellers[i].revenue),
                          style: context.dsText.bodySmall.bold.tint(palette.ink),
                        ),
                        TrendDelta(
                          value: sellers[i].revenueGrowthPct,
                          suffix: '%',
                          fontSize: DsTypography.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────

class AdminTrendWaitingForData extends StatelessWidget {
  const AdminTrendWaitingForData({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.query_stats_rounded, size: 44, color: palette.primarySoft),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.trendsAdminEmptyTitle,
            textAlign: TextAlign.center,
            style: context.dsText.tileTitle.displayFamily.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.trendsAdminEmptyBody,
            textAlign: TextAlign.center,
            style: context.dsText.bodySmall.tint(palette.muted).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class AdminTrendAsOfFooter extends StatelessWidget {
  const AdminTrendAsOfFooter({super.key, required this.asOf});

  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final date =
        '${asOf.year}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xl,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: Text(
        l10n.trendsAsOf(date),
        textAlign: TextAlign.center,
        style: context.dsText.caption.tint(palette.muted),
      ),
    );
  }
}

class AdminTrendSkeleton extends StatelessWidget {
  const AdminTrendSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 5; i += 1)
              const Padding(
                padding: EdgeInsets.only(bottom: DsSpacing.sm),
                child: DsSkeleton(height: 88, borderRadius: DsRadius.lg),
              ),
          ],
        ),
      ),
    );
  }
}
