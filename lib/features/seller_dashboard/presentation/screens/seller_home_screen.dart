import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/market/presentation/widgets/market_entry_card.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_ai_insights_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_bench.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_conversion_metrics_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_goals_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_header.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_recent_reviews_widget.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_store_score_widget.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_entry_card.dart';

/// The seller's home: **behind the counter of her boutique**.
///
/// Not a reporting dashboard, and not a tailor's bench either: a seller on
/// Reem may sell perfume, flowers, jewellery, make-up or clothes, so the page
/// is drawn from what every women's shop shares. It opens on a length of plum
/// satin saying good morning to her shop by name, with today's takings set
/// large and the month's goal as Reem's arch filling with gold. Then the one
/// thing to do first, and the few after it; the order path, the stages
/// waiting on her lit in gold; her tools as pearl buttons; the shelf of what
/// sells and what is running out, each piece with a gift tag; and the rhythm
/// of sales as a satin ribbon.
///
/// The older panels (store health, funnel, insights, reviews, goals) follow
/// under «المزيد عن متجركِ»: still there, no longer in the way.
class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(sellerDashboardNotifierProvider.notifier).refresh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(
      sellerDashboardNotifierProvider.select((s) => s.error),
    );
    final l10n = context.l10n;
    final gutter = benchGutter(context);

    // A gutter-wide section of the bench, entering with the shared rise.
    Widget section(int index, Widget child) => SliverToBoxAdapter(
      child: DsStaggerAnimations.item(
        index: index,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );

    // The shelf scrolls to the screen's edge, so it pads itself.
    Widget fullBleed(int index, Widget child) => SliverToBoxAdapter(
      child: DsStaggerAnimations.item(index: index, child: child),
    );

    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      background: const SellerAtelierBackground(),
      backgroundColor: context.dsColors.background,
      slivers: [
        const SellerHeaderSliver(),

        if (error != null)
          section(
            0,
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.md),
              child: DsErrorState(
                icon: Icons.cloud_off_rounded,
                title: l10n.sellerDashboardUnavailable,
                message: error.resolve(l10n),
                retryLabel: l10n.retry,
                onRetry: () => _refresh(ref),
              ),
            ),
          ),

        section(0, const BenchHero()),
        const _Gap(),
        section(1, const BenchFirstThing()),
        const _Gap(),
        section(2, const BenchOrderPath()),
        const _Gap(),
        section(3, const BenchTools()),
        const _Gap(),
        fullBleed(4, const BenchShelf()),
        const _Gap(),
        section(5, const BenchSalesRhythm()),
        const _Gap(),

        // ── More about her shop ──────────────────────────────────────────
        section(6, AtelierHeading(title: l10n.sellerBenchMoreTitle)),
        const _Gap(small: true),
        // The other widgets carry their own side padding.
        const _More(child: IntelligenceEntryCard()),
        const _More(child: SellerMarketEntryCard()),
        const _More(child: SellerStoreScoreWidget()),
        const _More(child: SellerConversionMetricsWidget()),
        const _More(child: SellerAiInsightsWidget()),
        const _More(child: SellerRecentReviewsWidget()),
        const _More(child: SellerGoalsWidget()),

        // Breathing room above the floating bottom bar.
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _More extends StatelessWidget {
  const _More({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xl),
      child: child,
    ),
  );
}

class _Gap extends StatelessWidget {
  const _Gap({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: small ? DsGaps.vLg : DsGaps.vXxl);
}
