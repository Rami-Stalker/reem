import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required ForgotPasswordUseCase forgotPasswordUseCase,
  })  : _login = loginUseCase,
        _register = registerUseCase,
        _logout = logoutUseCase,
        _getCurrentUser = getCurrentUserUseCase,
        _forgotPassword = forgotPasswordUseCase,
        super(const AuthState()) {
    restoreSession();
  }

  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final GetCurrentUserUseCase _getCurrentUser;
  final ForgotPasswordUseCase _forgotPassword;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getCurrentUser();
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          isInitialized: true,
          user: data,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          isInitialized: true,
          clearUser: true,
          error: failure.message,
        ),
    };
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _login(email: email, password: password);
    return _handleAuthResult(result);
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _register(name: name, email: email, password: password);
    return _handleAuthResult(result);
  }

  Future<bool> forgotPassword({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _forgotPassword(email: email);
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

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _logout();
    state = switch (result) {
      Success() => state.copyWith(
          isLoading: false,
          clearUser: true,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          error: failure.message,
        ),
    };
  }

  bool _handleAuthResult(Result<User> result) {
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(isLoading: false, user: data);
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }
}
