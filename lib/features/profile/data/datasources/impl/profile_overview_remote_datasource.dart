import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/entities/loyalty.dart';
import 'package:reem/features/profile/data/datasources/profile_overview_datasource.dart';
import 'package:reem/features/profile/domain/entities/followed_store.dart';
import 'package:reem/features/profile/domain/entities/orders_overview.dart';
import 'package:reem/features/profile/domain/entities/profile_overview.dart';
import 'package:reem/features/profile/domain/entities/referral.dart';

/// Her profile centre, read from her own rows.
///
/// Replaces a mock that shipped to production, where the order counts, the
/// followed stores, the referral code and the points balance were all invented
/// in the client.
///
/// Achievements and recently-viewed come back empty and stay empty: the first
/// was a list of badges with no backing anywhere, and the second needs a
/// per-customer view log the platform does not keep. Both render as nothing,
/// which is the truth.
final class ProfileOverviewRemoteDataSource extends BaseRemoteDataSource
    implements ProfileOverviewDataSource {
  const ProfileOverviewRemoteDataSource(super.dio);

  @override
  Future<ProfileOverview> getOverview() async {
    final json = await getJson(ApiEndpoints.profileOverview);

    return ProfileOverview(
      completionSteps: _list(json['completion_steps'])
          .map(
            (step) => ProfileCompletionStep(
              label: step['label'] as String? ?? '',
              done: step['done'] as bool? ?? false,
            ),
          )
          .toList(),
      followedStores: _list(json['followed_stores'])
          .map(
            (store) => FollowedStore(
              id: store['id'] as String? ?? '',
              name: store['name'] as String? ?? '',
              logoUrl: store['logo_url'] as String? ?? '',
              isVerified: store['is_verified'] as bool? ?? false,
            ),
          )
          .toList(),
      orders: _orders(json['orders']),
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      referral: _referral(json['referral']),
      loyalty: _loyalty(json['loyalty']),
    );
  }

  OrdersOverview _orders(dynamic json) {
    if (json is! Map<String, dynamic>) return const OrdersOverview();
    return OrdersOverview(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      processing: (json['processing'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  /// Null when she has never been given a code — the card then invites her to
  /// get one rather than showing an empty box where a code should be.
  Referral? _referral(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final code = json['code'] as String?;
    if (code == null || code.isEmpty) return null;

    return Referral(
      code: code,
      invited: (json['invited'] as num?)?.toInt() ?? 0,
      earnedPoints: (json['earned_points'] as num?)?.toInt() ?? 0,
      // What an invite is worth is a campaign setting, not a fact about her.
      // Empty until the rewards module publishes it, so the card shows the
      // code and the count without inventing a promise.
      rewardHint: json['reward_hint'] as String? ?? '',
    );
  }

  LoyaltySummary? _loyalty(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final points = (json['points'] as num?)?.toInt() ?? 0;
    final tier = LoyaltyTierX.fromWire(json['tier'] as String?);

    return LoyaltySummary(
      points: points,
      tier: tier,
      nextTier: tier.next,
      pointsToNextTier: tier.next == null
          ? 0
          : (tier.next!.threshold - points).clamp(0, tier.next!.threshold),
      availableCoupons: 0,
      rewardHint: '',
      lifetimePoints: (json['lifetime_points'] as num?)?.toInt(),
    );
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];
}
