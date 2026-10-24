import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:ohara/features/checkout/presentation/providers/orders_notifier.dart';
import 'package:ohara/features/checkout/presentation/widgets/order_status_chip.dart';

/// Her orders, in one of the four piles her profile counts.
///
/// The profile screen has shown those counts since it was built and every tile
/// opened this screen unfiltered — tapping «ملغاة» handed her everything she
/// had ever bought, which is how a real number ends up feeling invented. The
/// pile arrives in the route and the row of chips keeps it switchable.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.initialBucket});

  final OrderBucket? initialBucket;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late OrderBucket? _bucket = widget.initialBucket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(ordersNotifierProvider(_bucket));

    return OharaScrollPage(
      onRefresh: () => ref.read(ordersNotifierProvider(_bucket).notifier).refresh(),
      slivers: [
        PremiumAppBar(title: l10n.myOrders, showBack: true),
        SliverToBoxAdapter(
          child: _Filters(
            selected: _bucket,
            onSelect: (bucket) => setState(() => _bucket = bucket),
          ),
        ),
        if (state.isLoading && state.orders.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else if (state.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.myOrders,
              // A pile that happens to be empty is not the same as never
              // having ordered, and "browse the shop" is the wrong offer for
              // a shopper filtering her own history.
              message: _bucket == null
                  ? l10n.browseAndAdd
                  : l10n.ordersEmptyForFilter,
              actionLabel: _bucket == null ? l10n.emptyCartAction : null,
              onAction: _bucket == null
                  ? () => context.go(RoutePaths.home)
                  : null,
            ),
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
              separatorBuilder: (_, _) => DsGaps.vMd,
              itemBuilder: (_, i) => _OrderCard(order: state.orders[i]),
            ),
          ),
      ],
    );
  }
}

/// The pile switcher — «الكل» plus the four the profile counts.
class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final OrderBucket? selected;
  final ValueChanged<OrderBucket?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String label(OrderBucket bucket) => switch (bucket) {
      OrderBucket.pending => l10n.statusPending,
      OrderBucket.processing => l10n.statusProcessing,
      OrderBucket.delivered => l10n.statusDelivered,
      OrderBucket.cancelled => l10n.statusCancelled,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          DsChip(
            label: l10n.ordersFilterAll,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final bucket in OrderBucket.values) ...[
            const SizedBox(width: DsSpacing.xs),
            DsChip(
              label: label(bucket),
              selected: selected == bucket,
              onTap: () => onSelect(bucket),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final l10n = context.l10n;
    final meta = [
      l10n.itemsCount(order.itemsCount),
      if (order.isSplit) l10n.sellersCount(order.sellersCount),
      _date(order.createdAt),
    ].join(' · ');

    return CustomerPanel(
      onTap: () => context.push(RoutePaths.orderDetailOf(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.number, style: text.cardTitle.bold),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          DsGaps.vXs,
          Text(meta, style: text.cardSubtitle),
          DsGaps.vSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.total, style: text.caption),
              Text(order.grandTotal.format(), style: text.price.tabular),
            ],
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
