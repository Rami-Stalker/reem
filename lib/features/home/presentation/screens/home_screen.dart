import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/experience/role_experience.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/product/product_rail.dart';
import '../../../discovery/domain/entities/product_collection.dart';
import '../../../experience/presentation/providers/role_experience_provider.dart';
import '../../../experience/presentation/screens/experience_surface_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../seller_dashboard/presentation/screens/seller_home_screen.dart';
import '../providers/home_content_provider.dart';
import '../providers/home_provider.dart';
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
import '../widgets/home_showcase_section.dart';
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

/// Buyer home, read as a magazine in three chapters.
///
/// **The welcome** — greeting, search, the boutiques' stories and the banner:
/// who she is and what the shops posted today. **The shelves** — deals,
/// loyalty, the collection rails and the boutiques: the merchandising middle,
/// scanned rather than dwelt in. **New in** — the showcase, where the newest
/// pieces are told as posts (or, if she prefers, as a mosaic or a grid).
///
/// The showcase closes the page deliberately. It is the section she is meant
/// to sink into, and putting it last gives it no floor: the feed simply keeps
/// going, where a middle placement would have capped it at a handful of cards
/// before the next shelf interrupted.
///
/// The running order still honours the client's Q78 pick — *«مختلط: ستوريات
/// فوق + بانر + شبكة منتجات تحت»*.
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
    final l10n = context.l10n;

    return ReemScrollPage(
      onRefresh: () => _refresh(ref),
      slivers: [
        const HomeTopBar(),

        // ── Chapter one: the welcome ─────────────────────────────────────
        const SliverToBoxAdapter(child: HomeGreeting()),
        const SliverToBoxAdapter(child: HomeSmartSearch()),
        const _Gap(DsSpacing.lg),

        const HomeStoriesRail(),
        const _Gap(DsSpacing.lg),

        _box(const HomeHeroCarousel()),
        const _Gap(_gap),

        _box(const HomeCategoriesShowcase()),
        const _Gap(_gap),

        // ── Chapter two: the shelves ─────────────────────────────────────
        const _Ornament(),
        _box(const HomeFlashDeals()),
        const _Gap(_gap),

        // Admin-configured merchandising.
        _box(const HomeDynamicBlocks()),

        _box(const HomeLoyaltyCard()),
        const _Gap(_gap),

        _box(
          _CollectionRail(
            collection: ProductCollection.recommended,
            eyebrow: l10n.homeRecommendedEyebrow,
            title: l10n.recommended,
          ),
        ),
        const _Gap(_gap),

        _box(const HomeContinueShopping()),
        const _Gap(_gap),

        _box(
          _CollectionRail(
            collection: ProductCollection.newArrivals,
            eyebrow: l10n.homeNewArrivalsEyebrow,
            title: l10n.newArrivals,
          ),
        ),
        const _Gap(_gap),

        _box(const HomeFeaturedStores()),
        const _Gap(_gap),

        _box(
          _CollectionRail(
            collection: ProductCollection.bestSelling,
            eyebrow: l10n.homeBestSellersEyebrow,
            title: l10n.bestSeller,
          ),
        ),
        const _Gap(_gap),

        _box(const HomeRecentlyViewed()),
        const _Gap(_gap),

        _box(const HomeWishlistHighlights()),
        const _Gap(_gap),

        _box(const HomeNearbyStores()),
        const _Gap(_gap),

        _box(const HomeNotificationsSummary()),
        const _Gap(_gap),

        // ── Chapter three: "New in" closes the page, and owns it ─────────
        //
        // The finale rather than an aperitif: everything above is a shelf she
        // scans, this is the one she stays in. Ending here also means the feed
        // has no floor — she can keep scrolling posts for as long as she likes
        // instead of hitting another section.
        const _Ornament(),
        const HomeShowcaseSection(),

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

/// The visual full stop between chapters.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: DsOrnamentDivider());
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
