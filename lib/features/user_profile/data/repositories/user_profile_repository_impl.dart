import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/user_profile/data/datasources/user_profile_remote_datasource.dart';
import 'package:reem/features/user_profile/data/models/update_profile_request.dart';
import 'package:reem/features/user_profile/domain/entities/follow_result.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl
    with RepositoryHandler
    implements UserProfileRepository {
  const UserProfileRepositoryImpl(this.remote);

  final UserProfileRemoteDataSource remote;

  @override
  Future<Result<UserProfile>> getMyProfile() =>
      guard(() => remote.getMyProfile());

  @override
  Future<Result<UserProfile>> getProfile(String userId) =>
      guard(() => remote.getProfile(userId));

  @override
  Future<Result<User>> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
    String? location,
  }) =>
      guard(() => remote.updateProfile(
            UpdateProfileRequest(
              name: name,
              bio: bio,
              imageUrl: imageUrl,
              location: location,
            ),
          ));

  @override
  Future<Result<FollowResult>> follow(String userId) =>
      guard(() => remote.follow(userId));

  @override
  Future<Result<FollowResult>> unfollow(String userId) =>
      guard(() => remote.unfollow(userId));

  @override
  Future<Result<List<User>>> followers(String userId) =>
      guard(() async => remote.followers(userId));

  @override
  Future<Result<List<User>>> following(String userId) =>
      guard(() async => remote.following(userId));
}
