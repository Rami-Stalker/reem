import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';

/// What this piece costs, from the seller currently selected.
///
/// The old block showed `$240` struck through `$420` with a 45% badge for
/// every product in the catalogue. This one reads the selected [SellerOffer],
/// falls back to the catalogue price range when no offer is buyable, and says
/// how many boutiques list the item — the compare-prices affordance the domain
/// model has always supported and the UI never surfaced.
class ProductPriceBlock extends StatelessWidget {
  const ProductPriceBlock({
    super.key,
    required this.product,
    required this.offer,
    this.onComparePrices,
  });

  final Product product;
  final SellerOffer? offer;
  final VoidCallback? onComparePrices;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final colors = context.dsColors;
    final l10n = context.l10n;

    final price = offer?.price ?? product.priceFrom;
    final compareAt = offer?.compareAtPrice;
    final discount = offer?.discountPercent ?? 0;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.formPrice, style: text.overline),
          DsGaps.vXs,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: DsSpacing.sm,
                  runSpacing: DsSpacing.xxs,
                  children: [
                    Text(
                      price?.format() ?? '—',
                      style: text.priceHero.tabular,
                    ),
                    if (compareAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
                        child: Text(
                          compareAt.format(),
                          style: text.priceStruck.tabular,
                        ),
                      ),
                  ],
                ),
              ),
              if (discount > 0) DsDiscountBadge(percentOff: discount),
            ],
          ),
          if (product.hasPriceRange) ...[
            DsGaps.vXs,
            Text(
              '${product.priceFrom!.format()} — ${product.priceTo!.format()}',
              style: text.caption,
            ),
          ],
          if (product.hasMultipleOffers) ...[
            DsGaps.vSm,
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: DsSizes.iconXs,
                  color: colors.onSurfaceVariant,
                ),
                DsGaps.hXxs,
                Expanded(
                  child: Text(
                    l10n.productOffersFrom(product.offersCount),
                    style: text.caption,
                  ),
                ),
                if (onComparePrices != null)
                  GhostButton(
                    label: l10n.comparePrices,
                    onPressed: onComparePrices,
                    size: DsButtonSize.sm,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
