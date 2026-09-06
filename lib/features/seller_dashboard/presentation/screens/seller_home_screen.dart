import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/market/presentation/widgets/market_entry_card.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_ai_insights_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_attention_strip.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_conversion_metrics_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_goals_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_header.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_low_stock.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_orders_overview.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_quick_actions.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_recent_reviews_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_revenue_card.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_sales_chart.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_store_score_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_tasks_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_top_products.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_entry_card.dart';

/// The seller's command centre.
///
/// The page is ordered the way a shopkeeper's morning goes, not the way the
/// data model is shaped. It used to be twelve panels of equal weight, so
/// finding out whether anything was on fire meant reading all of them.
///
/// **Act** — what is waiting on her, and the shortcuts that clear it.
/// **Measure** — the money, the trend, the order pipeline.
/// **Steer** — what is selling, what is running out.
/// **Grow** — store health, funnel, insights, reviews, tasks, goals.
///
/// Everything reads from the atelier palette, so the dashboard is legible in
/// dark mode instead of painting white cards on aubergine.
/// Anchors the tasks panel so the attention strip can bring it into view.
///
/// The strip's "open tasks" alert had `onTap: null` while the list it counts
/// sits further down this same page — the one alert of the three that led
/// nowhere. Scrolling to it is the honest destination; there is no separate
/// tasks screen to push.
final GlobalKey _tasksSectionKey = GlobalKey();

class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  static const double _gap = DsSpacing.xl;

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(sellerDashboardNotifierProvider.notifier).refresh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(
      sellerDashboardNotifierProvider.select((s) => s.error),
    );
    final l10n = context.l10n;

    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      background: const SellerAtelierBackground(),
      backgroundColor: context.dsColors.background,
      slivers: [
        const SellerHeaderSliver(),

        if (error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.xxxs,
                DsSpacing.lg,
                DsSpacing.md,
              ),
              child: DsErrorState(
                icon: Icons.cloud_off_rounded,
                title: l10n.sellerDashboardUnavailable,
                message: error.resolve(l10n),
                retryLabel: l10n.retry,
                onRetry: () => _refresh(ref),
              ),
            ),
          ),

        // ── Act ──────────────────────────────────────────────────────────
        _box(
          SellerAttentionStrip(
            onOpenTasks: () {
              final target = _tasksSectionKey.currentContext;
              if (target == null) return;
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                alignment: 0.1,
              );
            },
          ),
        ),
        const _Gap(_gap),

        _box(const SellerQuickActions()),
        const _Gap(_gap),

        // ── Measure ──────────────────────────────────────────────────────
        const _Rule(),
        _box(const SellerRevenueCard()),
        const _Gap(_gap),

        _box(const SellerSalesChart()),
        const _Gap(_gap),

        _box(const SellerOrdersOverview()),
        const _Gap(_gap),

        // ── Steer ────────────────────────────────────────────────────────
        const _Rule(),
        _box(const SellerTopProducts()),
        const _Gap(_gap),

        _box(const SellerLowStockAlert()),
        const _Gap(_gap),

        // ── Grow ─────────────────────────────────────────────────────────
        const _Rule(),
        // Phase two's way in. Placed at the head of Grow because that is what
        // it is for, and above the older store-score widget because it is the
        // measured version of the same idea.
        _box(const IntelligenceEntryCard()),
        const _Gap(_gap),

        // Phase four, directly under it: the same idea widened from her own
        // shop to the market around it.
        _box(const SellerMarketEntryCard()),
        const _Gap(_gap),

        _box(const SellerStoreScoreWidget()),
        const _Gap(_gap),

        _box(const SellerConversionMetricsWidget()),
        const _Gap(_gap),

        _box(const SellerAiInsightsWidget()),
        const _Gap(_gap),

        _box(const SellerRecentReviewsWidget()),
        const _Gap(_gap),

        _box(SellerTasksWidget(key: _tasksSectionKey)),
        const _Gap(_gap),

        _box(const SellerGoalsWidget()),

        // Breathing room above the floating bottom bar.
        const _Gap(140),
      ],
    );
  }

  static Widget _box(Widget child) => SliverToBoxAdapter(
    child: child
        .animate()
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        ),
  );
}

/// A hairline between chapters — quieter than the buyer's sparkle divider,
/// because a workroom does not need ornament to know where it is.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.xxxs,
          DsSpacing.lg,
          DsSpacing.xl,
        ),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.line.withValues(alpha: 0),
                palette.line,
                palette.line.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap(this.height);

  final double height;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: SizedBox(height: height));
}
