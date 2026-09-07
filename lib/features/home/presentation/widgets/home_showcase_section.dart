import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/presentation/providers/product_shape_provider.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';
import 'package:reem/features/home/presentation/widgets/reem_post_card.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';

/// The heart of the home page: **one set of pieces, three ways to look at it.**
///
/// The post shape leads — it is the one the client asked to build the page
/// around — and the mosaic and grid sit behind a switcher for the moods where
/// storytelling is not what she wants. All three read the same feed, so
/// switching never changes *what* she is looking at, only how.
class HomeShowcaseSection extends ConsumerWidget {
  const HomeShowcaseSection({super.key});

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
          ],
          DsProductShape.grid => [
            SliverProductGrid(
              products: products,
              isLoading: productsLoading,
              onTapProduct: (p) => _openProduct(context, p),
              onToggleFavorite: (p) => ref
                  .read(favoritesNotifierProvider.notifier)
                  .toggleFavorite(p.id),
            ),
          ],
        },
      ],
    );
  }

  static void _openProduct(BuildContext context, Product product) =>
      context.push(RoutePaths.productDetailsOf(product.id));

  List<Widget> _posts(BuildContext context, List<Post> posts, bool loading) {
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
      ];
    }

    return [
      SliverList.separated(
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
        itemBuilder: (context, index) => Padding(
          padding: _hPad,
          child: ReemPostCard(post: posts[index], featured: index == 0)
              .animate()
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.04,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ),
    ];
  }
}
