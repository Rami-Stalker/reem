import 'package:reem/core/storage/secure_storage_service.dart';
import 'package:reem/features/auth/data/datasources/auth_local_datasource.dart';

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
  Future<String?> getAccessToken() =>
      storage.read(SecureStorageKeys.accessToken);

  @override
  Future<String?> getRefreshToken() =>
      storage.read(SecureStorageKeys.refreshToken);

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
    await storage.delete(SecureStorageKeys.guestMode);
  }
}
