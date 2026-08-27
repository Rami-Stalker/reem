import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design_system.dart';
import '../../shared/entities/product.dart';
import '../../media/media_variants.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

/// An **editorial mosaic** of products — the magazine spread shape.
///
/// Where the grid gives every piece the same rectangle, the mosaic lets one
/// image carry the page: each unit is a tall hero beside two stacked companion
/// tiles, and the hero swaps sides every unit so the eye zig-zags down the
/// page instead of marching. Presentational only — it takes products and two
/// callbacks, nothing else.
class SliverProductMosaic extends StatelessWidget {
  const SliverProductMosaic({
    super.key,
    this.products = const [],
    this.isLoading = false,
    this.onTapProduct,
    this.skeletonUnits = 2,
  });

  final List<Product> products;
  final bool isLoading;
  final void Function(Product product)? onTapProduct;
  final int skeletonUnits;

  /// Three products make one unit: the hero plus its two companions.
  static const int _perUnit = 3;
  static const double _unitHeight = 292;
  static const double _gap = DsSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final showSkeletons = isLoading && products.isEmpty;
    if (!showSkeletons && products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final unitCount = showSkeletons
        ? skeletonUnits
        : (products.length + _perUnit - 1) ~/ _perUnit;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      sliver: SliverList.separated(
        itemCount: unitCount,
        separatorBuilder: (_, _) => const SizedBox(height: _gap),
        itemBuilder: (context, unit) {
          if (showSkeletons) return const _MosaicSkeleton(height: _unitHeight);
          final slice = products.skip(unit * _perUnit).take(_perUnit).toList();
          return _MosaicUnit(
            products: slice,
            heroOnStart: unit.isEven,
            onTapProduct: onTapProduct,
          );
        },
      ),
    );
  }
}

class _MosaicUnit extends StatelessWidget {
  const _MosaicUnit({
    required this.products,
    required this.heroOnStart,
    required this.onTapProduct,
  });

  final List<Product> products;
  final bool heroOnStart;
  final void Function(Product product)? onTapProduct;

  @override
  Widget build(BuildContext context) {
    // A tail of one or two pieces gets its own honest shape rather than a hero
    // padded out with holes.
    if (products.length == 1) {
      return SizedBox(
        height: 210,
        child: _MosaicTile(
          product: products.first,
          scale: _TileScale.banner,
          onTap: onTapProduct,
        ),
      );
    }
    if (products.length == 2) {
      return SizedBox(
        height: 210,
        child: Row(
          children: [
            Expanded(
              child: _MosaicTile(
                product: products[0],
                scale: _TileScale.small,
                onTap: onTapProduct,
              ),
            ),
            const SizedBox(width: SliverProductMosaic._gap),
            Expanded(
              child: _MosaicTile(
                product: products[1],
                scale: _TileScale.small,
                onTap: onTapProduct,
              ),
            ),
          ],
        ),
      );
    }

    final hero = Expanded(
      flex: 55,
      child: _MosaicTile(
        product: products[0],
        scale: _TileScale.hero,
        onTap: onTapProduct,
      ),
    );
    final companions = Expanded(
      flex: 45,
      child: Column(
        children: [
          Expanded(
            child: _MosaicTile(
              product: products[1],
              scale: _TileScale.small,
              onTap: onTapProduct,
            ),
          ),
          const SizedBox(height: SliverProductMosaic._gap),
          Expanded(
            child: _MosaicTile(
              product: products[2],
              scale: _TileScale.small,
              onTap: onTapProduct,
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: SliverProductMosaic._unitHeight,
      child: Row(
        children: heroOnStart
            ? [hero, const SizedBox(width: SliverProductMosaic._gap), companions]
            : [
                companions,
                const SizedBox(width: SliverProductMosaic._gap),
                hero,
              ],
      ),
    );
  }
}

enum _TileScale { hero, small, banner }

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.product,
    required this.scale,
    required this.onTap,
  });

  final Product product;
  final _TileScale scale;
  final void Function(Product product)? onTap;

  bool get _isHero => scale != _TileScale.small;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final url = product.coverUrl ?? '';

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(product),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(
            _isHero ? DsRadius.xxl : DsRadius.xl,
          ),
          boxShadow: context.shadowSoft,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isEmpty)
              Center(child: DsSparkle(size: 26, color: c.primary, opacity: 0.4))
            else
              CachedNetworkImage(
                imageUrl: MediaVariants.thumb(url),
                fit: BoxFit.cover,
                fadeInDuration: DsMotion.normal,
                placeholder: (_, _) {
                  // The cover's own colours while it loads, rather than a grey
                  // block that pops.
                  final hash = product.coverBlurHash;
                  return hash == null || hash.isEmpty
                      ? ColoredBox(color: c.shimmerBase)
                      : BlurHash(hash: hash, imageFit: BoxFit.cover);
                },
                errorWidget: (_, _, _) => ColoredBox(color: c.surfaceVariant),
              ),

            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: context.imageScrim),
              ),
            ),

            if (product.hasDiscount)
              PositionedDirectional(
                top: DsSpacing.xs,
                start: DsSpacing.xs,
                child: DsDiscountBadge(percentOff: product.discountPercent),
              ),

            PositionedDirectional(
              start: DsSpacing.sm,
              end: DsSpacing.sm,
              bottom: DsSpacing.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.title,
                    maxLines: _isHero ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: (_isHero
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.labelLarge)
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: DsTypography.semiBold,
                          height: 1.25,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.price?.format() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.price(
                      Colors.white,
                      size: _isHero
                          ? DsTypography.titleSmall
                          : DsTypography.labelMedium,
                    ).copyWith(
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black45),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MosaicSkeleton extends StatelessWidget {
  const _MosaicSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DsShimmer(
        child: Row(
          children: [
            const Expanded(
              flex: 55,
              child: DsSkeleton.box(
                height: double.infinity,
                borderRadius: DsRadius.xxl,
              ),
            ),
            const SizedBox(width: SliverProductMosaic._gap),
            Expanded(
              flex: 45,
              child: Column(
                children: const [
                  Expanded(
                    child: DsSkeleton.box(
                      height: double.infinity,
                      borderRadius: DsRadius.xl,
                    ),
                  ),
                  SizedBox(height: SliverProductMosaic._gap),
                  Expanded(
                    child: DsSkeleton.box(
                      height: double.infinity,
                      borderRadius: DsRadius.xl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
