import 'package:reem/features/settings/domain/entities/coupon_entity.dart';

class CouponModel extends CouponEntity {
  const CouponModel({
    required super.id,
    required super.code,
    required super.title,
    required super.kind,
    required super.expiresAt,
    super.discountPercent,
    super.amountOff,
    super.minOrderAmount,
    super.maxUses,
    super.usedCount,
    super.isUserSpecific,
    super.isActive,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String? ?? json['code'] as String,
      kind: kindFromWire(json['type']),
      discountPercent: _number(json['discount_percent']) ?? 0,
      amountOff: _number(json['amount_off']),
      minOrderAmount: _number(json['min_order_amount']),
      maxUses: (json['max_uses'] as num?)?.toInt(),
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      isUserSpecific: json['is_user_specific'] as bool? ?? false,
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Shared with the validate response, which names the type the same way.
  static CouponKind kindFromWire(Object? value) => switch (value) {
    'percentage' || 'percent' => CouponKind.percent,
    'fixed' => CouponKind.fixed,
    _ => CouponKind.unknown,
  };

  /// Decimal columns cross the wire as strings, not numbers.
  ///
  /// `amount_off` and `min_order_amount` are `Decimal` on the server, and
  /// `JSON.stringify` renders those as `"5000"` rather than `5000`. Reading
  /// them with `as num?` returns null for every one of them, which is how a
  /// fixed-amount coupon silently displays as «خصم ٠».
  static double? _number(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}
