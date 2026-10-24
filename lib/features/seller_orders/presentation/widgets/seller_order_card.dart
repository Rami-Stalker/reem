import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';
import 'package:reem/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:reem/features/seller_orders/presentation/widgets/seller_order_status_chip.dart';

/// One parcel in the seller's queue.
///
/// The card answers, top to bottom, the three questions she asks of every row:
/// *what is it*, *what do I get*, and *what do I do next*. The primary action
/// is a real button rather than a chevron into a detail screen — a seller
/// clearing twenty new orders in the morning should not have to open twenty
/// screens to say yes.
class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({
    super.key,
    required this.order,
    required this.onOpen,
    required this.onAction,
    this.isBusy = false,
  });

  final SellerOrderSummary order;
  final VoidCallback onOpen;
  final void Function(SellerOrderAction action) onAction;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;
    final primary = order.primaryAction;
    final canCancel = order.actions.contains(SellerOrderAction.cancel);

    final tone = SellerOrderStatusChip.toneOf(order.status, atelier);

    // The job on the ticket's body; her money and the parcel's state on the
    // tear-off stub, tinted in the state's colour.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The number is the thing she quotes on the phone, so it is pinned
        // LTR: an order number with Arabic digit shaping around it becomes
        // unreadable aloud.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            order.number,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.tileTitle.bold.tint(atelier.ink),
          ),
        ),
        DsGaps.vXxxs,
        Text(
          _subtitle(context),
          style: context.dsText.bodySmall.tint(atelier.muted),
        ),
        DsGaps.vSm,
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: DsSizes.iconXs,
              color: atelier.muted,
            ),
            DsGaps.hXxs,
            Expanded(
              child: Text(
                order.customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.bodySmall.tint(atelier.ink),
              ),
            ),
          ],
        ),
        if (order.isCashOnDelivery && !order.isPaid) ...[
          DsGaps.vXs,
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: DsSizes.iconXxs,
                color: atelier.caution,
              ),
              DsGaps.hXxs,
              Flexible(
                child: Text(
                  l10n.sellerOrderCashOnDelivery,
                  style: context.dsText.caption.tint(atelier.caution),
                ),
              ),
            ],
          ),
        ],
        // Only shown when the platform actually wants her to do something
        // differently. A "low risk" line on ninety per cent of her queue is a
        // line she stops reading, and then the one that matters is invisible
        // too.
        if (order.codRisk case final risk?
            when risk.isElevated || risk.awaitingConfirmation) ...[
          DsGaps.vXs,
          Row(
            children: [
              Icon(
                risk.awaitingConfirmation
                    ? Icons.hourglass_empty_rounded
                    : Icons.info_outline_rounded,
                size: DsSizes.iconXxs,
                color: risk.tier == 'high' ? atelier.caution : atelier.muted,
              ),
              DsGaps.hXxs,
              Expanded(
                child: Text(
                  risk.awaitingConfirmation
                      ? l10n.sellerOrderAwaitingCustomerCode
                      : risk.label,
                  style: context.dsText.caption.tint(
                    risk.tier == 'high' ? atelier.caution : atelier.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (primary != null || canCancel) ...[
          DsGaps.vMd,
          Row(
            children: [
              if (primary != null)
                Expanded(
                  child: DsButton(
                    label: l10n.parcelAction(primary),
                    size: DsButtonSize.sm,
                    isLoading: isBusy,
                    onPressed: isBusy ? null : () => onAction(primary),
                  ),
                ),
              if (primary != null && canCancel) DsGaps.hXs,
              if (canCancel)
                DsButton(
                  label: l10n.parcelAction(SellerOrderAction.cancel),
                  variant: DsButtonVariant.ghost,
                  size: DsButtonSize.sm,
                  isExpanded: false,
                  onPressed: isBusy
                      ? null
                      : () => onAction(SellerOrderAction.cancel),
                ),
            ],
          ),
        ],
      ],
    );

    final stub = Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.parcelStatus(order.status),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.dsText.captionStrong.tint(tone),
        ),
        // Her share, not the customer's total. Gold, because on this screen
        // it is the only number that is hers.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            order.net.format(),
            textAlign: TextAlign.center,
            style: context.dsText.cardTitle.displayFamily.bold.tint(
              atelier.gold,
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: DsSizes.iconSm, color: tone),
      ],
    );

    return Semantics(
      button: true,
      label: '${order.number}، ${context.l10n.parcelStatus(order.status)}',
      child: OrderTicket(
        onTap: onOpen,
        stubColor: tone,
        body: body,
        stub: stub,
      ),
    );
  }

  /// «قطعتان • 26 آب • 09:12».
  ///
  /// The piece count goes through the shared plural rather than an
  /// `if (count == 1)`: Arabic has six plural categories, and two of them
  /// cover most of a busy shop's rows.
  String _subtitle(BuildContext context) {
    final when = formatCalendarDate(
      context.l10n,
      order.placedAt,
      // l10n-ignore: an intl pattern; the locale supplies the words
      pattern: 'd MMM • HH:mm',
    );
    return '${context.l10n.itemsCount(order.itemsCount)} • $when';
  }
}
