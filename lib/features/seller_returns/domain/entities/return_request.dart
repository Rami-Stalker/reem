import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/value_objects/money.dart';

/// Where a return has got to.
///
/// The order matters: it is the order the queue sorts by, and it is the order
/// the seller works. `requested` is the only state that is *waiting on her*.
enum ReturnStatus {
  requested,
  approved,
  inTransit,
  received,
  refunded,
  exchanged,
  rejected,
  cancelled;

  static ReturnStatus fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'APPROVED' => ReturnStatus.approved,
        'IN_TRANSIT' => ReturnStatus.inTransit,
        'RECEIVED' => ReturnStatus.received,
        'REFUNDED' => ReturnStatus.refunded,
        'EXCHANGED' => ReturnStatus.exchanged,
        'REJECTED' => ReturnStatus.rejected,
        'CANCELLED' => ReturnStatus.cancelled,
        _ => ReturnStatus.requested,
      };

  String get wire => switch (this) {
    ReturnStatus.requested => 'REQUESTED',
    ReturnStatus.approved => 'APPROVED',
    ReturnStatus.inTransit => 'IN_TRANSIT',
    ReturnStatus.received => 'RECEIVED',
    ReturnStatus.refunded => 'REFUNDED',
    ReturnStatus.exchanged => 'EXCHANGED',
    ReturnStatus.rejected => 'REJECTED',
    ReturnStatus.cancelled => 'CANCELLED',
  };

  /// Nothing more will happen to it on its own.
  bool get isClosed =>
      this == ReturnStatus.refunded ||
      this == ReturnStatus.exchanged ||
      this == ReturnStatus.rejected ||
      this == ReturnStatus.cancelled;

  /// The seller is the one holding this up.
  bool get needsSeller =>
      this == ReturnStatus.requested ||
      this == ReturnStatus.approved ||
      this == ReturnStatus.inTransit;
}

/// Why the customer sent it back. Some of these accuse the seller of a fault
/// and some do not, which is what decides who pays the return leg.
enum ReturnReason {
  defective,
  wrongItem,
  notAsDescribed,
  damagedInTransit,
  changedMind,
  sizeIssue,
  lateDelivery,
  other;

  static ReturnReason fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'DEFECTIVE' => ReturnReason.defective,
        'WRONG_ITEM' => ReturnReason.wrongItem,
        'NOT_AS_DESCRIBED' => ReturnReason.notAsDescribed,
        'DAMAGED_IN_TRANSIT' => ReturnReason.damagedInTransit,
        'CHANGED_MIND' => ReturnReason.changedMind,
        'SIZE_ISSUE' => ReturnReason.sizeIssue,
        'LATE_DELIVERY' => ReturnReason.lateDelivery,
        _ => ReturnReason.other,
      };

  /// Whether the reason asserts something was wrong with the goods. The
  /// server decides who pays; this only shapes how the request is presented.
  bool get allegesFault =>
      this == ReturnReason.defective ||
      this == ReturnReason.wrongItem ||
      this == ReturnReason.notAsDescribed ||
      this == ReturnReason.damagedInTransit;

  /// The value `POST /returns` expects. The mirror of [fromWire], added when
  /// the customer gained a way to open a return — until then nothing in the
  /// client ever had to send a reason, only read one back.
  String get wire => switch (this) {
    ReturnReason.defective => 'DEFECTIVE',
    ReturnReason.wrongItem => 'WRONG_ITEM',
    ReturnReason.notAsDescribed => 'NOT_AS_DESCRIBED',
    ReturnReason.damagedInTransit => 'DAMAGED_IN_TRANSIT',
    ReturnReason.changedMind => 'CHANGED_MIND',
    ReturnReason.sizeIssue => 'SIZE_ISSUE',
    ReturnReason.lateDelivery => 'LATE_DELIVERY',
    ReturnReason.other => 'OTHER',
  };
}

/// Who carries the cost of the return leg (Q67 P1).
enum ReturnCostBearer {
  customer,
  seller,
  platform;

  static ReturnCostBearer? fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'CUSTOMER' => ReturnCostBearer.customer,
        'SELLER' => ReturnCostBearer.seller,
        'PLATFORM' => ReturnCostBearer.platform,
        _ => null,
      };

  String get wire => name.toUpperCase();
}

/// How it was settled.
enum ReturnResolution {
  none,
  refundToWallet,
  refundToSource,
  exchange,
  repair;

  static ReturnResolution fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'REFUND_TO_WALLET' => ReturnResolution.refundToWallet,
        'REFUND_TO_SOURCE' => ReturnResolution.refundToSource,
        'EXCHANGE' => ReturnResolution.exchange,
        'REPAIR' => ReturnResolution.repair,
        _ => ReturnResolution.none,
      };
}

