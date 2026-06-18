import 'package:equatable/equatable.dart';

/// The customer's referral programme snapshot.
class Referral extends Equatable {
  const Referral({
    required this.code,
    required this.invited,
    required this.earnedPoints,
    required this.rewardHint,
  });

  final String code;
  final int invited;
  final int earnedPoints;

  /// What each successful invite earns, e.g. "You both get 500 pts".
  final String rewardHint;

  @override
  List<Object?> get props => [code, invited, earnedPoints, rewardHint];
}
