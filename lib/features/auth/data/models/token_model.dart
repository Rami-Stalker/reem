/// The token pair, with the lifetimes the server has always sent.
///
/// `expires_in` and `refresh_expires_at` were both in every auth response and
/// both discarded here, which left the client with no idea when its access
/// token died. The only way it found out was by making a request, getting a
/// 401, refreshing, and replaying — three sequential round-trips at Syrian
/// latencies, at a random moment in the session. Keeping them lets the app
/// refresh *before* the token expires.
class TokenModel {
  final String accessToken;
  final String refreshToken;

  /// When the access token stops being accepted.
  final DateTime? accessExpiresAt;

  /// When the refresh token stops being accepted — after this, she signs in
  /// again, and the app can say so instead of failing mid-action.
  final DateTime? refreshExpiresAt;

  const TokenModel({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'];
    return TokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessExpiresAt: expiresIn is num
          ? DateTime.now().add(Duration(seconds: expiresIn.toInt()))
          : null,
      refreshExpiresAt: json['refresh_expires_at'] is String
          ? DateTime.tryParse(json['refresh_expires_at'] as String)
          : null,
    );
  }

  /// Refresh at 80% of the token's life: early enough that a slow Syrian
  /// connection still completes before expiry, late enough not to churn.
  DateTime? get refreshAt {
    final expiry = accessExpiresAt;
    if (expiry == null) return null;
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) return DateTime.now();
    return DateTime.now().add(remaining * 0.8);
  }
}
