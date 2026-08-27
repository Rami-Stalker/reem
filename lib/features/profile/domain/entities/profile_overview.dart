import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/loyalty.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/profile/domain/entities/achievement.dart';
import 'package:reem/features/profile/domain/entities/followed_store.dart';
import 'package:reem/features/profile/domain/entities/orders_overview.dart';
import 'package:reem/features/profile/domain/entities/referral.dart';

/// One step in the profile-completion checklist.
class ProfileCompletionStep extends Equatable {
  const ProfileCompletionStep({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  List<Object?> get props => [label, done];
}

/// The bespoke profile-centre data fetched in one pass: completion, gamified
/// badges, loyalty, an orders snapshot, followed boutiques, referral and the
/// reviews summary. Identity, favorites and orders lists stay in their own
/// providers (auth / favorites / orders).
class ProfileOverview extends Equatable {
  const ProfileOverview({
    this.completionSteps = const [],
    this.achievements = const [],
    this.followedStores = const [],
    this.recentlyViewed = const [],
    this.orders = const OrdersOverview(),
    this.reviewsCount = 0,
    this.averageRating = 0,
    this.referral,
    this.loyalty,
  });

  final List<ProfileCompletionStep> completionSteps;
  final List<Achievement> achievements;
  final List<FollowedStore> followedStores;
  final List<Product> recentlyViewed;
  final OrdersOverview orders;
  final int reviewsCount;
  final double averageRating;
  final Referral? referral;
  final LoyaltySummary? loyalty;

  /// Completion 0..1, derived from the checklist.
  double get completion {
    if (completionSteps.isEmpty) return 0;
    final done = completionSteps.where((s) => s.done).length;
    return done / completionSteps.length;
  }

  int get completionPercent => (completion * 100).round();

  /// The first not-yet-done step, to nudge the customer.
  ProfileCompletionStep? get nextStep =>
      completionSteps.where((s) => !s.done).firstOrNull;

  int get earnedAchievements => achievements.where((a) => a.earned).length;

  @override
  List<Object?> get props => [
        completionSteps,
        achievements,
        followedStores,
        recentlyViewed,
        orders,
        reviewsCount,
        averageRating,
        referral,
        loyalty,
      ];
}
