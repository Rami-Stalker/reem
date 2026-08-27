import 'package:equatable/equatable.dart';

import '../../../../core/shared/value_objects/money.dart';
import '../../../checkout/domain/entities/order.dart' show SellerOrderStatus;

export '../../../checkout/domain/entities/order.dart' show SellerOrderStatus;

/// How a parcel reaches the customer (Q57) — and therefore what the seller is
/// allowed to see and to do with it.
enum FulfilmentMode {
  platformCourier,
  thirdPartyCarrier,
  sellerShips,
  pickupPoint;

  static FulfilmentMode fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'SELLER_SHIPS' => FulfilmentMode.sellerShips,
        'THIRD_PARTY_CARRIER' => FulfilmentMode.thirdPartyCarrier,
        'PICKUP_POINT' => FulfilmentMode.pickupPoint,
        _ => FulfilmentMode.platformCourier,
      };

  /// True when the seller is the one knocking on the door.
  bool get isSelfCarried => this == FulfilmentMode.sellerShips;
}

/// The tabs the seller's queue is organised by, in the order she works them.
///
/// The names match the backend's own grouping exactly — the counts come back
/// keyed by these, and a tab the server does not know about would render a
/// badge that never changes.
enum SellerQueueTab {
  newOrders('new'),
  preparing('preparing'),
  ready('ready'),
  shipping('shipping'),
  returns('returns'),
  completed('completed');

  const SellerQueueTab(this.wire);

  final String wire;

}

/// One thing the seller may do to this parcel *right now*.
///
/// The list comes from the server, which derives it from the same lifecycle
/// table that will judge the request. Nothing here is inferred client-side: a
/// button the backend would refuse teaches a seller to distrust the app.
enum SellerOrderAction {
  confirm,
  ready,
  handOver,
  deliver,
  cancel;

  static SellerOrderAction? fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'confirm' => SellerOrderAction.confirm,
        'ready' => SellerOrderAction.ready,
        'hand_over' => SellerOrderAction.handOver,
        'deliver' => SellerOrderAction.deliver,
        'cancel' => SellerOrderAction.cancel,
        _ => null,
      };

  /// Whether pressing it needs something from her first.
  bool get needsInput =>
      this == SellerOrderAction.cancel || this == SellerOrderAction.deliver;

  bool get isDestructive => this == SellerOrderAction.cancel;
}

/// What the seller is shown of the customer.
///
/// Q57 makes this depend on the shipping method, which is the only reading
/// under which Q44's masking and self-shipping can both hold. The server
/// decides; the client only has to render the decision — and to say *why*
/// something is hidden, so a seller does not think the app is broken.
class SellerOrderCustomer extends Equatable {
  const SellerOrderCustomer({
    required this.name,
    required this.isMasked,
    this.phone,
    this.governorate,
    this.city,
    this.district,
    this.addressLine,
    this.landmark,
    this.deliveryInstructions,
    this.maskedBecause,
  });

  final String name;
  final bool isMasked;
  final String? phone;
  final String? governorate;
  final String? city;
  final String? district;
  final String? addressLine;
  final String? landmark;
  final String? deliveryInstructions;

  /// The server's own explanation for the masking, in Arabic.
  final String? maskedBecause;

  /// The address as one line, skipping the parts she was not given.
  String get addressSummary => [
    governorate,
    city,
    district,
    addressLine,
  ].where((part) => part != null && part.trim().isNotEmpty).join('، ');

  bool get hasAddress => addressLine != null && addressLine!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    name,
    isMasked,
    phone,
    governorate,
    city,
    district,
    addressLine,
    landmark,
    deliveryInstructions,
    maskedBecause,
  ];
}

/// One line of the parcel, as it was bought.
class SellerOrderLine extends Equatable {
  const SellerOrderLine({
    required this.id,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variant,
    this.image,
    this.customisation,
  });

  final String id;
  final String title;
  final int quantity;
  final Money unitPrice;
  final Money lineTotal;
  final String? variant;
  final String? image;

  /// Q30 — the made-to-order payload: engraved text, an uploaded reference,
  /// a due date. Shown verbatim, because it is an instruction to her.
  final Map<String, dynamic>? customisation;

  @override
  List<Object?> get props => [id, title, quantity, variant];
}

/// The parcel's journey, when the platform is carrying it.
class SellerParcelShipment extends Equatable {
  const SellerParcelShipment({
    required this.trackingCode,
    required this.status,
    required this.isAssigned,
  });

  final String trackingCode;
  final String status;

  /// Whether a courier has been put on it yet.
  final bool isAssigned;

