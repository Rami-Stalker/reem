import 'package:equatable/equatable.dart';

import '../../../../core/shared/value_objects/money.dart';

/// The classical account kinds, mirrored from the backend chart of accounts.
enum LedgerAccountKind {
  asset,
  liability,
  equity,
  revenue,
  expense,
  unknown;

  static LedgerAccountKind fromWire(String? value) => switch (value) {
    'ASSET' => LedgerAccountKind.asset,
    'LIABILITY' => LedgerAccountKind.liability,
    'EQUITY' => LedgerAccountKind.equity,
    'REVENUE' => LedgerAccountKind.revenue,
    'EXPENSE' => LedgerAccountKind.expense,
    _ => LedgerAccountKind.unknown,
  };
}

/// One line of the trial balance.
class TrialBalanceRow extends Equatable {
  const TrialBalanceRow({
    required this.accountId,
    required this.code,
    required this.kind,
    required this.label,
    required this.debit,
    required this.credit,
    required this.balance,
    this.ownerId,
  });

  final String accountId;
  final String code;
  final LedgerAccountKind kind;
  final String label;
  final Money debit;
  final Money credit;
  final Money balance;

  /// Set for per-party accounts — a seller's payable, a customer's wallet.
  final String? ownerId;

  bool get isPlatformAccount => ownerId == null;

  @override
  List<Object?> get props => [accountId, code, ownerId, balance];
}

/// A problem the books found in themselves.
enum ReconciliationKind {
  trialBalanceOff,
  cachedBalanceDrift,
  suspenseNotEmpty,
  negativeLiability,
  unknown;

  static ReconciliationKind fromWire(String? value) => switch (value) {
    'TRIAL_BALANCE_OFF' => ReconciliationKind.trialBalanceOff,
    'CACHED_BALANCE_DRIFT' => ReconciliationKind.cachedBalanceDrift,
    'SUSPENSE_NOT_EMPTY' => ReconciliationKind.suspenseNotEmpty,
    'NEGATIVE_LIABILITY' => ReconciliationKind.negativeLiability,
    _ => ReconciliationKind.unknown,
  };

  /// Money created or destroyed outranks everything else.
  bool get isCritical =>
      this == ReconciliationKind.trialBalanceOff ||
      this == ReconciliationKind.cachedBalanceDrift;
}

class ReconciliationFinding extends Equatable {
  const ReconciliationFinding({required this.kind, required this.detail});

  final ReconciliationKind kind;
  final String detail;

  @override
  List<Object?> get props => [kind, detail];
}

/// Cash a courier collected and has not handed over (Q56).
class CourierCashPosition extends Equatable {
  const CourierCashPosition({
    required this.outstanding,
    this.courierName,
    this.courierPhone,
  });

  final Money outstanding;
  final String? courierName;
  final String? courierPhone;

  @override
  List<Object?> get props => [courierName, outstanding];
}

/// A dispute past its decision deadline (Q107).
class OverdueDispute extends Equatable {
  const OverdueDispute({
    required this.id,
    required this.number,
    required this.subject,
    required this.frozenAmount,
    required this.dueAt,
  });

  final String id;
  final String number;
  final String subject;
  final Money frozenAmount;
  final DateTime dueAt;

  int daysOverdue(DateTime now) => now.difference(dueAt).inDays;

  @override
  List<Object?> get props => [id, number, dueAt];
}

/// The platform's foreign-currency position.
class FxPosition extends Equatable {
  const FxPosition({
    required this.rate,
    required this.rateSource,
    required this.foreignCurrency,
    required this.assets,
    required this.liabilities,
    required this.netExposure,
    required this.netResult,
  });

  final String rate;
  final String rateSource;
  final String foreignCurrency;
  final Money assets;
  final Money liabilities;

  /// Assets minus liabilities — what a rate move actually moves.
  final Money netExposure;

  /// What conversions have already cost or earned. Positive is a gain.
  final Money netResult;

  bool get hasExposure => !netExposure.isZero;

  @override
  List<Object?> get props => [rate, netExposure, netResult];
}

/// The standing balances an operator watches, all computed server-side.
///
/// Nothing here is summed on the client. Every figure arrives finished from
/// the backend, where `Money` guarantees decimal arithmetic — folding ledger
/// balances with Dart `double` would reintroduce exactly the rounding error
/// the ledger exists to prevent.
class FinancePositions extends Equatable {
  const FinancePositions({
    required this.platformCash,
    required this.gatewayReceivable,
    required this.courierInTransit,
    required this.sellerPayable,
    required this.sellerEscrow,
    required this.customerWallets,
    required this.disputeHeld,
    required this.loyaltyLiability,
    required this.commissionRevenue,
    required this.totalOwed,
    required this.totalHeld,
    required this.coverage,
  });

  final Money platformCash;
  final Money gatewayReceivable;
  final Money courierInTransit;

  final Money sellerPayable;
  final Money sellerEscrow;
  final Money customerWallets;
  final Money disputeHeld;
  final Money loyaltyLiability;

  final Money commissionRevenue;

  final Money totalOwed;
  final Money totalHeld;

  /// Held minus owed. Negative means the platform has taken on more obligation
  /// than it holds funds to meet — solvency, in one line.
  final Money coverage;

  bool get isUndercovered => coverage.isNegative;

  @override
  List<Object?> get props => [platformCash, totalOwed, totalHeld, coverage];
}

/// Everything the finance console shows.
///
/// The headline is not a revenue figure — it is [isSound]. A marketplace can
/// read its takings off any report; only a double-entry book can say whether
/// the takings are *true*, and that is the question this screen answers before
/// it answers any other.
class FinanceOverview extends Equatable {
  const FinanceOverview({
    required this.currency,
    required this.balanced,
    required this.isSound,
    required this.totalDebit,
    required this.totalCredit,
    required this.discrepancy,
    required this.positions,
    required this.courierCashTotal,
    this.rows = const [],
    this.findings = const [],
    this.courierCash = const [],
    this.overdueDisputes = const [],
    this.fx,
  });

  final Currency currency;

  /// Whether debits equal credits across the whole book.
  final bool balanced;

  /// Balanced *and* nothing drifted, nothing in suspense, no liability negative.
  final bool isSound;

  final Money totalDebit;
  final Money totalCredit;

  /// Non-zero means money has been created or destroyed.
  final Money discrepancy;

  final FinancePositions positions;
  final Money courierCashTotal;

  final List<TrialBalanceRow> rows;
  final List<ReconciliationFinding> findings;
  final List<CourierCashPosition> courierCash;
  final List<OverdueDispute> overdueDisputes;
  final FxPosition? fx;

  bool get hasCriticalFinding => findings.any((f) => f.kind.isCritical);

  bool get needsAttention =>
      !isSound || overdueDisputes.isNotEmpty || positions.isUndercovered;

  @override
  List<Object?> get props => [currency, balanced, isSound, rows, findings];
}
