import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/seller_earnings.dart';

/// Wire → domain.
///
/// Every figure goes through [Money], never `double`. The older
/// `commission_models.dart` parses money as `double`, which is the exact
/// mistake the backend's own `Money` class exists to prevent — a decimal
/// through a float is a rounding error waiting for a big enough number.
class SellerEarningsModel extends SellerEarnings {
  const SellerEarningsModel({
    required super.heldInEscrow,
    required super.availableForPayout,
    required super.frozenInDisputes,
    required super.lifetimePaid,
    required super.lifetimeCommission,
    required super.lifetimeGross,
    super.pendingPayouts,
    super.movements,
  });

  factory SellerEarningsModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    Money money(String key) =>
        Money.fromJson(json[key], fallback: currency);

    return SellerEarningsModel(
      heldInEscrow: money('held_in_escrow'),
      availableForPayout: money('available_for_payout'),
      frozenInDisputes: money('frozen_in_disputes'),
      lifetimePaid: money('lifetime_paid'),
      lifetimeCommission: money('lifetime_commission'),
      lifetimeGross: money('lifetime_gross'),
      pendingPayouts: (json['pending_payouts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _payout(row, currency))
          .toList(growable: false),
      movements: (json['movements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _movement(row, currency))
          .toList(growable: false),
    );
  }

  static PendingPayout _payout(Map<String, dynamic> json, Currency currency) {
    return PendingPayout(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      net: Money.fromJson(json['net'], fallback: currency),
      periodStart:
          DateTime.tryParse(json['period_start'] as String? ?? '') ??
          DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['period_end'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static EarningsMovement _movement(
    Map<String, dynamic> json,
    Currency currency,
  ) {
    return EarningsMovement(
      id: json['id'] as String? ?? '',
      type: EarningsMovementType.fromWire(json['type'] as String?),
      account: EarningsAccount.fromWire(json['account'] as String?),
      description: json['description'] as String? ?? '',
      amount: Money.fromJson(json['amount'], fallback: currency),
      isTransfer: json['is_transfer'] as bool? ?? false,
      sellerOrderId: json['seller_order_id'] as String?,
      occurredAt:
          DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
