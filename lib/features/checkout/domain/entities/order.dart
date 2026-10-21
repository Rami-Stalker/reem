import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';

/// The lifecycle of one seller's parcel.
///
/// The client enumerated fourteen states and added five more (Q37). They live
/// on the SUB-order, because in a basket spanning three sellers one parcel can
/// be delivered while another is still being prepared.
enum SellerOrderStatus {
  newOrder,
  awaitingSellerConfirmation,
  preparing,
  readyToShip,
  handedToCourier,
  inTransit,
  delivered,
  deliveryFailed,
  cancelledByCustomer,
  cancelledBySeller,
  rejectedOnDelivery,
  returnRequested,
  returnInTransit,
  returned,
  exchangeInProgress,
  exchanged,
  refundPending,
  refunded,
  disputed;

  static SellerOrderStatus fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'awaiting_seller_confirmation' =>
          SellerOrderStatus.awaitingSellerConfirmation,
        'preparing' => SellerOrderStatus.preparing,
        'ready_to_ship' => SellerOrderStatus.readyToShip,
        'handed_to_courier' => SellerOrderStatus.handedToCourier,
        'in_transit' => SellerOrderStatus.inTransit,
        'delivered' => SellerOrderStatus.delivered,
        'delivery_failed' => SellerOrderStatus.deliveryFailed,
        'cancelled_by_customer' => SellerOrderStatus.cancelledByCustomer,
        'cancelled_by_seller' => SellerOrderStatus.cancelledBySeller,
        'rejected_on_delivery' => SellerOrderStatus.rejectedOnDelivery,
        'return_requested' => SellerOrderStatus.returnRequested,
        'return_in_transit' => SellerOrderStatus.returnInTransit,
        'returned' => SellerOrderStatus.returned,
        'exchange_in_progress' => SellerOrderStatus.exchangeInProgress,
        'exchanged' => SellerOrderStatus.exchanged,
        'refund_pending' => SellerOrderStatus.refundPending,
        'refunded' => SellerOrderStatus.refunded,
        'disputed' => SellerOrderStatus.disputed,
        _ => SellerOrderStatus.newOrder,
      };

  String get label => switch (this) {
        SellerOrderStatus.newOrder => 'طلب جديد',
        SellerOrderStatus.awaitingSellerConfirmation => 'بانتظار تأكيد البائعة',
        SellerOrderStatus.preparing => 'قيد التجهيز',
        SellerOrderStatus.readyToShip => 'جاهز للشحن',
        SellerOrderStatus.handedToCourier => 'تم التسليم للمندوب',
        SellerOrderStatus.inTransit => 'بالطريق',
        SellerOrderStatus.delivered => 'تم التسليم',
        SellerOrderStatus.deliveryFailed => 'فشل التسليم',
        SellerOrderStatus.cancelledByCustomer => 'ألغيتِ الطلب',
        SellerOrderStatus.cancelledBySeller => 'ألغته البائعة',
        SellerOrderStatus.rejectedOnDelivery => 'مرفوض عند الاستلام',
        SellerOrderStatus.returnRequested => 'طلب إرجاع',
        SellerOrderStatus.returnInTransit => 'قيد الإرجاع',
        SellerOrderStatus.returned => 'تم الإرجاع',
        SellerOrderStatus.exchangeInProgress => 'قيد الاستبدال',
        SellerOrderStatus.exchanged => 'تم الاستبدال',
        SellerOrderStatus.refundPending => 'قيد الاسترداد المالي',
        SellerOrderStatus.refunded => 'تم الاسترداد',
        SellerOrderStatus.disputed => 'قيد النزاع',
      };

  /// Q38 — the customer may cancel until the parcel is handed over.
  bool get isCancellableByCustomer => const {
        SellerOrderStatus.newOrder,
        SellerOrderStatus.awaitingSellerConfirmation,
        SellerOrderStatus.preparing,
        SellerOrderStatus.readyToShip,
      }.contains(this);

  bool get isTerminal => const {
        SellerOrderStatus.refunded,
        SellerOrderStatus.exchanged,
        SellerOrderStatus.cancelledByCustomer,
        SellerOrderStatus.cancelledBySeller,
      }.contains(this);

  bool get isDelivered => this == SellerOrderStatus.delivered;
}

/// The customer-facing roll-up of every sub-order.
enum OrderStatus {
  draft,
  pendingPayment,
  confirmed,
  partiallyShipped,
  shipped,
  partiallyDelivered,
  delivered,
  partiallyCancelled,
  cancelled,
  closed;

