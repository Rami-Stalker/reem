import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:ohara/core/security/device_identity_service.dart';

/// Builds the signed assertion the server calls a device proof.
///
/// It is a compact JWS over `{jti, iat, htm, htu, ath}`, and each claim exists
/// to close one hole:
///
/// * `htm` / `htu` bind it to this exact method and URL, so a proof captured on
///   a harmless request cannot be replayed against the payout endpoint;
/// * `ath` binds it to the access token sent with it, so neither half is worth
///   stealing alone;
/// * `iat` bounds it to a minute;
/// * `jti` closes even that minute — the server records it and refuses a
///   second use.
class DeviceProofSigner {
  DeviceProofSigner(this._identity);

  final DeviceIdentityService _identity;
  static final _random = Random.secure();

  /// Returns the proof header value, or null when this device has no
  /// registered key yet — the caller then simply omits the header.
  Future<String?> sign({
    required String method,
    required Uri url,
    String? accessToken,
  }) async {
    final kid = await _identity.deviceKeyId();
    if (kid == null) return null;

    final header = _encode({
      'alg': 'EdDSA',
      'typ': 'device-proof+jwt',
      'kid': kid,
    });
    final payload = _encode({
      'jti': _jti(),
      'iat': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      'htm': method.toUpperCase(),
      // Query strings are excluded on both sides: they carry pagination and
      // filters, which would make a proof unusable for no security gain.
      'htu': '${url.origin}${url.path}',
      if (accessToken != null)
        'ath': _base64Url(sha256.convert(utf8.encode(accessToken)).bytes),
    });

    final signingInput = '$header.$payload';
    final signature = await _identity.sign(utf8.encode(signingInput));
    return '$signingInput.${_base64Url(signature)}';
  }

  String _jti() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return _base64Url(bytes);
  }

  String _encode(Map<String, Object?> value) =>
      _base64Url(utf8.encode(jsonEncode(value)));

  String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
