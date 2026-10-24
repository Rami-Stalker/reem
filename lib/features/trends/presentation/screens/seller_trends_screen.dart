import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/presentation/providers/trends_providers.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_cards.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_pieces.dart';

/// The seller's Trend Engine.
///
/// The page is ordered the way a shopkeeper actually asks: **what should I do
/// today** (the recommended actions), then *what is climbing*, then *what is
/// wrong*, then *what will I sell*, and only then the underlying figures. An
/// analytics page that opens on a chart is asking her to do the analysis; this
/// one opens on the conclusion and keeps the working underneath it.
///
/// It sits beside `SellerAnalyticsScreen` rather than replacing it. That one
/// answers "what happened" — revenue, orders, cohorts. This one answers "what
/// is about to happen", which is a different question and the reason the whole
/// engine exists.
class SellerTrendsScreen extends ConsumerWidget {
  const SellerTrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerTrendsNotifierProvider);
    final notifier = ref.read(sellerTrendsNotifierProvider.notifier);
    final l10n = context.l10n;
    final overview = state.overview;

    return OharaScrollPage(
      onRefresh: notifier.refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.auto_graph_rounded,
          title: l10n.trendsSellerTitle,
        ),
        // Air between the banner and the page.
        DsGaps.sliverMd,
        SliverToBoxAdapter(
          child: TrendWindowBar(
            selected: state.window,
            onSelect: notifier.setWindow,
          ),
        ),

        if (state.isInitialLoading)
          const SliverToBoxAdapter(child: _Skeleton())
        else if (overview == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: state.error ?? l10n.trendsFailed,
                onRetry: notifier.refresh,
              ),
            ),
          )
        else if (overview.isEmpty)
          const SliverToBoxAdapter(child: _WaitingForData())
        else
          ..._body(context, overview, state, notifier),

        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    SellerTrendOverview overview,
    SellerTrendsState state,
    SellerTrendsNotifier notifier,
  ) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return [
      // ── What to do today ───────────────────────────────────────────────
      if (overview.recommendedActions.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsRecommendedActions,
            hint: l10n.trendsRecommendedActionsHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.recommendedActions.length,
          itemBuilder: (context, index) {
            final insight = overview.recommendedActions[index];
            return TrendInsightCard(
              insight: insight,
              isBusy: state.busyInsightId == insight.id,
              onAcknowledge: () =>
                  notifier.updateInsight(insight.id, InsightStatus.actioned),
              onDismiss: () =>
                  notifier.updateInsight(insight.id, InsightStatus.dismissed),
            );
          },
        ),
      ],

      // ── Demand, separately from sales ──────────────────────────────────
      SliverToBoxAdapter(
        child: TrendSectionHeader(
          l10n.trendsDemandSignals,
          hint: l10n.trendsDemandSignalsHint,
        ),
      ),
      SliverToBoxAdapter(
        child: TrendMetricGrid(
          tiles: [
            TrendMetricTile(
              label: l10n.trendViews,
              value: formatCount(overview.demandSignals.views),
              delta: _growthPct(
                overview.demandSignals.views,
                overview.demandSignals.previousViews,
              ),
            ),
            TrendMetricTile(
              label: l10n.trendSearchHits,
              value: formatCount(overview.demandSignals.searchHits),
            ),
            TrendMetricTile(
              label: l10n.trendCartAdds,
              value: formatCount(overview.demandSignals.cartAdds),
            ),
            TrendMetricTile(
              label: l10n.trendFavorites,
              value: formatCount(overview.demandSignals.favorites),
            ),
            TrendMetricTile(
              label: l10n.trendUnitsSold,
              value: formatCount(overview.headline.units),
              delta: _growthPct(
                overview.headline.units,
                overview.headline.previousUnits,
              ),
              tone: palette.primary,
            ),
            TrendMetricTile(
              label: l10n.trendAverageScore,
              value: overview.headline.averageScore.toStringAsFixed(0),
              hint: l10n.trendRisingCount(overview.headline.risingProducts),
            ),
          ],
        ),
      ),

      // ── The forecast ───────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: TrendSectionHeader(
          l10n.trendsForecast,
          hint: l10n.trendsForecastHint,
        ),
      ),
      SliverToBoxAdapter(child: _ForecastPanel(forecast: overview.forecast)),

      // ── What is climbing ───────────────────────────────────────────────
      if (overview.emerging.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsEmerging,
            hint: l10n.trendsEmergingHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.emerging.length,
          itemBuilder: (context, index) =>
              SellerTrendProductCard(product: overview.emerging[index]),
        ),
      ],

      if (overview.trending.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsTrending,
            hint: l10n.trendsTrendingHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.trending.length,
          itemBuilder: (context, index) =>
              SellerTrendProductCard(product: overview.trending[index]),
        ),
      ],

      // ── What is wrong ──────────────────────────────────────────────────
      if (overview.stockOpportunities.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsStockOpportunities,
            hint: l10n.trendsStockOpportunitiesHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.stockOpportunities.length,
          itemBuilder: (context, index) => SellerTrendProductCard(
            product: overview.stockOpportunities[index],
          ),
        ),
      ],

      if (overview.lowConversion.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsLowConversion,
            hint: l10n.trendsLowConversionHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.lowConversion.length,
          itemBuilder: (context, index) =>
              SellerTrendProductCard(product: overview.lowConversion[index]),
        ),
      ],

      SliverToBoxAdapter(child: _AsOfFooter(asOf: overview.asOf)),
    ];
  }

  /// The same smoothed percentage the server prints, so the app's own deltas
  /// cannot disagree with the ones inside an insight's sentence.
  double _growthPct(int current, int previous) {
    if (current == 0 && previous == 0) return 0;
    final ratio = (current + 1) / (previous + 1);
    return ((ratio - 1) * 100).clamp(-99, 999);
  }
}

