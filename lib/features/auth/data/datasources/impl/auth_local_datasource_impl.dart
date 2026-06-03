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
  Future<void> clear() => storage.deleteAll();
}
