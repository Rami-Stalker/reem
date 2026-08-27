import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip({super.key, required this.status});

  final ProductStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = switch (status) {
      ProductStatus.active => colors.success,
      ProductStatus.pendingReview => colors.warning,
      ProductStatus.draft => colors.onSurfaceVariant,
      ProductStatus.outOfStock => colors.warning,
      ProductStatus.paused => colors.onSurfaceVariant,
      ProductStatus.archived => colors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontFamily: DsTypography.fontFamily,
          fontSize: DsTypography.bodySmall,
          fontWeight: DsTypography.semiBold,
          color: color,
        ),
      ),
    );
  }
}
