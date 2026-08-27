import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/network/network_info.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/security/device_identity_service.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:reem/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:reem/features/auth/data/models/identity_models.dart';
import 'package:reem/features/auth/data/models/token_model.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl with RepositoryHandler implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
    required this.identity,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final NetworkInfo networkInfo;
  final DeviceIdentityService identity;

  /// The nonce minted for the sign-in code currently outstanding.
  ///
  /// Deliberately in memory and deliberately short-lived: it exists only
  /// between "send me a code" and "here is the code", and a nonce that
  /// survived a restart would defeat the point of binding the challenge to
  /// this running install.
  String? _pendingNonce;

  String _newClientNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Persists the pair *and* its lifetimes.
  ///
  /// The expiry timestamps used to be dropped on the floor, which is why the
  /// app could only discover an expired token by failing a request with it.
  Future<void> _persistTokens(TokenModel tokens, {bool persistRefresh = true}) async {
    await local.saveAccessToken(tokens.accessToken);
    if (persistRefresh) {
      await local.saveRefreshToken(tokens.refreshToken);
    } else {
      await local.clearRefreshToken();
    }
    await local.saveTokenLifetimes(
      accessExpiresAt: tokens.accessExpiresAt,
      refreshExpiresAt: tokens.refreshExpiresAt,
    );
  }

  @override
  Future<Result<OtpChallenge>> startOtpLogin({required String phone}) =>
      guard(() async {
        await _ensureConnected();
        // A fresh nonce per attempt, kept only until the code comes back. It is
        // what lets the server prove the code was entered by the install that
        // asked for it — so a code read aloud to "Reem support" cannot be spent
        // from their handset.
        final nonce = _newClientNonce();
        _pendingNonce = nonce;
        return remote.startOtpLogin(
          phone: phone,
          clientNonce: nonce,
          platform: defaultTargetPlatform.name,
        );
      });

  @override
  Future<Result<OtpLoginResult>> completeOtpLogin({
    required String phone,
    required String code,
  }) => guard(() async {
    await _ensureConnected();
    final response = await remote.completeOtpLogin(
      phone: phone,
      code: code,
      clientNonce: _pendingNonce,
      platform: defaultTargetPlatform.name,
    );
    _pendingNonce = null;

    final tokens = response.tokens;
    if (tokens != null) {
      await _persistTokens(tokens);
      await local.clearGuestSession();
      await local.saveGuestMode(false);
    }
    return response.result;
  });

  @override
  Future<Result<bool>> setPassword({
    String? currentPassword,
    required String newPassword,
  }) => guard(() async {
    await _ensureConnected();
    return remote.setPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  });

  @override
  Future<Result<bool>> removePassword() => guard(() async {
    await _ensureConnected();
    return remote.removePassword();
  });

  @override
  Future<Result<PhoneChangeRequest>> startPhoneChange({
    required String newPhone,
  }) => guard(() async {
    await _ensureConnected();
    return remote.startPhoneChange(newPhone: newPhone);
  });

  @override
  Future<Result<PhoneChangeRequest>> verifyCurrentPhone({
    required String requestId,
    required String code,
  }) => guard(() async {
    await _ensureConnected();
    return remote.verifyCurrentPhone(requestId: requestId, code: code);
  });

  @override
  Future<Result<DateTime?>> confirmPhoneChange({
    required String requestId,
    required String code,
  }) => guard(() async {
    await _ensureConnected();
    final json = await remote.confirmPhoneChange(
      requestId: requestId,
      code: code,
    );
    final frozen = json['payout_frozen_until'];
    return frozen is String ? DateTime.parse(frozen) : null;
  });

  @override
  Future<Result<void>> cancelPhoneChange(String requestId) => guard(() async {
    await _ensureConnected();
    await remote.cancelPhoneChange(requestId);
  });

  @override
  Future<Result<PhoneChangeRequest?>> pendingPhoneChange() => guard(() async {
    await _ensureConnected();
    return remote.pendingPhoneChange();
  });

  @override
  Future<Result<OtpChallenge>> requestStepUp(String scope) => guard(() async {
    await _ensureConnected();
    return remote.requestStepUp(scope);
  });

  @override
  Future<Result<void>> verifyStepUp({
    required String scope,
    required String code,
    String? method,
  }) => guard(() async {
    await _ensureConnected();
    await remote.verifyStepUp(scope: scope, code: code, method: method);
  });

  @override
  Future<Result<List<String>>> generateRecoveryCodes() => guard(() async {
    await _ensureConnected();
    return remote.generateRecoveryCodes();
  });

  @override
  Future<Result<int>> remainingRecoveryCodes() => guard(() async {
    await _ensureConnected();
    final json = await remote.recoveryCodeStatus();
    return json['remaining'] as int? ?? 0;
  });

  @override
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
  }) => guard(() async {
    await _ensureConnected();
    return remote.submitRecoveryCase(
      RecoveryClaimModel(
        claimedPhone: claimedPhone,
        contactPhone: contactPhone,
        contactCode: contactCode,
        registrationMonth: registrationMonth,
        displayName: displayName,
        city: city,
        lastOrderMonth: lastOrderMonth,
        lastOrderTotal: lastOrderTotal,
        deviceLabel: deviceLabel,
      ),
    );
  });

  @override
  Future<Result<String>> recoveryCaseStatus({
    required String caseId,
    required String claimSecret,
  }) => guard(() async {
    await _ensureConnected();
    final json = await remote.recoveryCaseStatus(
      caseId: caseId,
      claimSecret: claimSecret,
    );
    return json['status'] as String? ?? 'submitted';
  });

  @override
  Future<Result<List<OpenRecoveryCase>>> openRecoveryCases() => guard(() async {
    await _ensureConnected();
    return remote.openRecoveryCases();
  });

  @override
  Future<Result<void>> cancelRecoveryCase(String caseId) => guard(() async {
    await _ensureConnected();
    await remote.cancelRecoveryCase(caseId);
  });

  @override
  Future<Result<User>> login({
    required String phone,
    required String password,
    required bool rememberMe,
  }) => guard(() async {
    await _ensureConnected();
    final response = await remote.login(phone: phone, password: password);
    await _persistTokens(response.tokens, persistRefresh: rememberMe);
    await local.clearGuestSession();
    await local.saveGuestMode(false);
    return response.user;
  });

  @override
  Future<Result<User>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String registrationTicket,
    String? password,
    required String country,
    required String city,
    required bool declaredFemale,
    UserRole role = UserRole.customer,
  }) => guard(() async {
    await _ensureConnected();
    final response = await remote.register(
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
    await _persistTokens(response.tokens);
    await local.clearGuestSession();
    await local.saveGuestMode(false);
    return response.user;
  });

  @override
  Future<Result<void>> ensureDeviceRegistered() => guard(() async {
    if (await identity.deviceKeyId() != null) return;
    await _ensureConnected();
    final id = await remote.registerDeviceKey(
      publicKey: await identity.publicKeyBase64Url(),
      // Software-backed for now — the key lives in secure storage, not in
      // Keystore/Secure Enclave. Recorded honestly so the server's fleet view
      // reflects reality rather than an aspiration.
      hardwareBacked: false,
      platform: defaultTargetPlatform.name,
    );
    await identity.saveDeviceKeyId(id);
  });

  @override
  Future<Result<void>> continueAsGuest() => guard(() async {
    await _ensureConnected();
    final guestToken = await remote.createGuestSession();
    await local.clear();
    await local.saveGuestToken(guestToken);
    await local.saveGuestMode(true);
  });

  @override
  Future<Result<bool>> isGuestSession() => guard(local.isGuestMode);

  @override
  Future<Result<void>> logout() => guard(() async {
    // Best-effort server-side revocation, then always clear local session.
    final refresh = await local.getRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await remote.logout(refresh);
      } catch (_) {
        // Network/expiry failures must not block local logout.
      }
    }
    await local.clear();
  });

  @override
  Future<Result<User?>> getCurrentUser() => guard(() async {
    final token = await local.getAccessToken();
    if (token == null || token.isEmpty) return null;
    await _ensureConnected();
    return remote.getCurrentUser();
  });

  @override
  Future<Result<User>> refreshSession() => guard(() async {
    final refresh = await local.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedException(
        'Session expired. Please sign in again.',
      );
    }
    final response = await remote.refreshToken(refresh);
    await _persistTokens(response.tokens);
    return response.user;
  });

  @override
  Future<Result<void>> forgotPassword({required String phone}) =>
      guard(() async {
        await _ensureConnected();
        await remote.forgotPassword(phone: phone);
      });

  @override
  Future<Result<OtpChallenge>> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) => guard(() async {
    await _ensureConnected();
    return remote.requestOtp(phone: phone, purpose: purpose);
  });

  @override
  Future<Result<void>> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  }) => guard(() async {
    await _ensureConnected();
    await remote.verifyOtp(phone: phone, purpose: purpose, code: code);
  });

  @override
  Future<Result<void>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) => guard(() async {
    await _ensureConnected();
    await remote.resetPassword(
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
  });

  @override
  Future<Result<AuthAccount>> getAccount() => guard(() async {
    await _ensureConnected();
    return remote.getAccount();
  });

  @override
  Future<Result<User>> updateAccount({
    String? name,
    String? email,
    String? location,
  }) => guard(() async {
    await _ensureConnected();
    final user = await remote.updateAccount(
      name: name,
      email: email,
      location: location,
    );
    return user;
  });

  @override
  Future<Result<SecuritySettings>> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) => guard(() async {
    await _ensureConnected();
    return remote.updateSecurity(
      mfaEnabled: mfaEnabled,
      deviceVerificationRequired: deviceVerificationRequired,
    );
  });

  @override
  Future<Result<List<AccountDevice>>> getDevices() => guard(() async {
    await _ensureConnected();
    return remote.getDevices();
  });

  @override
  Future<Result<AccountDevice>> renameDevice({
    required String id,
    required String name,
  }) => guard(() async {
    await _ensureConnected();
    return remote.renameDevice(id: id, name: name);
  });

  @override
  Future<Result<void>> revokeDevice(String id) => guard(() async {
    await _ensureConnected();
    await remote.revokeDevice(id);
  });

  @override
  Future<Result<List<AccountSession>>> getSessions() => guard(() async {
    await _ensureConnected();
    return remote.getSessions();
  });

  @override
  Future<Result<void>> revokeSession(String id) => guard(() async {
    await _ensureConnected();
    await remote.revokeSession(id);
  });

  @override
  Future<Result<void>> logoutAll() => guard(() async {
    await _ensureConnected();
    await remote.logoutAll();
    await local.clear();
  });

  @override
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
  }) => guard(() async {
    await _ensureConnected();
    return remote.submitSellerVerification(
      businessName: businessName,
      legalName: legalName,
      businessCategory: businessCategory,
      storeDescription: storeDescription,
      storeLogoUrl: storeLogoUrl,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      businessAddress: businessAddress,
      warehouseAddress: warehouseAddress,
      commercialRegistration: commercialRegistration,
      governmentIdUrl: governmentIdUrl,
      businessLicenseUrl: businessLicenseUrl,
      taxId: taxId,
      bankName: bankName,
      accountHolder: accountHolder,
      iban: iban,
      paymentInformation: paymentInformation,
      shippingMethods: shippingMethods,
      returnPolicy: returnPolicy,
      productCategories: productCategories,
      yearsExperience: yearsExperience,
      website: website,
      socialMediaLinks: socialMediaLinks,
      documentUrls: documentUrls,
    );
  });

  @override
  Future<Result<SellerVerification?>> getSellerVerification() =>
      guard(() async {
        await _ensureConnected();
        return remote.getSellerVerification();
      });

  Future<void> _ensureConnected() async {
    if (!await networkInfo.isConnected) {
      throw const NetworkException(
        'You are offline. Please reconnect and try again.',
      );
    }
  }
}
