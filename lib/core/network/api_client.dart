import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../security/device_identity_service.dart';
import '../security/device_proof_signer.dart';
import '../storage/secure_storage_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/device_proof_interceptor.dart';

class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio create({SecureStorageService? storage}) {
    final dio = Dio(
      BaseOptions(
        // Resolves per platform (10.0.2.2 on the Android emulator, localhost
        // elsewhere) and is overridden for physical devices with
        // `--dart-define=API_BASE_URL=http://<LAN-IP>:3000`. It used to be a
        // hardcoded LAN address, which only worked on one machine's network.
        baseUrl: AppEnv.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (storage != null) {
      // Order matters: the auth interceptor attaches the bearer token first,
      // because the device proof is bound to it.
      dio.interceptors.add(AuthInterceptor(storage));
      dio.interceptors.add(
        DeviceProofInterceptor(
          DeviceProofSigner(DeviceIdentityService(storage)),
        ),
      );
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
