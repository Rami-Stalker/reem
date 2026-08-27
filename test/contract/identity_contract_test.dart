import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/features/auth/data/models/account_models.dart';
import 'package:reem/features/auth/data/models/identity_models.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

/// Contract tests for Identity v2, against **real captured responses**.
///
/// The fixtures were produced by driving the running API — see
/// `scratchpad/capture.sh` — so they cannot drift into agreeing with the client
/// by accident. That mattered here more than usual: the previous device and
/// session readers were parsing field names the server had stopped sending, and
/// nothing caught it because both sides were hand-written from the same
/// out-of-date assumption. Two of them threw at runtime.
dynamic _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync());

Map<String, dynamic> _map(String name) => _fixture(name) as Map<String, dynamic>;

void main() {
  group('OTP-first sign-in', () {
    test('the phone step carries the two digits she must compare', () {
      final challenge = OtpChallengeModel.fromJson(
        _map('otp_login_start.json'),
      );

      // The match code is the only defence against "this is Reem support, read
      // me the code" — and it is worth nothing if the client drops it, which is
      // exactly what happened before: the server had always sent it and no
      // screen ever read it.
      expect(challenge.matchCode, isNotNull);
      expect(challenge.matchCode, matches(RegExp(r'^\d{2}$')));
      expect(challenge.maskedDestination, isNotNull);
      expect(challenge.maskedDestination, contains('*'));
      expect(challenge.resendAfter, isNotNull);
      expect(challenge.expiresAt.isAfter(DateTime.utc(2020)), isTrue);
    });

    test('the response never carries the code itself, in any field', () {
      final raw = File('test/contract/otp_login_start.json').readAsStringSync();
      // The code used to ship as `debug_code` whenever NODE_ENV was not
      // production — the effective default — which, with a public route, was a
      // complete account-takeover chain.
      expect(raw, isNot(contains('debug_code')));
      expect(raw, isNot(contains('"code"')));
    });

    test('an unverified number comes back as a registration ticket', () {
      final response = OtpLoginResponse.fromJson(
        _map('otp_login_registration_required.json'),
      );

      final result = response.result;
      expect(result, isA<OtpLoginRegistrationRequired>());
      result as OtpLoginRegistrationRequired;
      expect(result.registrationTicket, isNotEmpty);
      expect(result.phone, startsWith('+963'));
      expect(result.expiresIn, greaterThan(0));
      // Nothing to persist: no session was created.
      expect(response.tokens, isNull);
    });

    test('a passwordless account is created verified, with real tokens', () {
      final json = _map('register_passwordless.json');
      final user = json['user'] as Map<String, dynamic>;
      final tokens = json['tokens'] as Map<String, dynamic>;

      // The number was proved before the account existed, so there is no
      // "now verify your phone" step left to strand her on.
      expect(user['is_verified'], isTrue);
      expect(user['phone_verified_at'], isNotNull);
      expect(json['verification']['phone_verified'], isTrue);

      expect(tokens['access_token'], isNotEmpty);
      expect(tokens['refresh_token'], isNotEmpty);
      // Lifetimes travel with the pair; without them the app can only discover
      // an expired token by failing a request with it.
      expect(tokens['expires_in'], isA<int>());
      expect(tokens['refresh_expires_at'], isNotNull);
    });
  });

  group('the optional password', () {
    test('a correct password on an unknown device yields a code, not a session',
        () {
      final json = _map('login_new_device_refusal.json');

      expect(json['statusCode'], 403);
      expect(json['code'], 'DEVICE_VERIFICATION_REQUIRED');
      expect(json['tokens'], isNull);

      // The challenge rides in `details`, which the error envelope used to
      // discard — so the app can go straight to the code screen instead of
      // showing a dead end.
      final challenge = OtpChallengeModel.fromJson(
        Map<String, dynamic>.from(
          (json['details'] as Map)['challenge'] as Map,
        ),
      );
      expect(challenge.matchCode, isNotNull);
      expect(challenge.maskedDestination, contains('*'));
    });
  });

  group('the security centre', () {
    late AuthAccountModel account;

    setUp(() => account = AuthAccountModel.fromJson(_map('auth_account.json')));

    test('reports every fact the security screen renders', () {
      final security = account.security;

      // A fresh account: no password, no authenticator, no codes written down.
      expect(security.passwordEnabled, isFalse);
      expect(security.totpEnabled, isFalse);
      expect(security.recoveryCodesRemaining, 0);
      expect(security.hasOfflineRecovery, isFalse);
      expect(security.payoutsFrozen, isFalse);
      expect(account.openRecoveryCases, isEmpty);
      expect(account.permissions, contains('session:manage'));
    });

    test('a session parses both clocks, and they are not the same clock', () {
      final sessions = (_fixture('auth_sessions.json') as List)
          .map((e) => AccountSessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(sessions, isNotEmpty);
      final session = sessions.first;
      expect(session.isActive, isTrue);

      // The idle clock slides on every refresh; the absolute one never moves,
      // and it is the checkpoint that eventually forces a real sign-in. Reading
      // one where the other was meant is how a session list starts lying.
      expect(
        session.absoluteExpiresAt.isAfter(session.idleExpiresAt),
        isTrue,
        reason: 'a 90-day cap should outlast a 7-day idle window',
      );
    });
  });
}
