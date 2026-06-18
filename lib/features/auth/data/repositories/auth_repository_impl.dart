import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/network/network_info.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl with RepositoryHandler implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final NetworkInfo networkInfo;

  Future<void> _persistTokens({
    required String access,
    required String refresh,
  }) async {
    await local.saveAccessToken(access);
    await local.saveRefreshToken(refresh);
  }

  @override
  Future<Result<User>> login({
    required String phone,
    required String password,
  }) =>
      guard(() async {
        await _ensureConnected();
        final response = await remote.login(phone: phone, password: password);
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        await local.saveGuestMode(false);
        return response.user;
      });

  @override
  Future<Result<User>> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role = UserRole.customer,
  }) =>
      guard(() async {
        await _ensureConnected();
        final response = await remote.register(
          name: name,
          email: email,
          phone: phone,
          password: password,
          role: role,
        );
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        await local.saveGuestMode(false);
        return response.user;
      });

  @override
  Future<Result<User>> socialSignIn(SocialAuthProvider provider) =>
      guard(() async {
        await _ensureConnected();
        final deviceId = await local.getOrCreateDeviceId();
        final response = await remote.socialSignIn(
          provider: provider,
          providerUserId: 'dev-${provider.wire}-$deviceId',
          email: '${provider.wire}.$deviceId@dev.reem.local',
          name: '${provider.label} shopper',
        );
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        await local.saveGuestMode(false);
        return response.user;
      });

  @override
  Future<Result<void>> continueAsGuest() => guard(() async {
        await local.clear();
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
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
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
  }) =>
      guard(() async {
        await _ensureConnected();
        return remote.requestOtp(phone: phone, purpose: purpose);
      });

  @override
  Future<Result<void>> verifyOtp({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  }) =>
      guard(() async {
        await _ensureConnected();
        await remote.verifyOtp(phone: phone, purpose: purpose, code: code);
      });

  @override
  Future<Result<void>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      guard(() async {
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
    String? phone,
    String? location,
  }) =>
      guard(() async {
        await _ensureConnected();
        final user = await remote.updateAccount(
          name: name,
          email: email,
          phone: phone,
          location: location,
        );
        return user;
      });

  @override
  Future<Result<void>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) =>
      guard(() async {
        await _ensureConnected();
        await remote.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      });

  @override
  Future<Result<SecuritySettings>> updateSecurity({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) =>
      guard(() async {
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
  }) =>
      guard(() async {
        await _ensureConnected();
        return remote.renameDevice(id: id, name: name);
      });

  @override
  Future<Result<void>> trustDevice(String id) => guard(() async {
        await _ensureConnected();
        await remote.trustDevice(id);
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
  Future<Result<AuthAccount>> linkAccount(SocialAuthProvider provider) =>
      guard(() async {
        await _ensureConnected();
        final deviceId = await local.getOrCreateDeviceId();
        return remote.linkAccount(
          provider: provider,
          providerUserId: 'dev-${provider.wire}-$deviceId',
          email: '${provider.wire}.$deviceId@dev.reem.local',
          name: '${provider.label} shopper',
        );
      });

  @override
  Future<Result<AuthAccount>> unlinkAccount(SocialAuthProvider provider) =>
      guard(() async {
        await _ensureConnected();
        return remote.unlinkAccount(provider);
      });

  @override
  Future<Result<SellerVerification>> submitSellerVerification({
    required String businessName,
    required String legalName,
    String? taxId,
    required List<String> documentUrls,
  }) =>
      guard(() async {
        await _ensureConnected();
        return remote.submitSellerVerification(
          businessName: businessName,
          legalName: legalName,
          taxId: taxId,
          documentUrls: documentUrls,
        );
      });

  @override
  Future<Result<SellerVerification?>> getSellerVerification() => guard(() async {
        await _ensureConnected();
        return remote.getSellerVerification();
      });

  Future<void> _ensureConnected() async {
    if (!await networkInfo.isConnected) {
      throw const NetworkException('You are offline. Please reconnect and try again.');
    }
  }
}
