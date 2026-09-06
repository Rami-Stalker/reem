import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';

/// Which of the seller's accounts a movement touched.
enum EarningsAccount {
  escrow,
  payable,
  disputeHeld,
  unknown;

  static EarningsAccount fromWire(String? value) => switch (value) {
    'SELLER_ESCROW' => EarningsAccount.escrow,
    'SELLER_PAYABLE' => EarningsAccount.payable,
    'DISPUTE_HELD' => EarningsAccount.disputeHeld,
    _ => EarningsAccount.unknown,
  };
}

/// What caused the movement.
enum EarningsMovementType {
  commissionEarned,
  escrowReleased,
  payoutPaid,
  disputeHeld,
  disputeReleased,
  refundIssued,
  returnSettled,
  reversal,
  unknown;

  static EarningsMovementType fromWire(String? value) => switch (value) {
    'COMMISSION_EARNED' => EarningsMovementType.commissionEarned,
    'ESCROW_RELEASED' => EarningsMovementType.escrowReleased,
    'PAYOUT_PAID' => EarningsMovementType.payoutPaid,
    'DISPUTE_HELD' => EarningsMovementType.disputeHeld,
    'DISPUTE_RELEASED' => EarningsMovementType.disputeReleased,
    'REFUND_ISSUED' => EarningsMovementType.refundIssued,
    'RETURN_SETTLED' => EarningsMovementType.returnSettled,
    'REVERSAL' => EarningsMovementType.reversal,
    _ => EarningsMovementType.unknown,
  };
}

/// One line of the seller's statement, signed from her point of view.
class EarningsMovement extends Equatable {
  const EarningsMovement({
    required this.id,
    required this.type,
    required this.account,
    required this.description,
    required this.amount,
    required this.occurredAt,
    this.isTransfer = false,
    this.sellerOrderId,
  });

  final String id;
  final EarningsMovementType type;
  final EarningsAccount account;
  final String description;

  /// Positive is money coming to her, negative is money leaving. For a
  /// transfer the sign is meaningless — see [isTransfer].
  final Money amount;

  /// True when the money only moved between two of her own accounts — escrow
  /// to payable, or escrow to frozen. Nothing entered or left her balance, so
  /// the statement shows it without a plus or a minus.
  final bool isTransfer;

  final String? sellerOrderId;
  final DateTime occurredAt;

  bool get isIncoming => !amount.isNegative;

  /// Whether the row should carry a direction sign at all.
  bool get isSigned => !isTransfer;

  @override
  List<Object?> get props => [id, type, account, amount, occurredAt];
}

/// Where a withdrawal request has got to.
enum PayoutStatus {
  pending,
  approved,
  paid,
  failed,
  cancelled;

  static PayoutStatus fromWire(String? value) =>
      switch ((value ?? '').toUpperCase()) {
        'APPROVED' => PayoutStatus.approved,
        'PAID' => PayoutStatus.paid,
        'FAILED' => PayoutStatus.failed,
        'CANCELLED' => PayoutStatus.cancelled,
        _ => PayoutStatus.pending,
      };

  /// Still waiting on the platform, and still counted against her balance.
  bool get isOpen => this == PayoutStatus.pending || this == PayoutStatus.approved;

  /// Only a request nobody has approved yet is hers to withdraw. Once the
  /// general manager has approved it the money is on its way out.
  bool get isCancellable => this == PayoutStatus.pending;
}

/// A withdrawal request — «طلب سحب».
class PendingPayout extends Equatable {
  const PendingPayout({
    required this.id,
    required this.status,
    required this.net,
    required this.periodStart,
    required this.periodEnd,
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final PayoutStatus status;
  final Money net;

  /// What the request spans: the earliest sale still unpaid, through the
  /// moment she asked.
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? createdAt;
  final DateTime? paidAt;

  bool get isApproved => status == PayoutStatus.approved;

  @override
  List<Object?> get props => [id, status, net, periodStart, periodEnd];
}

/// Why she cannot ask to be paid right now.
enum PayoutBlocker {
  /// A security freeze. Stamped by a phone change or account recovery — both
  /// shaped like a takeover, and a payout is what a takeover is after.
  frozen,

  /// She already has a request waiting; it covers everything released.
  requestOpen,

  /// Nothing has come out of escrow yet.
  nothingReleased;

  static PayoutBlocker? fromWire(String? value) => switch (value) {
    'payout_frozen' => PayoutBlocker.frozen,
    'request_open' => PayoutBlocker.requestOpen,
    'nothing_released' => PayoutBlocker.nothingReleased,
    _ => null,
  };
}

/// What a withdrawal request would be worth this second, and what stops one.
///
/// Read before the button is drawn, so a disabled «سحب» can say why instead
/// of being mysteriously grey.
class PayoutAvailability extends Equatable {
  const PayoutAvailability({
    required this.claimable,
    this.ordersIncluded = 0,
    this.canRequest = false,
    this.blockedBy,
    this.frozenUntil,
    this.openRequest,
  });

  final Money claimable;

  /// How many settled sales the request would gather.
  final int ordersIncluded;
  final bool canRequest;
  final PayoutBlocker? blockedBy;
  final DateTime? frozenUntil;
  final PendingPayout? openRequest;

  @override
  List<Object?> get props => [
    claimable,
    ordersIncluded,
    canRequest,
    blockedBy,
    frozenUntil,
    openRequest,
  ];
}

/// The seller's financial position.
///
/// Three balances, never summed into one headline. A seller argues about
/// exactly the difference between them: what is still inside the return
/// window (Q24), what a payout run will actually pay (Q25), and what a
/// dispute has frozen (Q107). Collapsing them into a single number is how a
/// marketplace ends up in an argument it cannot answer.
class SellerEarnings extends Equatable {
  const SellerEarnings({
    required this.heldInEscrow,
    required this.availableForPayout,
    required this.frozenInDisputes,
    required this.lifetimePaid,
    required this.lifetimeCommission,
    required this.lifetimeGross,
    this.pendingPayouts = const [],
    this.movements = const [],
  });

  /// Earned, but the return window has not closed yet (Q24).
  final Money heldInEscrow;

  /// Released and drainable by the next weekly payout (Q25).
  final Money availableForPayout;

  /// Hers, but contested and therefore unpayable until a ruling (Q107).
  final Money frozenInDisputes;

  final Money lifetimePaid;
  final Money lifetimeCommission;
  final Money lifetimeGross;

  final List<PendingPayout> pendingPayouts;
  final List<EarningsMovement> movements;

  bool get hasFrozenFunds => !frozenInDisputes.isZero;

  bool get isEmpty =>
      heldInEscrow.isZero &&
      availableForPayout.isZero &&
      frozenInDisputes.isZero &&
      movements.isEmpty;

  @override
  List<Object?> get props => [
    heldInEscrow,
    availableForPayout,
    frozenInDisputes,
    lifetimePaid,
    movements,
  ];
}
