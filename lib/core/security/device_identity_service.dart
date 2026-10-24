import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'package:ohara/core/observability/error_report.dart';
import 'package:ohara/core/observability/error_reporter.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';

/// This device's cryptographic identity.
///
/// The app generates an Ed25519 keypair on first launch and registers the
/// public half with the server. From then on the private key — which never
/// leaves the handset — is what proves "this is the same device", replacing a
/// fingerprint that was a hash of request headers and therefore both forgeable
/// by anyone and different on every network.
///
/// **Software keys, deliberately.** The private key lives in
/// `flutter_secure_storage`, not in Keystore/Secure Enclave. That is a decided
/// trade-off, not an oversight: the wire format and the server model are
/// identical either way, so moving to hardware later is a value change rather
/// than a schema change, while platform-channel work across the Transsion,
/// Xiaomi, Oppo and no-GMS Huawei devices that make up much of the Syrian fleet
/// risks a regression that would force every user on that SKU to re-verify by
/// SMS — a support incident and a messaging bill in the same afternoon.
///
/// What this defends against is token exfiltration: a backup, a log, a database
/// dump, a shared handset. It does not defend against a fully compromised
/// device, and pretending otherwise would be dishonest.
class DeviceIdentityService {
  DeviceIdentityService(this._storage);

  final SecureStorageService _storage;
  static final _algorithm = Ed25519();

  SimpleKeyPair? _cached;

  /// Base64url of the raw 32-byte public key, as the server stores it.
  Future<String> publicKeyBase64Url() async {
    final keyPair = await _keyPair();
    final publicKey = await keyPair.extractPublicKey();
    return base64Url.encode(publicKey.bytes).replaceAll('=', '');
  }

  /// The server's id for this key, once registered. Null before first launch
  /// registration succeeds.
  Future<String?> deviceKeyId() => _storage.read(SecureStorageKeys.deviceKeyId);

  Future<void> saveDeviceKeyId(String id) =>
      _storage.write(SecureStorageKeys.deviceKeyId, id);

  /// Signs `message` with the device key.
  Future<List<int>> sign(List<int> message) async {
    final signature = await _algorithm.sign(message, keyPair: await _keyPair());
    return signature.bytes;
  }

  /// True once a key exists locally — used to decide whether to register.
  Future<bool> hasKey() async =>
      (await _storage.read(SecureStorageKeys.devicePrivateKey)) != null;

  /// Drops the identity. Used when the server says the key is unknown or
  /// revoked: the app re-enrols rather than retrying forever with a key
  /// nothing recognises.
  Future<void> reset() async {
    _cached = null;
    await _storage.delete(SecureStorageKeys.devicePrivateKey);
    await _storage.delete(SecureStorageKeys.deviceKeyId);
  }

  Future<SimpleKeyPair> _keyPair() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = await _storage.read(SecureStorageKeys.devicePrivateKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        final seed = base64Url.decode(base64Url.normalize(stored));
        final keyPair = await _algorithm.newKeyPairFromSeed(seed);
        _cached = keyPair;
        return keyPair;
      } catch (error) {
        // A key we cannot load is worse than no key: it would fail every proof
        // silently. Start over and let the app re-register.
        ErrorReporter.report(
          error,
          null,
          severity: ErrorSeverity.warning,
          context: 'device key unreadable, regenerating',
        );
        await _storage.delete(SecureStorageKeys.deviceKeyId);
      }
    }

    final keyPair = await _algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    await _storage.write(
      SecureStorageKeys.devicePrivateKey,
      base64Url.encode(seed).replaceAll('=', ''),
    );
    _cached = keyPair;
    return keyPair;
  }
}
