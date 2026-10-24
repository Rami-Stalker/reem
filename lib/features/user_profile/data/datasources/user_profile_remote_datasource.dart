import 'package:ohara/core/shared/models/user_model.dart';

import 'package:ohara/features/user_profile/data/models/follow_result_model.dart';
import 'package:ohara/features/user_profile/data/models/update_profile_request.dart';
import 'package:ohara/features/user_profile/data/models/user_profile_model.dart';

abstract interface class UserProfileRemoteDataSource {
  Future<UserProfileModel> getMyProfile();

  Future<UserProfileModel> getProfile(String userId);

  Future<UserModel> updateProfile(UpdateProfileRequest body);

  Future<FollowResultModel> follow(String userId);

  Future<FollowResultModel> unfollow(String userId);

  Future<List<UserModel>> followers(String userId);

  Future<List<UserModel>> following(String userId);
}
