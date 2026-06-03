import '../config/app_env.dart';
import '../network/api_endpoints.dart';

/// @deprecated Use [AppEnv.baseUrl] and [ApiEndpoints] instead.
class ApiConstants {
  static String get baseUrl => AppEnv.baseUrl;
  static const String login = ApiEndpoints.authLogin;
  static const String register = ApiEndpoints.authRegister;
  static const String refreshToken = ApiEndpoints.authRefresh;
  static const String me = ApiEndpoints.authMe;
}
