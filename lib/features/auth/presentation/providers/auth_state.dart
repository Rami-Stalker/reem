import 'package:reem/core/shared/entities/user.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.user,
    this.error,
    this.successMessage,
  });

  final bool isLoading;
  final bool isInitialized;
  final User? user;
  final String? error;
  final String? successMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
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
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : error,
      successMessage: clearSuccess ? null : successMessage,
    );
  }
}
