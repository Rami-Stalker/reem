import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class SecureStorageKeys {
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const deviceId = 'device_id';
  static const guestMode = 'guest_mode';
  static const guestToken = 'guest_token';

  /// Ed25519 seed for this device's identity key. Never leaves the handset.
  static const devicePrivateKey = 'device_private_key';

  /// The server's id for the registered public key — the proof's `kid`.
  static const deviceKeyId = 'device_key_id';

  /// When the current access token dies, so the client can refresh before it
  /// does instead of discovering it through a failed request.
  static const accessTokenExpiresAt = 'access_token_expires_at';
  static const refreshTokenExpiresAt = 'refresh_token_expires_at';
}

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // `encryptedSharedPreferences` is a deprecated no-op in
              // flutter_secure_storage 10.x — the plugin always uses the
              // encrypted implementation now, so setting it said nothing.
              aOptions: AndroidOptions(),
              // Without this the item is included in encrypted backups and can
              // be restored onto a *different* handset, which would defeat the
              // point of a device-bound key.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
