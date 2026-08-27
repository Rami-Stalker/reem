import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:reem/features/checkout/presentation/widgets/order_status_chip.dart';

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
    return CustomerPanel(
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
                    color: CustomerExperience.ink,
                  ),
                ),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            order.isSplit
                ? '${order.itemsCount} قطعة من ${order.sellersCount} بائعات · ${_date(order.createdAt)}'
                : '${order.itemsCount} قطعة · ${_date(order.createdAt)}',
            style: TextStyle(
              fontSize: DsTypography.bodySmall,
              color: CustomerExperience.muted,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: const TextStyle(color: CustomerExperience.muted),
              ),
              Text(
                order.grandTotal.format(),
                style: const TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.bold,
                  color: CustomerExperience.rose,
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
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: CustomerExperience.signatureGradient,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          const Text(
            'No orders yet',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: CustomerExperience.ink,
            ),
          ),
        ],
      ),
    );
  }
}
