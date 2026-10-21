import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/shared/entities/product.dart';

/// The catalogue card the client picked in Q80: *«صورة كبيرة بلا إطار — بصري
/// وأنيق، معلومات أقل»*.
///
/// Deliberately frameless — no border, no card fill. The image carries the
/// card and the page background shows through, which is what makes a grid of
/// these read as an editorial spread rather than a price list. Everything
/// below the image is trimmed to the three things a shopper actually scans:
/// name, price, and a discount if there is one.
///
/// The image is 4:5 ([Product] photography is mandated at that ratio, Q132).
class ProductCardLuxe extends StatelessWidget {
  const ProductCardLuxe({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  /// Locked in Q132 — every product photo on the platform is shot 4:5.
  static const double imageAspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Image(product: product),
          const SizedBox(height: DsSpacing.sm),
          // The grid hands every tile the same fixed height, and the 4:5 plate
          // claims most of it. Letting the caption flex means a tall price line
          // (or a larger text scale) gives way quietly instead of painting an
          // overflow stripe across the catalogue.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.medium,
                    fontSize: DsTypography.bodyMedium,
                    height: 1.3,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
                _PriceLine(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The image plate: rounded artwork, an optional discount flag, and the
/// product's own interaction floating on glass so it stays legible over any
/// photo.
class _Image extends StatelessWidget {
  const _Image({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadius.image),
      child: AspectRatio(
        aspectRatio: ProductCardLuxe.imageAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product.coverUrl != null)
              AuthorizedMediaImage(
                url: product.coverUrl!,
                blurHash: product.coverBlurHash,
                variantWidth: MediaVariants.thumbnail,
              )
            else
              const _MissingPhoto(),

            if (product.hasDiscount)
              PositionedDirectional(
                top: DsSpacing.xs,
                start: DsSpacing.xs,
                child: DsDiscountBadge(percentOff: product.discountPercent),
              ),

            // Supplied by `DsProductActions`, installed once above the
            // navigator. The card used to own a favourite toggle that each
            // screen had to remember to hand it a callback for — so the grid
            // had one, the mosaic and the rails had none, and the one the grid
            // had wrote to a different store than the product page did.
            if (DsProductActions.of(context, product, DsProductSurface.tile)
                case final action?)
              PositionedDirectional(
                top: DsSpacing.xs,
                end: DsSpacing.xs,
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for a photo that is absent or failed to load. A tinted plate with
/// a faint mark reads as "no picture yet" rather than as a broken tile.
class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.checkroom_rounded,
          size: 28,
          color: colors.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Price, plus the struck-through original when the item is discounted.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final price = product.price;
    if (price == null) return const SizedBox.shrink();

    return Row(
      children: [
        // The live price never shrinks — it is the one number she is looking
        // for. Only the struck-through original gives way when space runs out.
        Text(
          price.format(),
          maxLines: 1,
          style: DsTypography.price(
            colors.price,
            size: DsTypography.bodyMedium,
          ),
        ),
        if (product.hasDiscount && product.compareAtPrice != null) ...[
          const SizedBox(width: DsSpacing.xs),
          Flexible(
            child: Text(
              // Currency omitted — the live price beside it already said it.
              product.compareAtPrice!.format(includeSymbol: false),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.priceStrike(colors.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}