  @override
  List<Object?> get props => [trackingCode, status, isAssigned];
}

/// A parcel as it appears in the seller's queue.
class SellerOrderSummary extends Equatable {
  const SellerOrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.fulfilmentMode,
    required this.placedAt,
    required this.itemsCount,
    required this.net,
    required this.commission,
    required this.customer,
    required this.actions,
    this.paymentMethod,
    this.paymentStatus,
    this.trackingCode,
  });

  final String id;
  final String number;
  final SellerOrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final DateTime placedAt;
  final int itemsCount;

  /// What she keeps, and what the platform took. Never the customer's total —
  /// quoting a gross she was never going to receive only starts arguments.
  final Money net;
  final Money commission;

  final SellerOrderCustomer customer;
  final List<SellerOrderAction> actions;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? trackingCode;

  bool get isCashOnDelivery =>
      paymentMethod == 'COD' || paymentMethod == 'COURIER_COLLECT';

  bool get isPaid => paymentStatus == 'PAID';

  /// The one action a card puts forward. Everything else lives behind the
  /// overflow, so the queue reads as a single column of next steps.
  SellerOrderAction? get primaryAction => actions
      .where((action) => action != SellerOrderAction.cancel)
      .firstOrNull;

  @override
  List<Object?> get props => [id, number, status, actions];
}

/// Everything about one parcel, for the screen she opens to work it.
class SellerOrderDetail extends Equatable {
  const SellerOrderDetail({
    required this.summary,
    required this.orderNumber,
    required this.currency,
    required this.itemsSubtotal,
    required this.discountTotal,
    required this.shippingCost,
    required this.commissionBase,
    required this.items,
    required this.escrowReleased,
    this.shipment,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.escrowReleaseAt,
    this.cancellationReason,
  });

  final SellerOrderSummary summary;
  final String orderNumber;
  final Currency currency;
  final Money itemsSubtotal;
  final Money discountTotal;
  final Money shippingCost;

  /// What the commission was charged on.
  ///
  /// Usually the goods after her discount (Q50) — but a platform-funded coupon
  /// (Q49 P2) leaves it at the full price, because she sold at full price and
  /// the platform made up the difference. Her net and the commission always
  /// add back up to *this*, never to what the customer paid.
  final Money commissionBase;
  final List<SellerOrderLine> items;
  final SellerParcelShipment? shipment;

  /// Q24 — when her money stops being escrowed, and whether it already has.
  final bool escrowReleased;
  final DateTime? escrowReleaseAt;

  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? cancellationReason;

  String get id => summary.id;
  SellerOrderStatus get status => summary.status;
  List<SellerOrderAction> get actions => summary.actions;

  @override
  List<Object?> get props => [summary, items, shipment, escrowReleased];
}

/// The seller's queue: her parcels, and how many are waiting in each tab.
class SellerOrderQueue extends Equatable {
  const SellerOrderQueue({
    required this.orders,
    required this.counts,
    this.hasMore = false,
  });

  final List<SellerOrderSummary> orders;

  /// Keyed by [SellerQueueTab.wire]. Counts cover her whole shop, not the
  /// current page — a badge that only counted what was loaded would fall as
  /// she scrolled.
  final Map<String, int> counts;
  final bool hasMore;

  int countFor(SellerQueueTab tab) => counts[tab.wire] ?? 0;

  /// The tabs that need her attention now, for the home screen's strip.
  int get needsAttention =>
      countFor(SellerQueueTab.newOrders) +
      countFor(SellerQueueTab.preparing) +
      countFor(SellerQueueTab.returns);

  @override
  List<Object?> get props => [orders, counts, hasMore];
}

/// What the shared lifecycle means to a seller.
///
/// The wording lives in the ARB bundles (see `seller_order_labels.dart`);
/// what belongs here is the one question the queue asks of a status that the
/// customer's side never asks.
extension SellerParcelWork on SellerOrderStatus {
  /// Whether this parcel is still work: something she has to do or wait for.
  bool get isOpenForSeller => const {
    SellerOrderStatus.newOrder,
    SellerOrderStatus.awaitingSellerConfirmation,
    SellerOrderStatus.preparing,
    SellerOrderStatus.readyToShip,
    SellerOrderStatus.handedToCourier,
    SellerOrderStatus.inTransit,
    SellerOrderStatus.deliveryFailed,
    SellerOrderStatus.returnRequested,
    SellerOrderStatus.returnInTransit,
    SellerOrderStatus.returned,
    SellerOrderStatus.exchangeInProgress,
    SellerOrderStatus.disputed,
  }.contains(this);
}
