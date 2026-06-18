import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/usecases/get_my_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'edit_profile_state.dart';

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  EditProfileNotifier({
    required GetMyProfileUseCase getMyProfile,
    required UpdateProfileUseCase updateProfile,
  })  : _getMyProfile = getMyProfile,
        _updateProfile = updateProfile,
        super(const EditProfileState());

  final GetMyProfileUseCase _getMyProfile;
  final UpdateProfileUseCase _updateProfile;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getMyProfile();
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, user: data.user),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  /// Saves the profile. Returns true on success.
  Future<bool> save({
    String? name,
    String? bio,
    String? location,
    String? imageUrl,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    final result = await _updateProfile(
      name: name,
      bio: bio,
      location: location,
      imageUrl: imageUrl,
    );
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isSaving: false,
            user: data,
            successMessage: 'Profile updated',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isSaving: false, error: failure.message);
          return false;
        }(),
    };
  }
}
