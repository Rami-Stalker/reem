import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/finance_overview.dart';

/// Wire → domain for the finance console.
///
/// Every money field arrives as `{amount, currency}` and stays a [Money]; none
/// of it passes through `double`.
class FinanceOverviewModel extends FinanceOverview {
  const FinanceOverviewModel({
    required super.currency,
    required super.balanced,
    required super.isSound,
    required super.totalDebit,
    required super.totalCredit,
    required super.discrepancy,
    required super.positions,
    required super.courierCashTotal,
    super.rows,
    super.findings,
    super.courierCash,
    super.overdueDisputes,
    super.fx,
  });

  factory FinanceOverviewModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    Money money(dynamic value) => Money.fromJson(value, fallback: currency);

    final positionsJson =
        json['positions'] as Map<String, dynamic>? ?? const {};

    return FinanceOverviewModel(
      currency: currency,
      balanced: json['balanced'] as bool? ?? false,
      isSound: json['sound'] as bool? ?? false,
      totalDebit: money(json['total_debit']),
      totalCredit: money(json['total_credit']),
      discrepancy: money(json['discrepancy']),
      positions: _positions(positionsJson, currency),
      courierCashTotal: money(json['courier_cash_total']),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _row(row, currency))
          .toList(growable: false),
      findings: (json['findings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_finding)
          .toList(growable: false),
      courierCash: (json['courier_cash'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _courier(row, currency))
          .toList(growable: false),
      overdueDisputes:
          (json['overdue_disputes'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((row) => _dispute(row, currency))
              .toList(growable: false),
      fx: json['fx'] is Map<String, dynamic>
          ? _fx(json['fx'] as Map<String, dynamic>, currency)
          : null,
    );
  }

  static FinancePositions _positions(
    Map<String, dynamic> json,
    Currency currency,
  ) {
    Money at(String key) => Money.fromJson(json[key], fallback: currency);
    return FinancePositions(
      platformCash: at('platform_cash'),
      gatewayReceivable: at('gateway_receivable'),
      courierInTransit: at('courier_in_transit'),
      sellerPayable: at('seller_payable'),
      sellerEscrow: at('seller_escrow'),
      customerWallets: at('customer_wallets'),
      disputeHeld: at('dispute_held'),
      loyaltyLiability: at('loyalty_liability'),
      commissionRevenue: at('commission_revenue'),
      totalOwed: at('total_owed'),
      totalHeld: at('total_held'),
      coverage: at('coverage'),
    );
  }

  static TrialBalanceRow _row(Map<String, dynamic> json, Currency currency) {
    return TrialBalanceRow(
      accountId: json['account_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      kind: LedgerAccountKind.fromWire(json['kind'] as String?),
      label: json['label'] as String? ?? '',
      ownerId: json['owner_id'] as String?,
      debit: Money.fromJson(json['debit'], fallback: currency),
      credit: Money.fromJson(json['credit'], fallback: currency),
      balance: Money.fromJson(json['balance'], fallback: currency),
    );
  }

  static ReconciliationFinding _finding(Map<String, dynamic> json) {
    return ReconciliationFinding(
      kind: ReconciliationKind.fromWire(json['kind'] as String?),
      detail: json['detail'] as String? ?? '',
    );
  }

  static CourierCashPosition _courier(
    Map<String, dynamic> json,
    Currency currency,
  ) {
    final courier = json['courier'] as Map<String, dynamic>?;
    return CourierCashPosition(
      outstanding: Money.fromJson(json['outstanding'], fallback: currency),
      courierName: courier?['displayName'] as String?,
      courierPhone: courier?['phone'] as String?,
    );
  }

  static OverdueDispute _dispute(
    Map<String, dynamic> json,
    Currency currency,
  ) {
    return OverdueDispute(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      frozenAmount: Money.fromJson(json['frozen_amount'], fallback: currency),
      dueAt:
          DateTime.tryParse(json['due_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static FxPosition _fx(Map<String, dynamic> json, Currency currency) {
    return FxPosition(
      rate: json['rate'] as String? ?? '',
      rateSource: json['rate_source'] as String? ?? '',
      foreignCurrency: json['foreign_currency'] as String? ?? 'USD',
      assets: Money.fromJson(json['assets'], fallback: currency),
      liabilities: Money.fromJson(json['liabilities'], fallback: currency),
      netExposure: Money.fromJson(json['net_exposure'], fallback: currency),
      netResult: Money.fromJson(json['net_result'], fallback: currency),
    );
  }
}
