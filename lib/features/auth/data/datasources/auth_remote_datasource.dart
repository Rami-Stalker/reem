import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import '../models/account_models.dart';
import '../models/auth_response_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role,
  });

  Future<AuthResponseModel> refreshToken(String refreshToken);

  Future<AuthResponseModel> socialSignIn({
    required SocialAuthProvider provider,
    String? idToken,
    String? providerUserId,
    String? email,
    String? name,
  });

  Future<UserModel> getCurrentUser();

  Future<void> logout(String refreshToken);

  Future<void> forgotPassword({required String phone});

  Future<OtpChallengeModel> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  });

  Future<void> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  });

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  });

  Future<AuthAccountModel> getAccount();

  Future<UserModel> updateAccount({
    String? name,
    String? email,
    String? phone,
    String? location,
  });

  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  Future<SecuritySettingsModel> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  });

  Future<List<AccountDeviceModel>> getDevices();

  Future<AccountDeviceModel> renameDevice({
    required String id,
    required String name,
  });

  Future<void> trustDevice(String id);

  Future<void> revokeDevice(String id);

  Future<List<AccountSessionModel>> getSessions();

  Future<void> revokeSession(String id);

  Future<void> logoutAll();

  Future<AuthAccountModel> linkAccount({
    required SocialAuthProvider provider,
    String? idToken,
    String? providerUserId,
    String? email,
    String? name,
  });

  Future<AuthAccountModel> unlinkAccount(SocialAuthProvider provider);

  Future<SellerVerificationModel> submitSellerVerification({
    required String businessName,
    required String legalName,
    String? taxId,
    required List<String> documentUrls,
  });

  Future<SellerVerificationModel?> getSellerVerification();
}
