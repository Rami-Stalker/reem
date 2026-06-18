abstract interface class AuthLocalDataSource {
  Future<void> saveAccessToken(String token);

  Future<void> saveRefreshToken(String token);

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<String> getOrCreateDeviceId();

  Future<void> saveGuestMode(bool enabled);

  Future<bool> isGuestMode();

  Future<void> clear();
}
