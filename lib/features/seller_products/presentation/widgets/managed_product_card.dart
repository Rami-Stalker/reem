import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';
import 'package:ohara/features/seller_products/presentation/widgets/product_status_chip.dart';

/// What a seller can do to one of her listings from the list.
///
/// `archive` and `delete` used to sit side by side and did nearly the same
/// thing, one of them against a route that no longer existed. Removal is one
/// action now — it takes the listing off the shop and leaves the row behind,
/// because an order placed against it still has to be explainable.
enum ProductCardAction { edit, publish, pause, draft, restock, remove }

/// One listing in the seller's product list: its photo, price, stock, status
/// and the menu of things she can do to it.
///
/// Colours come from the atelier palette rather than the old fixed slate set,
/// and the row-menu labels are localized — they were English literals sitting
/// next to a stock line that had already been hand-translated into Arabic, so
/// the same row spoke both languages at once.
class ManagedProductCard extends StatelessWidget {
  const ManagedProductCard({
    super.key,
    required this.product,
    required this.isMutating,
    required this.onAction,
  });

  final ManagedProduct product;
  final bool isMutating;
  final ValueChanged<ProductCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    // Stock read as a tape: amber from ten down, red from three — the same
    // thresholds the home's rail uses for «باقي».
    final stockColor = product.stock <= 3
        ? palette.critical
        : product.stock <= 10
        ? palette.caution
        : palette.positive;

    return GiftTagCard(
      onTap: () => onAction(ProductCardAction.edit),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The piece, cut to Ohara's arch.
          ClipPath(
            clipper: const DsArchClipper(),
            child: SizedBox(
              width: 72,
              height: 90,
              child: product.coverImage != null
                  ? AuthorizedMediaImage(
                      url: product.coverImage!,
                      variantWidth: MediaVariants.thumbnail,
                    )
                  : _Placeholder(palette: palette),
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
                DsGaps.vXxs,
                Text(
                  product.price.format(),
                  style: context.dsText.tileTitle.displayFamily.bold.tint(
                    palette.gold,
                  ),
                ),
                DsGaps.vXs,
                Row(
                  children: [
                    Expanded(
                      child: RibbonGauge(
                        value: product.stock.toDouble(),
                        max: 30,
                        color: stockColor,
                      ),
                    ),
                    DsGaps.hSm,
                    Text(
                      l10n.sellerStock('${product.stock}'),
                      style: context.dsText.captionStrong.tint(stockColor),
                    ),
                  ],
                ),
                DsGaps.vSm,
                Wrap(
                  spacing: DsSpacing.sm,
                  runSpacing: DsSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ProductStatusChip(status: product.status),
                    // A stat, not a status — and «0 حفظ» in an accent pill on
                    // every card read like an action the seller had to take.
                    if (product.favoritesCount > 0)
                      SellerStatusPill(
                        label: l10n.savedCount('${product.favoritesCount}'),
                        icon: Icons.favorite,
                        color: palette.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isMutating)
            const Padding(
              padding: EdgeInsets.all(DsSpacing.sm),
              child: DsLoadingIndicator.inline(),
            )
          else
            PopupMenuButton<ProductCardAction>(
              icon: Icon(Icons.more_vert, color: palette.muted),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: ProductCardAction.edit,
                  child: Text(l10n.sellerEditProduct),
                ),
                if (product.status != ProductStatus.active)
                  PopupMenuItem(
                    value: ProductCardAction.publish,
                    child: Text(l10n.productPublish),
                  ),
                if (product.status == ProductStatus.active)
                  PopupMenuItem(
                    value: ProductCardAction.pause,
                    child: Text(l10n.productPause),
                  ),
                if (product.status != ProductStatus.draft)
                  PopupMenuItem(
                    value: ProductCardAction.draft,
                    child: Text(l10n.sellerMoveToDraft),
                  ),
                PopupMenuItem(
                  value: ProductCardAction.restock,
                  child: Text(l10n.productRestock),
                ),
                if (product.status != ProductStatus.archived)
                  PopupMenuItem(
                    value: ProductCardAction.remove,
                    child: Text(l10n.productArchive),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette});

  final SellerAtelierPalette palette;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.primarySoft, palette.goldSoft],
      ),
    ),
    child: Icon(Icons.local_mall_outlined, color: palette.primary),
  );
}
