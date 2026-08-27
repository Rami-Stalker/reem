import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/user_profile/domain/entities/seller_stats.dart';

/// Premium seller dashboard summary: products, sales, orders, rating.
class SellerStatsCard extends StatelessWidget {
  const SellerStatsCard({super.key, required this.stats});

  final SellerStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final money = stats.totalSales >= 1000
        ? '\$${(stats.totalSales / 1000).toStringAsFixed(1)}k'
        : '\$${stats.totalSales.toStringAsFixed(0)}';

    return DsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Text(
                'Seller insights',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.bold,
                  fontSize: DsTypography.titleSmall,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              _Metric(
                icon: Icons.inventory_2_outlined,
                value: '${stats.productsCount}',
                label: 'Products',
              ),
              _Metric(
                icon: Icons.payments_outlined,
                value: money,
                label: 'Sales',
              ),
              _Metric(
                icon: Icons.receipt_long_outlined,
                value: '${stats.ordersCount}',
                label: 'Orders',
              ),
              _Metric(
                icon: Icons.star_rounded,
                value: stats.averageRating.toStringAsFixed(1),
                label: 'Rating',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

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
          Text(
            value,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.bodySmall,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