// ── Forecast panel ───────────────────────────────────────────────────────

/// How much she will sell, with how much to believe it.
///
/// The confidence is on the face of the panel rather than buried, and an
/// `INSUFFICIENT_DATA` forecast says so in words instead of drawing a
/// confident line through zero. A forecast presented with more authority than
/// it has costs a seller real money in stock.
class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({required this.forecast});

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
            if (!forecast.hasData)
              Row(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 16,
                    color: palette.muted,
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.trendsForecastInsufficient,
                      style: context.dsText.bodySmall.tint(palette.muted).copyWith(height: 1.5),
                    ),
                  ),
                ],
              )
            else ...[
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
                        DsGaps.vXxxs,
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
                      values: [
                        for (final point in forecast.points) point.units,
                      ],
                      colour: palette.primary,
                      height: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.sm),
              _ConfidenceBar(confidence: forecast.confidence),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final colour = confidence >= 0.6
        ? palette.positive
        : (confidence >= 0.35 ? palette.caution : palette.critical);

    return Row(
      children: [
        Text(
          l10n.trendConfidence,
          style: context.dsText.caption.tint(palette.muted),
        ),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: DsMeter(
            value: confidence.clamp(0, 1),
            weight: DsMeterWeight.regular,
            color: colour,
            track: palette.line,
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        Text(
          '${(confidence * 100).round()}%',
          style: context.dsText.caption.bold.tint(colour),
        ),
      ],
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────

/// The engine has run and has nothing to say yet.
///
/// A distinct state from a failure, and worded as one: a new seller with three
/// days of history has done nothing wrong, and an error card would tell her
/// she had.
class _WaitingForData extends StatelessWidget {
  const _WaitingForData();

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.insights_rounded, size: 44, color: palette.primarySoft),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.trendsEmptyTitle,
            textAlign: TextAlign.center,
            style: context.dsText.tileTitle.displayFamily.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.trendsEmptyBody,
            textAlign: TextAlign.center,
            style: context.dsText.bodySmall.tint(palette.muted).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// When the figures were computed.
///
/// Stated rather than implied, because the engine has one opinion a day: a
/// seller who refreshes at noon and sees the same numbers should know that is
/// correct rather than broken.
class _AsOfFooter extends StatelessWidget {
  const _AsOfFooter({required this.asOf});

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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 4; i += 1)
              const Padding(
                padding: EdgeInsets.only(bottom: DsSpacing.sm),
                child: DsSkeleton(height: 96, borderRadius: DsRadius.lg),
              ),
          ],
        ),
      ),
    );
  }
}
