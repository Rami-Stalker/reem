import 'package:reem/core/shared/entities/user.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.isGuest = false,
    this.user,
    this.error,
    this.successMessage,
  });

  final bool isLoading;
  final bool isInitialized;
  final bool isGuest;
  final User? user;
  final String? error;
  final String? successMessage;

  bool get isAuthenticated => user != null;
  bool get canBrowseAsGuest => isGuest && user == null;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    bool? isGuest,
    User? user,
    String? error,
    String? successMessage,
    bool clearUser = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isGuest: isGuest ?? this.isGuest,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : error,
      successMessage: clearSuccess ? null : successMessage,
    );
  }
}
