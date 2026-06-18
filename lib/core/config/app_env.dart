/// Environment configuration for API and feature flags.
abstract final class AppEnv {
  /// Node.js REST API base URL — override per flavor in CI/CD.
  ///
  /// Defaults to `localhost` for web (Chrome) / iOS-simulator / desktop.
  /// For the Android emulator, override with:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  /// For a physical device, use your PC's LAN IP, e.g. http://192.168.1.50:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
