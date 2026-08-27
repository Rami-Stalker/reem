import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/presentation/providers/core_providers.dart';
import '../../data/datasources/impl/user_profile_remote_datasource_impl.dart';
import '../../data/datasources/user_profile_remote_datasource.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/usecases/follow_seller_usecase.dart';
import '../../domain/usecases/get_my_profile_usecase.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/unfollow_seller_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'edit_profile_notifier.dart';
import 'edit_profile_state.dart';
import 'user_profile_notifier.dart';
import 'user_profile_state.dart';

final userProfileRemoteDataSourceProvider =
    Provider<UserProfileRemoteDataSource>(
  (ref) => UserProfileRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepositoryImpl(
    ref.watch(userProfileRemoteDataSourceProvider),
  ),
);

final getMyProfileUseCaseProvider = Provider(
  (ref) => GetMyProfileUseCase(ref.watch(userProfileRepositoryProvider)),
);

final getUserProfileUseCaseProvider = Provider(
  (ref) => GetUserProfileUseCase(ref.watch(userProfileRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfileUseCase(ref.watch(userProfileRepositoryProvider)),
);

final followSellerUseCaseProvider = Provider(
  (ref) => FollowSellerUseCase(ref.watch(userProfileRepositoryProvider)),
);

final unfollowSellerUseCaseProvider = Provider(
  (ref) => UnfollowSellerUseCase(ref.watch(userProfileRepositoryProvider)),
);

/// View a profile by id; pass `null` to load the signed-in user's own profile.
final userProfileNotifierProvider = StateNotifierProvider.autoDispose
    .family<UserProfileNotifier, UserProfileState, String?>((ref, userId) {
  return UserProfileNotifier(
    userId: userId,
    getMyProfile: ref.watch(getMyProfileUseCaseProvider),
    getProfile: ref.watch(getUserProfileUseCaseProvider),
    follow: ref.watch(followSellerUseCaseProvider),
    unfollow: ref.watch(unfollowSellerUseCaseProvider),
  )..load();
});

final editProfileNotifierProvider =
    StateNotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>(
  (ref) => EditProfileNotifier(
    getMyProfile: ref.watch(getMyProfileUseCaseProvider),
    updateProfile: ref.watch(updateProfileUseCaseProvider),
  )..load(),
);
