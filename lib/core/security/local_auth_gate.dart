import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_storage_service.dart';

/// Re-authenticates the person holding the phone, not the account.
///
/// The dominant real threat here is not a remote attacker: it is someone
/// picking up her unlocked handset — a relative, a partner, anyone in a shared
/// household. No amount of server-side cryptography addresses that, because
/// every credential the app holds is already on the device and valid.
///
/// So the app asks the device to confirm the person, and it does so **by
/// default wherever the hardware exists**. Defaults decide behaviour: a
/// protection that ships off is a protection almost nobody turns on, and this
/// one costs a returning user a fingerprint touch.
///
/// Where there is no biometric and no lock screen — a real share of the Syrian
/// fleet — the gate reports unavailable rather than pretending. It is not
/// treated as a failure, because refusing to open the app on a device that
/// cannot satisfy the check would lock out exactly the users with the cheapest
/// phones.
class LocalAuthGate {
  LocalAuthGate(this._storage, {LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final SecureStorageService _storage;
  final LocalAuthentication _auth;

  /// How long the app may stay in the background before it asks again.
  ///
  /// Fifteen minutes: long enough that answering a message or checking a price
  /// elsewhere does not become a prompt, short enough that a handset left on a
  /// table is not an open session.
  static const backgroundGrace = Duration(minutes: 15);

  static const _enabledKey = 'local_auth_enabled';
  static const _lastUnlockKey = 'local_auth_last_unlock';

  /// True when the device can actually perform the check — a biometric sensor
  /// or, failing that, a lock screen.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception catch (error) {
      debugPrint('Local auth unavailable: $error');
      return false;
    }
  }

  /// On by default where the hardware exists — see the class comment.
  Future<bool> isEnabled() async {
    final stored = await _storage.read(_enabledKey);
    if (stored != null) return stored == 'true';
    return isAvailable();
  }

  Future<void> setEnabled(bool enabled) =>
      _storage.write(_enabledKey, enabled ? 'true' : 'false');

  /// Whether the app should challenge before showing content again.
  Future<bool> shouldChallenge() async {
    if (!await isEnabled()) return false;
    if (!await isAvailable()) return false;

    final raw = await _storage.read(_lastUnlockKey);
    if (raw == null) return true;
    final last = DateTime.tryParse(raw);
    if (last == null) return true;
    return DateTime.now().difference(last) > backgroundGrace;
  }

  /// Runs the platform prompt. Returns true when the person is confirmed.
  Future<bool> challenge({required String reason}) async {
    if (!await isAvailable()) return true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Device PIN/pattern is accepted as well as biometrics: on a handset
        // with a lock screen but no fingerprint reader, the PIN is the only
        // thing standing between a bystander and her account.
        biometricOnly: false,
        // Survives the app being backgrounded mid-prompt instead of failing.
        persistAcrossBackgrounding: true,
      );
      if (ok) await markUnlocked();
      return ok;
    } on Exception catch (error) {
      // A platform failure must not lock her out of her own app. The session is
      // still valid and the server-side controls still apply.
      debugPrint('Local auth failed, allowing through: $error');
      return true;
    }
  }

  Future<void> markUnlocked() =>
      _storage.write(_lastUnlockKey, DateTime.now().toIso8601String());
}
