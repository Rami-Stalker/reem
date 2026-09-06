import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:reem/features/auth/data/models/account_models.dart';
import 'package:reem/features/auth/data/models/auth_response_model.dart';
import 'package:reem/features/auth/data/models/identity_models.dart';
import 'package:reem/features/auth/data/models/login_request_model.dart';
import 'package:reem/features/auth/data/models/register_request_model.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

final class AuthRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(super.dio);

  @override
  Future<String> createGuestSession() async {
    final json = await postJson(ApiEndpoints.authGuest);
    final token = json['guest_token'];
    if (token is String && token.isNotEmpty) return token;
    throw StateError('Guest session response did not include guest_token');
  }

  @override
  Future<String> registerDeviceKey({
    required String publicKey,
    required bool hardwareBacked,
    String? label,
    String? platform,
    String? appVersion,
  }) async {
    final json = await postJson(
      ApiEndpoints.authDeviceKeys,
      body: {
        'public_key': publicKey,
        'key_storage': hardwareBacked ? 'hardware' : 'software',
        'hardware_backed': hardwareBacked,
        'label': ?label,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
    );
    final id = json['device_key_id'];
    if (id is String && id.isNotEmpty) return id;
    throw StateError('Device key response did not include device_key_id');
  }

  @override
  Future<OtpChallengeModel> startOtpLogin({
    required String phone,
    String? clientNonce,
    String? deviceName,
    String? platform,
    String? appVersion,
  }) async {
    final json = await postJson(
      ApiEndpoints.authOtpLoginStart,
      body: {
        'phone': phone,
        'client_nonce': ?clientNonce,
        'device_name': ?deviceName,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
    );
    return OtpChallengeModel.fromJson(json);
  }

  @override
  Future<OtpLoginResponse> completeOtpLogin({
    required String phone,
    required String code,
    String? clientNonce,
    String? deviceName,
    String? platform,
    String? appVersion,
  }) async {
    final json = await postJson(
      ApiEndpoints.authOtpLoginVerify,
      body: {
        'phone': phone,
        'code': code,
        'client_nonce': ?clientNonce,
        'device_name': ?deviceName,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
    );
    return OtpLoginResponse.fromJson(json);
  }

  @override
  Future<bool> setPassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final json = await postJson(
      ApiEndpoints.authAccountPassword,
      body: {
        'current_password': ?currentPassword,
        'new_password': newPassword,
      },
    );
    return json['password_enabled'] as bool? ?? true;
  }

  @override
  Future<bool> removePassword() async {
    final json = await deleteJson(ApiEndpoints.authAccountPassword);
    return json['password_enabled'] as bool? ?? false;
  }

  @override
  Future<PhoneChangeRequestModel> startPhoneChange({
    required String newPhone,
  }) async {
    final json = await postJson(
      ApiEndpoints.authPhoneChangeStart,
      body: {'new_phone': newPhone},
    );
    return PhoneChangeRequestModel.fromJson(json);
  }

  @override
  Future<PhoneChangeRequestModel> verifyCurrentPhone({
    required String requestId,
    required String code,
  }) async {
    final json = await postJson(
      ApiEndpoints.authPhoneChangeVerifyCurrent(requestId),
      body: {'code': code},
    );
    return PhoneChangeRequestModel.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> confirmPhoneChange({
    required String requestId,
    required String code,
  }) {
    return postJson(
      ApiEndpoints.authPhoneChangeConfirm(requestId),
      body: {'code': code},
    );
  }

  @override
  Future<void> cancelPhoneChange(String requestId) async {
    await deleteRequest(ApiEndpoints.authPhoneChange(requestId));
  }

  @override
  Future<PhoneChangeRequestModel?> pendingPhoneChange() async {
    final json = await getJson(ApiEndpoints.authPhoneChangePending);
    final pending = json['pending'];
    if (pending is! Map) return null;
    return PhoneChangeRequestModel.fromJson(Map<String, dynamic>.from(pending));
  }

  @override
  Future<OtpChallengeModel> requestStepUp(String scope) async {
    final json = await postJson(
      ApiEndpoints.authStepUpRequest,
      body: {'scope': scope},
    );
    return OtpChallengeModel.fromJson(json);
  }

  @override
  Future<void> verifyStepUp({
    required String scope,
    required String code,
    String? method,
  }) async {
    await postJson(
      ApiEndpoints.authStepUpVerify,
      body: {
        'scope': scope,
        'code': code,
        'method': ?method,
      },
    );
  }

  @override
  Future<List<String>> generateRecoveryCodes() async {
    final json = await postJson(ApiEndpoints.authRecoveryCodes);
    final codes = json['codes'];
    return codes is List ? codes.map((e) => e.toString()).toList() : const [];
  }

  @override
  Future<Map<String, dynamic>> recoveryCodeStatus() {
    return getJson(ApiEndpoints.authRecoveryCodes);
  }

  @override
  Future<RecoveryCaseReceiptModel> submitRecoveryCase(
    RecoveryClaimModel claim,
  ) async {
    final json = await postJson(
      ApiEndpoints.authRecoveryCases,
      body: claim.toJson(),
    );
    return RecoveryCaseReceiptModel.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> recoveryCaseStatus({
    required String caseId,
    required String claimSecret,
  }) {
    // POST, not GET: the claim secret must never travel in a URL, where every
    // proxy between her handset and the server would write it to a log.
    return postJson(
      ApiEndpoints.authRecoveryCaseStatus(caseId),
      body: {'claim_secret': claimSecret},
    );
  }

  @override
  Future<List<OpenRecoveryCaseModel>> openRecoveryCases() async {
    final list = await getList(ApiEndpoints.authRecoveryCases);
    return list
        .whereType<Map>()
        .map(
          (item) =>
              OpenRecoveryCaseModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<void> cancelRecoveryCase(String caseId) async {
    await postJson(ApiEndpoints.authRecoveryCaseCancel(caseId));
  }

  @override
  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    final json = await postJson(
      ApiEndpoints.authLogin,
      body: LoginRequestModel(phone: phone, password: password).toJson(),
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> register({
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
    final json = await postJson(
      ApiEndpoints.authRegister,
      body: RegisterRequestModel(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        registrationTicket: registrationTicket,
        password: password,
        country: country,
        city: city,
        declaredFemale: declaredFemale,
        role: role,
      ).toJson(),
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    final json = await postJson(
      ApiEndpoints.authRefresh,
      body: {'refresh_token': refreshToken},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final json = await getJson(ApiEndpoints.authMe);
    return UserModel.fromAuthPayload(json);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await postJson(
      ApiEndpoints.authLogout,
      body: {'refresh_token': refreshToken},
    );
  }

  @override
  Future<void> forgotPassword({required String phone}) async {
    await postJson(ApiEndpoints.authForgotPassword, body: {'phone': phone});
  }

  @override
  Future<OtpChallengeModel> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    final json = await postJson(
      ApiEndpoints.authOtpRequest,
      body: {'phone': phone, 'purpose': purpose.wire},
    );
    return OtpChallengeModel.fromJson(json);
  }

  @override
  Future<void> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  }) async {
    await postJson(
      ApiEndpoints.authOtpVerify,
      body: {'phone': phone, 'purpose': purpose.wire, 'code': code},
    );
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await postJson(
      ApiEndpoints.authResetPassword,
      body: {'phone': phone, 'code': code, 'new_password': newPassword},
    );
  }

  @override
  Future<AuthAccountModel> getAccount() async {
    final json = await getJson(ApiEndpoints.authAccount);
    return AuthAccountModel.fromJson(json);
  }

  @override
  Future<UserModel> updateAccount({
    String? name,
    String? email,
    String? location,
  }) async {
    final json = await patchJson(
      ApiEndpoints.authAccount,
      body: {
        'name': ?name,
        'email': ?email,
        'location': ?location,
      },
    );
    return UserModel.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<SecuritySettingsModel> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) async {
    final json = await patchJson(
      ApiEndpoints.authSecurity,
      body: {
        'mfa_enabled': ?mfaEnabled,
        'device_verification_required': ?deviceVerificationRequired,
      },
    );
    return SecuritySettingsModel.fromJson(json);
  }

  @override
  Future<List<AccountDeviceModel>> getDevices() async {
    final list = await getList(ApiEndpoints.authDevices);
    return list
        .whereType<Map>()
        .map(
          (item) =>
              AccountDeviceModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<AccountDeviceModel> renameDevice({
    required String id,
    required String name,
  }) async {
    final json = await patchJson(
      ApiEndpoints.authDevice(id),
      body: {'name': name},
    );
    return AccountDeviceModel.fromJson(json);
  }

  @override
  Future<void> revokeDevice(String id) async {
    await deleteRequest(ApiEndpoints.authDevice(id));
  }

  @override
  Future<List<AccountSessionModel>> getSessions() async {
    final list = await getList(ApiEndpoints.authSessions);
    return list
        .whereType<Map>()
        .map(
          (item) =>
              AccountSessionModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<void> revokeSession(String id) async {
    await deleteRequest(ApiEndpoints.authSession(id));
  }

  @override
  Future<void> logoutAll() async {
    await postJson(ApiEndpoints.authLogoutAll);
  }

  @override
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
  }) async {
    final json = await postJson(
      ApiEndpoints.authSellerVerification,
      body: {
        'business_name': businessName,
        'legal_name': legalName,
        'business_category': businessCategory,
        'store_description': storeDescription,
        'store_logo_url': storeLogoUrl,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'business_address': businessAddress,
        'warehouse_address': warehouseAddress,
        'commercial_registration': commercialRegistration,
        'government_id_url': governmentIdUrl,
        'business_license_url': businessLicenseUrl,
        'tax_id': ?taxId,
        'bank_name': bankName,
        'account_holder': accountHolder,
        'iban': iban,
        'payment_information': ?paymentInformation,
        'shipping_methods': shippingMethods,
        'return_policy': returnPolicy,
        'product_categories': productCategories,
        'years_experience': yearsExperience,
        'website': ?website,
        'social_media_links': ?socialMediaLinks,
        'document_urls': documentUrls,
      },
    );
    return SellerVerificationModel.fromJson(json);
  }

  @override
  Future<SellerVerificationModel?> getSellerVerification() async {
    final json = await getJson(ApiEndpoints.authSellerVerificationMe);
    final verification = json['seller_verification'];
    if (verification is! Map) return null;
    return SellerVerificationModel.fromJson(
      Map<String, dynamic>.from(verification),
    );
  }
}
