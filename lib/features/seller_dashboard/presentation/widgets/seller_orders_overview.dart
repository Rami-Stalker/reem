import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/seller_orders_summary.dart';
import '../providers/seller_dashboard_provider.dart';
import 'seller_labels.dart';

class SellerOrdersOverview extends ConsumerWidget {
  const SellerOrdersOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 160, borderRadius: DsRadius.xxl)),
      );
    }

    final orders = state.data?.orders;
    if (orders == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.orders,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: DsTypography.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.sellerOrders),
                child: Text(context.l10n.sellerManageAll,
                    style: TextStyle(color: c.primary,
                        fontSize: DsTypography.labelMedium)),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          // Urgent row (new + processing + ready).
          Row(
            children: [
              _OrderCard(
                status: SellerOrderStatus.newOrders,
                count: orders.newOrders,
                urgent: true,
              ),
              const SizedBox(width: DsSpacing.sm),
              _OrderCard(
                status: SellerOrderStatus.processing,
                count: orders.processing,
              ),
              const SizedBox(width: DsSpacing.sm),
              _OrderCard(
                status: SellerOrderStatus.readyForShipment,
                count: orders.readyForShipment,
                urgent: orders.readyForShipment > 0,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          // Resolved row.
          Row(
            children: [
              _OrderCard(
                status: SellerOrderStatus.delivered,
                count: orders.delivered,
              ),
              const SizedBox(width: DsSpacing.sm),
              _OrderCard(
                status: SellerOrderStatus.cancelled,
                count: orders.cancelled,
              ),
              const SizedBox(width: DsSpacing.sm),
              _OrderCard(
                status: SellerOrderStatus.returned,
                count: orders.returned,
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
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.status,
    required this.count,
    this.urgent = false,
  });

  final SellerOrderStatus status;
  final int count;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final color = status.color;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.sellerOrders),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm, vertical: DsSpacing.sm),
          decoration: BoxDecoration(
            color: urgent && count > 0
                ? color.withValues(alpha: 0.1)
                : c.card,
            borderRadius: DsRadius.borderLg,
            border: Border.all(
              color: urgent && count > 0
                  ? color.withValues(alpha: 0.35)
                  : c.border.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(status.icon, size: 14, color: color),
                  if (urgent && count > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DsSpacing.xxs),
              Text(
                '$count',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: DsTypography.bold,
                  color: urgent && count > 0 ? color : c.onSurface,
                ),
              ),
              Text(
                status.labelOf(context.l10n),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: c.onSurfaceVariant,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
