import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';

abstract interface class AuthRepository {
  /// Step one of the main door: a code to whatever number she typed.
  ///
  /// Answers identically whether or not the number has an account, so the
  /// screen after it is the same either way.
  Future<Result<OtpChallenge>> startOtpLogin({required String phone});

  /// Step two. Either she is signed in, or she is handed a ticket that is the
  /// only way an account gets created for that number.
  Future<Result<OtpLoginResult>> completeOtpLogin({
    required String phone,
    required String code,
  });

  /// Step two on the reverse rail, where she sent the code rather than typing
  /// it. Same two outcomes as `completeOtpLogin`.
  Future<Result<OtpLoginResult>> completeReverseOtpLogin({
    required String phone,
  });

  /// Where her outstanding reverse ceremony stands: `pending`, `verified` or
  /// `expired`.
  Future<Result<String>> reverseOtpStatus({required String phone});

  /// Turns a password on, or replaces one. Needs a fresh second factor.
  Future<Result<bool>> setPassword({
    String? currentPassword,
    required String newPassword,
  });

  /// Turns it off. Leaves her sessions alone — dropping a credential she is
  /// not using should not sign her out of her own phone.
  Future<Result<bool>> removePassword();

  // ── Moving the account to another number ────────────────────────────────

  Future<Result<PhoneChangeRequest>> startPhoneChange({
    required String newPhone,
  });

  Future<Result<PhoneChangeRequest>> verifyCurrentPhone({
    required String requestId,
    required String code,
  });

  /// Completes the move. Every other session dies and payouts freeze for a
  /// week; returns when the freeze lifts so the app can say so.
  Future<Result<DateTime?>> confirmPhoneChange({
    required String requestId,
    required String code,
  });

  Future<Result<void>> cancelPhoneChange(String requestId);

  Future<Result<PhoneChangeRequest?>> pendingPhoneChange();

  // ── Step-up and the factors that satisfy it ─────────────────────────────

  Future<Result<OtpChallenge>> requestStepUp(String scope);

  Future<Result<void>> verifyStepUp({
    required String scope,
    required String code,
    String? method,
  });

  /// Ten single-use codes. Regenerating silently invalidates the previous set,
  /// so the screen has to show them once and say so.
  Future<Result<List<String>>> generateRecoveryCodes();

  Future<Result<int>> remainingRecoveryCodes();

  /// Begins authenticator enrolment — the secret, shown once.
  Future<Result<TotpEnrolment>> enrolTotp();

  /// Confirms it with a code read off her authenticator.
  Future<Result<void>> confirmTotp(String code);

  // ── The last door ───────────────────────────────────────────────────────

  Future<Result<RecoveryCaseReceipt>> submitRecoveryCase({
    required String claimedPhone,
    required String contactPhone,
    required String contactCode,
    String? registrationMonth,
    String? displayName,
    String? city,
    String? lastOrderMonth,
    double? lastOrderTotal,
    String? deviceLabel,
  });

  Future<Result<String>> recoveryCaseStatus({
    required String caseId,
    required String claimSecret,
  });

  /// Cases open against the signed-in account — the warning she must see while
  /// the 72-hour cool-off is running.
  Future<Result<List<OpenRecoveryCase>>> openRecoveryCases();

  Future<Result<void>> cancelRecoveryCase(String caseId);

  Future<Result<User>> login({
    required String phone,
    required String password,
    required bool rememberMe,
  });

  Future<Result<User>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String registrationTicket,
    String? password,
    required String country,
    required String city,
    required bool declaredFemale,
    List<String> acceptedPolicyVersionIds,
    UserRole role,
  });

  /// Makes sure this device has an identity key registered with the server.
  /// Safe to call on every launch — it is a no-op once enrolled.
  Future<Result<void>> ensureDeviceRegistered();

  /// Drops this device's key and enrols a fresh one for the signed-in
  /// account. For a server that no longer recognises the key this install
  /// holds — or that records it under another account — which no amount of
  /// retrying with the old key fixes.
  Future<Result<void>> reenrolDevice();

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
    String? location,
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

  Future<Result<void>> revokeDevice(String id);

  Future<Result<List<AccountSession>>> getSessions();

  Future<Result<void>> revokeSession(String id);

  Future<Result<void>> logoutAll();

  /// Whether the account can be deleted now, and what is in the way if not.
  Future<Result<AccountDeletionStatus>> accountDeletionStatus();

  /// Deletes the account and clears this handset's session. Irreversible.
  Future<Result<void>> deleteAccount({String? reason});

  Future<Result<SellerVerification>> submitSellerVerification({
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

    /// The seller terms and the commissions policy, signed here.
    ///
    /// This route is where a customer becomes a seller, so it is the only
    /// honest moment to ask: at registration those documents did not address
    /// her, and after approval she is already selling. Version ids, for the
    /// same reason registration takes them.
    List<String> acceptedPolicyVersionIds,
  });

  Future<Result<SellerVerification?>> getSellerVerification();
}
