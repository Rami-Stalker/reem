import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/arabic_numerals.dart';
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        child: Ink(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The number is the thing she quotes on the phone, so
                        // it is pinned LTR: an order number with Arabic digit
                        // shaping around it becomes unreadable aloud.
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            order.number,
                            textAlign: TextAlign.left,
                            style: context.dsText.tileTitle.bold.tint(atelier.ink),
                          ),
                        ),
                        DsGaps.vXxxs,
                        Text(
                          _subtitle(context),
                          style: context.dsText.bodySmall.tint(atelier.muted),
                        ),
                      ],
                    ),
                  ),
                  SellerOrderStatusChip(status: order.status),
                ],
              ),

              const SizedBox(height: DsSpacing.sm),
              Divider(height: 1, color: atelier.line),
              const SizedBox(height: DsSpacing.sm),

              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: atelier.muted),
                  DsGaps.hXxs,
                  Expanded(
                    child: Text(
                      order.customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.bodySmall.tint(atelier.ink),
                    ),
                  ),

                  // Her share, not the customer's total. Gold, because on this
                  // screen it is the only number that is hers.
                  Text(
                    order.net.format(),
                    style: context.dsText.tileTitle.bold.tint(atelier.gold),
                  ),
                ],
              ),

              if (order.isCashOnDelivery && !order.isPaid) ...[
                const SizedBox(height: DsSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: atelier.caution,
                    ),
                    DsGaps.hXxs,
                    Text(
                      l10n.sellerOrderCashOnDelivery,
                      style: context.dsText.caption.tint(atelier.caution),
                    ),
                  ],
                ),
              ],

              // Only shown when the platform actually wants her to do
              // something differently. A "low risk" line on ninety per cent of
              // her queue is a line she stops reading, and then the one that
              // matters is invisible too.
              if (order.codRisk case final risk?
                  when risk.isElevated || risk.awaitingConfirmation) ...[
                const SizedBox(height: DsSpacing.xs),
                Row(
                  children: [
                    Icon(
                      risk.awaitingConfirmation
                          ? Icons.hourglass_empty_rounded
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: risk.tier == 'high'
                          ? atelier.caution
                          : atelier.muted,
                    ),
                    DsGaps.hXxs,
                    Expanded(
                      child: Text(
                        risk.awaitingConfirmation
                            ? l10n.sellerOrderAwaitingCustomerCode
                            : risk.label,
                        style: context.dsText.caption.tint(risk.tier == 'high'
                              ? atelier.caution
                              : atelier.muted),
                      ),
                    ),
                  ],
                ),
              ],

              if (primary != null || canCancel) ...[
                const SizedBox(height: DsSpacing.md),
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
                    if (primary != null && canCancel)
                      const SizedBox(width: DsSpacing.xs),
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
          ),
        ),
      ),
    );
  }

  /// «قطعتان • 26 آب • 09:12».
  ///
  /// The piece count goes through the shared plural rather than an
  /// `if (count == 1)`: Arabic has six plural categories, and two of them
  /// cover most of a busy shop's rows.
  String _subtitle(BuildContext context) {
    final when = toWesternDigits(
      // l10n-ignore: an intl pattern; the locale supplies the words
      DateFormat('d MMM • HH:mm', 'ar').format(order.placedAt),
    );
    return '${context.l10n.itemsCount(order.itemsCount)} • $when';
  }
}
