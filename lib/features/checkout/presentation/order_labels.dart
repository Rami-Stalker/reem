import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Wording for the customer's orders.
///
/// The mirror of `seller_order_labels.dart`: the enums carry no text, so every
/// word passes through the ARB bundles — translated, and covered by the guard
/// in `test/localization_test.dart`. These are the customer's words: «ألغيتِ
/// الطلب» is true for her, which is why the seller's queue has its own set.
extension OrderLabels on AppLocalizations {
  String orderStatusLabel(OrderStatus status) => switch (status) {
    OrderStatus.draft => orderStateDraft,
    OrderStatus.pendingPayment => orderStatePendingPayment,
    OrderStatus.confirmed => orderStateConfirmed,
    OrderStatus.partiallyShipped => orderStatePartiallyShipped,
    OrderStatus.shipped => orderStateShipped,
    OrderStatus.partiallyDelivered => orderStatePartiallyDelivered,
    OrderStatus.delivered => orderStateDelivered,
    OrderStatus.partiallyCancelled => orderStatePartiallyCancelled,
    OrderStatus.cancelled => orderStateCancelled,
    OrderStatus.closed => orderStateClosed,
  };

  String customerParcelStatus(SellerOrderStatus status) => switch (status) {
    SellerOrderStatus.newOrder => parcelStateNew,
    SellerOrderStatus.awaitingSellerConfirmation => parcelStateAwaitingSeller,
    SellerOrderStatus.preparing => parcelStatePreparing,
    SellerOrderStatus.readyToShip => parcelStateReadyToShip,
    SellerOrderStatus.handedToCourier => parcelStateHandedToCourier,
    SellerOrderStatus.inTransit => parcelStateInTransit,
    SellerOrderStatus.delivered => parcelStateDelivered,
    SellerOrderStatus.deliveryFailed => parcelStateDeliveryFailed,
    SellerOrderStatus.cancelledByCustomer => parcelStateCancelledByYou,
    SellerOrderStatus.cancelledBySeller => parcelStateCancelledBySeller,
    SellerOrderStatus.rejectedOnDelivery => parcelStateRejectedOnDelivery,
    SellerOrderStatus.returnRequested => parcelStateReturnRequested,
    SellerOrderStatus.returnInTransit => parcelStateReturnInTransit,
    SellerOrderStatus.returned => parcelStateReturned,
    SellerOrderStatus.exchangeInProgress => parcelStateExchangeInProgress,
    SellerOrderStatus.exchanged => parcelStateExchanged,
    SellerOrderStatus.refundPending => parcelStateRefundPending,
    SellerOrderStatus.refunded => parcelStateRefunded,
    SellerOrderStatus.disputed => parcelStateDisputed,
  };

  String paymentMethodName(String method) => switch (method) {
    'cod' => payMethodCod,
    'courier_collect' => payMethodCourierCollect,
    'syriatel_cash' => payMethodSyriatelCash,
    'mtn_cash' => payMethodMtnCash,
    'sham_cash' => payMethodShamCash,
    'bank_card' => payMethodBankCard,
    'bank_transfer' => payMethodBankTransfer,
    'hawala' => payMethodHawala,
    'platform_wallet' => payMethodWallet,
    _ => method,
  };

  /// Payment and shipment statuses, which stay free-form strings on the wire.
  String rawStatus(String status) => switch (status) {
    'pending' => rawStatePending,
    'paid' => rawStatePaid,
    'failed' => rawStateFailed,
    'refunded' => rawStateRefunded,
    'created' => rawStateCreated,
    'assigned' => rawStateAssigned,
    'picked_up' => rawStatePickedUp,
    'in_transit' => rawStateInTransit,
    'out_for_delivery' => rawStateOutForDelivery,
    'delivered' => rawStateDelivered,
    'returning' => rawStateReturning,
    'returned' => rawStateReturned,
    'cancelled' => rawStateCancelled,
    _ =>
      status
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
  };

  /// A timeline entry in her words.
  ///
  /// The server writes these rows in English («Order created», «Sent to the
  /// sellers for preparation») and they are stored that way, so the words are
  /// chosen here from the status the row moved to. A row the app cannot name
  /// keeps the server's title.
  String orderEventTitle(OrderEvent event) {
    if (event.fromStatus == null &&
        OrderStatus.fromWire(event.toStatus) == OrderStatus.pendingPayment) {
      return orderTimelineCreated;
    }
    return switch (OrderStatus.fromWire(event.toStatus)) {
      OrderStatus.confirmed => orderTimelineConfirmed,
      OrderStatus.cancelled => orderTimelineCancelled,
      OrderStatus.draft => event.title,
      final status => orderStatusLabel(status),
    };
  }

  /// The line under a timeline entry, when there is one worth saying.
  String? orderEventDescription(OrderEvent event) {
    final status = OrderStatus.fromWire(event.toStatus);
    if (status == OrderStatus.confirmed) return orderTimelineConfirmedBody;
    if (status == OrderStatus.cancelled &&
        event.title.toLowerCase().contains('deadline')) {
      return orderTimelinePaymentExpired;
    }
    // The stored sentence is English; it is only said where English is read.
    return localeName.startsWith('ar') ? null : event.description;
  }
}
