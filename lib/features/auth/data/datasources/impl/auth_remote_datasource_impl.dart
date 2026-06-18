import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:reem/features/auth/data/models/account_models.dart';
import 'package:reem/features/auth/data/models/auth_response_model.dart';
import 'package:reem/features/auth/data/models/login_request_model.dart';
import 'package:reem/features/auth/data/models/register_request_model.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

final class AuthRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(super.dio);

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
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    final json = await postJson(
      ApiEndpoints.authRegister,
      body: RegisterRequestModel(
        name: name,
        email: email,
        phone: phone,
        password: password,
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
  Future<AuthResponseModel> socialSignIn({
    required SocialAuthProvider provider,
    String? idToken,
    String? providerUserId,
    String? email,
    String? name,
  }) async {
    final json = await postJson(
      ApiEndpoints.authSocial,
      body: {
        'provider': provider.wire,
        if (idToken != null) 'id_token': idToken,
        if (providerUserId != null) 'provider_user_id': providerUserId,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
      },
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final json = await getJson(ApiEndpoints.authMe);
    final userJson = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return UserModel.fromJson(userJson);
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
    String? phone,
    String? location,
  }) async {
    final json = await patchJson(
      ApiEndpoints.authAccount,
      body: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (location != null) 'location': location,
      },
    );
    return UserModel.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    await patchJson(
      ApiEndpoints.authAccountPassword,
      body: {
        if (currentPassword != null) 'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<SecuritySettingsModel> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) async {
    final json = await patchJson(
      ApiEndpoints.authSecurity,
      body: {
        if (mfaEnabled != null) 'mfa_enabled': mfaEnabled,
        if (deviceVerificationRequired != null)
          'device_verification_required': deviceVerificationRequired,
      },
    );
    return SecuritySettingsModel.fromJson(json);
  }

  @override
  Future<List<AccountDeviceModel>> getDevices() async {
    final list = await getList(ApiEndpoints.authDevices);
    return list
        .whereType<Map>()
        .map((item) => AccountDeviceModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
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
  Future<void> trustDevice(String id) async {
    await postJson(ApiEndpoints.authTrustDevice(id));
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
        .map((item) => AccountSessionModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
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
  Future<AuthAccountModel> linkAccount({
    required SocialAuthProvider provider,
    String? idToken,
    String? providerUserId,
    String? email,
    String? name,
  }) async {
    final json = await postJson(
      ApiEndpoints.authAccountLink,
      body: {
        'provider': provider.wire,
        if (idToken != null) 'id_token': idToken,
        if (providerUserId != null) 'provider_user_id': providerUserId,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
      },
    );
    return AuthAccountModel.fromJson(json);
  }

  @override
  Future<AuthAccountModel> unlinkAccount(SocialAuthProvider provider) async {
    final json = await deleteJson(ApiEndpoints.authAccountUnlink(provider.wire));
    return AuthAccountModel.fromJson(json);
  }

  @override
  Future<SellerVerificationModel> submitSellerVerification({
    required String businessName,
    required String legalName,
    String? taxId,
    required List<String> documentUrls,
  }) async {
    final json = await postJson(
      ApiEndpoints.authSellerVerification,
      body: {
        'business_name': businessName,
        'legal_name': legalName,
        if (taxId != null) 'tax_id': taxId,
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
