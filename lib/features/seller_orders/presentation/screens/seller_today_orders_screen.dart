import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';
import 'package:ohara/features/seller_orders/presentation/providers/seller_orders_provider.dart';
import 'package:ohara/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:ohara/features/seller_orders/presentation/widgets/seller_order_action_prompt.dart';
import 'package:ohara/features/seller_orders/presentation/widgets/seller_order_card.dart';

/// Parcels placed today, on a Damascus clock.
final sellerTodayOrdersProvider =
    FutureProvider.autoDispose<List<SellerOrderSummary>>((ref) async {
      final result = await ref
          .watch(sellerOrdersRepositoryProvider)
          .queue(today: true, limit: 50);
      return switch (result) {
        Success(:final data) => data.orders,
        Error(:final failure) => throw failure.message,
      };
    });

/// «طلبات اليوم» — every order that came in today, whatever its state, with
/// how many still wait on her. The menu item used to open the courier's
/// delivery round, which a boutique account is refused.
class SellerTodayOrdersScreen extends ConsumerWidget {
  const SellerTodayOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final orders = ref.watch(sellerTodayOrdersProvider);
    final gutter = atelierGutter(context);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(sellerTodayOrdersProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.today_rounded,
          title: l10n.courierDay,
          subtitle: l10n.todayOrdersSubtitle,
          showBack: true,
          actions: [
            TextButton(
              onPressed: () => context.go(RoutePaths.sellerOrders),
              child: Text(
                l10n.todayOrdersAll,
                style: context.dsText.labelStrong.tint(DsColors.onMedia),
              ),
            ),
          ],
        ),
        DsGaps.sliverMd,
        ...orders.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
          ],
          error: (error, _) => [
            SliverToBoxAdapter(
              child: DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(sellerTodayOrdersProvider),
              ),
            ),
          ],
          data: (list) => list.isEmpty
              ? [
                  SliverToBoxAdapter(
                    child: DsEmptyState(
                      icon: Icons.inbox_outlined,
                      title: l10n.todayOrdersEmpty,
                      message: l10n.todayOrdersEmptyBody,
                    ),
                  ),
                ]
              : [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverToBoxAdapter(child: _Summary(orders: list)),
                  ),
                  DsGaps.sliverMd,
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => DsGaps.vMd,
                      itemBuilder: (context, index) {
                        final order = list[index];
                        return SellerOrderCard(
                          order: order,
                          onOpen: () => context.push(
                            RoutePaths.sellerOrderDetailFor(order.id),
                          ),
                          onAction: (action) =>
                              _run(context, ref, order, action),
                        );
                      },
                    ),
                  ),
                ],
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    SellerOrderSummary order,
    SellerOrderAction action,
  ) async {
    final input = await SellerOrderActionPrompt.ask(
      context,
      action,
      order: order,
    );
    if (input == null || !context.mounted) return;
    final ok = await ref
        .read(sellerOrdersNotifierProvider.notifier)
        .run(
          order,
          action,
          reason: input.reason,
          collected: input.collected,
          carrier: input.carrier,
        );
    ref.invalidate(sellerTodayOrdersProvider);
    if (ok && context.mounted) {
      DsSnackbar.success(context, context.l10n.parcelActionDone(action));
    }
  }
}

/// «٤ طلبات اليوم · ٢ بحاجة لإجراء».
class _Summary extends StatelessWidget {
  const _Summary({required this.orders});

  final List<SellerOrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final waiting = orders.where((o) => o.actions.isNotEmpty).length;
    return SellerPanel(
      child: Row(
        children: [
          Icon(Icons.today_rounded, color: palette.gold),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todayOrdersSummary(orders.length),
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
                Text(
                  l10n.todayOrdersNeedAction(waiting),
                  style: context.dsText.caption.tint(
                    waiting > 0 ? palette.caution : palette.positive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
