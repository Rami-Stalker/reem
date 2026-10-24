import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/user_profile/presentation/providers/edit_profile_message.dart';

class EditProfileState {
  const EditProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.user,
    this.error,
    this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final User? user;
  final String? error;

  /// Named, not spelled out — the screen resolves it in her locale.
  final EditProfileMessage? successMessage;

  EditProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    User? user,
    String? error,
    EditProfileMessage? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}
