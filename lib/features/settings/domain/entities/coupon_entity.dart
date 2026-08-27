import 'package:equatable/equatable.dart';

/// How a coupon takes money off.
///
/// The two are not interchangeable in the copy: «خصم ٢٠٪» and «خصم ٥٬٠٠٠ ل.س»
/// are different promises, and the screen used to be able to say only the
/// first because the entity carried only a percentage.
enum CouponKind { percent, fixed, unknown }

class CouponEntity extends Equatable {
  const CouponEntity({
    required this.id,
    required this.code,
    required this.title,
    required this.kind,
    required this.expiresAt,
    this.discountPercent = 0,
    this.amountOff,
    this.minOrderAmount,
    this.maxUses,
    this.usedCount = 0,
    this.isUserSpecific = false,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String title;
  final CouponKind kind;

  /// Set when [kind] is [CouponKind.percent].
  final double discountPercent;

  /// Set when [kind] is [CouponKind.fixed]. In the platform's currency.
  final double? amountOff;

  /// What the basket must reach before this applies.
  final double? minOrderAmount;

  final int? maxUses;
  final int usedCount;

  /// Issued to her alone rather than to everybody — worth saying on the card,
  /// because it is the difference between an offer and a gift.
  final bool isUserSpecific;

  final bool isActive;

  /// Redemptions left, or null when the coupon is uncapped.
  int? get remainingUses =>
      maxUses == null ? null : (maxUses! - usedCount).clamp(0, maxUses!);

  bool get isExhausted => remainingUses != null && remainingUses == 0;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  /// Only a coupon that would actually be accepted at checkout.
  ///
  /// The server already filters out the inactive and the expired, but a list
  /// held on screen while midnight passes would otherwise keep offering one
  /// that has just lapsed.
  bool get isRedeemable => isActive && !isExpired && !isExhausted;

  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    id,
    code,
    title,
    kind,
    discountPercent,
    amountOff,
    minOrderAmount,
    maxUses,
    usedCount,
    isUserSpecific,
    expiresAt,
    isActive,
  ];
}
