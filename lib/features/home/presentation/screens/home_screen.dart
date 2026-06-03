import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../providers/home_provider.dart';
import '../widgets/category_section.dart';
import '../widgets/coupons_strip.dart';
import '../widgets/discount_banner.dart';
import '../widgets/home_header.dart';
import '../widgets/post_feed.dart';
import '../widgets/product_slider.dart';
import '../widgets/rewards_points_card.dart';
import '../widgets/stories_section.dart';
import '../widgets/trending_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final homeState = ref.watch(homeNotifierProvider);

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.appTitle),
        if (homeState.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DsSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (homeState.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: Text(
                homeState.error!,
                style: TextStyle(color: context.dsColors.error),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, 120,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const HomeHeader(),
              const SizedBox(height: DsSpacing.xl),
              const RewardsPointsCard(),
              const SizedBox(height: DsSpacing.lg),
              const CouponsStrip(),
              const SizedBox(height: DsSpacing.xxl),
              const StoriesSection(),
              const SizedBox(height: DsSpacing.xxl),
              const DiscountBanner(),
              const SizedBox(height: DsSpacing.xxl),
              const CategorySection(),
              const SizedBox(height: DsSpacing.xxl),
              const TrendingSection(),
              const SizedBox(height: DsSpacing.xxl),
              const ProductSlider(),
              const SizedBox(height: DsSpacing.xxl),
              const PostFeed(),
            ]),
          ),
        ),
      ],
    );
  }
}
