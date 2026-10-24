import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/features/user_profile/data/datasources/user_profile_remote_datasource.dart';
import 'package:ohara/features/user_profile/data/models/follow_result_model.dart';
import 'package:ohara/features/user_profile/data/models/update_profile_request.dart';
import 'package:ohara/features/user_profile/data/models/user_profile_model.dart';

final class UserProfileRemoteDataSourceImpl extends BaseRemoteDataSource
    implements UserProfileRemoteDataSource {
  const UserProfileRemoteDataSourceImpl(super.dio);

  @override
  Future<UserProfileModel> getMyProfile() async {
    final json = await getJson(ApiEndpoints.usersMe);
    return UserProfileModel.fromJson(json);
  }

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    final json = await getJson(ApiEndpoints.userById(userId));
    return UserProfileModel.fromJson(json);
  }

  @override
  Future<UserModel> updateProfile(UpdateProfileRequest body) async {
    final json = await patchJson(ApiEndpoints.usersMe, body: body.toJson());
    return UserModel.fromJson(json);
  }

  @override
  Future<FollowResultModel> follow(String userId) async {
    final json = await postJson(ApiEndpoints.userFollow(userId));
    return FollowResultModel.fromJson(json);
  }

  @override
  Future<FollowResultModel> unfollow(String userId) async {
    final json = await deleteJson(ApiEndpoints.userFollow(userId));
    return FollowResultModel.fromJson(json);
  }

  @override
  Future<List<UserModel>> followers(String userId) async {
    final list = await getList(ApiEndpoints.userFollowers(userId));
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserModel>> following(String userId) async {
    final list = await getList(ApiEndpoints.userFollowing(userId));
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
