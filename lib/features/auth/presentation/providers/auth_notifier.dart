import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/network/http_cache/session_cache.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart' show User, UserRole;
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

import 'package:reem/features/auth/domain/usecases/continue_as_guest_usecase.dart';
import 'package:reem/features/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:reem/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:reem/features/auth/domain/usecases/login_usecase.dart';
import 'package:reem/features/auth/domain/usecases/logout_usecase.dart';
import 'package:reem/features/auth/domain/usecases/otp_usecases.dart';
import 'package:reem/features/auth/domain/usecases/register_usecase.dart';
import 'package:reem/features/auth/presentation/providers/auth_message.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required ForgotPasswordUseCase forgotPasswordUseCase,
    required ContinueAsGuestUseCase continueAsGuestUseCase,
    required RequestOtpUseCase requestOtpUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required AuthRepository repository,
  }) : _login = loginUseCase,
       _register = registerUseCase,
       _logout = logoutUseCase,
       _getCurrentUser = getCurrentUserUseCase,
       _forgotPassword = forgotPasswordUseCase,
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
  final ContinueAsGuestUseCase _continueAsGuest;
  final RequestOtpUseCase _requestOtp;
  final VerifyOtpUseCase _verifyOtp;
  final ResetPasswordUseCase _resetPassword;
  final AuthRepository _repository;

  /// Keeps the response cache aligned with whoever is signed in.
  ///
  /// Every path that changes the session — sign-in, OTP verify, guest, restore,
  /// sign-out — ends in a `state =`, so binding here catches all of them
  /// instead of asking thirty call sites to remember. Signing out also empties
  /// the cache, because a shared handset must not carry the last account's
  /// reads on its disk.
  @override
  set state(AuthState value) {
    final previous = super.state.user?.id;
    super.state = value;
    final next = value.user?.id;
    if (previous == next) return;
    if (next == null) {
      unawaited(SessionCache.forget());
    } else {
      SessionCache.bind(next);
    }
  }

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Before anything else: make sure this device has an identity key the
    // server knows. Every device proof is signed under it, and a device that
    // never enrolled simply cannot sign one — so this runs on every cold
    // start, and is a no-op after the first.
    await _repository.ensureDeviceRegistered();

    final result = await _getCurrentUser();
    switch (result) {
      case Success(:final data):
        state = await _restoreSuccessState(data);
      case Error(:final failure):
        // No signed-in user — so she is browsing as a visitor, and a visitor
        // needs a guest session on the server before she touches the cart or
        // saves anything.
        //
        // This used to be created only by tapping "Continue as a guest" on the
        // login screen. The app opens on /home, so anyone who simply started
        // browsing had no guest token at all: every cart and favourites route
        // answered 401, and the guest-cart migration on sign-up had nothing to
        // migrate. Issuing it here is what makes browse-without-login real.
        final isGuest = await _ensureGuestSession();
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          isGuest: isGuest,
          clearUser: true,
          error: failure.message,
        );
    }
  }

  /// Reuses the existing guest session, or asks the server for one. The issue
  /// endpoint is idempotent — it touches and returns the live session when the
  /// device already has a valid token — so this is safe on every cold start.
  Future<bool> _ensureGuestSession() async {
    final existing = await _repository.isGuestSession();
    if (existing case Success(data: true)) return true;

    final created = await _continueAsGuest();
    return created is Success;
  }

  /// The optional password path.
  ///
  /// On a handset the account has never signed in from, the server refuses with
  /// `DEVICE_VERIFICATION_REQUIRED` and sends a code instead — by design, since
  /// a password that could admit a new device would be exactly the credential
  /// this design exists to neutralise. `passwordNeedsCode` reports that so the
  /// screen can carry on to the code step rather than showing an error.
  Future<bool> login({
    required String phone,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      clearPasswordNeedsCode: true,
    );
    final result = await _login(
      phone: phone,
      password: password,
      rememberMe: rememberMe,
    );
    if (result case Error(:final failure)
        when failure.code == 'DEVICE_VERIFICATION_REQUIRED') {
      state = state.copyWith(isLoading: false, passwordNeedsCode: true);
      return false;
    }
    return _handleAuthResult(result);
  }

  /// Creates the account for a number whose control was just proved.
  ///
  /// `registrationTicket` comes from `verifyOtpLogin` and is not optional: the
  /// server will not create an account without it. The password is the reverse
  /// — leaving it null is the normal case, and the account signs in with a code
  /// on her SIM.
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String registrationTicket,
    String? password,
    required String country,
    required String city,
    required bool declaredFemale,
    UserRole role = UserRole.customer,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _register(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      registrationTicket: registrationTicket,
      password: password,
      country: country,
      city: city,
      declaredFemale: declaredFemale,
      role: role,
    );
    return _handleAuthResult(result);
  }

  // ─────────────────── OTP-first sign-in (the main door) ──────────────────

  /// Sends a code to the number she typed.
  ///
  /// Returns the challenge so the code screen can show her the two-digit match
  /// code and where the message went. The answer is identical for a number
  /// with an account and one without — the app cannot tell, and must not try
  /// to guess before the code comes back.
  Future<OtpChallenge?> startOtpLogin({required String phone}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.startOtpLogin(phone: phone);
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

  /// Spends the code. Signs her in, or hands back a ticket for the signup form.
  ///
  /// Returns null only on failure; the caller branches on the result type, so
  /// "she needs to register" is never confused with "something went wrong".
  Future<OtpLoginResult?> verifyOtpLogin({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.completeOtpLogin(phone: phone, code: code);
    return switch (result) {
      Success(:final data) => () {
        switch (data) {
          case OtpLoginAuthenticated(:final user):
            state = state.copyWith(
              isLoading: false,
              user: user,
              isGuest: false,
            );
          case OtpLoginRegistrationRequired():
            state = state.copyWith(isLoading: false);
        }
        return data;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(isLoading: false, error: failure.message);
        return null;
      }(),
    };
  }

  Future<bool> continueAsGuest() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _forgotPassword(phone: phone);
    return switch (result) {
      Success() => () {
        state = state.copyWith(
          isLoading: false,
          successMessage: AuthMessage.codeSent,
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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _verifyOtp(phone: phone, purpose: purpose, code: code);
    return switch (result) {
      Success() => () {
        state = state.copyWith(
          isLoading: false,
          successMessage: AuthMessage.verificationComplete,
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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _resetPassword(
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
    return switch (result) {
      Success() => () {
        state = state.copyWith(
          isLoading: false,
          successMessage: AuthMessage.passwordUpdatedSignInAgain,
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
        state = state.copyWith(isLoading: false, user: data, isGuest: false);
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
    // A visitor, and this is the *common* path — not the error one.
    //
    // `getCurrentUser` answers `Success(null)` when there is simply no access
    // token, which is what a first-time visitor looks like. So the guest
    // session was being created only in the `Error` branch, which fires on a
    // network failure or a refresh that was refused: a woman opening the app
    // for the first time went straight past it. Her cart and her favourites
    // then answered 401 on every call, and the guest checkout had no session
    // to attach an order to — the whole guest path was unreachable from a cold
    // start. Caught by watching a real first load: `/auth/device-keys` went
    // out, `/auth/guest` never did.
    final isGuest = await _ensureGuestSession();
    return state.copyWith(
      isLoading: false,
      isInitialized: true,
      isGuest: isGuest,
      clearUser: true,
    );
  }
}
