import 'package:ohara/features/rewards/domain/entities/rewards_hub.dart';

class RewardsHubModel extends RewardsHub {
  const RewardsHubModel({
    required super.points,
    required super.lifetimePoints,
    required super.tier,
    required super.redeemStep,
    required super.redeemValueSyp,
    required super.membership,
    required super.cashback,
    required super.referral,
    required super.rewards,
  });

  factory RewardsHubModel.fromJson({
    required Map<String, dynamic> rewardsJson,
    required Map<String, dynamic> referralJson,
  }) {
    return RewardsHubModel(
      points: _int(rewardsJson['points']),
      lifetimePoints: _int(rewardsJson['lifetime_points']),
      tier: rewardsJson['tier'] as String? ?? 'Bronze',
      redeemStep: _int(rewardsJson['redeem_step'], fallback: 10),
      redeemValueSyp: _int(rewardsJson['redeem_value_syp'], fallback: 5000),
      membership: MembershipSummaryModel.fromJson(
        _map(rewardsJson['membership']),
        fallbackTier: rewardsJson['tier'] as String? ?? 'Bronze',
      ),
      cashback: CashbackSummaryModel.fromJson(_map(rewardsJson['cashback'])),
      referral: ReferralSummaryModel.fromJson(referralJson),
      rewards: _list(rewardsJson['rewards'])
          .map((e) => LoyaltyRewardItemModel.fromJson(_map(e)))
          .toList(growable: false),
    );
  }
}

class MembershipSummaryModel extends MembershipSummary {
  const MembershipSummaryModel({
    required super.tierName,
    required super.vip,
    required super.pointsMultiplier,
    required super.cashbackBps,
    required super.progress,
    super.nextTierName,
    super.benefits,
  });

  factory MembershipSummaryModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackTier,
  }) {
    final tier = _map(json['tier']);
    final nextTier = _map(json['next_tier']);
    final progress = _map(json['progress']);
    return MembershipSummaryModel(
      tierName: tier['name'] as String? ?? fallbackTier,
      vip: json['vip'] as bool? ?? false,
      pointsMultiplier: _double(json['points_multiplier'], fallback: 1),
      cashbackBps: _int(json['cashback_bps']),
      progress: _double(progress['percentage']).clamp(0, 1).toDouble(),
      nextTierName: nextTier['name'] as String?,
      benefits: _benefits(tier['benefits']),
    );
  }
}

class CashbackSummaryModel extends CashbackSummary {
  const CashbackSummaryModel({
    required super.available,
    required super.pending,
    required super.lifetimeEarned,
    super.entries,
  });

  factory CashbackSummaryModel.fromJson(Map<String, dynamic> json) {
    return CashbackSummaryModel(
      available: _double(json['available']),
      pending: _double(json['pending']),
      lifetimeEarned: _double(json['lifetime_earned']),
      entries: _list(json['entries'])
          .map((e) => CashbackEntryModel.fromJson(_map(e)))
          .toList(growable: false),
    );
  }
}

class CashbackEntryModel extends CashbackEntry {
  const CashbackEntryModel({
    required super.id,
    required super.amount,
    required super.status,
    super.createdAt,
    super.expiresAt,
  });

  factory CashbackEntryModel.fromJson(Map<String, dynamic> json) {
    return CashbackEntryModel(
      id: json['id'] as String? ?? '',
      amount: _double(json['amount']),
      status: json['status'] as String? ?? 'earned',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    );
  }
}

class ReferralSummaryModel extends ReferralSummary {
  const ReferralSummaryModel({
    required super.customerCode,
    required super.sellerCode,
    required super.total,
    required super.qualified,
    required super.rewarded,
    required super.sellerReferrals,
    required super.customerReferrals,
    required super.pointsEarned,
    required super.cashbackEarned,
    required super.suspicious,
  });

  factory ReferralSummaryModel.fromJson(Map<String, dynamic> json) {
    final customerCode = _map(json['customer_code']);
    final sellerCode = _map(json['seller_code']);
    final stats = _map(json['stats']);
    return ReferralSummaryModel(
      customerCode: customerCode['code'] as String? ?? '',
      sellerCode: sellerCode['code'] as String? ?? '',
      total: _int(stats['total']),
      qualified: _int(stats['qualified']),
      rewarded: _int(stats['rewarded']),
      sellerReferrals: _int(stats['seller_referrals']),
      customerReferrals: _int(stats['customer_referrals']),
      pointsEarned: _int(stats['points_earned']),
      cashbackEarned: _double(stats['cashback_earned']),
      suspicious: _int(stats['suspicious']),
    );
  }
}

class LoyaltyRewardItemModel extends LoyaltyRewardItem {
  const LoyaltyRewardItemModel({
    required super.id,
    required super.type,
    required super.title,
    required super.exclusive,
    required super.isActive,
    super.description,
    super.pointsCost,
    super.cashbackAmount,
  });

  factory LoyaltyRewardItemModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyRewardItemModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'coupon',
      title: json['title'] as String? ?? 'Reward',
      description: json['description'] as String?,
      pointsCost: json['points_cost'] == null ? null : _int(json['points_cost']),
      cashbackAmount: json['cashback_amount'] == null
          ? null
          : _double(json['cashback_amount']),
      exclusive: json['exclusive'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _double(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

List<String> _benefits(Object? raw) {
  final benefits = _map(raw);
  final highlights = benefits['highlights'];
  if (highlights is List) {
    return highlights.map((e) => '$e').toList(growable: false);
  }
  return const [];
}
