import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/presentation/providers/trends_providers.dart';
import 'package:ohara/features/trends/presentation/widgets/admin_trend_panels.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_cards.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_pieces.dart';

/// The market, from the platform's chair.
///
/// Where the seller's page answers "what should I do about my products", this
/// one answers "what is happening to demand" — a question asked a level up, at
/// a category, a colour, a price band, a search nobody could answer.
///
/// The order is the argument again: **opportunities first**, because a gap in
/// the assortment is the only thing on this page that turns directly into
/// revenue; then the shape of demand; then the products at each end of the
/// curve; then the operational panels.
class AdminTrendsScreen extends ConsumerWidget {
  const AdminTrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminTrendsNotifierProvider);
    final notifier = ref.read(adminTrendsNotifierProvider.notifier);
    final l10n = context.l10n;
    final overview = state.overview;

    return OharaScrollPage(
      onRefresh: notifier.refresh,
      background: const AdminConsoleBackground(),
      backgroundColor: context.console.background,
      slivers: [
        // The console's sky, as on every page under the rail. The trend cards
        // below are the seller's own, shared with her trends page.
        SliverToBoxAdapter(
          child: AdminPageHeader(
            title: l10n.trendsAdminTitle,
            icon: Icons.auto_graph_rounded,
            actions: [
              IconButton(
                tooltip: l10n.trendsRecompute,
                onPressed: state.isRecomputing ? null : notifier.recompute,
                icon: state.isRecomputing
                    ? const DsLoadingIndicator.inline()
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: TrendWindowBar(
            selected: state.window,
            onSelect: notifier.setWindow,
          ),
        ),

        if (state.isInitialLoading)
          const SliverToBoxAdapter(child: AdminTrendSkeleton())
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
          const SliverToBoxAdapter(child: AdminTrendWaitingForData())
        else
          ..._body(context, state, overview, notifier),

        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    AdminTrendsState state,
    AdminTrendOverview overview,
    AdminTrendsNotifier notifier,
  ) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return [
      // ── Where the money is not being made ──────────────────────────────
      if (state.opportunities.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsOpportunities,
            hint: l10n.trendsOpportunitiesHint,
          ),
        ),
        SliverList.builder(
          itemCount: state.opportunities.length,
          itemBuilder: (context, index) => AdminTrendOpportunityCard(
            opportunity: state.opportunities[index],
          ),
        ),
      ],

      // ── Overall ────────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: TrendSectionHeader(
          l10n.trendsOverall,
          hint: l10n.trendsOverallHint,
        ),
      ),
      SliverToBoxAdapter(
        child: TrendMetricGrid(
          tiles: [
            TrendMetricTile(
              label: l10n.trendViews,
              value: formatCount(overview.headline.views),
              delta: overview.headline.viewsGrowthPct,
            ),
            TrendMetricTile(
              label: l10n.trendSearches,
              value: formatCount(overview.headline.searches),
              delta: overview.headline.searchGrowthPct,
            ),
            TrendMetricTile(
              label: l10n.trendCartAdds,
              value: formatCount(overview.headline.cartAdds),
              delta: overview.headline.cartGrowthPct,
            ),
            TrendMetricTile(
              label: l10n.trendOrders,
              value: formatCount(overview.headline.orders),
              delta: overview.headline.ordersGrowthPct,
            ),
            TrendMetricTile(
              label: l10n.trendRevenue,
              value: formatMoney(overview.headline.revenue),
              delta: overview.headline.revenueGrowthPct,
              tone: palette.gold,
            ),
            TrendMetricTile(
              label: l10n.trendConversion,
              value: formatRate(overview.headline.cartToOrderRate),
              hint: l10n.trendViewToCart(
                formatRate(overview.headline.viewToCartRate),
              ),
            ),
          ],
        ),
      ),

      if (overview.series.length >= 2)
        SliverToBoxAdapter(
          child: AdminTrendDemandChart(series: overview.series),
        ),

      SliverToBoxAdapter(
        child: AdminTrendStageDistribution(stages: overview.headline.stages),
      ),

      // ── Forecast ───────────────────────────────────────────────────────
      if (overview.forecast.hasData) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsDemandForecast,
            hint: l10n.trendsDemandForecastHint,
          ),
        ),
        SliverToBoxAdapter(
          child: AdminTrendPlatformForecast(forecast: overview.forecast),
        ),
      ],

      // ── Categories ─────────────────────────────────────────────────────
      if (overview.categoryTrends.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsCategories,
            hint: l10n.trendsCategoriesHint,
          ),
        ),
        SliverToBoxAdapter(
          child: AdminTrendCategoryList(categories: overview.categoryTrends),
        ),
      ],

      // ── Colours and price bands ────────────────────────────────────────
      if (overview.colourTrends.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsColours,
            hint: l10n.trendsColoursHint,
          ),
        ),
        SliverToBoxAdapter(
          child: AdminTrendShareList(rows: overview.colourTrends),
        ),
      ],

      if (overview.priceTrends.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsPriceBands,
            hint: l10n.trendsPriceBandsHint,
          ),
        ),
        SliverToBoxAdapter(
          child: AdminTrendShareList(rows: overview.priceTrends),
        ),
      ],

      // ── The two ends of the curve ──────────────────────────────────────
      if (overview.emergingProducts.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsEmerging,
            hint: l10n.trendsEmergingHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.emergingProducts.length,
          itemBuilder: (context, index) =>
              AdminTrendProductTile(product: overview.emergingProducts[index]),
        ),
      ],

      if (overview.decliningProducts.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsDeclining,
            hint: l10n.trendsDecliningHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.decliningProducts.length,
          itemBuilder: (context, index) =>
              AdminTrendProductTile(product: overview.decliningProducts[index]),
        ),
      ],

      // ── Search intelligence ────────────────────────────────────────────
      if (overview.unmetDemand.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsUnmetDemand,
            hint: l10n.trendsUnmetDemandHint,
            trailing: overview.unmetDemandTotal > overview.unmetDemand.length
                ? Text(
                    l10n.trendsOfTotal(overview.unmetDemandTotal),
                    style: context.dsText.caption.tint(palette.muted),
                  )
                : null,
          ),
        ),
        SliverList.builder(
          itemCount: overview.unmetDemand.length,
          itemBuilder: (context, index) => UnmetDemandCard(
            signal: overview.unmetDemand[index],
            onReview: (status) => notifier.reviewUnmetDemand(
              overview.unmetDemand[index].id,
              status,
            ),
          ),
        ),
      ],

      if (overview.searchTrends.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsSearches,
            hint: l10n.trendsSearchesHint,
          ),
        ),
        SliverToBoxAdapter(
          child: AdminTrendSearchList(terms: overview.searchTrends),
        ),
      ],

      // ── Sellers ────────────────────────────────────────────────────────
      if (state.sellers.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsSellerPerformance,
            hint: l10n.trendsSellerPerformanceHint,
          ),
        ),
        SliverToBoxAdapter(child: AdminTrendSellerList(sellers: state.sellers)),
      ],

      // ── Insights ───────────────────────────────────────────────────────
      if (overview.insights.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: TrendSectionHeader(
            l10n.trendsMarketInsights,
            hint: l10n.trendsMarketInsightsHint,
          ),
        ),
        SliverList.builder(
          itemCount: overview.insights.length,
          itemBuilder: (context, index) {
            final insight = overview.insights[index];
            return TrendInsightCard(
              insight: insight,
              onAcknowledge: () =>
                  notifier.updateInsight(insight.id, InsightStatus.actioned),
              onDismiss: () =>
                  notifier.updateInsight(insight.id, InsightStatus.dismissed),
            );
          },
        ),
      ],

      SliverToBoxAdapter(child: AdminTrendAsOfFooter(asOf: overview.asOf)),
    ];
  }
}
