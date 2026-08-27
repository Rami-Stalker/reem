import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/post.dart';
import '../../../../core/shared/entities/product.dart';
import '../../../../core/shared/wedgets/product/product_grid.dart';
import '../../../../core/shared/wedgets/product/product_mosaic.dart';
import '../../../discovery/domain/entities/product_collection.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/home_provider.dart';
import '../providers/home_showcase_provider.dart';
import 'home_section_header.dart';
import 'reem_post_card.dart';

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
    final shape = ref.watch(homeShowcaseShapeProvider);

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
              0,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              0,
              DsSpacing.lg,
              DsSpacing.lg,
            ),
            child: ShapeSwitcher(
              selected: shape,
              onSelect: (next) {
                HapticFeedback.selectionClick();
                ref.read(homeShowcaseShapeProvider.notifier).state = next;
              },
            ),
          ),
        ),
        ...switch (shape) {
          HomeShowcaseShape.posts => _posts(context, posts, loading),
          HomeShowcaseShape.mosaic => [
            SliverProductMosaic(
              products: products,
              isLoading: productsLoading,
              onTapProduct: (p) => _openProduct(context, p),
            ),
          ],
          HomeShowcaseShape.grid => [
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
      context.push('${RoutePaths.productDetails}?id=${product.id}');

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
          child:
              ReemPostCard(
                    post: posts[index],
                    featured: index == 0,
                  )
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

/// The segmented pill that swaps shapes — a rose capsule gliding under three
/// labels. Deliberately the only control on the page with this much colour:
/// it is the one thing on home she is meant to notice she can change.
class ShapeSwitcher extends StatelessWidget {
  const ShapeSwitcher({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final HomeShowcaseShape selected;
  final ValueChanged<HomeShowcaseShape> onSelect;

  static const double _inset = 4;
  static const double _height = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    const shapes = HomeShowcaseShape.values;
    final index = shapes.indexOf(selected);

    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: c.surfaceElevated.withValues(alpha: 0.9),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
        boxShadow: context.shadowXs,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final segment = box.maxWidth / shapes.length;
          // Expand, so the sliding capsule inherits the pill's full height
          // rather than collapsing to the height of a label.
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositionedDirectional(
                duration: DsMotion.moderate,
                curve: DsMotion.silk,
                start: segment * index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    borderRadius: DsRadius.borderPill,
                    boxShadow: context.glowShadow(
                      c.primary,
                      blur: 16,
                      alpha: 0.34,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final shape in shapes)
                    Expanded(
                      child: _Segment(
                        label: shape.label(l10n),
                        icon: shape.icon,
                        selected: shape == selected,
                        onTap: () => onSelect(shape),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final fg = selected ? c.onPrimary : c.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: DsSpacing.xxs),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: DsMotion.fast,
                style: TextStyle(
                  color: fg,
                  fontSize: DsTypography.labelMedium,
                  fontWeight: selected
                      ? DsTypography.bold
                      : DsTypography.semiBold,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
