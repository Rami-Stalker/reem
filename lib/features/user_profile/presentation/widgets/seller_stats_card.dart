import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/user_profile/domain/entities/seller_stats.dart';

/// Premium seller dashboard summary: products, sales, orders, rating.
class SellerStatsCard extends StatelessWidget {
  const SellerStatsCard({super.key, required this.stats});

  final SellerStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    // Her revenue, in the currency she actually earned it in. The tile used to
    // hard-code a dollar sign in front of the figure and abbreviate it "k",
    // which on a Damascus boutique's SYP takings was wrong twice over.
    final sales = stats.totalSales.primary;
    final money = sales == null ? '—' : sales.formatCompact();

    return DsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Text(
                context.l10n.sellerInsights,
                style: context.dsText.tileTitle.bold.tint(colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              _Metric(
                icon: Icons.inventory_2_outlined,
                value: '${stats.productsCount}',
                label: context.l10n.sellerProductsStat,
              ),
              _Metric(
                icon: Icons.payments_outlined,
                value: money,
                label: context.l10n.sellerSalesStat,
              ),
              _Metric(
                icon: Icons.receipt_long_outlined,
                value: '${stats.ordersCount}',
                label: context.l10n.sellerOrdersStat,
              ),
              _Metric(
                icon: Icons.star_rounded,
                value: stats.averageRating.toStringAsFixed(1),
                label: context.l10n.sellerRatingStat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(height: DsSpacing.xs),
          Text(value, style: context.dsText.body.bold.tint(colors.onSurface)),
          DsGaps.vXxxs,
          Text(
            label,
            style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
