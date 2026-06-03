/// Environment configuration for API and feature flags.
abstract final class AppEnv {
  /// Node.js REST API base URL — override per flavor in CI/CD.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
