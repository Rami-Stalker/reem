import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/security/device_identity_service.dart';
import 'package:ohara/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:ohara/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:ohara/features/auth/data/datasources/impl/auth_local_datasource_impl.dart';
import 'package:ohara/features/auth/data/datasources/impl/auth_remote_datasource_impl.dart';
import 'package:ohara/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ohara/features/auth/domain/repositories/auth_repository.dart';
import 'package:ohara/features/auth/domain/usecases/continue_as_guest_usecase.dart';
import 'package:ohara/features/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:ohara/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:ohara/features/auth/domain/usecases/login_usecase.dart';
import 'package:ohara/features/auth/domain/usecases/logout_usecase.dart';
import 'package:ohara/features/auth/domain/usecases/otp_usecases.dart';
import 'package:ohara/features/auth/domain/usecases/register_usecase.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSourceImpl(ref.watch(secureStorageProvider)),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(dioProvider)),
);

/// This device's key. Held here so the repository, the proof signer and the
/// Dio interceptor all talk about the same key rather than each generating one.
final deviceIdentityProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(ref.watch(secureStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    identity: ref.watch(deviceIdentityProvider),
  ),
);


final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final getCurrentUserUseCaseProvider = Provider(
  (ref) => GetCurrentUserUseCase(ref.watch(authRepositoryProvider)),
);

final forgotPasswordUseCaseProvider = Provider(
  (ref) => ForgotPasswordUseCase(ref.watch(authRepositoryProvider)),
);



final continueAsGuestUseCaseProvider = Provider(
  (ref) => ContinueAsGuestUseCase(ref.watch(authRepositoryProvider)),
);

final requestOtpUseCaseProvider = Provider(
  (ref) => RequestOtpUseCase(ref.watch(authRepositoryProvider)),
);

final verifyOtpUseCaseProvider = Provider(
  (ref) => VerifyOtpUseCase(ref.watch(authRepositoryProvider)),
);

final resetPasswordUseCaseProvider = Provider(
  (ref) => ResetPasswordUseCase(ref.watch(authRepositoryProvider)),
);

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
    forgotPasswordUseCase: ref.watch(forgotPasswordUseCaseProvider),
    continueAsGuestUseCase: ref.watch(continueAsGuestUseCaseProvider),
    requestOtpUseCase: ref.watch(requestOtpUseCaseProvider),
    verifyOtpUseCase: ref.watch(verifyOtpUseCaseProvider),
    resetPasswordUseCase: ref.watch(resetPasswordUseCaseProvider),
    repository: ref.watch(authRepositoryProvider),
  );
});
