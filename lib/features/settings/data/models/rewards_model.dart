import '../../domain/entities/rewards_entity.dart';

class RewardsModel extends RewardsEntity {
  const RewardsModel({
    required super.points,
    required super.lifetimePoints,
    required super.tier,
  });

  factory RewardsModel.fromJson(Map<String, dynamic> json) {
    return RewardsModel(
      points: json['points'] as int? ?? 0,
      lifetimePoints: json['lifetime_points'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'Bronze',
    );
  }
}
