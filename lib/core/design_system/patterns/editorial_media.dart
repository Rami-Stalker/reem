/// The furniture of an editorial image plate — the frame itself, the glass
/// chips that float over it, and the "shop this" plate at its foot.
///
/// These were private to `ReemPostCard`, which was fine while the feed was the
/// only surface telling a product as a full-bleed image. It is not: the
/// category and collection pages offer the same post shape now, and copying a
/// hundred and thirty lines of frosted plate into a second file is exactly how
/// two cards meant to be one card start drifting apart.
library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';

/// One frame of a gallery: the photograph, with a play badge over a video.
class DsMediaFrame extends StatelessWidget {
  const DsMediaFrame({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final url = item.displayUrl;
    if (url.isEmpty) return const DsMediaFallback();

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          // The feed's own photographs, drawn at card width. The original is
          // whatever the boutique uploaded — often three thousand pixels wide
          // for a card that is four hundred.
          imageUrl: MediaVariants.at(url, MediaVariants.medium),
          fit: BoxFit.cover,
          fadeInDuration: DsMotion.normal,
          placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
          errorWidget: (_, _, _) => const DsMediaFallback(),
        ),
        if (item.isVideo)
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DsColors.black.withValues(alpha: 0.34),
                border: Border.all(color: DsColors.onMediaMuted, width: 1.4),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: DsColors.onMedia,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }
}

/// What stands in for a photograph that is missing or refused to load: a
/// tinted plate with a single sparkle, rather than a broken-image glyph.
class DsMediaFallback extends StatelessWidget {
  const DsMediaFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ColoredBox(
      color: c.surfaceVariant,
      child: Center(child: DsSparkle(size: 34, color: c.primary, opacity: 0.4)),
    );
  }
}

/// "2/5" on frosted glass — where she is in a gallery.
class DsCounterPill extends StatelessWidget {
  const DsCounterPill({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DsRadius.borderPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xs,
            vertical: DsSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: DsColors.black.withValues(alpha: 0.28),
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: DsColors.onMediaFaint),
          ),
          child: Text(
            '${index + 1}/$count',
            style: context.dsText.caption.semibold.tint(DsColors.onMedia),
          ),
        ),
      ),
    );
  }
}

/// Rating over the media — social proof where the eye already is.
class DsRatingChip extends StatelessWidget {
  const DsRatingChip({super.key, required this.rating, required this.reviews});

  final double rating;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xs,
            vertical: DsSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: DsColors.black.withValues(alpha: 0.28),
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: DsColors.onMediaFaint),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 12, color: c.rating),
              DsGaps.hXxs,
              Text(
                rating.toStringAsFixed(1),
                style: context.dsText.badge.tint(DsColors.onMedia),
              ),
              if (reviews > 0) ...[
                DsGaps.hXxs,
                Text(
                  '(${formatCount(reviews)})',
                  style: context.dsText.badge.regular.tint(
                    DsColors.onMediaMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The frosted "shop this" plate floating over the foot of an image.
///
/// It carries the piece's name and price, and closes the sale where it stands:
/// the bag drops the cheapest live offer into the cart without leaving the
/// page. Where nothing is in stock to add, it becomes an arrow and only
/// navigates.
class DsShopPlate extends StatelessWidget {
  const DsShopPlate({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToBag,
  });

  final Product product;
  final VoidCallback onTap;

  /// Null when nothing is in stock to add — the plate then only navigates.
  final VoidCallback? onAddToBag;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DsBlur.medium,
            sigmaY: DsBlur.medium,
          ),
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.xs),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(DsRadius.xl),
              border: Border.all(
                color: DsColors.onMedia.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    borderRadius: BorderRadius.circular(DsRadius.md),
                    boxShadow: context.glowShadow(
                      c.primary,
                      blur: 14,
                      alpha: 0.34,
                    ),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 19,
                    color: c.onPrimary,
                  ),
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.labelLarge.copyWith(
                          color: c.onSurface,
                          fontWeight: DsTypography.semiBold,
                          height: 1.2,
                        ),
                      ),
                      DsGaps.vXxxs,
                      // Two flexible children split the row evenly when both
                      // want more than half, which was clipping the live price
                      // ("264,000 …") to make room for a decorative strike.
                      // The weights hand the price the larger share; the
                      // was-price gives way first.
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              product.price?.format() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.price(
                                c.price,
                                size: DsTypography.labelLarge,
                              ),
                            ),
                          ),
                          if (product.hasDiscount) ...[
                            const SizedBox(width: DsSpacing.xxs),
                            Flexible(
                              flex: 2,
                              child: Text(
                                product.compareAtPrice?.format() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.priceStrike(
                                  c.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DsSpacing.xxs),
                if (onAddToBag != null)
                  _AddToBagButton(onTap: onAddToBag!)
                else
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: DsSpacing.xs,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: c.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gradient bag inside the shop plate.
class _AddToBagButton extends StatelessWidget {
  const _AddToBagButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: context.primaryGradient,
          borderRadius: BorderRadius.circular(DsRadius.md),
          boxShadow: context.glowShadow(c.primary, blur: 12, alpha: 0.36),
        ),
        child: Icon(Icons.add_rounded, size: 22, color: c.onPrimary),
      ),
    );
  }
}
