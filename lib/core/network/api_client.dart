import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../storage/secure_storage_service.dart';
import 'interceptors/auth_interceptor.dart';

class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio create({SecureStorageService? storage}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (storage != null) {
      dio.interceptors.add(AuthInterceptor(storage));
    }

    return dio;
  }

  static Dio get instance {
    _instance ??= create();
    return _instance!;
  }

  static void configure({required SecureStorageService storage}) {
    _instance = create(storage: storage);
  }
}
