import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/user_profile/domain/entities/seller_stats.dart';

/// A boutique's figures under its awning: the rating given the most room —
/// it is the one a shopper reads first — then pieces, sales and orders.
class SellerStatsCard extends StatelessWidget {
  const SellerStatsCard({super.key, required this.stats});

  final SellerStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    // Her revenue, in the currency she actually earned it in. The tile used to
    // hard-code a dollar sign in front of the figure and abbreviate it "k",
    // which on a Damascus boutique's SYP takings was wrong twice over.
    final sales = stats.totalSales.primary;
    final money = sales == null ? '—' : sales.formatCompact();
    final rating = stats.averageRating.clamp(0, 5).toDouble();

    return ProfileAwning(
      title: l10n.sellerInsights,
      child: Column(
        children: [
          Semantics(
            label: '${l10n.sellerRatingStat} ${rating.toStringAsFixed(1)}',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: context.dsText.metric.displayFamily.bold.copyWith(
                    color: DsColors.gold600,
                    height: 1,
                  ),
                ),
                DsGaps.hSm,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            rating >= i
                                ? Icons.star_rounded
                                : rating >= i - 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                            size: DsSizes.iconXs,
                            color: colors.rating,
                          ),
                      ],
                    ),
                    Text(l10n.sellerRatingStat, style: context.dsText.caption),
                  ],
                ),
              ],
            ),
          ),
          DsGaps.vMd,
          Divider(height: 1, color: DsColors.gold300.withValues(alpha: 0.4)),
          DsGaps.vMd,
          Row(
            children: [
              _Metric(
                icon: Icons.inventory_2_rounded,
                value: '${stats.productsCount}',
                label: l10n.sellerProductsStat,
              ),
              _Metric(
                icon: Icons.payments_rounded,
                value: money,
                label: l10n.sellerSalesStat,
              ),
              _Metric(
                icon: Icons.receipt_long_rounded,
                value: '${stats.ordersCount}',
                label: l10n.sellerOrdersStat,
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
          Container(
            width: DsSizes.avatarSm,
            height: DsSizes.avatarSm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentContainer,
            ),
            child: Icon(icon, size: DsSizes.iconXs, color: DsColors.gold600),
          ),
          DsGaps.vXs,
          FittedBox(
            child: Text(
              value,
              style: context.dsText.bodyStrong.tint(colors.onSurface),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption,
          ),
        ],
      ),
    );
  }
}
