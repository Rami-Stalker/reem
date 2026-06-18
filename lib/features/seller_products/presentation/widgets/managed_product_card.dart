import 'package:flutter/material.dart';

import '../../../../core/design_system/components/cards/surface_card.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_status.dart';
import 'product_status_chip.dart';

enum ProductCardAction { edit, activate, draft, archive, delete }

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
    final colors = context.dsColors;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.md),
            child: SizedBox(
              width: 64,
              height: 64,
              child: product.coverImage != null
                  ? Image.network(
                      product.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
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
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.semiBold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${product.price.toStringAsFixed(0)} · ${product.stock} in stock',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.bodySmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DsSpacing.xs),
                Row(
                  children: [
                    ProductStatusChip(status: product.status),
                    const SizedBox(width: DsSpacing.sm),
                    Icon(Icons.favorite, size: 12, color: colors.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      '${product.favoritesCount}',
                      style: TextStyle(
                        fontSize: DsTypography.bodySmall,
                        color: colors.onSurfaceVariant,
                      ),
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
              icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: ProductCardAction.edit,
                  child: Text('Edit'),
                ),
                if (product.status != ProductStatus.active)
                  const PopupMenuItem(
                    value: ProductCardAction.activate,
                    child: Text('Set Active'),
                  ),
                if (product.status != ProductStatus.draft)
                  const PopupMenuItem(
                    value: ProductCardAction.draft,
                    child: Text('Move to Draft'),
                  ),
                if (product.status != ProductStatus.archived)
                  const PopupMenuItem(
                    value: ProductCardAction.archive,
                    child: Text('Archive'),
                  ),
                const PopupMenuItem(
                  value: ProductCardAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      color: colors.surfaceVariant,
      child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
    );
  }
}
