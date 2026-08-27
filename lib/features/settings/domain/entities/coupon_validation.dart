import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/settings/domain/entities/coupon_entity.dart';

/// What the server says a coupon is worth on *this* basket.
///
/// The discount is computed server-side and never here. A percentage looks
/// trivial to apply on the client, but the rule it is applied to is not: the
/// coupon may cap the amount, the minimum may exclude the basket, and a
/// per-user limit may already be spent. A client that does the arithmetic
/// itself shows her a figure the order then contradicts.
class CouponValidation extends Equatable {
  const CouponValidation({
    required this.code,
    required this.kind,
    required this.discount,
  });

  final String code;
  final CouponKind kind;

  /// What comes off the basket, in the basket's own currency.
  final Money discount;

  @override
  List<Object?> get props => [code, kind, discount];
}
