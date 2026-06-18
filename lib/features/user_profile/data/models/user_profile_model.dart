import 'package:reem/core/shared/models/user_model.dart';

import '../../domain/entities/user_profile.dart';
import 'seller_stats_model.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.user,
    super.isMe,
    super.isFollowing,
    super.productsCount,
    super.postsCount,
    super.sellerStats,
  });

  /// The backend returns user fields at the top level (spread) plus the
  /// relationship/stat annotations alongside them.
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final statsJson = json['seller_stats'];
    return UserProfileModel(
      user: UserModel.fromJson(json),
      isMe: json['is_me'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
      productsCount: json['products_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      sellerStats: statsJson is Map<String, dynamic>
          ? SellerStatsModel.fromJson(statsJson)
          : null,
    );
  }
}
