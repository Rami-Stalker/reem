import 'package:flutter/material.dart';

import '../design_system.dart';
import '../../shared/entities/product.dart';

/// The two-per-row catalogue grid that anchors the bottom of the home screen
/// (Q78 «مختلط: ستوريات + بانر + شبكة منتجات», Q81 «اثنين» per row).
///
/// Ships as a sliver so it shares one scroll view with the rails above it —
/// a nested `GridView` inside a `CustomScrollView` would build every tile up
/// front and lose the lazy build that keeps a long home screen smooth on the
/// mid-range phones most of these shoppers carry.
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({
    super.key,
    this.products = const [],
    this.isLoading = false,
    this.onTapProduct,
    this.onToggleFavorite,
    this.skeletonCount = 6,
  });

  final List<Product> products;
  final bool isLoading;
  final void Function(Product product)? onTapProduct;
  final void Function(Product product)? onToggleFavorite;
  final int skeletonCount;

  /// Two columns, with room under the image for the name and price line.
  ///
  /// The ratio has to clear the 4:5 plate *plus* the caption; at 0.62 a tile
  /// came up a couple of points short once a was-price joined the row.
  static const int _columns = 2;
  static const double _tileAspectRatio = 0.58;

  @override
  Widget build(BuildContext context) {
    final showSkeletons = isLoading && products.isEmpty;
    if (!showSkeletons && products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final grid = SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        crossAxisSpacing: DsSpacing.sm,
        mainAxisSpacing: DsSpacing.lg,
        childAspectRatio: _tileAspectRatio,
      ),
      delegate: showSkeletons
          ? SliverChildBuilderDelegate(
              (_, _) => const _Skeleton(),
              childCount: skeletonCount,
            )
          : SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return ProductCardLuxe(
                  product: product,
                  onTap: () => onTapProduct?.call(product),
                  onFavoriteToggle: onToggleFavorite == null
                      ? null
                      : () => onToggleFavorite!(product),
                );
              },
              childCount: products.length,
            ),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      sliver: grid,
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tight constraints from [Expanded] override the skeleton's own
          // default height, so the plate fills the tile above the text lines.
          Expanded(
            child: DsSkeleton.box(borderRadius: DsRadius.image),
          ),
          SizedBox(height: DsSpacing.sm),
          DsSkeleton.line(width: 120),
          SizedBox(height: DsSpacing.xxs),
          DsSkeleton.line(width: 70),
        ],
      ),
    );
  }
}
