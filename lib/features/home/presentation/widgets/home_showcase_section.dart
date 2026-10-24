import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:ohara/core/presentation/providers/product_shape_provider.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/home/presentation/feed_interleave.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/features/home/presentation/widgets/home_section_header.dart';
import 'package:ohara/features/home/presentation/widgets/ohara_post_card.dart';

/// The heart of the home page: **one set of pieces, three ways to look at it.**
///
/// The post shape leads — it is the one the client asked to build the page
/// around — and the mosaic and grid sit behind a switcher for the moods where
/// storytelling is not what she wants. All three read the same feed, so
/// switching never changes *what* she is looking at, only how.
///
/// It is also the page's spine now rather than its finale. The shop modules
/// the home page used to stack above it — deals, drops, bundles, rails — are
/// handed in as [modules] and set between the posts by [interleaveFeed]; in
/// the mosaic and grid shapes, which have no posts to set them between, they
/// follow the pieces.
class HomeShowcaseSection extends ConsumerWidget {
  const HomeShowcaseSection({super.key, this.modules = const []});

  /// Box widgets, each already carrying its own spacing and collapsing to
  /// nothing when it has nothing to show.
  final List<Widget> modules;

  static const _hPad = EdgeInsets.symmetric(horizontal: DsSpacing.lg);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(homeNotifierProvider);
    final shape = ref.watch(productShapeProvider);

    final posts = state.feed;
    final loading = state.feedLoading && posts.isEmpty;

    // Mosaic and grid speak products, the feed speaks posts — so unwrap them,
    // skipping the notes and looks that tag nothing. The fallback is the new
    // arrivals shelf rather than trending: this section is "New in", and a
    // shape switch should never quietly change what "new" means.
    final arrivals = state.sectionOf(ProductCollection.newArrivals);
    final tagged = <Product>[
      for (final post in posts)
        if (post.product != null) post.product!,
    ];
    final products = tagged.isEmpty ? arrivals.products : tagged;
    final productsLoading = products.isEmpty && (loading || arrivals.isLoading);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: HomeSectionHeader(
            eyebrow: l10n.homeShowcaseEyebrow,
            title: l10n.homeShowcaseTitle,
            subtitle: l10n.homeShowcaseSubtitle,
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xxxs,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xxxs,
              DsSpacing.lg,
              DsSpacing.lg,
            ),
            child: ShapeSwitcher(
              selected: shape,
              onSelect: (next) {
                AppHaptics.selection();
                ref.read(productShapeProvider.notifier).state = next;
              },
            ),
          ),
        ),
        ...switch (shape) {
          DsProductShape.posts => _posts(context, posts, loading),
          DsProductShape.mosaic => [
            SliverProductMosaic(
              products: products,
              isLoading: productsLoading,
              onTapProduct: (p) => _openProduct(context, p),
            ),
            ..._trailingModules(),
          ],
          DsProductShape.grid => [
            SliverProductGrid(
              products: products,
              isLoading: productsLoading,
              onTapProduct: (p) => _openProduct(context, p),
            ),
            ..._trailingModules(),
          ],
        },
      ],
    );
  }

  /// The modules in one run below whatever came before them.
  List<Widget> _trailingModules() => [
    if (modules.isNotEmpty)
      SliverPadding(
        padding: const EdgeInsets.only(top: DsSpacing.xl),
        sliver: SliverList.list(children: modules),
      ),
  ];

  static void _openProduct(BuildContext context, Product product) =>
      context.push(RoutePaths.productDetailsOf(product.id));

  List<Widget> _posts(BuildContext context, List<Post> posts, bool loading) {
    // While the posts load the modules wait below the skeletons rather than
    // standing in for them: the first thing on the page stays a post.
    if (loading) {
      return [
        SliverList.separated(
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
          itemBuilder: (_, _) => const Padding(
            padding: _hPad,
            child: DsPostCardSkeleton(mediaAspectRatio: 4 / 5),
          ),
        ),
        ..._trailingModules(),
      ];
    }

    if (posts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
            child: DsEmptyState(
              icon: Icons.auto_awesome_rounded,
              title: context.l10n.homeFeedEmptyTitle,
              message: context.l10n.homeFeedEmptyBody,
            ),
          ),
        ),
        ..._trailingModules(),
      ];
    }

    final slots = interleaveFeed<Post, Widget>(posts, modules);

    return [
      SliverList.builder(
        itemCount: slots.length,
        itemBuilder: (context, index) => switch (slots[index]) {
          // Each post carries the gap beneath it, and each module its own,
          // so a module that collapses takes its spacing with it instead of
          // leaving a double gap between two posts.
          FeedPost(:final post) => Padding(
            padding: _hPad.copyWith(bottom: DsSpacing.xl),
            child: OharaPostCard(post: post, featured: index == 0)
                .animate()
                .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                .slideY(
                  begin: 0.04,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
          FeedModule(:final module) => module,
        },
      ),
    ];
  }
}
