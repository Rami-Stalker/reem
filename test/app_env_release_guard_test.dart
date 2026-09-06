import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/config/app_env.dart';

/// Run with the production flavour and no host:
///
/// ```
/// flutter test --dart-define=APP_ENV=production test/app_env_release_guard_test.dart
/// ```
///
/// Without the define this file asserts the opposite — that a local build
/// still gets its loopback default — so the same file is meaningful either way.
void main() {
  test('a production build refuses to fall back to a loopback API', () {
    if (!AppEnv.isProduction) {
      // Local/dev: the convenience default is the whole point.
      expect(AppEnv.baseUrl, contains('://'));
      return;
    }

    // Production with no API_BASE_URL: 10.0.2.2 is an emulator's view of its
    // own host, and Android blocks cleartext anyway — the app would ship
    // looking fine and fail every request.
    expect(
      () => AppEnv.baseUrl,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
  });
}
