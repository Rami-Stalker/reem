import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/core/utils/arabic_numerals.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';
import 'package:reem/features/seller_orders/presentation/providers/seller_orders_provider.dart';
import 'package:reem/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:reem/features/seller_orders/presentation/widgets/seller_customer_panel.dart';
import 'package:reem/features/seller_orders/presentation/widgets/seller_order_action_prompt.dart';
import 'package:reem/features/seller_orders/presentation/widgets/seller_order_status_chip.dart';

/// One parcel, everything about it, and the next thing to do with it.
///
/// The order of the page is the order she needs it in: what state it is in,
/// what to pack, who it goes to, and only then the money. The action sits in a
/// pinned bar rather than at the bottom of a long scroll, because the whole
/// reason she opened the screen was to press it.
class SellerOrderDetailScreen extends ConsumerWidget {
  const SellerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerOrderDetailProvider(orderId));
    final notifier = ref.read(sellerOrderDetailProvider(orderId).notifier);
    final atelier = context.atelier;
    final order = state.order;

    ref.listen(sellerOrderDetailProvider(orderId), (previous, next) {
      final error = next.serverError;
      if (error != null && error != previous?.serverError) {
        DsSnackbar.error(context, error);
      }
    });

    return ReemScrollPage(
      onRefresh: notifier.load,
      background: const SellerAtelierBackground(),
      backgroundColor: atelier.background,
      bottom: order == null
          ? null
          : _ActionBar(
              order: order,
              isBusy: state.isBusy,
              onAction: (action) => _run(context, ref, order, action),
            ),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(order?.summary.number ?? ''),
          ),
        ),

        if (state.isLoading)
          const SliverToBoxAdapter(child: _DetailSkeleton())
        else if (order == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(
              message: state.issue == SellerOrdersIssue.offline
                  ? context.l10n.sellerOrdersOffline
                  : (state.serverError ?? context.l10n.sellerOrdersLoadFailed),
              onRetry: notifier.load,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.xxxs,
              DsSpacing.md,
              DsSpacing.xxl,
            ),
            sliver: SliverList.list(
              children: [
                _Header(order: order),
                const SizedBox(height: DsSpacing.md),

                SellerCustomerPanel(
                  customer: order.summary.customer,
                  mode: order.summary.fulfilmentMode,
                ),
                const SizedBox(height: DsSpacing.md),

                _Items(order: order),
                const SizedBox(height: DsSpacing.md),

                _Money(order: order),

                if (order.cancellationReason != null) ...[
                  const SizedBox(height: DsSpacing.md),
                  _Note(
                    icon: Icons.cancel_outlined,
                    tone: atelier.critical,
                    text: order.cancellationReason!,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    SellerOrderDetail order,
    SellerOrderAction action,
  ) async {
    final input = await SellerOrderActionPrompt.ask(
      context,
      action,
      order: order.summary,
    );
    if (input == null) return;
    if (!context.mounted) return;

    final ok = await ref
        .read(sellerOrderDetailProvider(orderId).notifier)
        .run(
          action,
          reason: input.reason,
          collected: input.collected,
          carrier: input.carrier,
        );

    if (ok && context.mounted) {
      DsSnackbar.success(context, context.l10n.sellerOrdersUpdated);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final SellerOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: atelier.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: atelier.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SellerOrderStatusChip(status: order.status),
              const Spacer(),
              Text(
                l10n.fulfilmentMode(order.summary.fulfilmentMode),
                style: context.dsText.caption.tint(atelier.muted),
              ),
            ],
          ),

          const SizedBox(height: DsSpacing.sm),

          // The journey so far. Only the steps that happened are listed —
          // drawing the ones that have not is how a screen ends up promising a
          // delivery that never comes.
          _Step(label: l10n.sellerOrderStepPlaced, at: order.summary.placedAt),
          if (order.confirmedAt != null)
            _Step(label: l10n.sellerOrderStepConfirmed, at: order.confirmedAt!),
          if (order.shippedAt != null)
            _Step(label: l10n.sellerOrderStepShipped, at: order.shippedAt!),
          if (order.deliveredAt != null)
            _Step(
              label: l10n.sellerOrderStepDelivered,
              at: order.deliveredAt!,
              isLast: true,
            ),

          if (order.shipment != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 15,
                  color: atelier.muted,
                ),
                const SizedBox(width: DsSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    order.shipment!.trackingCode,
                    style: context.dsText.bodySmall.tint(atelier.ink),
                  ),
                ),
                const Spacer(),
                Text(
                  order.shipment!.isAssigned
                      ? l10n.sellerOrderCourierAssigned
                      : l10n.sellerOrderCourierPending,
                  style: context.dsText.caption.tint(order.shipment!.isAssigned
                        ? atelier.positive
                        : atelier.caution),
                ),
              ],
            ),
            // Which company took it, and their number for it — so a seller
            // chasing a late parcel knows who to ring without asking support.
            if (order.shipment!.carrierName != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: DsSpacing.xxs,
                  right: DsSpacing.lg,
                ),
                child: Text(
                  order.shipment!.carrierTrackingNumber == null
                      ? '${l10n.deliveryCarrier}: ${order.shipment!.carrierName}'
                      : '${l10n.deliveryCarrier}: ${order.shipment!.carrierName}'
                            ' · ${order.shipment!.carrierTrackingNumber}',
                  style: context.dsText.caption.tint(atelier.muted),
                ),
              ),
            // A parcel the carrier would not take is hers to chase: it is
            // packed, it is not moving, and nobody else is watching this row.
            if (order.shipment!.isWaitingForCarrier)
              Padding(
                padding: const EdgeInsets.only(
                  top: DsSpacing.xxs,
                  right: DsSpacing.lg,
                ),
                child: Text(
                  l10n.sellerOrderCarrierPendingRetry,
                  style: context.dsText.caption.tint(atelier.caution),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.at, this.isLast = false});

  final String label;
  final DateTime at;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xs),
      child: Row(
        children: [
          Icon(
            isLast ? Icons.check_circle : Icons.circle,
            size: isLast ? 14 : 8,
            color: isLast ? atelier.positive : atelier.line,
          ),
          const SizedBox(width: DsSpacing.xs),
          Text(
            label,
            style: context.dsText.bodySmall.tint(atelier.ink),
          ),
          const Spacer(),
          Text(
            // l10n-ignore: an intl pattern; the locale supplies the words
            toWesternDigits(DateFormat('d MMM • HH:mm', 'ar').format(at)),
            style: context.dsText.caption.tint(atelier.muted),
          ),
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.order});

  final SellerOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: atelier.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: atelier.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.sellerOrderItemsToPack,
            style: context.dsText.tileTitle.semibold.tint(atelier.ink),
          ),
          const SizedBox(height: DsSpacing.sm),

          for (final item in order.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: atelier.primarySoft,
                    borderRadius: BorderRadius.circular(DsRadius.sm),
                  ),
                  child: Text(
                    '×${toWesternDigits('${item.quantity}')}',
                    style: context.dsText.caption.bold.tint(atelier.primary),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: context.dsText.body.tint(atelier.ink),
                      ),
                      if (item.variant != null)
                        Text(
                          item.variant!,
                          style: context.dsText.caption.tint(atelier.muted),
                        ),

                      // Q30 — a made-to-order instruction is the difference
                      // between the right parcel and a returned one, so it is
                      // shown in full rather than behind a tap.
                      if (item.customisation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpacing.xxs),
                          child: Text(
                            item.customisation!.entries
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' • '),
                            style: context.dsText.caption.tint(atelier.caution),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  item.lineTotal.format(),
                  style: context.dsText.bodySmall.tint(atelier.muted),
                ),
              ],
            ),
            if (item != order.items.last)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                child: Divider(height: 1, color: atelier.line),
              ),
          ],
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.order});

  final SellerOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: atelier.raised,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: atelier.line),
      ),
      child: Column(
        children: [
          _Row(
            label: l10n.sellerOrderItemsSubtotal,
            value: order.itemsSubtotal,
          ),
          if (!order.discountTotal.isZero)
            _Row(
              label: l10n.sellerOrderDiscount,
              value: order.discountTotal,
              isNegative: true,
            ),
          _Row(
            label: l10n.sellerOrderCommission,
            value: order.summary.commission,
            isNegative: true,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
            child: Divider(height: 1, color: atelier.line),
          ),

          _Row(
            label: l10n.sellerOrderNet,
            value: order.summary.net,
            emphasise: true,
          ),

          const SizedBox(height: DsSpacing.sm),
          // Q24 — the seller's money is escrowed until the return window
          // closes. Saying when turns "لماذا لم أُدفع؟" into a date.
          Row(
            children: [
              Icon(
                order.escrowReleased ? Icons.lock_open : Icons.lock_outline,
                size: 14,
                color: order.escrowReleased ? atelier.positive : atelier.muted,
              ),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  _escrowNote(context, order),
                  style: context.dsText.caption.tint(atelier.muted).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _escrowNote(BuildContext context, SellerOrderDetail order) {
    final l10n = context.l10n;
    if (order.escrowReleased) return l10n.sellerOrderEscrowReleased;

    final at = order.escrowReleaseAt;
    // No date yet means the parcel has not been delivered: the clock Q56
    // counts starts at the door, not at payment.
    if (at == null) return l10n.sellerOrderEscrowPending;

    return l10n.sellerOrderEscrowOn(
      toWesternDigits(DateFormat('d MMMM', 'ar').format(at)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.isNegative = false,
    this.emphasise = false,
  });

  final String label;
  final Money value;
  final bool isNegative;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        children: [
          Text(
            label,
            style: emphasise
                  ? context.dsText.bodyStrong.tint(atelier.ink)
                  : context.dsText.bodySmall.tint(atelier.muted),
          ),
          const Spacer(),
          // Money keeps the page's own direction, the way it does on the card
          // and in the earnings statement. Only identifiers people read aloud
          // — the order number, the tracking code — are pinned LTR.
          Text(
            '${isNegative ? '−' : ''}${value.format()}',
            style: (emphasise
                    ? context.dsText.tileTitle.bold.tint(atelier.gold)
                    : context.dsText.bodySmall.tint(atelier.ink))
                .tabular,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DsRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: context.dsText.bodySmall.tint(tone).copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pinned action bar.
///
/// Only the moves the server said are available appear, and the destructive
/// one never sits where a thumb lands by accident — cancelling is a text
/// button beside the primary, not a second big block under it.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.order,
    required this.isBusy,
    required this.onAction,
  });

  final SellerOrderDetail order;
  final bool isBusy;
  final void Function(SellerOrderAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;
    final primary = order.summary.primaryAction;
    final canCancel = order.actions.contains(SellerOrderAction.cancel);

    if (primary == null && !canCancel) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: atelier.surface,
        border: Border(top: BorderSide(color: atelier.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (primary != null)
              Expanded(
                child: DsButton(
                  label: l10n.parcelAction(primary),
                  isLoading: isBusy,
                  onPressed: isBusy ? null : () => onAction(primary),
                ),
              ),
            if (primary != null && canCancel) const SizedBox(width: DsSpacing.sm),
            if (canCancel)
              TextButton(
                onPressed: isBusy
                    ? null
                    : () => onAction(SellerOrderAction.cancel),
                child: Text(
                  l10n.parcelAction(SellerOrderAction.cancel),
                  style: context.dsText.body.tint(atelier.critical),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.md),
      child: DsShimmer(
        child: Column(
          children: [
            DsSkeleton.box(height: 140),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 120),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 180),
          ],
        ),
      ),
    );
  }
}
