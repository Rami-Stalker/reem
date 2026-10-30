import 'package:ohara/core/shared/entities/referral_terms.dart';

/// `terms` on the profile overview and on `/referrals/me`. Null when absent,
/// so a screen says nothing rather than quoting a number the server did not.
ReferralTerms? referralTermsFromJson(Object? value) {
  if (value is! Map) return null;
  int? read(String key) => (value[key] as num?)?.toInt();
  final referrerPoints = read('referrer_points');
  final referredPoints = read('referred_points');
  if (referrerPoints == null || referredPoints == null) return null;
  return ReferralTerms(
    referrerPoints: referrerPoints,
    referredPoints: referredPoints,
    referrerDiscountPercent: read('referrer_discount_percent') ?? 0,
    referredDiscountPercent: read('referred_discount_percent') ?? 0,
    couponValidDays: read('coupon_valid_days'),
  );
}
