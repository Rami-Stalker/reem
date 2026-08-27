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

/// A payout that has been calculated but not yet paid.
class PendingPayout extends Equatable {
  const PendingPayout({
    required this.id,
    required this.status,
    required this.net,
    required this.periodStart,
    required this.periodEnd,
  });

  final String id;
  final String status;
  final Money net;
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get isApproved => status == 'APPROVED';

  @override
  List<Object?> get props => [id, status, net];
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
