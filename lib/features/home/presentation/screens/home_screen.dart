import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_categories_showcase.dart';
import 'package:reem/features/home/presentation/widgets/home_continue_shopping.dart';
import 'package:reem/features/home/presentation/widgets/home_dynamic_blocks.dart';
import 'package:reem/features/home/presentation/widgets/home_featured_stores.dart';
import 'package:reem/features/home/presentation/widgets/home_flash_deals.dart';
import 'package:reem/features/home/presentation/widgets/home_greeting.dart';
import 'package:reem/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:reem/features/home/presentation/widgets/home_loyalty_card.dart';
import 'package:reem/features/home/presentation/widgets/home_nearby_stores.dart';
import 'package:reem/features/home/presentation/widgets/home_notifications_summary.dart';
import 'package:reem/features/home/presentation/widgets/home_recently_viewed.dart';
import 'package:reem/features/home/presentation/widgets/home_showcase_section.dart';
import 'package:reem/features/home/presentation/widgets/home_smart_search.dart';
import 'package:reem/features/home/presentation/widgets/home_stories_rail.dart';
import 'package:reem/features/home/presentation/widgets/home_stylist_entry.dart';
import 'package:reem/features/home/presentation/widgets/home_top_bar.dart';
import 'package:reem/features/home/presentation/widgets/home_wishlist_highlights.dart';
import 'package:reem/features/market/presentation/screens/drops_screen.dart';
import 'package:reem/features/market/presentation/widgets/bundles_rail.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_home_screen.dart';
import 'package:reem/features/value/presentation/widgets/value_standing_card.dart';

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
        // Beside the search bar on purpose: search answers "I know what I
        // want", the stylist answers "I know the occasion, not the piece".
        const SliverToBoxAdapter(child: HomeStylistEntry()),
        const _Gap(DsSpacing.lg),

        const HomeStoriesRail(),

        _box(const HomeHeroCarousel()),

        _box(const HomeCategoriesShowcase()),

        // ── Chapter two: the shelves ─────────────────────────────────────
        const _Ornament(),

        // Phase four, above the deals on purpose: a drop she was invited to is
        // addressed to her, and a discount is addressed to everybody. Both
        // render nothing when there is nothing, so a quiet week leaves the
        // page exactly as it was.
        _box(const DropsRail()),

        _box(const HomeFlashDeals()),

        // Admin-configured merchandising.
        _box(const HomeDynamicBlocks()),

        // Reem Value, above the loyalty card for the same reason it sits above
        // it on the profile: standing is who she is here, points are what she
        // is owed. The card draws nothing at all until she has a rung, so a new
        // shopper's home page is unchanged.
        _box(const ValueStandingCard()),

        _box(const HomeLoyaltyCard()),

        _box(
          _CollectionRail(
            collection: ProductCollection.recommended,
            eyebrow: l10n.homeRecommendedEyebrow,
            title: l10n.recommended,
          ),
        ),

        // A solution rather than a shelf. Placed after the recommendations
        // because it answers the question those leave open — "fine, but what
        // do I wear it with".
        _box(const BundlesRail()),

        _box(const HomeContinueShopping()),

        // "New in" is not a shelf here. It is the finale — `HomeShowcaseSection`
        // at the foot of the page, under the same «وصل حديثاً» heading — and a
        // horizontal rail of the same pieces higher up meant the shopper met
        // the section twice on one screen. The rail was the lesser telling, so
        // the rail went.
        _box(const HomeFeaturedStores()),

        _box(
          _CollectionRail(
            collection: ProductCollection.bestSelling,
            eyebrow: l10n.homeBestSellersEyebrow,
            title: l10n.bestSeller,
          ),
        ),

        _box(const HomeRecentlyViewed()),

        _box(const HomeWishlistHighlights()),

        _box(const HomeNearbyStores()),

        _box(const HomeNotificationsSummary()),

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

  /// Wraps a box section in a sliver with a gentle entrance reveal, and with
  /// the breathing room that belongs *to that section* rather than sitting
  /// between two of them.
  ///
  /// The spacing used to be its own `_Gap` sliver after every box, which meant
  /// a section that collapsed left its gap behind. Half this page collapses on
  /// a real account — nothing records what she has viewed, no address carries
  /// coordinates, a new shopper has no loyalty tier and nothing to continue —
  /// so the home screen opened with five stacked bands of unexplained
  /// emptiness. Now the gap goes when the section goes.
  static Widget _box(Widget child) {
    return SliverToBoxAdapter(
      child: _SectionGap(
        gap: _gap,
        child: child
            .animate()
            .fadeIn(duration: 420.ms, curve: Curves.easeOut)
            .slideY(
              begin: 0.05,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

/// Reserves [gap] below [child] — but only when the child drew something.
///
/// A `SizedBox` after the section cannot know whether the section rendered, so
/// it always reserved its height. This measures the child first and simply has
/// no height of its own when the child has none.
class _SectionGap extends SingleChildRenderObjectWidget {
  const _SectionGap({required this.gap, required Widget super.child});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSectionGap(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSectionGap renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _RenderSectionGap extends RenderShiftedBox {
  _RenderSectionGap(this._gap) : super(null);

  double _gap;

  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset.zero;

    final height = child.size.height;
    size = constraints.constrain(
      Size(child.size.width, height == 0 ? 0 : height + _gap),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final height = child?.getMinIntrinsicHeight(width) ?? 0;
    return height == 0 ? 0 : height + _gap;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final height = child?.getMaxIntrinsicHeight(width) ?? 0;
    return height == 0 ? 0 : height + _gap;
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
      onTapProduct: (p) => context.push(RoutePaths.productDetailsOf(p.id)),
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
