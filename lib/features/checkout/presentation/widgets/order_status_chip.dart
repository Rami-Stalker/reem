import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/presentation/order_labels.dart';
import 'package:reem/l10n/app_localizations.dart';

/// Status pill for an order, a parcel or a payment.
///
/// The label comes from the enum rather than from a humanised wire string, so
/// the nineteen sub-order states each read as Arabic a customer understands
/// instead of "Awaiting Seller Confirmation".
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip._({
    required String Function(AppLocalizations l10n) label,
    required _Tone tone,
  }) : _label = label,
       _tone = tone;

  factory OrderStatusChip({Key? key, required OrderStatus status}) =>
      OrderStatusChip._(
        label: (l10n) => l10n.orderStatusLabel(status),
        tone: _orderTone(status),
      );

  factory OrderStatusChip.parcel(SellerOrderStatus status) => OrderStatusChip._(
    label: (l10n) => l10n.customerParcelStatus(status),
    tone: _parcelTone(status),
  );

  /// For payment and shipment statuses, which stay free-form strings.
  factory OrderStatusChip.raw(String status) => OrderStatusChip._(
    label: (l10n) => l10n.rawStatus(status),
    tone: _rawTone(status),
  );

  final String Function(AppLocalizations l10n) _label;
  final _Tone _tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = switch (_tone) {
      _Tone.success => colors.success,
      _Tone.info => colors.info,
      _Tone.primary => colors.primary,
      _Tone.warning => colors.warning,
      _Tone.danger => colors.error,
      _Tone.muted => colors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label(context.l10n),
        style: context.dsText.bodySmall.semibold.tint(color),
      ),
    );
  }
}

enum _Tone { success, info, primary, warning, danger, muted }

_Tone _orderTone(OrderStatus status) => switch (status) {
  OrderStatus.delivered || OrderStatus.closed => _Tone.success,
  OrderStatus.shipped || OrderStatus.partiallyShipped => _Tone.info,
  OrderStatus.confirmed || OrderStatus.partiallyDelivered => _Tone.primary,
  OrderStatus.pendingPayment || OrderStatus.draft => _Tone.warning,
  OrderStatus.cancelled => _Tone.danger,
  OrderStatus.partiallyCancelled => _Tone.warning,
};

_Tone _parcelTone(SellerOrderStatus status) => switch (status) {
  SellerOrderStatus.delivered || SellerOrderStatus.exchanged => _Tone.success,
  SellerOrderStatus.handedToCourier ||
  SellerOrderStatus.inTransit => _Tone.info,
  SellerOrderStatus.preparing ||
  SellerOrderStatus.readyToShip ||
  SellerOrderStatus.newOrder ||
  SellerOrderStatus.awaitingSellerConfirmation => _Tone.primary,
  SellerOrderStatus.returnRequested ||
  SellerOrderStatus.returnInTransit ||
  SellerOrderStatus.exchangeInProgress ||
  SellerOrderStatus.refundPending => _Tone.warning,
  SellerOrderStatus.deliveryFailed ||
  SellerOrderStatus.rejectedOnDelivery ||
  SellerOrderStatus.cancelledByCustomer ||
  SellerOrderStatus.cancelledBySeller ||
  SellerOrderStatus.disputed => _Tone.danger,
  SellerOrderStatus.returned || SellerOrderStatus.refunded => _Tone.muted,
};

_Tone _rawTone(String status) => switch (status) {
  'delivered' || 'paid' => _Tone.success,
  'in_transit' || 'out_for_delivery' || 'picked_up' => _Tone.info,
  'pending' || 'created' || 'assigned' => _Tone.warning,
  'failed' || 'cancelled' => _Tone.danger,
  _ => _Tone.muted,
};
