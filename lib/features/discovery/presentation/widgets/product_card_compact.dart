import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/entities/product.dart';

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
                      ? Image.network(
                          product.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: colors.surfaceVariant),
                        )
                      : Container(color: colors.surfaceVariant),
                ),
              ),
              if (product.hasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(DsRadius.full),
                    ),
                    child: Text(
                      '-${product.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.semiBold,
              fontSize: DsTypography.bodySmall,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '\$${product.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.bold,
                  color: colors.primary,
                ),
              ),
              if (product.hasDiscount) ...[
                const SizedBox(width: 4),
                Text(
                  '\$${product.oldPrice!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: DsTypography.bodySmall,
                    color: colors.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
              const Spacer(),
              Icon(Icons.star_rounded, size: 13, color: colors.warning),
              Text(
                product.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: DsTypography.bodySmall,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
