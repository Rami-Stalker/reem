import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../providers/seller_dashboard_provider.dart';
import '../widgets/seller_ai_insights_widget.dart';
import '../widgets/seller_conversion_metrics_widget.dart';
import '../widgets/seller_goals_widget.dart';
import '../widgets/seller_header.dart';
import '../widgets/seller_low_stock.dart';
import '../widgets/seller_mini_chart.dart';
import '../widgets/seller_orders_overview.dart';
import '../widgets/seller_quick_actions.dart';
import '../widgets/seller_recent_reviews_widget.dart';
import '../widgets/seller_revenue_card.dart';
import '../widgets/seller_store_score_widget.dart';
import '../widgets/seller_tasks_widget.dart';
import '../widgets/seller_top_products.dart';

/// The Seller Command Centre — a full-stack business dashboard comparable to
/// Shopify Analytics + Amazon Seller Central + TikTok Shop. Everything a seller
/// needs to understand store health in seconds.
class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(sellerDashboardNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);

    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      slivers: [
        // Floating seller app bar.
        const SellerHeaderSliver(),

        // Error banner.
        if (state.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.md),
              child: DsErrorState(
                icon: Icons.cloud_off_rounded,
                title: 'Dashboard unavailable',
                message: state.error!,
                retryLabel: 'Try again',
                onRetry: () => _refresh(ref),
              ),
            ),
          ),

        // Revenue dashboard — the hero widget.
        _box(const SellerRevenueCard()),
        _gap(DsSpacing.xl),

        // Orders overview.
        _box(const SellerOrdersOverview()),
        _gap(DsSpacing.xl),

        // Sales analytics chart.
        _box(const Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: SellerAnalyticsChart(),
        )),
        _gap(DsSpacing.xl),

        // Quick actions grid.
        _box(const SellerQuickActions()),
        _gap(DsSpacing.xl),

        // Top performing products.
        _box(const SellerTopProducts()),
        _gap(DsSpacing.xl),

        // Low stock alert.
        _box(const SellerLowStockAlert()),
        _gap(DsSpacing.xl),

        // Store performance score.
        _box(const SellerStoreScoreWidget()),
        _gap(DsSpacing.xl),

        // Conversion metrics.
        _box(const SellerConversionMetricsWidget()),
        _gap(DsSpacing.xl),

        // AI business insights.
        _box(const SellerAiInsightsWidget()),
        _gap(DsSpacing.xl),

        // Recent customer reviews.
        _box(const SellerRecentReviewsWidget()),
        _gap(DsSpacing.xl),

        // Tasks requiring attention.
        _box(const SellerTasksWidget()),
        _gap(DsSpacing.xl),

        // Store goals progress.
        _box(const SellerGoalsWidget()),

        // Breathing room for the floating bottom bar.
        _gap(140),
      ],
    );
  }

  static Widget _box(Widget child) => SliverToBoxAdapter(
        child: child
            .animate()
            .fadeIn(duration: 420.ms, curve: Curves.easeOut)
            .slideY(begin: 0.05, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
      );

  static Widget _gap(double h) =>
      SliverToBoxAdapter(child: SizedBox(height: h));
}
