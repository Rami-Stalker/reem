import 'package:equatable/equatable.dart';

/// Reem membership tiers, lowest → highest. Shared across the home rewards
/// widget and the profile loyalty dashboard.
enum LoyaltyTier { rose, gold, platinum, diamond }

extension LoyaltyTierX on LoyaltyTier {
  String get label => switch (this) {
        LoyaltyTier.rose => 'Rose',
        LoyaltyTier.gold => 'Gold',
        LoyaltyTier.platinum => 'Platinum',
        LoyaltyTier.diamond => 'Diamond',
      };

  /// The server stores the tier as free text on the account. Anything it does
  /// not recognise reads as the entry tier rather than throwing — a customer
  /// must never lose her home page over a spelling.
  static LoyaltyTier fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'gold' => LoyaltyTier.gold,
        'platinum' => LoyaltyTier.platinum,
        'diamond' => LoyaltyTier.diamond,
        _ => LoyaltyTier.rose,
      };

  /// Lifetime points at which this tier begins.
  int get threshold => switch (this) {
        LoyaltyTier.rose => 0,
        LoyaltyTier.gold => 1000,
        LoyaltyTier.platinum => 5000,
        LoyaltyTier.diamond => 15000,
      };

  LoyaltyTier? get next => switch (this) {
        LoyaltyTier.rose => LoyaltyTier.gold,
        LoyaltyTier.gold => LoyaltyTier.platinum,
        LoyaltyTier.platinum => LoyaltyTier.diamond,
        LoyaltyTier.diamond => null,
      };
}

/// The customer's loyalty snapshot.
class LoyaltySummary extends Equatable {
  const LoyaltySummary({
    required this.points,
    required this.tier,
    required this.pointsToNextTier,
    required this.availableCoupons,
    required this.rewardHint,
    this.nextTier,
    this.lifetimePoints,
    this.redeemedCount,
  });

  final int points;
  final LoyaltyTier tier;
  final LoyaltyTier? nextTier;

  /// Points still needed to reach [nextTier]. 0 when already at the top tier.
  final int pointsToNextTier;
  final int availableCoupons;

  /// A short nudge, e.g. "150 pts to a free gift wrap".
  final String rewardHint;

  /// Total points ever earned (for the dashboard). Optional.
  final int? lifetimePoints;

  /// Rewards redeemed to date (for the dashboard). Optional.
  final int? redeemedCount;

  /// Progress toward the next tier, 0..1. Full bar at the top tier.
  double get tierProgress {
    if (nextTier == null) return 1;
    final span = points + pointsToNextTier;
    return span <= 0 ? 0 : (points / span).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
        points,
        tier,
        nextTier,
        pointsToNextTier,
        availableCoupons,
        rewardHint,
        lifetimePoints,
        redeemedCount,
      ];
}