  static OrderStatus fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'pending_payment' => OrderStatus.pendingPayment,
        'confirmed' => OrderStatus.confirmed,
        'partially_shipped' => OrderStatus.partiallyShipped,
        'shipped' => OrderStatus.shipped,
        'partially_delivered' => OrderStatus.partiallyDelivered,
        'delivered' => OrderStatus.delivered,
        'partially_cancelled' => OrderStatus.partiallyCancelled,
        'cancelled' => OrderStatus.cancelled,
        'closed' => OrderStatus.closed,
        _ => OrderStatus.draft,
      };

  /// True while the order can still change on its own — a seller preparing,
  /// a courier on the road. What the tracking screen watches.
  bool get isInFlight => const {
    OrderStatus.pendingPayment,
    OrderStatus.confirmed,
    OrderStatus.partiallyShipped,
    OrderStatus.shipped,
    OrderStatus.partiallyDelivered,
  }.contains(this);

  String get label => switch (this) {
        OrderStatus.draft => 'مسودّة',
        OrderStatus.pendingPayment => 'بانتظار الدفع',
        OrderStatus.confirmed => 'مؤكّد',
        OrderStatus.partiallyShipped => 'شُحن جزئياً',
        OrderStatus.shipped => 'تم الشحن',
        OrderStatus.partiallyDelivered => 'سُلّم جزئياً',
        OrderStatus.delivered => 'تم التسليم',
        OrderStatus.partiallyCancelled => 'أُلغي جزئياً',
        OrderStatus.cancelled => 'ملغى',
        OrderStatus.closed => 'مغلق',
      };
}

class OrderItemLine extends Equatable {
  final String id;
  final String? offerId;
  final String? productId;
  final String title;
  final String? image;
  final String? variantName;

  /// The seller's name as it was at purchase time — a snapshot, so the line
  /// still reads correctly if the seller later renames their store.
  final String sellerName;

  final int quantity;
  final Money unitPrice;
  final Money lineTotal;

  const OrderItemLine({
    required this.id,
    required this.title,
    required this.sellerName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.offerId,
    this.productId,
    this.image,
    this.variantName,
  });

  @override
  List<Object?> get props =>
      [id, offerId, productId, variantName, quantity, lineTotal];
}

class OrderShipment extends Equatable {
  final String id;
  final String trackingCode;
  final String status;
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final String? proofImageUrl;
  final String? failureReason;
  final int attemptCount;
  final Money? codAmount;

  /// The delivery company carrying this parcel, when one is.
  ///
  /// Reem does not run drivers: past the seller's door a parcel belongs to a
  /// carrier, and the two things a woman needs then are its name and its own
  /// number for her box.
  final OrderCarrier? carrier;

  const OrderShipment({
    required this.id,
    required this.trackingCode,
    required this.status,
    this.scheduledFor,
    this.deliveredAt,
    this.proofImageUrl,
    this.failureReason,
    this.attemptCount = 0,
    this.codAmount,
    this.carrier,
  });

  @override
  List<Object?> get props => [id, trackingCode, status, deliveredAt, carrier];
}

/// What the app is told about a delivery company.
///
/// Deliberately four fields. The app has no carrier credential, calls no
/// carrier API and knows nothing about drivers or routes — everything about
/// the integration lives on the server, and this is the part a customer or a
/// seller is allowed to read.
class OrderCarrier extends Equatable {
  final String name;
  final String status;
  final String? trackingNumber;
  final String? trackingUrl;

  const OrderCarrier({
    required this.name,
    required this.status,
    this.trackingNumber,
    this.trackingUrl,
  });

  @override
  List<Object?> get props => [name, status, trackingNumber, trackingUrl];
}

/// One seller's parcel within an order.
class SellerOrder extends Equatable {
  final String id;
  final String number;
  final String sellerId;
  final String sellerName;
  final String? sellerImageUrl;

  final SellerOrderStatus status;
  final String fulfilmentMode;

  final Money itemsSubtotal;
  final Money discountTotal;
  final Money shippingCost;

  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? cancellationReason;

  final List<OrderItemLine> items;
  final OrderShipment? shipment;
  final List<OrderEvent> timeline;

  const SellerOrder({
    required this.id,
    required this.number,
    required this.sellerId,
    required this.sellerName,
    required this.status,
    required this.itemsSubtotal,
    required this.discountTotal,
    required this.shippingCost,
    this.sellerImageUrl,
    this.fulfilmentMode = 'platform_courier',
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancellationReason,
    this.items = const [],
    this.shipment,
    this.timeline = const [],
  });

