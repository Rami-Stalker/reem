import 'package:equatable/equatable.dart';

class RewardsEntity extends Equatable {
  const RewardsEntity({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
  });

  final int points;
  final int lifetimePoints;
  final String tier;

  @override
  List<Object?> get props => [points, lifetimePoints, tier];
}
