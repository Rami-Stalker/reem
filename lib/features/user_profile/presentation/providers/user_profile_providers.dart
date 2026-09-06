import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/user_profile/data/datasources/impl/user_profile_remote_datasource_impl.dart';
import 'package:reem/features/user_profile/data/datasources/user_profile_remote_datasource.dart';
import 'package:reem/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:reem/features/user_profile/domain/usecases/follow_seller_usecase.dart';
import 'package:reem/features/user_profile/domain/usecases/get_my_profile_usecase.dart';
import 'package:reem/features/user_profile/domain/usecases/get_user_profile_usecase.dart';
import 'package:reem/features/user_profile/domain/usecases/unfollow_seller_usecase.dart';
import 'package:reem/features/user_profile/domain/usecases/update_profile_usecase.dart';
import 'package:reem/features/user_profile/presentation/providers/edit_profile_notifier.dart';
import 'package:reem/features/user_profile/presentation/providers/edit_profile_state.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_notifier.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_state.dart';
import 'package:reem/features/user_profile/presentation/screens/follow_list_screen.dart';

final userProfileRemoteDataSourceProvider =
    Provider<UserProfileRemoteDataSource>(
      (ref) => UserProfileRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) =>
      UserProfileRepositoryImpl(ref.watch(userProfileRemoteDataSourceProvider)),
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

/// The people behind a profile's follower and following counts.
///
/// Both endpoints existed from the start and nothing called them; the counts
/// on every profile were numbers with nothing behind them.
final followListProvider = FutureProvider.autoDispose
    .family<List<User>, ({String userId, FollowListKind kind})>((
      ref,
      args,
    ) async {
      final repository = ref.watch(userProfileRepositoryProvider);
      final result = args.kind == FollowListKind.following
          ? await repository.following(args.userId)
          : await repository.followers(args.userId);

      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });
