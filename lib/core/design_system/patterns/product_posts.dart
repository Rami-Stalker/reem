import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/shared/entities/product.dart';

/// A catalogue told as **posts** — the same editorial shape the home feed
/// leads with, for a page that has products rather than posts.
///
/// The home showcase already let a shopper read the newest pieces as posts, as
/// a mosaic or as a grid. Every other product page — a department, "see all"
/// under a rail — put her back in a two-column grid with no say in it, which
/// made the switcher look like a decoration on one screen instead of the way
/// the catalogue is read.
///
/// A post here is not a social post: nothing is liked, nobody is followed and
/// there is no comment thread, because a product is not an author's story. It
/// borrows the shape — one large 4:5 plate, a swipeable gallery, the frosted
/// "shop this" plate — and the boutique selling it heads the card.
class SliverProductPosts extends StatelessWidget {
  const SliverProductPosts({
    super.key,
    this.products = const [],
    this.isLoading = false,
    this.onTapProduct,
    this.onTapSeller,
    this.onAddToBag,
    this.onToggleFavorite,
    this.skeletonCount = 2,
  });

  final List<Product> products;
  final bool isLoading;
  final void Function(Product product)? onTapProduct;

  /// Opens the boutique behind the piece. Null hides the header's tap target.
  final void Function(Product product)? onTapSeller;

  /// Adds the cheapest live offer to the bag. Null — or a piece with nothing
  /// in stock — leaves the plate as a plain way in to the product page.
  final void Function(Product product)? onAddToBag;

  final void Function(Product product)? onToggleFavorite;

  final int skeletonCount;

  static const EdgeInsets _hPad = EdgeInsets.symmetric(
    horizontal: DsSpacing.lg,
  );

  @override
  Widget build(BuildContext context) {
    final showSkeletons = isLoading && products.isEmpty;
    if (!showSkeletons && products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (showSkeletons) {
      return SliverList.separated(
        itemCount: skeletonCount,
        separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
        itemBuilder: (_, _) => const Padding(
          padding: _hPad,
          child: DsPostCardSkeleton(mediaAspectRatio: 4 / 5),
        ),
      );
    }

    return SliverList.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
      itemBuilder: (context, index) {
        final product = products[index];
        return Padding(
          padding: _hPad,
          child: DsProductPostCard(
            product: product,
            onTap: onTapProduct == null ? null : () => onTapProduct!(product),
            onTapSeller: onTapSeller == null
                ? null
                : () => onTapSeller!(product),
            onAddToBag: onAddToBag == null ? null : () => onAddToBag!(product),
            onToggleFavorite: onToggleFavorite == null
                ? null
                : () => onToggleFavorite!(product),
          ),
        );
      },
    );
  }
}

