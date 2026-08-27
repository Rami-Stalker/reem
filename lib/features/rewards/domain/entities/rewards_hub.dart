class RewardsHub {
  const RewardsHub({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
    required this.redeemStep,
    required this.redeemValueSyp,
    required this.membership,
    required this.cashback,
    required this.referral,
    required this.rewards,
  });

  final int points;
  final int lifetimePoints;
  final String tier;
  /// Q43 — points convert in steps of [redeemStep], each step worth
  /// [redeemValueSyp] of wallet credit.
  ///
  /// A single ratio used to stand here, and it disagreed with the rate the
  /// wallet actually credited by orders of magnitude. Two numbers, because the
  /// client's answer has two: «كل 10 نقاط = 5000 ل.س».
  final int redeemStep;
  final int redeemValueSyp;
  final MembershipSummary membership;
  final CashbackSummary cashback;
  final ReferralSummary referral;
  final List<LoyaltyRewardItem> rewards;
}

class MembershipSummary {
  const MembershipSummary({
    required this.tierName,
    required this.vip,
    required this.pointsMultiplier,
    required this.cashbackBps,
    required this.progress,
    this.nextTierName,
    this.benefits = const [],
  });

  final String tierName;
  final bool vip;
  final double pointsMultiplier;
  final int cashbackBps;
  final double progress;
  final String? nextTierName;
  final List<String> benefits;

  double get cashbackRate => cashbackBps / 100;
}

class CashbackSummary {
  const CashbackSummary({
    required this.available,
    required this.pending,
    required this.lifetimeEarned,
    this.entries = const [],
  });

  final double available;
  final double pending;
  final double lifetimeEarned;
  final List<CashbackEntry> entries;
}

class CashbackEntry {
  const CashbackEntry({
    required this.id,
    required this.amount,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}

class ReferralSummary {
  const ReferralSummary({
    required this.customerCode,
    required this.sellerCode,
    required this.total,
    required this.qualified,
    required this.rewarded,
    required this.sellerReferrals,
    required this.customerReferrals,
    required this.pointsEarned,
    required this.cashbackEarned,
    required this.suspicious,
  });

  final String customerCode;
  final String sellerCode;
  final int total;
  final int qualified;
  final int rewarded;
  final int sellerReferrals;
  final int customerReferrals;
  final int pointsEarned;
  final double cashbackEarned;
  final int suspicious;
}

class LoyaltyRewardItem {
  const LoyaltyRewardItem({
    required this.id,
    required this.type,
    required this.title,
    required this.exclusive,
    required this.isActive,
    this.description,
    this.pointsCost,
    this.cashbackAmount,
  });

  final String id;
  final String type;
  final String title;
  final bool exclusive;
  final bool isActive;
  final String? description;
  final int? pointsCost;
  final double? cashbackAmount;

  bool canRedeem(int availablePoints) =>
      isActive && (pointsCost == null || availablePoints >= pointsCost!);
}
