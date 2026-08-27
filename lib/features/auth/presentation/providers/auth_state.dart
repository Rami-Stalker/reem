import 'package:reem/core/shared/entities/user.dart';
import 'auth_message.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.isGuest = false,
    this.user,
    this.error,
    this.successMessage,
    this.passwordNeedsCode = false,
  });

  final bool isLoading;
  final bool isInitialized;
  final bool isGuest;
  final User? user;
  final String? error;
  /// The outcome to announce, resolved to text by the screen.
  final AuthMessage? successMessage;

  /// The password was right, but this handset is new to the account, so the
  /// server sent a code instead of a session. Not an error — the next screen
  /// is the code screen.
  final bool passwordNeedsCode;

  bool get isAuthenticated => user != null;
  bool get canBrowseAsGuest => isGuest && user == null;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    bool? isGuest,
    User? user,
    String? error,
    AuthMessage? successMessage,
    bool? passwordNeedsCode,
    bool clearUser = false,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearPasswordNeedsCode = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isGuest: isGuest ?? this.isGuest,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      passwordNeedsCode: clearPasswordNeedsCode
          ? false
          : (passwordNeedsCode ?? this.passwordNeedsCode),
    );
  }
}
