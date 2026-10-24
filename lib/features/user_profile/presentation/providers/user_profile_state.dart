import 'package:ohara/features/user_profile/domain/entities/user_profile.dart';

class UserProfileState {
  const UserProfileState({
    this.isLoading = false,
    this.profile,
    this.error,
    this.isFollowLoading = false,
  });

  final bool isLoading;
  final UserProfile? profile;
  final String? error;
  final bool isFollowLoading;

  bool get hasData => profile != null;

  UserProfileState copyWith({
    bool? isLoading,
    UserProfile? profile,
    String? error,
    bool? isFollowLoading,
    bool clearError = false,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
    );
  }
}
