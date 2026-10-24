import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/experience/role_experience.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/router/tab_reselect.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:ohara/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/features/home/presentation/widgets/home_continue_shopping.dart';
import 'package:ohara/features/home/presentation/widgets/home_dynamic_blocks.dart';
import 'package:ohara/features/home/presentation/widgets/home_featured_stores.dart';
import 'package:ohara/features/home/presentation/widgets/home_flash_deals.dart';
import 'package:ohara/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:ohara/features/home/presentation/widgets/home_loyalty_card.dart';
import 'package:ohara/features/home/presentation/widgets/home_nearby_stores.dart';
import 'package:ohara/features/home/presentation/widgets/home_notifications_summary.dart';
import 'package:ohara/features/home/presentation/widgets/home_recently_viewed.dart';
import 'package:ohara/features/home/presentation/widgets/home_showcase_section.dart';
import 'package:ohara/features/home/presentation/widgets/home_stories_rail.dart';
import 'package:ohara/features/home/presentation/widgets/home_wishlist_highlights.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_aura.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_bento.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_mood_dial.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_pulse.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_style_deck.dart';
import 'package:ohara/features/market/presentation/screens/drops_screen.dart';
import 'package:ohara/features/market/presentation/widgets/bundles_rail.dart';
import 'package:ohara/features/profile/presentation/providers/profile_provider.dart';
import 'package:ohara/features/salons/presentation/widgets/home_salons_rail.dart';
import 'package:ohara/features/seller_dashboard/presentation/screens/seller_home_screen.dart';
import 'package:ohara/features/value/presentation/widgets/value_standing_card.dart';

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

/// Buyer home: a living page rather than a stack of shelves.
///
/// The client asked for nothing traditional. So the page opens on a sky
/// that follows the Damascus hour and speaks to her by name ([HomeAura]),
/// with what changed since she last looked and a field that asks rather
/// than searches. A single live line follows ([HomePulse]); then the
/// stories, which the client's Q78 pick keeps on top; then three things she
/// *does* rather than scrolls — pick a mood and the stylist builds the look
/// ([HomeMoodDial]), decide on today's picks with a swipe ([HomeStyleDeck]),
/// wander the departments laid out as a bento ([HomeBento]). The feed starts
/// after that, with the remaining shelves set into it as before.
class _BuyerHomeScreen extends ConsumerStatefulWidget {
  const _BuyerHomeScreen();

  @override
  ConsumerState<_BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<_BuyerHomeScreen> {
  /// Sits just above the stories, so «posted today» can scroll to them.
  final _storiesAnchor = GlobalKey();

  static const double _gap = DsSpacing.xl;

  /// Held here so tapping Home while already on Home brings her back to the
  /// top of the page.
  final _scrollController = ScrollController();

  /// Which shell branch Home is. Mirrored by hand from the router.
  static const int _homeBranch = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    _scrollController.animateTo(
      0,
      duration: DsMotion.slow,
      curve: DsMotion.silk,
    );
  }

  void _showStories() {
    final target = _storiesAnchor.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: DsMotion.slow,
      curve: DsMotion.emphasized,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(homeContentNotifierProvider.notifier).refresh(),
      ref.read(homeNotifierProvider.notifier).refresh(),
      ref.read(favoritesNotifierProvider.notifier).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    ref.listen(tabReselectProvider(_homeBranch), (_, _) => _scrollToTop());

    return OharaScrollPage(
      controller: _scrollController,
      onRefresh: () => _refresh(ref),
      slivers: [
        HomeAura(onStoriesTap: _showStories),

        const SliverToBoxAdapter(child: HomePulse()),
        const _Gap(DsSpacing.lg),

        SliverToBoxAdapter(child: SizedBox(key: _storiesAnchor)),
        const HomeStoriesRail(),
        const _Gap(DsSpacing.xl),

        // ── Three things she does rather than scrolls ─────────────────────
        _reveal(const HomeMoodDial()),
        const _Gap(DsSpacing.xxl),
        _reveal(const HomeStyleDeck()),
        const _Gap(DsSpacing.xxl),
        _reveal(const HomeBento()),
        const _Gap(DsSpacing.xxl),

        // «الصالونات والجمال»: another way of shopping rather than another
        // shelf. Draws nothing until a salon is published.
        const SliverToBoxAdapter(child: HomeSalonsRail()),

        // ── The feed, with the shop set into it ──────────────────────────
        //
        // The order below is the order the modules meet her in: one after
        // the second post, then one every third. Most valuable first —
        // what the admin is promoting, then what was sent to her, then
        // what is ending soon — and the personal records last, because
        // they are the ones that are empty for a new shopper.
        HomeShowcaseSection(
          modules: [
            // Admin-configured banners, the client's «بانر» in Q78.
            _module(const HomeHeroCarousel()),
            // A drop she was invited to is addressed to her; a discount is
            // addressed to everybody. Both draw nothing in a quiet week.
            _module(const DropsRail()),
            _module(const HomeFlashDeals()),
            _module(
              _CollectionRail(
                collection: ProductCollection.recommended,
                eyebrow: l10n.homeRecommendedEyebrow,
                title: l10n.recommended,
              ),
            ),
            // A solution rather than a shelf: it answers the question the
            // recommendations leave open — "fine, but what do I wear it with".
            _module(const BundlesRail()),
            // Admin-configured merchandising.
            _module(const HomeDynamicBlocks()),
            _module(const HomeFeaturedStores()),
            _module(const HomeContinueShopping()),
            _module(
              _CollectionRail(
                collection: ProductCollection.bestSelling,
                eyebrow: l10n.homeBestSellersEyebrow,
                title: l10n.bestSeller,
              ),
            ),
            // Standing above points for the same reason as on the profile:
            // standing is who she is here, points are what she is owed. Both
            // draw nothing until there is something to say.
            _module(const ValueStandingCard()),
            _module(const HomeLoyaltyCard()),
            _module(const HomeRecentlyViewed()),
            _module(const HomeWishlistHighlights()),
            _module(const HomeNearbyStores()),
            _module(const HomeNotificationsSummary()),
          ],
        ),

        // Breathing room above the floating bottom bar.
        const _Gap(120),
      ],
    );
  }

  /// A block above the feed, risen into place as the page settles.
  static Widget _reveal(Widget child) => SliverToBoxAdapter(
    child: child
        .animate()
        .fadeIn(duration: 520.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 520.ms,
          curve: Curves.easeOutCubic,
        ),
  );

  /// Wraps a shop module in a gentle entrance reveal and the breathing room
  /// that belongs *to that module* rather than sitting between two of them.
  ///
  /// The spacing used to be its own `_Gap` sliver after every box, which meant
  /// a section that collapsed left its gap behind. Half these modules collapse
  /// on a real account — nothing records what she has viewed, no address
  /// carries coordinates, a new shopper has no loyalty tier and nothing to
  /// continue — and set between posts an orphaned gap would show as a hole in
  /// the feed. Now the gap goes when the module goes.
  static Widget _module(Widget child) {
    return DsCollapsingGap(
      after: _gap,
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
