import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/cards/surface_card.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../domain/entities/order.dart';
import '../providers/checkout_providers.dart';
import '../widgets/order_status_chip.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersNotifierProvider);

    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'My Orders', showBack: true),
        if (state.isLoading && state.orders.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyOrders(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              DsSpacing.xxl,
            ),
            sliver: SliverList.separated(
              itemCount: state.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (_, i) => _OrderCard(order: state.orders[i]),
            ),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      onTap: () => context.push(RoutePaths.orderDetailOf(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.number,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    color: colors.onSurface,
                  ),
                ),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            '${order.itemsCount} item(s) · ${_date(order.createdAt)}',
            style: TextStyle(
              fontSize: DsTypography.bodySmall,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 52, color: colors.primary),
          const SizedBox(height: DsSpacing.md),
          Text(
            'No orders yet',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
