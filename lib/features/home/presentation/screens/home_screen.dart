import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/experience/role_experience.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/product/product_rail.dart';
import '../../../discovery/domain/entities/product_collection.dart';
import '../../../experience/presentation/providers/role_experience_provider.dart';
import '../../../experience/presentation/screens/experience_surface_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../seller_dashboard/presentation/screens/seller_home_screen.dart';
import '../providers/home_content_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/feed_section.dart';
import '../widgets/home_categories_showcase.dart';
import '../widgets/home_continue_shopping.dart';
import '../widgets/home_dynamic_blocks.dart';
import '../widgets/home_featured_stores.dart';
import '../widgets/home_flash_deals.dart';
import '../widgets/home_greeting.dart';
import '../widgets/home_hero_carousel.dart';
import '../widgets/home_loyalty_card.dart';
import '../widgets/home_nearby_stores.dart';
import '../widgets/home_notifications_summary.dart';
import '../widgets/home_recently_viewed.dart';
import '../widgets/home_smart_search.dart';
import '../widgets/home_stories_rail.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/home_wishlist_highlights.dart';

/// Role-aware home screen dispatcher — renders [SellerHomeScreen] for sellers
/// and the buyer home feed for customers. Both share the same tab slot so the
/// bottom navigation never changes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(
      roleExperienceProvider.select((experience) => experience.role),
    );
    return switch (role) {
      ExperienceRole.seller => const SellerHomeScreen(),
      ExperienceRole.admin => const ExperienceSurfaceScreen(
        surface: ExperienceSurface.dashboard,
      ),
      ExperienceRole.buyer => const _BuyerHomeScreen(),
    };
  }
}

/// Buyer home — an intelligent, personalized social-commerce experience.
class _BuyerHomeScreen extends ConsumerWidget {
  const _BuyerHomeScreen();

  static const double _gap = DsSpacing.xl;

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(homeContentNotifierProvider.notifier).refresh(),
      ref.read(homeNotifierProvider.notifier).refresh(),
      ref.read(favoritesNotifierProvider.notifier).load(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      slivers: [
        const HomeTopBar(),

        // Greeting + smart search.
        const SliverToBoxAdapter(child: HomeGreeting()),
        const SliverToBoxAdapter(child: HomeSmartSearch()),
        const _Gap(DsSpacing.lg),

        // Stories.
        const HomeStoriesRail(),
        const _Gap(DsSpacing.lg),

        // Dynamic hero carousel.
        _box(const HomeHeroCarousel()),
        const _Gap(_gap),

        // Shop by category.
        _box(const HomeCategoriesShowcase()),
        const _Gap(_gap),

        // Flash deals.
        _box(const HomeFlashDeals()),
        const _Gap(_gap),

        // Loyalty & rewards.
        _box(const HomeLoyaltyCard()),
        const _Gap(_gap),

        // AI-powered recommendations.
        _box(
          const _CollectionRail(
            collection: ProductCollection.recommended,
            eyebrow: 'Picked for you',
            title: 'Recommended for you',
          ),
        ),
        const _Gap(_gap),

        // Continue shopping.
        _box(const HomeContinueShopping()),
        const _Gap(_gap),

        // Admin-configured merchandising.
        _box(const HomeDynamicBlocks()),

        // New arrivals.
        _box(
          const _CollectionRail(
            collection: ProductCollection.newArrivals,
            eyebrow: 'Just in',
            title: 'New arrivals',
          ),
        ),
        const _Gap(_gap),

        // Featured boutiques.
        _box(const HomeFeaturedStores()),
        const _Gap(_gap),

        // Best sellers.
        _box(
          const _CollectionRail(
            collection: ProductCollection.bestSelling,
            eyebrow: 'Loved by many',
            title: 'Best sellers',
          ),
        ),
        const _Gap(_gap),

        // Recently viewed.
        _box(const HomeRecentlyViewed()),
        const _Gap(_gap),

        // Wishlist highlights.
        _box(const HomeWishlistHighlights()),
        const _Gap(_gap),

        // Nearby stores (location-gated).
        _box(const HomeNearbyStores()),
        const _Gap(_gap),

        // Notifications summary.
        _box(const HomeNotificationsSummary()),
        const _Gap(_gap),

        // Social feed preview.
        const FeedSection(),

        // Breathing room above the floating bottom bar.
        const _Gap(120),
      ],
    );
  }

  /// Wraps a box section in a sliver with a gentle entrance reveal.
  static Widget _box(Widget child) {
    return SliverToBoxAdapter(
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
}

/// A single product-collection rail bound to its own slice of home state, so it
/// rebuilds independently as that collection loads.
class _CollectionRail extends ConsumerWidget {
  const _CollectionRail({
    required this.collection,
    required this.title,
    this.eyebrow,
  });

  final ProductCollection collection;
  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(
      homeNotifierProvider.select((s) => s.sectionOf(collection)),
    );

    return ProductRail(
      eyebrow: eyebrow,
      title: title,
      products: section.products,
      isLoading: section.isLoading && !section.hasItems,
      onSeeAll: () => context.push(RoutePaths.collectionOf(collection.key)),
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
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
