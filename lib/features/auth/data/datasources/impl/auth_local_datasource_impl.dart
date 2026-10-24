import 'package:ohara/core/storage/secure_storage_service.dart';
import 'package:ohara/features/auth/data/datasources/auth_local_datasource.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this.storage);

  final SecureStorageService storage;

  @override
  Future<void> saveAccessToken(String token) =>
      storage.write(SecureStorageKeys.accessToken, token);

  @override
  Future<void> saveRefreshToken(String token) =>
      storage.write(SecureStorageKeys.refreshToken, token);

  @override
  Future<void> clearRefreshToken() =>
      storage.delete(SecureStorageKeys.refreshToken);

  @override
  Future<String?> getAccessToken() =>
      storage.read(SecureStorageKeys.accessToken);

  @override
  Future<String?> getRefreshToken() =>
      storage.read(SecureStorageKeys.refreshToken);

  @override
  Future<void> saveGuestToken(String token) =>
      storage.write(SecureStorageKeys.guestToken, token);

  @override
  Future<void> saveTokenLifetimes({
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
  }) async {
    if (accessExpiresAt == null) {
      await storage.delete(SecureStorageKeys.accessTokenExpiresAt);
    } else {
      await storage.write(
        SecureStorageKeys.accessTokenExpiresAt,
        accessExpiresAt.toIso8601String(),
      );
    }
    if (refreshExpiresAt == null) {
      await storage.delete(SecureStorageKeys.refreshTokenExpiresAt);
    } else {
      await storage.write(
        SecureStorageKeys.refreshTokenExpiresAt,
        refreshExpiresAt.toIso8601String(),
      );
    }
  }

  @override
  Future<DateTime?> getAccessTokenExpiry() async {
    final raw = await storage.read(SecureStorageKeys.accessTokenExpiresAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<String?> getGuestToken() => storage.read(SecureStorageKeys.guestToken);

  @override
  Future<void> clearGuestSession() async {
    await storage.delete(SecureStorageKeys.guestToken);
    await storage.delete(SecureStorageKeys.guestMode);
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await storage.read(SecureStorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = 'reem-${DateTime.now().microsecondsSinceEpoch}';
    await storage.write(SecureStorageKeys.deviceId, generated);
    return generated;
  }

  @override
  Future<void> saveGuestMode(bool enabled) =>
      storage.write(SecureStorageKeys.guestMode, enabled ? 'true' : 'false');

  @override
  Future<bool> isGuestMode() async =>
      (await storage.read(SecureStorageKeys.guestMode)) == 'true';

  @override
  Future<void> clear() async {
    await storage.delete(SecureStorageKeys.accessToken);
    await storage.delete(SecureStorageKeys.refreshToken);
    await storage.delete(SecureStorageKeys.guestToken);
    await storage.delete(SecureStorageKeys.guestMode);
  }
}
