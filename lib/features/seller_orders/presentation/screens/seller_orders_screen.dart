import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';
import 'package:ohara/features/seller_orders/presentation/providers/seller_orders_provider.dart';
import 'package:ohara/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:ohara/features/seller_orders/presentation/widgets/seller_order_action_prompt.dart';
import 'package:ohara/features/seller_orders/presentation/widgets/seller_order_card.dart';

/// The seller's queue — the screen she works a sale from.
///
/// Q37's eighteen states are far too many to put in front of her, so they are
/// grouped into the six piles a shop actually has: new, being made, packed,
/// travelling, coming back, and done. The counts on the tabs are the whole
/// point of the screen — they are what tells her, before she reads a single
/// row, whether anything is waiting.
class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerOrdersNotifierProvider);
    final notifier = ref.read(sellerOrdersNotifierProvider.notifier);
    final atelier = context.atelier;
    final l10n = context.l10n;

    // Server refusals are shown as they arrive rather than parked in the
    // layout: the parcel is already back to its old state, so the message is
    // about what just failed, not about the screen.
    ref.listen(sellerOrdersNotifierProvider, (previous, next) {
      final error = next.serverError;
      if (error != null && error != previous?.serverError) {
        DsSnackbar.error(context, error);
      }
    });

    return OharaScrollPage(
      onRefresh: notifier.refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: atelier.background,
      slivers: [
        PremiumAppBar(title: l10n.sellerOrdersTitle, showBack: true),

        SliverToBoxAdapter(
          child: _Tabs(
            selected: state.tab,
            countFor: state.countFor,
            onSelect: notifier.selectTab,
          ),
        ),

        if (state.isLoading)
          const SliverToBoxAdapter(child: _QueueSkeleton())
        else if (state.orders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: state.issue == SellerOrdersIssue.offline
                  ? DsErrorState(
                      message: l10n.sellerOrdersOffline,
                      onRetry: notifier.refresh,
                    )
                  : DsEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.queueEmptyTitle(state.tab),
                      message: l10n.queueEmptyBody(state.tab),
                    ),
            ),
          )
        else
          SliverPadding(
            // The queue is a shell TAB now, not a pushed page, so the last
            // card has to clear the seller's navigation bar rather than
            // hiding the final order of the day behind it.
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.xs,
              DsSpacing.md,
              140,
            ),
            sliver: SliverList.separated(
              itemCount: state.orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
              itemBuilder: (context, index) {
                final order = state.orders[index];
                return SellerOrderCard(
                  order: order,
                  isBusy: state.busyOrderId == order.id,
                  onOpen: () => context.push(
                    RoutePaths.sellerOrderDetailFor(order.id),
                  ),
                  onAction: (action) => _run(context, ref, order, action),
                );
              },
            ),
          ),
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
    if (input == null) return;
    if (!context.mounted) return;

    final ok = await ref
        .read(sellerOrdersNotifierProvider.notifier)
        .run(
          order,
          action,
          reason: input.reason,
          collected: input.collected,
          carrier: input.carrier,
        );

    if (ok && context.mounted) {
      DsSnackbar.success(context, context.l10n.parcelActionDone(action));
    }
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  final SellerQueueTab selected;
  final int Function(SellerQueueTab tab) countFor;
  final void Function(SellerQueueTab tab) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
        itemCount: SellerQueueTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
        itemBuilder: (context, index) {
          final tab = SellerQueueTab.values[index];
          final count = countFor(tab);
          return DsChip(
            label: context.l10n.queueTab(tab),
            selected: tab == selected,
            // Zero is left off rather than shown: a row of "0"s reads as
            // failure, and the absence of a badge already says the same thing.
            count: count > 0 ? count : null,
            onTap: () => onSelect(tab),
          );
        },
      ),
    );
  }
}

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            const DsShimmer(
              child: DsSkeleton.box(height: 148),
            ),
            const SizedBox(height: DsSpacing.sm),
          ],
        ],
      ),
    );
  }
}