  bool get isCancellable => status.isCancellableByCustomer;
  bool get canBeTracked => shipment != null;

  /// Q56 — a return can only be opened on a delivered parcel.
  bool get canRequestReturn => status.isDelivered;

  @override
  List<Object?> get props =>
      [id, number, sellerId, status, itemsSubtotal, items, shipment];
}

/// What a payment rail asks of her once the order is placed. Mirrors the
/// server's `PaymentRail`.
enum PaymentRail {
  /// Cash at the door — nothing to do in the app.
  cash,

  /// Taken from her balance the moment she ordered.
  wallet,

  /// A gateway to visit, which answers back.
  online,

  /// A transfer she makes herself, then tells us the reference for.
  manual;

  static PaymentRail fromWire(String? value) => switch (value) {
    'wallet' => PaymentRail.wallet,
    'online' => PaymentRail.online,
    'manual' => PaymentRail.manual,
    _ => PaymentRail.cash,
  };
}

class OrderPayment extends Equatable {
  final String id;
  final String method;
  final String status;
  final Money amount;
  final Money capturedAmount;
  final Money refundedAmount;
  final String? transactionRef;
  final String? providerRef;
  final DateTime? paidAt;

  /// Which kind of rail this is, from the server rather than guessed from the
  /// method name.
  final PaymentRail rail;

  /// True while the money still needs something from her.
  final bool needsCustomerAction;

  const OrderPayment({
    required this.id,
    required this.method,
    required this.status,
    required this.amount,
    required this.capturedAmount,
    required this.refundedAmount,
    this.transactionRef,
    this.providerRef,
    this.paidAt,
    this.rail = PaymentRail.cash,
    this.needsCustomerAction = false,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  String get methodLabel => switch (method) {
        'cod' => 'الدفع عند الاستلام',
        'courier_collect' => 'الدفع لمندوب الشحن',
        'syriatel_cash' => 'سيرياتيل كاش',
        'mtn_cash' => 'MTN كاش',
        'sham_cash' => 'شام كاش',
        'bank_card' => 'بطاقة بنكية',
        'bank_transfer' => 'تحويل بنكي',
        'hawala' => 'حوالة داخلية',
        'platform_wallet' => 'محفظة المنصة',
        _ => method,
      };

  @override
  List<Object?> get props => [id, method, status, amount, paidAt];
}

/// One attempt at settling a payment: the payment as it now stands, and the
/// gateway link to send her to when there is one.
class PaymentAttempt extends Equatable {
  const PaymentAttempt({required this.payment, this.redirectUrl});

  final OrderPayment payment;
  final String? redirectUrl;

  @override
  List<Object?> get props => [payment, redirectUrl];
}

class OrderEvent extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? fromStatus;
  final String? toStatus;
  final String? actorRole;
  final DateTime createdAt;

  const OrderEvent({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.fromStatus,
    this.toStatus,
    this.actorRole,
  });

  @override
  List<Object?> get props => [id, title, toStatus, createdAt];

  /// What «التتبّع» actually shows for this entry.
  ///
  /// The stored [title] is prose the API wrote at the moment the event
  /// happened, and for most of this app's life that prose was English — "Out
  /// for delivery", "Order accepted", "Return approved" — rendered verbatim on
  /// the one screen a woman opens to find out where her parcel is. The API now
  /// writes Arabic, but the rows already in the database do not change, and a
  /// customer looking at an order from last month should not be the one who
  /// pays for that.
  ///
  /// So the status the event moved *to* is preferred over the prose: it is a
  /// machine value, it is the same value the status chip on the same screen
  /// already renders in Arabic, and it is present on every event that changed
  /// anything. [title] remains the answer for the entries that change no
  /// status — a note from support, a partial return — which the API now writes
  /// in Arabic anyway.
  String get label => _statusLabel(toStatus) ?? title;

  /// The description, dropped when it is one of the English sentences the API
  /// used to write. A line of English under an Arabic heading reads worse than
  /// no line at all, and the heading already says what happened.
  String? get detail {
    final value = description?.trim();
    if (value == null || value.isEmpty) return null;
    return _legacyEnglishDetails.contains(value) ? null : value;
  }
}

/// The Arabic reading of an order-event status, or null when the value belongs
/// to neither enum — a future status, or a note that changed nothing.
///
/// Parcel statuses are tried first because the customer's timeline is mostly
/// made of them: the workflow writes one event carrying both the parent order
/// id and the sub-order id, so the two vocabularies share this column and the
/// narrower one has to win where they overlap.
String? _statusLabel(String? wire) {
  final value = (wire ?? '').trim().toLowerCase();
  if (value.isEmpty) return null;
  return _sellerOrderStatusLabels[value] ?? _orderStatusLabels[value];
}

final Map<String, String> _sellerOrderStatusLabels = {
  for (final status in SellerOrderStatus.values)
    _wireOf(status.name): status.label,
};

final Map<String, String> _orderStatusLabels = {
  for (final status in OrderStatus.values) _wireOf(status.name): status.label,
};

/// `handedToCourier` → `handed_to_courier`, which is the spelling the API sends
/// (lower-cased from the Prisma enum).
String _wireOf(String name) => name
    .replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}')
    .toLowerCase();

