import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/data/models/account_models.dart';
import 'package:reem/features/auth/data/models/auth_response_model.dart';
import 'package:reem/features/auth/data/models/identity_models.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

abstract interface class AuthRemoteDataSource {
  Future<String> createGuestSession();

  /// Registers this device's public key and returns the server-side id every
  /// later device proof is signed under.
  Future<String> registerDeviceKey({
    required String publicKey,
    required bool hardwareBacked,
    String? label,
    String? platform,
    String? appVersion,
  });

  /// Step one of the main door: a code to whatever number she typed.
  Future<OtpChallengeModel> startOtpLogin({
    required String phone,
    String? clientNonce,
    String? deviceName,
    String? platform,
    String? appVersion,
  });

  /// Step two: either a session, or a ticket to create the account.
  Future<OtpLoginResponse> completeOtpLogin({
    required String phone,
    required String code,
    String? clientNonce,
    String? deviceName,
    String? platform,
    String? appVersion,
  });

  /// The optional password path. Refused with `DEVICE_VERIFICATION_REQUIRED`
  /// on a handset the account has never signed in from — by design, that is
  /// what keeps an optional password from being an account takeover.
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String registrationTicket,
    String? password,
    required String country,
    required String city,
    required bool declaredFemale,
    UserRole role,
  });

  Future<AuthResponseModel> refreshToken(String refreshToken);

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

  /// `phone` is deliberately absent: the number is the account, and moving it
  /// runs through the two-sided flow above rather than a profile patch.
  Future<UserModel> updateAccount({
    String? name,
    String? email,
    String? location,
  });

  /// Opting into a password, or replacing one. Needs AAL3.
  Future<bool> setPassword({
    String? currentPassword,
    required String newPassword,
  });

  /// Dropping it again.
  Future<bool> removePassword();

  // ── Moving the account to another number ──────────────────────────────
  Future<PhoneChangeRequestModel> startPhoneChange({required String newPhone});

  Future<PhoneChangeRequestModel> verifyCurrentPhone({
    required String requestId,
    required String code,
  });

  Future<Map<String, dynamic>> confirmPhoneChange({
    required String requestId,
    required String code,
  });

  Future<void> cancelPhoneChange(String requestId);

  Future<PhoneChangeRequestModel?> pendingPhoneChange();

  // ── Step-up, and the factors that satisfy it ──────────────────────────
  Future<OtpChallengeModel> requestStepUp(String scope);

  Future<void> verifyStepUp({
    required String scope,
    required String code,
    String? method,
  });

  Future<List<String>> generateRecoveryCodes();

  Future<Map<String, dynamic>> recoveryCodeStatus();

  // ── The last door ─────────────────────────────────────────────────────
  Future<RecoveryCaseReceiptModel> submitRecoveryCase(RecoveryClaimModel claim);

  Future<Map<String, dynamic>> recoveryCaseStatus({
    required String caseId,
    required String claimSecret,
  });

  Future<List<OpenRecoveryCaseModel>> openRecoveryCases();

  Future<void> cancelRecoveryCase(String caseId);

  Future<SecuritySettingsModel> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  });

  Future<List<AccountDeviceModel>> getDevices();

  Future<AccountDeviceModel> renameDevice({
    required String id,
    required String name,
  });

  Future<void> revokeDevice(String id);

  Future<List<AccountSessionModel>> getSessions();

  Future<void> revokeSession(String id);

  Future<void> logoutAll();

  Future<SellerVerificationModel> submitSellerVerification({
    required String businessName,
    required String legalName,
    required String businessCategory,
    required String storeDescription,
    required String storeLogoUrl,
    required String contactPhone,
    required String contactEmail,
    required String businessAddress,
    required String warehouseAddress,
    required String commercialRegistration,
    required String governmentIdUrl,
    required String businessLicenseUrl,
    String? taxId,
    required String bankName,
    required String accountHolder,
    required String iban,
    Map<String, dynamic>? paymentInformation,
    required List<String> shippingMethods,
    required String returnPolicy,
    required List<String> productCategories,
    required int yearsExperience,
    String? website,
    Map<String, dynamic>? socialMediaLinks,
    required List<String> documentUrls,
  });

  Future<SellerVerificationModel?> getSellerVerification();
}
