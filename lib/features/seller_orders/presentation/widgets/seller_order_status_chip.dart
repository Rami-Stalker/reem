import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';
import 'package:reem/features/seller_orders/presentation/seller_order_labels.dart';

/// The parcel's state, in the seller's own words.
///
/// Colour carries the same message as the label rather than decorating it:
/// something waiting on *her* is plum, something moving is neutral, something
/// that went wrong is critical. A seller scanning twenty rows reads the colours
/// first and the words only where a colour surprises her.
class SellerOrderStatusChip extends StatelessWidget {
  const SellerOrderStatusChip({super.key, required this.status, this.compact = false});

  final SellerOrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final tone = toneOf(status, atelier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DsSpacing.xs : DsSpacing.sm,
        vertical: compact ? DsSpacing.xxxs : DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Text(
        context.l10n.parcelStatus(status),
        style: (compact
                ? context.dsText.caption.semibold
                : context.dsText.labelStrong)
            .tint(tone),
      ),
    );
  }

  /// The colour a status is drawn in, wherever it is drawn.
  static Color toneOf(SellerOrderStatus status, SellerAtelierPalette atelier) =>
      switch (status) {
        // Waiting on her.
        SellerOrderStatus.newOrder ||
        SellerOrderStatus.awaitingSellerConfirmation ||
        SellerOrderStatus.preparing ||
        SellerOrderStatus.readyToShip => atelier.primary,

        // On the move, nothing for her to do.
        SellerOrderStatus.handedToCourier ||
        SellerOrderStatus.inTransit => atelier.muted,

        // Money earned.
        SellerOrderStatus.delivered ||
        SellerOrderStatus.exchanged => atelier.positive,

        // Something needs attention but is not lost.
        SellerOrderStatus.deliveryFailed ||
        SellerOrderStatus.returnRequested ||
        SellerOrderStatus.returnInTransit ||
        SellerOrderStatus.returned ||
        SellerOrderStatus.exchangeInProgress ||
        SellerOrderStatus.refundPending => atelier.caution,

        // Lost, refused or contested.
        SellerOrderStatus.cancelledByCustomer ||
        SellerOrderStatus.cancelledBySeller ||
        SellerOrderStatus.rejectedOnDelivery ||
        SellerOrderStatus.refunded ||
        SellerOrderStatus.disputed => atelier.critical,
      };
}
