import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/config/app_env.dart';

/// The two things a production build must never do: fall back to a loopback
/// API, and talk to it in the clear.
///
/// Both are compile-time decisions, so they are exercised by running this file
/// with different defines. All three invocations are meaningful:
///
/// ```
/// flutter test test/app_env_release_guard_test.dart
/// flutter test --dart-define=APP_ENV=production test/app_env_release_guard_test.dart
/// flutter test --dart-define=APP_ENV=production \
///   --dart-define=API_BASE_URL=http://api.example.com \
///   test/app_env_release_guard_test.dart
/// ```
///
/// The assertions are written as one invariant per test rather than one per
/// invocation, because a test that only holds under one set of defines is a
/// test that quietly passes vacuously under the others.
void main() {
  /// What `AppEnv.baseUrl` did, without letting the throw escape.
  ({String? url, StateError? error}) resolve() {
    try {
      return (url: AppEnv.baseUrl, error: null);
    } on StateError catch (error) {
      return (url: null, error: error);
    }
  }

  test('a local build always resolves a host', () {
    if (AppEnv.isProduction) return;
    // The convenience default is the whole point off production: localhost for
    // desktop and web, 10.0.2.2 for the Android emulator.
    expect(resolve().url, contains('://'));
  });

  test('production either resolves an https host or refuses to run', () {
    if (!AppEnv.isProduction) return;

    final outcome = resolve();
    if (outcome.error != null) {
      // Refused. Either no host was configured — 10.0.2.2 is an emulator's view
      // of its own host and Android blocks cleartext anyway, so the app would
      // ship looking fine and fail every request — or the host was cleartext.
      expect(
        outcome.error!.message,
        anyOf(contains('API_BASE_URL'), contains('https')),
      );
      return;
    }

    // Resolved. There is no third possibility: TLS or nothing.
    expect(
      outcome.url,
      startsWith('https://'),
      reason: 'a cleartext production host would put every access token and '
          'one-time code on the wire in the clear',
    );
  });

  test('the cleartext guard survives compilation to release', () {
    // It used to be an `assert`, which the release compiler removes — so the
    // one check that mattered was present in every build except the one that
    // ships. Under `flutter test` assertions are enabled, which is precisely
    // why the old form looked correct here and was absent in production.
    //
    // This asserts the *mechanism*: the refusal is a thrown `StateError`, not
    // an assertion. `dart:core` assertion failures are `AssertionError`, so a
    // regression to `assert` would fail this even with assertions on.
    if (!AppEnv.isProduction) return;
    final outcome = resolve();
    if (outcome.error == null) return; // https host: nothing to refuse.
    expect(outcome.error, isA<StateError>());
    expect(outcome.error, isNot(isA<AssertionError>()));
  });
}
