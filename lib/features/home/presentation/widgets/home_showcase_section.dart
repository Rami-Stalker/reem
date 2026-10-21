import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';
import 'package:reem/features/product_social/presentation/widgets/product_shelf.dart';

/// The heart of the home page: **one set of pieces, three ways to look at it.**
///
/// The post shape leads — it is the one the client asked to build the page
/// around — and the mosaic and grid sit behind a switcher for the moods where
/// storytelling is not what she wants.
///
/// That claim used to be false in two ways, and both were the same bug. The
/// post shape rendered the home *feed* — `Post` objects, including the looks
/// and notes that tag no product — while the mosaic and grid rendered the
/// products unwrapped from it, so switching shape could quietly change which
/// pieces were on the page. And because a post's heart belongs to the post,
/// liking a dress here and liking the same dress on the grid wrote to two
/// different rows.
///
/// All three shapes now draw the same products through [SliverProductShelf],
/// with the product's own interactions. The post shape is still a post card
/// — [ProductPostCard] is assembled from the same `DsPostFrame`,
/// `DsPostHeader`, `DsPostGallery`, `DsPostActionBar` and `DsPostCaption` as
/// the feed's card — so the page reads exactly as it did.
class HomeShowcaseSection extends ConsumerWidget {
  const HomeShowcaseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(homeNotifierProvider);

    final posts = state.feed;
    final loading = state.feedLoading && posts.isEmpty;

    // The feed speaks posts and this section speaks products, so unwrap them,
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
        if (products.isEmpty && !productsLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsEmptyState(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.homeFeedEmptyTitle,
                message: context.l10n.homeFeedEmptyBody,
              ),
            ),
          )
        else
          SliverProductShelf(
            products: products,
            isLoading: productsLoading,
            onTapProduct: (p) => _openProduct(context, p),
            switcherPadding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xxxs,
              DsSpacing.lg,
              DsSpacing.lg,
            ),
          ),
      ],
    );
  }

  static void _openProduct(BuildContext context, Product product) =>
      context.push(RoutePaths.productDetailsOf(product.id));
}
