import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Wording for the seller's queue.
///
/// The enums carry no text of their own. That is deliberate: the domain layer
/// has no `BuildContext`, so a label written there can never be translated and
/// — more to the point — never passes under the guard in
/// `test/localization_test.dart` that keeps every Arabic string addressing a
/// woman rather than a man (Q69 P2). Putting the words in the ARB bundles is
/// what makes that check cover this screen too.
///
/// The seller's words are her own, not the customer's. `SellerOrderStatus`
/// already carries customer-facing labels for the same states, and they are
/// written from the other side of the sale: «ألغيتِ الطلب» is true for the
/// woman who cancelled and wrong for the woman reading her queue.
extension SellerOrderLabels on AppLocalizations {
  String parcelStatus(SellerOrderStatus status) => switch (status) {
    SellerOrderStatus.newOrder => sellerParcelStatusNew,
    SellerOrderStatus.awaitingSellerConfirmation =>
      sellerParcelStatusAwaitingConfirmation,
    SellerOrderStatus.preparing => sellerParcelStatusPreparing,
    SellerOrderStatus.readyToShip => sellerParcelStatusReadyToShip,
    SellerOrderStatus.handedToCourier => sellerParcelStatusHandedToCourier,
    SellerOrderStatus.inTransit => sellerParcelStatusInTransit,
    SellerOrderStatus.delivered => sellerParcelStatusDelivered,
    SellerOrderStatus.deliveryFailed => sellerParcelStatusDeliveryFailed,
    SellerOrderStatus.cancelledByCustomer =>
      sellerParcelStatusCancelledByCustomer,
    SellerOrderStatus.cancelledBySeller => sellerParcelStatusCancelledBySeller,
    SellerOrderStatus.rejectedOnDelivery => sellerParcelStatusRejectedOnDelivery,
    SellerOrderStatus.returnRequested => sellerParcelStatusReturnRequested,
    SellerOrderStatus.returnInTransit => sellerParcelStatusReturnInTransit,
    SellerOrderStatus.returned => sellerParcelStatusReturned,
    SellerOrderStatus.exchangeInProgress =>
      sellerParcelStatusExchangeInProgress,
    SellerOrderStatus.exchanged => sellerParcelStatusExchanged,
    SellerOrderStatus.refundPending => sellerParcelStatusRefundPending,
    SellerOrderStatus.refunded => sellerParcelStatusRefunded,
    SellerOrderStatus.disputed => sellerParcelStatusDisputed,
  };

  String parcelAction(SellerOrderAction action) => switch (action) {
    SellerOrderAction.confirm => sellerOrderActionConfirm,
    SellerOrderAction.ready => sellerOrderActionReady,
    SellerOrderAction.handOver => sellerOrderActionHandOver,
    SellerOrderAction.deliver => sellerOrderActionDeliver,
    SellerOrderAction.cancel => sellerOrderActionCancel,
  };

  /// What she is told once the action has actually landed. Separate from the
  /// button's own label because "قبول الطلب" is a request and "قبلتِ الطلب"
  /// is a fact, and telling her the first after the second has happened is how
  /// an app makes a woman press a button twice.
  String parcelActionDone(SellerOrderAction action) => switch (action) {
    SellerOrderAction.confirm => sellerOrderConfirmed,
    SellerOrderAction.ready => sellerOrderMarkedReady,
    SellerOrderAction.handOver => sellerOrderHandedOver,
    SellerOrderAction.deliver => sellerOrderDelivered,
    SellerOrderAction.cancel => sellerOrderCancelled,
  };

  String queueTab(SellerQueueTab tab) => switch (tab) {
    SellerQueueTab.newOrders => sellerOrdersTabNew,
    SellerQueueTab.preparing => sellerOrdersTabPreparing,
    SellerQueueTab.ready => sellerOrdersTabReady,
    SellerQueueTab.shipping => sellerOrdersTabShipping,
    SellerQueueTab.returns => sellerOrdersTabReturns,
    SellerQueueTab.completed => sellerOrdersTabCompleted,
  };

  String queueEmptyTitle(SellerQueueTab tab) => switch (tab) {
    SellerQueueTab.newOrders => sellerOrdersEmptyNew,
    SellerQueueTab.preparing => sellerOrdersEmptyPreparing,
    SellerQueueTab.ready => sellerOrdersEmptyReady,
    SellerQueueTab.shipping => sellerOrdersEmptyShipping,
    SellerQueueTab.returns => sellerOrdersEmptyReturns,
    SellerQueueTab.completed => sellerOrdersEmptyCompleted,
  };

  String queueEmptyBody(SellerQueueTab tab) => switch (tab) {
    SellerQueueTab.newOrders => sellerOrdersEmptyNewBody,
    // An empty returns tab is not an empty state to apologise for.
    SellerQueueTab.returns => sellerOrdersEmptyReturnsBody,
    _ => sellerOrdersEmptyBody,
  };

  String fulfilmentMode(FulfilmentMode mode) => switch (mode) {
    FulfilmentMode.platformCourier => sellerFulfilmentPlatformCourier,
    FulfilmentMode.thirdPartyCarrier => sellerFulfilmentThirdParty,
    FulfilmentMode.sellerShips => sellerFulfilmentSelfShips,
    FulfilmentMode.pickupPoint => sellerFulfilmentPickupPoint,
  };
}
