import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../providers/seller_dashboard_provider.dart';
import '../widgets/seller_ai_insights_widget.dart';
import '../widgets/seller_financial_widget.dart';
import '../widgets/seller_goals_widget.dart';
import '../widgets/seller_profile_menu.dart';
import '../widgets/seller_store_header.dart';
import '../widgets/seller_store_score_widget.dart';
import '../widgets/seller_store_stats.dart';

/// The Seller Store Management Profile — a complete store operations hub with
/// store information, statistics, financial centre, performance, and settings.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(sellerDashboardNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      slivers: [
        // Cover + logo + store info header.
        const SellerStoreHeader(),

        // Store stats (revenue, orders, products, followers).
        _box(const SellerStoreStats()),
        _gap(DsSpacing.xl),

        // Revenue / withdrawal centre.
        _box(const SellerFinancialWidget()),
        _gap(DsSpacing.xl),

        // Store performance score.
        _box(const SellerStoreScoreWidget()),
        _gap(DsSpacing.xl),

        // Goals.
        _box(const SellerGoalsWidget()),
        _gap(DsSpacing.xl),

        // AI insights (brief preview).
        _box(const SellerAiInsightsWidget()),
        _gap(DsSpacing.xl),

        // Settings menu.
        _box(const SellerProfileMenu()),
        _gap(DsSpacing.xl),

        // Footer.
        const SliverToBoxAdapter(child: _VersionFooter()),
        _gap(140),
      ],
    );
  }

  static Widget _box(Widget child) => SliverToBoxAdapter(
        child: child
            .animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
      );

  static Widget _gap(double h) =>
      SliverToBoxAdapter(child: SizedBox(height: h));
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Center(
      child: Column(
        children: [
          Text(
            'REEM',
            style: TextStyle(
              fontFamily: DsTypography.fontFamilyDisplay,
              fontFamilyFallback: DsTypography.displayFallback,
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: c.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Seller Platform · Version 1.0.0',
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
