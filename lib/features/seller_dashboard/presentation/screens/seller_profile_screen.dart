import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/highlights/presentation/widgets/highlights_rail.dart';
import 'package:ohara/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_ai_insights_widget.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_financial_widget.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_goals_widget.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_profile_menu.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_store_header.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_store_score_widget.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_store_stats.dart';

/// The seller's store profile — who the shop is, what it has earned, how it is
/// performing, and every setting that governs it.
///
/// The page used to fall through to [OharaScrollPage]'s default ground, which
/// is the buyer's blush silk: a seller opened her own store settings and found
/// herself standing on the customer's carpet. It now paints the atelier.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(sellerDashboardNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OharaScrollPage(
      onRefresh: () => _refresh(ref),
      background: const SellerAtelierBackground(),
      backgroundColor: context.dsColors.background,
      slivers: [
        // Cover + logo + store info header.
        const SellerStoreHeader(),

        // «الأبرز» — the stories she chose to keep. Directly under the
        // header, because it is part of what the storefront *is*: the size
        // guide, the fabric close-ups, the deliveries that went well.
        const SliverToBoxAdapter(child: HighlightsRail()),

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

  /// Kept in one place so the footer and the About sheet cannot drift apart.
  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Center(
      child: Column(
        children: [
          OharaWordmark(
            semanticLabel: context.l10n.appTitle,
            size: OharaWordmarkSize.footer,
            color: palette.muted,
          ),
          DsGaps.vXxxs,
          Text(
            context.l10n.sellerPlatformFooter(_version),
            style: context.dsText.caption.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}
