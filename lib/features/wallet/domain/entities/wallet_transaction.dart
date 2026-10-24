import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/value_objects/money.dart';

/// Where a movement came from (Q41 P2).
///
/// The source is not decoration — it is what lets her statement say *why* a
/// figure changed, which is the whole point of «سجل كامل لحركات المحفظة».
enum WalletMovementSource {
  returnRefund,
  pointsConversion,
  adminCompensation,
  customerTopUp,
  campaignGift,
  priceAdjustment,
  orderPayment,
  orderReversal,
  unknown;

  static WalletMovementSource fromWire(String? value) => switch (value) {
    'RETURN_REFUND' => WalletMovementSource.returnRefund,
    'POINTS_CONVERSION' => WalletMovementSource.pointsConversion,
    'ADMIN_COMPENSATION' => WalletMovementSource.adminCompensation,
    'CUSTOMER_TOPUP' => WalletMovementSource.customerTopUp,
    'CAMPAIGN_GIFT' => WalletMovementSource.campaignGift,
    'PRICE_ADJUSTMENT' => WalletMovementSource.priceAdjustment,
    'ORDER_PAYMENT' => WalletMovementSource.orderPayment,
    'ORDER_REVERSAL' => WalletMovementSource.orderReversal,
    _ => WalletMovementSource.unknown,
  };
}

/// One line of her wallet statement.
class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.source,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final WalletMovementSource source;

  /// Signed: positive credited her, negative was spent.
  final Money amount;

  /// The balance immediately after this movement, so a statement reads down
  /// the page without the client re-summing anything.
  final Money balanceAfter;

  /// Arabic, written by whatever caused the movement.
  final String reason;

  final String? orderId;
  final DateTime createdAt;

  bool get isCredit => !amount.isNegative;

  @override
  List<Object?> get props => [id, source, amount, balanceAfter, createdAt];
}

/// Her balance, plus the statement behind it.
class WalletSummary extends Equatable {
  const WalletSummary({
    required this.balance,
    this.transactions = const [],
    this.total = 0,
  });

  final Money balance;
  final List<WalletTransaction> transactions;

  /// Total movements on record, which may exceed [transactions] when paged.
  final int total;

  /// Q42 — «لا، بينصرف بالموقع بس». The balance is never withdrawable as cash,
  /// so nothing in the UI may offer to pay it out.
  bool get isWithdrawable => false;

  bool get isEmpty => balance.isZero && transactions.isEmpty;

  @override
  List<Object?> get props => [balance, transactions, total];
}
