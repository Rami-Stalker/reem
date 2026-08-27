import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/seller_top_product.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerTopProducts extends ConsumerWidget {
  const SellerTopProducts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 240, borderRadius: DsRadius.xxl)),
      );
    }

    final products = state.data?.topProducts ?? [];
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.sellerTopProducts,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: DsTypography.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.myProducts),
                child: Text(context.l10n.viewAll,
                    style:
                        TextStyle(color: c.primary, fontSize: DsTypography.labelMedium)),
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpacing.xs),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xs),
          itemBuilder: (context, i) => _TopProductTile(
            product: products[i],
            rank: i + 1,
          )
              .animate(delay: (i * 60).ms)
              .fadeIn(duration: 320.ms)
              .slideX(begin: 0.04, end: 0, duration: 320.ms),
        ),
      ],
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.product, required this.rank});

  final SellerTopProduct product;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final hasChange = product.revenueChange != null;
    final isPositive = (product.revenueChange ?? 0) >= 0;
    final changeColor =
        isPositive ? c.success : c.error;

    return GestureDetector(
      onTap: () =>
          context.push('${RoutePaths.productDetails}?id=${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.sm),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderLg,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            // Rank badge.
            SizedBox(
              width: 24,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.labelSmall,
                  fontWeight: DsTypography.bold,
                  color: rank == 1
                      ? const Color(0xFFD9A94F)
                      : rank == 2
                          ? c.onSurfaceVariant
                          : c.disabled,
                ),
              ),
            ),
            const SizedBox(width: DsSpacing.xs),
            // Image.
            ClipRRect(
              borderRadius: DsRadius.borderSm,
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                errorWidget: (_, _, _) =>
                    ColoredBox(color: c.surfaceVariant),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            // Title + units sold.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.unitsSold} sold · ★ ${product.rating}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpacing.xs),
            // Revenue + trend.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${_fmt(product.revenue)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: DsTypography.bold,
                    color: c.onSurface,
                  ),
                ),
                if (hasChange)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 10,
                        color: changeColor,
                      ),
                      Text(
                        '${product.revenueChange!.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontFamily: DsTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: DsTypography.bold,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (product.isLowStock || product.isOutOfStock)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: product.isOutOfStock
                        ? c.error.withValues(alpha: 0.12)
                        : c.warning.withValues(alpha: 0.12),
                    borderRadius: DsRadius.borderFull,
                  ),
                  child: Text(
                    product.isOutOfStock ? 'OOS' : 'Low',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: DsTypography.bold,
                      color: product.isOutOfStock ? c.error : c.warning,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
