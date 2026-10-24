import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/models/user_model.dart';

import 'package:ohara/features/user_profile/domain/entities/follow_result.dart';
import 'package:ohara/features/user_profile/domain/entities/user_profile.dart';
import 'package:ohara/features/user_profile/domain/usecases/follow_seller_usecase.dart';
import 'package:ohara/features/user_profile/domain/usecases/get_my_profile_usecase.dart';
import 'package:ohara/features/user_profile/domain/usecases/get_user_profile_usecase.dart';
import 'package:ohara/features/user_profile/domain/usecases/unfollow_seller_usecase.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_state.dart';

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier({
    required this.userId,
    required GetMyProfileUseCase getMyProfile,
    required GetUserProfileUseCase getProfile,
    required FollowSellerUseCase follow,
    required UnfollowSellerUseCase unfollow,
  }) : _getMyProfile = getMyProfile,
       _getProfile = getProfile,
       _follow = follow,
       _unfollow = unfollow,
       super(const UserProfileState());

  /// `null` => the signed-in user's own profile.
  final String? userId;

  final GetMyProfileUseCase _getMyProfile;
  final GetUserProfileUseCase _getProfile;
  final FollowSellerUseCase _follow;
  final UnfollowSellerUseCase _unfollow;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = userId == null
        ? await _getMyProfile()
        : await _getProfile(userId!);
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, profile: data),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  Future<void> toggleFollow() async {
    final profile = state.profile;
    if (profile == null || profile.isMe || state.isFollowLoading) return;

    state = state.copyWith(isFollowLoading: true, clearError: true);
    final result = profile.isFollowing
        ? await _unfollow(profile.user.id)
        : await _follow(profile.user.id);

    state = switch (result) {
      Success(:final data) => state.copyWith(
        isFollowLoading: false,
        profile: _apply(profile, data),
      ),
      Error(:final failure) => state.copyWith(
        isFollowLoading: false,
        error: failure.message,
      ),
    };
  }

  /// After she opened or closed her page — the server's answer, not a guess.
  void applyVisibility(bool isPublic) {
    final profile = state.profile;
    if (profile == null) return;
    state = state.copyWith(profile: profile.copyWith(profileIsPublic: isPublic));
  }

  UserProfile _apply(UserProfile profile, FollowResult result) {
    final updatedUser = UserModel.fromEntity(
      profile.user,
    ).copyWith(followersCount: result.followersCount);
    return profile.copyWith(isFollowing: result.isFollowing, user: updatedUser);
  }
}
