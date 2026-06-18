import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart' show User, UserRole;
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

import '../../domain/usecases/continue_as_guest_usecase.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/otp_usecases.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/social_sign_in_usecase.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required ForgotPasswordUseCase forgotPasswordUseCase,
    required SocialSignInUseCase socialSignInUseCase,
    required ContinueAsGuestUseCase continueAsGuestUseCase,
    required RequestOtpUseCase requestOtpUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required AuthRepository repository,
  })  : _login = loginUseCase,
        _register = registerUseCase,
        _logout = logoutUseCase,
        _getCurrentUser = getCurrentUserUseCase,
        _forgotPassword = forgotPasswordUseCase,
        _socialSignIn = socialSignInUseCase,
        _continueAsGuest = continueAsGuestUseCase,
        _requestOtp = requestOtpUseCase,
        _verifyOtp = verifyOtpUseCase,
        _resetPassword = resetPasswordUseCase,
        _repository = repository,
        super(const AuthState()) {
    restoreSession();
  }

  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final GetCurrentUserUseCase _getCurrentUser;
  final ForgotPasswordUseCase _forgotPassword;
  final SocialSignInUseCase _socialSignIn;
  final ContinueAsGuestUseCase _continueAsGuest;
  final RequestOtpUseCase _requestOtp;
  final VerifyOtpUseCase _verifyOtp;
  final ResetPasswordUseCase _resetPassword;
  final AuthRepository _repository;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getCurrentUser();
    switch (result) {
      case Success(:final data):
        state = await _restoreSuccessState(data);
      case Error(:final failure):
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          clearUser: true,
          error: failure.message,
        );
    }
  }

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _login(phone: phone, password: password);
    return _handleAuthResult(result);
  }

  Future<bool> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );
    return _handleAuthResult(result);
  }

  Future<bool> socialSignIn(SocialAuthProvider provider) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _socialSignIn(provider);
    return _handleAuthResult(result);
  }

  Future<bool> continueAsGuest() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _continueAsGuest();
    return switch (result) {
      Success() => () {
          state = state.copyWith(
            isLoading: false,
            isInitialized: true,
            isGuest: true,
            clearUser: true,
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<bool> forgotPassword({required String phone}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _forgotPassword(phone: phone);
    return switch (result) {
      Success() => () {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Password reset link sent to your email.',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<OtpChallenge?> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _requestOtp(phone: phone, purpose: purpose);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(isLoading: false);
          return data;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return null;
        }(),
    };
  }

  Future<bool> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _verifyOtp(phone: phone, purpose: purpose, code: code);
    return switch (result) {
      Success() => () {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Verification complete.',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _resetPassword(
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
    return switch (result) {
      Success() => () {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Password updated. Please sign in again.',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _logout();
    state = switch (result) {
      Success() => state.copyWith(
          isLoading: false,
          clearUser: true,
          isGuest: false,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          error: failure.message,
        ),
    };
  }

  /// Re-fetches the signed-in user (e.g. after a profile edit) so the rest of
  /// the app reflects the latest name/avatar/bio without a full re-login.
  Future<void> refreshUser() async {
    final result = await _getCurrentUser();
    if (result case Success(:final data) when data != null) {
          state = state.copyWith(user: data);
    }
  }

  bool _handleAuthResult(Result<User> result) {
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isLoading: false,
            user: data,
            isGuest: false,
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<AuthState> _restoreSuccessState(User? user) async {
    if (user != null) {
      return state.copyWith(
        isLoading: false,
        isInitialized: true,
        user: user,
        isGuest: false,
      );
    }
    final guest = await _repository.isGuestSession();
    final isGuest = switch (guest) {
      Success(:final data) => data,
      Error() => false,
    };
    return state.copyWith(
      isLoading: false,
      isInitialized: true,
      isGuest: isGuest,
      clearUser: true,
    );
  }
}
