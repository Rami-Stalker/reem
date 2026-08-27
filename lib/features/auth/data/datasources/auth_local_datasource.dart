abstract interface class AuthLocalDataSource {
  Future<void> saveAccessToken(String token);

  Future<void> saveRefreshToken(String token);

  Future<void> clearRefreshToken();

  /// Records when each token dies, so the app can refresh ahead of expiry
  /// instead of finding out through a failed request.
  Future<void> saveTokenLifetimes({
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
  });

  Future<DateTime?> getAccessTokenExpiry();

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> saveGuestToken(String token);

  Future<String?> getGuestToken();

  Future<void> clearGuestSession();

  Future<String> getOrCreateDeviceId();

  Future<void> saveGuestMode(bool enabled);

  Future<bool> isGuestMode();

  Future<void> clear();
}