/// One product, told as a post.
class DsProductPostCard extends StatefulWidget {
  const DsProductPostCard({
    super.key,
    required this.product,
    this.onTap,
    this.onTapSeller,
    this.onAddToBag,
    this.onToggleFavorite,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onTapSeller;
  final VoidCallback? onAddToBag;
  final VoidCallback? onToggleFavorite;

  @override
  State<DsProductPostCard> createState() => _DsProductPostCardState();
}

class _DsProductPostCardState extends State<DsProductPostCard> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Product get product => widget.product;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final media = product.media;
    final count = math.max(media.length, 1);
    final seller = product.displaySeller;

    // The same thread as the feed card, held at its unfeatured weight so a
    // page of these reads calm.
    final ring = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        c.primary.withValues(alpha: 0.38),
        c.secondary.withValues(alpha: 0.18),
        c.accent.withValues(alpha: 0.38),
      ],
    );

    return DsGradientBorder(
      radius: 34,
      width: 1.1,
      gradient: ring,
      backgroundColor: c.card,
      boxShadow: [
        BoxShadow(
          color: c.primary.withValues(alpha: 0.10),
          blurRadius: 30,
          offset: const Offset(0, 16),
        ),
        BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 6)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (seller != null)
            _SellerHeader(
              name: seller.name,
              imageUrl: seller.imageUrl,
              isVerified: seller.isVerified,
              subtitle: product.category.name(
                arabic: Localizations.localeOf(context).languageCode == 'ar',
              ),
              onTap: widget.onTapSeller,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.xxl),
              child: GestureDetector(
                onTap: widget.onTap,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (media.isEmpty)
                        const DsMediaFallback()
                      else
                        PageView.builder(
                          controller: _pages,
                          physics: count > 1
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) => setState(() => _index = i),
                          itemCount: count,
                          itemBuilder: (_, i) => DsMediaFrame(item: media[i]),
                        ),

                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.imageScrimTop,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.imageScrim,
                          ),
                        ),
                      ),

                      if (product.hasDiscount)
                        PositionedDirectional(
                          top: DsSpacing.sm,
                          start: DsSpacing.sm,
                          child: DsDiscountBadge(
                            percentOff: product.discountPercent,
                          ),
                        ),

                      PositionedDirectional(
                        top: DsSpacing.sm,
                        end: DsSpacing.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (widget.onToggleFavorite != null)
                              _FavouriteButton(
                                isFavorite: product.isLiked,
                                onTap: widget.onToggleFavorite!,
                              ),
                            if (count > 1) ...[
                              const SizedBox(height: DsSpacing.xxs),
                              DsCounterPill(index: _index, count: count),
                            ],
                            if (product.rating > 0) ...[
                              const SizedBox(height: DsSpacing.xxs),
                              DsRatingChip(
                                rating: product.rating,
                                reviews: product.reviewsCount,
                              ),
                            ],
                          ],
                        ),
                      ),

                      PositionedDirectional(
                        start: DsSpacing.sm,
                        end: DsSpacing.sm,
                        bottom: DsSpacing.sm,
                        child: DsShopPlate(
                          product: product,
                          onTap: widget.onTap ?? () {},
                          onAddToBag: product.isAvailable
                              ? widget.onAddToBag
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (media.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.sm),
              child: Center(
                child: _MediaDots(count: media.length, index: _index),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.sm,
              DsSpacing.md,
              DsSpacing.md,
            ),
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                product.description.trim().isEmpty
                    ? product.title
                    : product.description.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.body
                    .tint(c.onSurfaceVariant)
                    .copyWith(height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The boutique above its piece — the masthead of a product post.
class _SellerHeader extends StatelessWidget {
  const _SellerHeader({
    required this.name,
    required this.imageUrl,
    required this.isVerified,
    required this.subtitle,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool isVerified;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.sm,
      ),
      child: Row(
        children: [
          DsAvatar(
            imageUrl: imageUrl,
            name: name,
            size: 46,
            hasRing: true,
            onTap: onTap,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.tileTitle.displayFamily.bold
                              .tint(c.onSurface)
                              .copyWith(height: 1.25),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: DsSpacing.xxs),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: c.secondary,
                        ),
                      ],
                    ],
                  ),
                  DsGaps.vXxxs,
                  Row(
                    children: [
                      DsSparkle(size: 8, color: c.accent, opacity: 0.9),
                      const SizedBox(width: DsSpacing.xxs),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.tint(
                            c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The favourite toggle on glass, so it stays legible over any photograph.
class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      button: true,
      selected: isFavorite,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.glass,
            shape: BoxShape.circle,
            border: Border.all(color: c.glassBorder),
          ),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18,
            color: isFavorite ? c.favorite : c.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Gallery position: soft dots with the active one stretched into a capsule.
class _MediaDots extends StatelessWidget {
  const _MediaDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: DsMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: i == index ? context.primaryGradient : null,
              color: i == index ? null : c.border,
              borderRadius: DsRadius.borderPill,
            ),
          ),
      ],
    );
  }
}