/// Sentences the API wrote before the timeline had an Arabic vocabulary.
///
/// A closed list rather than a heuristic: these are the exact strings this
/// repository used to emit, so suppressing them is a fact about our own past
/// output and cannot swallow something a seller or an operator typed.
const _legacyEnglishDetails = {
  'The seller has started preparing this parcel',
  'On the way to the customer',
  'The courier has the parcel',
  'The delivery company has the parcel',
  'The parcel is with the delivery company',
  'The parcel is out for delivery today',
  'The carrier is returning the parcel',
  'The carrier returned the parcel',
  'Sent to the sellers for preparation',
};

class OrderShipping extends Equatable {
  final String recipientName;
  final String recipientPhone;
  final String governorate;
  final String? district;
  final String city;
  final String addressLine;
  final String? landmark;

  const OrderShipping({
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.district,
    this.landmark,
  });

  @override
  List<Object?> get props =>
      [recipientName, recipientPhone, governorate, district, city, addressLine];
}

class OrderSummary extends Equatable {
  final String id;
  final String number;
  final OrderStatus status;

  final Money itemsSubtotal;
  final Money discountTotal;
  final Money shippingTotal;
  final Money walletApplied;
  final Money grandTotal;

  /// Q46 — the exchange rate this order was priced at, kept so an old order can
  /// be explained when today's rate differs.
  final String fxRate;
  final DateTime fxFrozenAt;

  final int sellersCount;
  final int itemsCount;
  final DateTime createdAt;

  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.itemsSubtotal,
    required this.discountTotal,
    required this.shippingTotal,
    required this.walletApplied,
    required this.grandTotal,
    required this.fxRate,
    required this.fxFrozenAt,
    required this.sellersCount,
    required this.itemsCount,
    required this.createdAt,
  });

  Currency get currency => grandTotal.currency;

  /// True when this order arrived — or will arrive — as several parcels.
  bool get isSplit => sellersCount > 1;

  @override
  List<Object?> get props => [id, number, status, grandTotal, sellersCount];
}

class OrderDetail extends OrderSummary {
  final String? couponCode;
  final String? notes;
  final String? deliveryInstructions;
  final bool privacyMaskEnabled;
  final OrderShipping shipping;
  final List<SellerOrder> sellerOrders;
  final OrderPayment? payment;
  final List<OrderEvent> timeline;

  /// The order is placed but held: a cash-on-delivery confirmation code is
  /// still owed. Nothing is being prepared until it is read back.
  ///
  /// One boolean is all the server sends. She is never told a risk score
  /// exists, only what she can do about it.
  final bool awaitingCodConfirmation;

  const OrderDetail({
    required super.id,
    required super.number,
    required super.status,
    required super.itemsSubtotal,
    required super.discountTotal,
    required super.shippingTotal,
    required super.walletApplied,
    required super.grandTotal,
    required super.fxRate,
    required super.fxFrozenAt,
    required super.sellersCount,
    required super.itemsCount,
    required super.createdAt,
    required this.shipping,
    this.couponCode,
    this.notes,
    this.deliveryInstructions,
    this.privacyMaskEnabled = false,
    this.sellerOrders = const [],
    this.payment,
    this.timeline = const [],
    this.awaitingCodConfirmation = false,
  });

  /// Every line across every parcel, for a flat list view.
  List<OrderItemLine> get allItems =>
      sellerOrders.expand((sellerOrder) => sellerOrder.items).toList();

  /// Any parcel the customer can still cancel — cancellation is per seller now,
  /// so one parcel can be called off while the others ship.
  List<SellerOrder> get cancellableParcels =>
      sellerOrders.where((sellerOrder) => sellerOrder.isCancellable).toList();

  bool get isCancellable => cancellableParcels.isNotEmpty;

  @override
  List<Object?> get props => [...super.props, sellerOrders, payment, timeline];
}