/// One line coming back.
class ReturnLine extends Equatable {
  const ReturnLine({
    required this.orderItemId,
    required this.title,
    required this.quantity,
    this.variant,
    this.image,
  });

  final String orderItemId;
  final String title;
  final int quantity;
  final String? variant;
  final String? image;

  @override
  List<Object?> get props => [orderItemId, title, quantity, variant, image];
}

/// What the customer would be paid, and out of whose pocket.
///
/// [settled] is the whole point of this type. Before the goods are back, the
/// figure is a *quote* the server recalculates; afterwards it is the amount
/// actually moved. Presenting a quote as a settled figure would have the
/// seller reading a proposal as a promise.
class RefundQuote extends Equatable {
  const RefundQuote({
    required this.amount,
    required this.settled,
    this.goods,
    this.returnShippingFee,
    this.borneBy,
    this.isFullParcel = false,
  });

  final Money amount;
  final bool settled;
  final Money? goods;
  final Money? returnShippingFee;
  final ReturnCostBearer? borneBy;
  final bool isFullParcel;

  @override
  List<Object?> get props => [
    amount,
    settled,
    goods,
    returnShippingFee,
    borneBy,
    isFullParcel,
  ];
}

/// The parcel a return belongs to.
class ReturnParcel extends Equatable {
  const ReturnParcel({
    required this.orderId,
    required this.orderNumber,
    required this.sellerOrderId,
    required this.sellerOrderNumber,
    this.status,
  });

  final String orderId;
  final String orderNumber;
  final String sellerOrderId;
  final String sellerOrderNumber;
  final String? status;

  @override
  List<Object?> get props => [
    orderId,
    orderNumber,
    sellerOrderId,
    sellerOrderNumber,
    status,
  ];
}

/// One return or exchange request.
class ReturnRequest extends Equatable {
  const ReturnRequest({
    required this.id,
    required this.number,
    required this.status,
    required this.reason,
    required this.parcel,
    required this.createdAt,
    this.resolution = ReturnResolution.none,
    this.reasonNote,
    this.shippingBorneBy,
    this.evidence = const [],
    this.items = const [],
    this.refund,
    this.windowClosesAt,
    this.decidedAt,
  });

  /// `RET-000123` — short enough to read out in a support call.
  final String id;
  final String number;
  final ReturnStatus status;
  final ReturnResolution resolution;
  final ReturnReason reason;
  final String? reasonNote;
  final ReturnCostBearer? shippingBorneBy;

  /// Photographs the customer attached. Required by the server for the reasons
  /// that assert a fault, so a defect claim with an empty gallery is worth
  /// noticing.
  final List<String> evidence;
  final ReturnParcel parcel;
  final List<ReturnLine> items;
  final RefundQuote? refund;
  final DateTime? windowClosesAt;
  final DateTime? decidedAt;
  final DateTime createdAt;

  int get totalUnits =>
      items.fold(0, (running, line) => running + line.quantity);

  /// What the seller may do to it right now.
  ///
  /// Derived from the status, which is the same table the server checks. The
  /// list is deliberately short at every step: a return has one obvious next
  /// move, and offering four buttons where one applies is how a seller ends
  /// up pressing the wrong one.
  List<ReturnAction> get availableActions => switch (status) {
    ReturnStatus.requested => const [
      ReturnAction.approve,
      ReturnAction.reject,
    ],
    // The goods have to leave the customer before they can arrive; the server
    // has no edge from approved straight to received.
    ReturnStatus.approved => const [ReturnAction.markInTransit],
    ReturnStatus.inTransit => const [ReturnAction.receive],
    // Received and not yet paid. The refund is the PLATFORM's act — a seller
    // who could press it would be deciding her own liability — and a sweep
    // presses it once she confirms receipt. Swapping the goods instead moves
    // no money, so that one is hers.
    ReturnStatus.received => const [ReturnAction.exchange],
    // The replacement is on its way; this closes the parcel and, with it, the
    // escrow the exchange was holding open.
    ReturnStatus.exchanged => const [ReturnAction.exchangeDelivered],
    _ => const [],
  };

  @override
  List<Object?> get props => [
    id,
    number,
    status,
    resolution,
    reason,
    reasonNote,
    shippingBorneBy,
    evidence,
    parcel,
    items,
    refund,
    windowClosesAt,
    decidedAt,
    createdAt,
  ];
}

/// One thing the seller can do to a return.
enum ReturnAction {
  approve,
  reject,
  markInTransit,
  receive,
  exchange,
  exchangeDelivered,
}
