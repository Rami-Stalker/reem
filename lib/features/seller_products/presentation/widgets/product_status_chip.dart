import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/l10n/app_localizations.dart';

/// A listing's state in the seller's words, from the ARB bundles.
extension ProductStatusLabel on ProductStatus {
  String labelOf(AppLocalizations l10n) => switch (this) {
    ProductStatus.draft => l10n.productStateDraft,
    ProductStatus.pendingReview => l10n.productStatePendingReview,
    ProductStatus.active => l10n.productStateActive,
    ProductStatus.outOfStock => l10n.productStateOutOfStock,
    ProductStatus.paused => l10n.productStatePaused,
    ProductStatus.archived => l10n.productStateArchived,
  };
}

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
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.labelOf(context.l10n),
        style: context.dsText.bodySmall.semibold.tint(color),
      ),
    );
  }
}
