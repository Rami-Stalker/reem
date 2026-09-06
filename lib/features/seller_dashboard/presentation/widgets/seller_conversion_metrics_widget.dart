import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

class SellerConversionMetricsWidget extends ConsumerWidget {
  const SellerConversionMetricsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 160, borderRadius: DsRadius.xxl)),
      );
    }

    final m = state.data?.conversionMetrics;
    if (m == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.sellerConversionMetrics,
            style: context.dsText.cardTitle
                .copyWith(fontWeight: DsTypography.bold),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              _MetricCard(
                label: context.l10n.sellerProductViews,
                value: _fmt(m.productViews),
                trend: m.viewsTrend,
                icon: Icons.visibility_outlined,
                color: c.info,
              ),
              const SizedBox(width: DsSpacing.sm),
              _MetricCard(
                label: context.l10n.sellerWishlistAdds,
                value: _fmt(m.wishlistAdds),
                trend: m.wishlistTrend,
                icon: Icons.favorite_outline_rounded,
                color: c.favorite,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              _MetricCard(
                label: context.l10n.sellerCartAdds,
                value: _fmt(m.cartAdds),
                trend: m.cartTrend,
                icon: Icons.shopping_cart_outlined,
                color: c.success,
              ),
              const SizedBox(width: DsSpacing.sm),
              _MetricCard(
                label: context.l10n.sellerConversionRate,
                value: '${m.conversionRate.toStringAsFixed(2)}%',
                trend: null,
                icon: Icons.swap_vert_rounded,
                color: c.secondary,
                note:
                    context.l10n.sellerCartAbandon(m.cartAbandonRate.toStringAsFixed(1)),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 380.ms);
  }

  static String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
    this.note,
  });

  final String label;
  final String value;
  final double? trend;
  final IconData icon;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final isPositive = (trend ?? 0) >= 0;
    final trendColor = isPositive ? c.success : c.error;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderLg,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(DsSpacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderSm,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              value,
              style: context.dsText.cardTitle
                  .copyWith(fontWeight: DsTypography.bold),
            ),
            Text(
              label,
              style: context.dsText.caption
                  .copyWith(color: c.onSurfaceVariant, fontSize: DsTypography.labelMicro),
            ),
            if (trend != null)
              Row(
                children: [
                  Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 10,
                    color: trendColor,
                  ),
                  Text(
                    '${trend!.abs().toStringAsFixed(1)}%',
                    style: context.dsText.micro.bold.tint(trendColor),
                  ),
                ],
              ),
            if (note != null)
              Text(
                note!,
                style: context.dsText.caption.copyWith(
                  color: c.onSurfaceVariant,
                  fontSize: DsTypography.labelMicro,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
