import 'package:reem/features/user_profile/domain/entities/follow_result.dart';

class FollowResultModel extends FollowResult {
  const FollowResultModel({
    required super.isFollowing,
    required super.followersCount,
  });

  factory FollowResultModel.fromJson(Map<String, dynamic> json) {
    return FollowResultModel(
      isFollowing: json['is_following'] as bool? ?? false,
      followersCount: json['followers_count'] as int? ?? 0,
    );
  }
}
