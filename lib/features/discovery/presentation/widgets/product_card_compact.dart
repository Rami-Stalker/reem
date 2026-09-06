import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/shared/entities/product.dart';

/// Compact product card sized by its parent (rail gives width, grid gives cell).
class ProductCardCompact extends StatelessWidget {
  const ProductCardCompact({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DsRadius.lg),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: product.coverUrl != null
                      ? AuthorizedMediaImage(
                          url: product.coverUrl!,
                          blurHash: product.coverBlurHash,
                          variantWidth: MediaVariants.thumbnail,
                        )
                      : Container(color: colors.surfaceVariant),
                ),
              ),
              if (product.hasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xs,
                      vertical: DsSpacing.xxxs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(DsRadius.full),
                    ),
                    child: Text(
                      '-${product.discountPercent}%',
                      style: context.dsText.micro
                          .tint(DsColors.onMedia)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.bodySmall.semibold.tint(colors.onSurface),
          ),
          DsGaps.vXxxs,
          // A live price, a was-price and a rating do not fit a 152pt rail
          // card: the row used to overflow rather than give — a red-striped
          // "RIGHT OVERFLOWED BY 41 PIXELS" down the recommended rail — and
          // squeezing all three only bought a clipped price ("217,000 …").
          // The was-price is dropped here; the "-15%" flag on the photo above
          // already tells the saving, and on this card the price she pays is
          // the number that has to be whole.
          Row(
            children: [
              Expanded(
                child: Text(
                  product.price?.format() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.bold.tint(colors.primary),
                ),
              ),
              const SizedBox(width: DsSpacing.xxs),
              Icon(Icons.star_rounded, size: 13, color: colors.warning),
              Text(
                product.rating.toStringAsFixed(1),
                style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
