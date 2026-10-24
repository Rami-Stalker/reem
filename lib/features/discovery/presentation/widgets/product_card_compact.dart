import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/design_system/patterns/product_cues.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/shared/entities/product.dart';

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
              // Directional, not `left`. The app is RTL, so a badge pinned to
              // the physical left sits on the *end* side — the corner the
              // product's like now occupies — and the two drew on top of each
              // other. The discount belongs opposite it, on the start side.
              if (product.hasDiscount)
                PositionedDirectional(
                  top: 6,
                  start: 6,
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
              // The product's own interaction, supplied by `DsProductActions`.
              // A rail card had none at all: a woman could scroll forty pieces
              // through «مختارة لكِ» and not be able to say she liked one
              // of them without opening each in turn.
              if (DsProductActions.of(context, product, DsProductSurface.rail)
                  case final action?)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: action,
                ),

              // The strongest honest claim, under the interaction rather than
              // opposite the discount flag — the top-end corner is now spoken
              // for, and a badge on top of a heart is neither.
              //
              // One, not two: this card is 152pt wide in a rail, and the price
              // row below it has already overflowed once in this file's
              // history. On the photograph rather than under the title for the
              // same reason — there is no vertical room left, and a scarcity
              // badge belongs on the image anyway.
              if (product.cues.strongestBadge case final cue?)
                PositionedDirectional(
                  bottom: 6,
                  end: 6,
                  child: DsBadge(label: cue.label, tone: cue.tone),
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
