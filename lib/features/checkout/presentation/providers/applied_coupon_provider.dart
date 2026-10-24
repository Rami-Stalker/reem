import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/settings/domain/entities/coupon_validation.dart';

/// The coupon she has chosen, waiting for checkout.
///
/// Lives here rather than in the coupons screen because checkout is what
/// consumes it, and it has to outlive the screen that set it: she picks an
/// offer from her coupons, goes back, fills a basket, and expects it to still
/// be there when she pays.
///
/// Deliberately **not** `autoDispose`, and deliberately cleared the moment the
/// basket changes — see [AppliedCouponNotifier.invalidateForBasket]. A discount
/// was quoted against one subtotal; once that subtotal moves, the figure on
/// screen is a promise the order will not keep.
class AppliedCoupon {
  const AppliedCoupon({required this.validation, required this.subtotal});

  final CouponValidation validation;

  /// The basket the discount was quoted against.
  final Money subtotal;

  String get code => validation.code;
  Money get discount => validation.discount;
}

class AppliedCouponNotifier extends StateNotifier<AppliedCoupon?> {
  AppliedCouponNotifier() : super(null);

  void apply(CouponValidation validation, Money subtotal) {
    state = AppliedCoupon(validation: validation, subtotal: subtotal);
  }

  void clear() => state = null;

  /// Drops the coupon when the basket is no longer the one it was priced
  /// against.
  ///
  /// The alternative — keeping it and re-validating silently — is worse: the
  /// server may now refuse it for falling under the minimum, and the first she
  /// would hear of that is the order failing.
  void invalidateForBasket(Money? subtotal) {
    final applied = state;
    if (applied == null) return;
    if (subtotal == null || subtotal.raw != applied.subtotal.raw) {
      state = null;
    }
  }
}

final appliedCouponProvider =
    StateNotifierProvider<AppliedCouponNotifier, AppliedCoupon?>(
      (ref) => AppliedCouponNotifier(),
    );
