import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/wallet_transaction.dart';

/// Wire → domain for one statement row.
///
/// The API is snake_case throughout, and money always arrives as
/// `{amount, currency}` so the currency is never inferred.
class WalletTransactionModel extends WalletTransaction {
  const WalletTransactionModel({
    required super.id,
    required super.source,
    required super.amount,
    required super.balanceAfter,
    required super.reason,
    required super.createdAt,
    super.orderId,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return WalletTransactionModel(
      id: json['id'] as String,
      source: WalletMovementSource.fromWire(json['source'] as String?),
      // Signed on the wire, and kept signed here — direction is data, not
      // something the UI should have to re-derive from the source.
      amount: Money.fromJson(json['amount'], fallback: currency),
      balanceAfter: Money.fromJson(json['balance_after'], fallback: currency),
      reason: json['reason'] as String? ?? '',
      orderId: json['order_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class WalletSummaryModel extends WalletSummary {
  const WalletSummaryModel({
    required super.balance,
    super.transactions,
    super.total,
  });

  /// Built from the two calls that make up the wallet screen: the balance and
  /// the statement.
  factory WalletSummaryModel.from({
    required Map<String, dynamic> balanceJson,
    Map<String, dynamic>? statementJson,
  }) {
    final balance = Money.fromJson(balanceJson['balance']);

    final rows =
        (statementJson?['transactions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WalletTransactionModel.fromJson)
            .toList(growable: false);

    return WalletSummaryModel(
      balance: balance,
      transactions: rows,
      total: (statementJson?['total'] as num?)?.toInt() ?? rows.length,
    );
  }
}
