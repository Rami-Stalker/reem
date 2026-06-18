import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../entities/follow_result.dart';
import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<Result<UserProfile>> getMyProfile();

  Future<Result<UserProfile>> getProfile(String userId);

  Future<Result<User>> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
    String? location,
  });

  Future<Result<FollowResult>> follow(String userId);

  Future<Result<FollowResult>> unfollow(String userId);

  Future<Result<List<User>>> followers(String userId);

  Future<Result<List<User>>> following(String userId);
}
