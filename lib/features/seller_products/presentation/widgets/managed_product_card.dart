import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/presentation/widgets/product_status_chip.dart';

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

    return SellerPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.md),
            child: SizedBox(
              width: 74,
              height: 74,
              child: product.coverImage != null
                  ? AuthorizedMediaImage(
                      url: product.coverImage!,
                      variantWidth: MediaVariants.thumbnail,
                    )
                  : _Placeholder(palette: palette),
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.bold.tint(palette.ink),
                ),
                DsGaps.vXxxs,
                Text(
                  _priceAndStock(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.bodySmall.tint(palette.muted),
                ),
                const SizedBox(height: DsSpacing.xs),
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
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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

  /// "12,000 ل.س · 8 in stock" — [ManagedProduct.price] is a non-null [Money],
  /// so it formats itself; only the stock half needs translating.
  String _priceAndStock(BuildContext context) =>
      '${product.price.format()} · ${context.l10n.sellerStock('${product.stock}')}';
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette});

  final SellerAtelierPalette palette;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: palette.background,
    child: Icon(Icons.image_outlined, color: palette.muted),
  );
}
