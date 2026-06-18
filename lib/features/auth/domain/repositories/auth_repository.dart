import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

abstract interface class AuthRepository {
  Future<Result<User>> login({
    required String phone,
    required String password,
  });

  Future<Result<User>> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role,
  });

  Future<Result<User>> socialSignIn(SocialAuthProvider provider);

  Future<Result<void>> continueAsGuest();

  Future<Result<bool>> isGuestSession();

  Future<Result<void>> logout();

  Future<Result<User?>> getCurrentUser();

  Future<Result<User>> refreshSession();

  Future<Result<void>> forgotPassword({required String phone});

  Future<Result<OtpChallenge>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  });

  Future<Result<void>> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  });

  Future<Result<void>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  });

  Future<Result<AuthAccount>> getAccount();

  Future<Result<User>> updateAccount({
    String? name,
    String? email,
    String? phone,
    String? location,
  });

  Future<Result<void>> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  Future<Result<SecuritySettings>> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  });

  Future<Result<List<AccountDevice>>> getDevices();

  Future<Result<AccountDevice>> renameDevice({
    required String id,
    required String name,
  });

  Future<Result<void>> trustDevice(String id);

  Future<Result<void>> revokeDevice(String id);

  Future<Result<List<AccountSession>>> getSessions();

  Future<Result<void>> revokeSession(String id);

  Future<Result<void>> logoutAll();

  Future<Result<AuthAccount>> linkAccount(SocialAuthProvider provider);

  Future<Result<AuthAccount>> unlinkAccount(SocialAuthProvider provider);

  Future<Result<SellerVerification>> submitSellerVerification({
    required String businessName,
    required String legalName,
    String? taxId,
    required List<String> documentUrls,
  });

  Future<Result<SellerVerification?>> getSellerVerification();
}
