import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/order.dart';

/// Fallback for free-form status strings (payment status, shipment status).
String humanizeStatus(String status) => switch (status) {
      'pending' => 'قيد الانتظار',
      'paid' => 'مدفوع',
      'failed' => 'فشل',
      'refunded' => 'مُسترد',
      'created' => 'تم الإنشاء',
      'assigned' => 'أُسند لمندوب',
      'picked_up' => 'تم الاستلام',
      'in_transit' => 'بالطريق',
      'out_for_delivery' => 'خارج للتسليم',
      'delivered' => 'تم التسليم',
      'returning' => 'قيد الإرجاع',
      'returned' => 'تم الإرجاع',
      'cancelled' => 'ملغى',
      _ => status
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
    };

/// Status pill for an order, a parcel or a payment.
///
/// The label comes from the enum rather than from a humanised wire string, so
/// the nineteen sub-order states each read as Arabic a customer understands
/// instead of "Awaiting Seller Confirmation".
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip._({
    required this.label,
    required this.tone,
  });

  factory OrderStatusChip({Key? key, required OrderStatus status}) =>
      OrderStatusChip._(label: status.label, tone: _orderTone(status));

  factory OrderStatusChip.parcel(SellerOrderStatus status) =>
      OrderStatusChip._(label: status.label, tone: _parcelTone(status));

  /// For payment and shipment statuses, which stay free-form strings.
  factory OrderStatusChip.raw(String status) => OrderStatusChip._(
        label: humanizeStatus(status),
        tone: _rawTone(status),
      );

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = switch (tone) {
      _Tone.success => colors.success,
      _Tone.info => colors.info,
      _Tone.primary => colors.primary,
      _Tone.warning => colors.warning,
      _Tone.danger => colors.error,
      _Tone.muted => colors.onSurfaceVariant,
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: DsTypography.fontFamily,
          fontSize: DsTypography.bodySmall,
          fontWeight: DsTypography.semiBold,
          color: color,
        ),
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
      SellerOrderStatus.delivered ||
      SellerOrderStatus.exchanged =>
        _Tone.success,
      SellerOrderStatus.handedToCourier ||
      SellerOrderStatus.inTransit =>
        _Tone.info,
      SellerOrderStatus.preparing ||
      SellerOrderStatus.readyToShip ||
      SellerOrderStatus.newOrder ||
      SellerOrderStatus.awaitingSellerConfirmation =>
        _Tone.primary,
      SellerOrderStatus.returnRequested ||
      SellerOrderStatus.returnInTransit ||
      SellerOrderStatus.exchangeInProgress ||
      SellerOrderStatus.refundPending =>
        _Tone.warning,
      SellerOrderStatus.deliveryFailed ||
      SellerOrderStatus.rejectedOnDelivery ||
      SellerOrderStatus.cancelledByCustomer ||
      SellerOrderStatus.cancelledBySeller ||
      SellerOrderStatus.disputed =>
        _Tone.danger,
      SellerOrderStatus.returned || SellerOrderStatus.refunded => _Tone.muted,
    };

_Tone _rawTone(String status) => switch (status) {
      'delivered' || 'paid' => _Tone.success,
      'in_transit' || 'out_for_delivery' || 'picked_up' => _Tone.info,
      'pending' || 'created' || 'assigned' => _Tone.warning,
      'failed' || 'cancelled' => _Tone.danger,
      _ => _Tone.muted,
    };
