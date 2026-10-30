import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/referral_terms.dart';

/// The customer's referral programme snapshot.
class Referral extends Equatable {
  const Referral({
    required this.code,
    required this.invited,
    required this.earnedPoints,
    required this.rewardHint,
    this.terms,
  });

  final String code;
  final int invited;
  final int earnedPoints;

  /// What each successful invite earns, e.g. "You both get 500 pts".
  final String rewardHint;

  /// What the programme pays each side; null on a server that predates it.
  final ReferralTerms? terms;

  @override
  List<Object?> get props => [code, invited, earnedPoints, rewardHint, terms];
}
