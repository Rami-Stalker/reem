import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

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

  /// Shared by the statement's `pending_payouts`, the request endpoint and the
  /// history list — all three serialise a payout identically.
  static PendingPayout payoutFromJson(
    Map<String, dynamic> json, {
    Currency currency = Currency.syp,
  }) {
    final resolved = Currency.fromWire(json['currency'] as String?);
    return PendingPayout(
      id: json['id'] as String? ?? '',
      status: PayoutStatus.fromWire(json['status'] as String?),
      net: Money.fromJson(
        json['net'],
        fallback: json['currency'] == null ? currency : resolved,
      ),
      periodStart:
          DateTime.tryParse(json['period_start'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['period_end'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      createdAt: DateTime.tryParse(
        json['created_at'] as String? ?? '',
      )?.toLocal(),
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? '')?.toLocal(),
    );
  }

  /// Parses `GET /finance/seller/payouts/availability`.
  static PayoutAvailability availabilityFromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    final open = json['open_request'];
    return PayoutAvailability(
      claimable: Money.fromJson(json['claimable'], fallback: currency),
      ordersIncluded: (json['orders_included'] as num?)?.toInt() ?? 0,
      canRequest: json['can_request'] as bool? ?? false,
      blockedBy: PayoutBlocker.fromWire(json['blocked_by'] as String?),
      frozenUntil: DateTime.tryParse(
        json['frozen_until'] as String? ?? '',
      )?.toLocal(),
      openRequest: open is Map
          ? payoutFromJson(open.cast<String, dynamic>(), currency: currency)
          : null,
    );
  }

  static PendingPayout _payout(Map<String, dynamic> json, Currency currency) =>
      payoutFromJson(json, currency: currency);

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
