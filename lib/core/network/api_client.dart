import 'package:dio/dio.dart';
import 'package:reem/core/config/app_env.dart';
import 'package:reem/core/network/http_cache/http_cache_store.dart';
import 'package:reem/core/network/interceptors/auth_interceptor.dart';
import 'package:reem/core/network/interceptors/cache_interceptor.dart';
import 'package:reem/core/network/interceptors/device_proof_interceptor.dart';
import 'package:reem/core/network/interceptors/telemetry_interceptor.dart';
import 'package:reem/core/security/device_identity_service.dart';
import 'package:reem/core/security/device_proof_signer.dart';
import 'package:reem/core/storage/secure_storage_service.dart';

class ApiClient {
  ApiClient._();

  static Dio? _instance;

  /// The response cache, kept as a field so sign-out can empty it.
  static HttpCacheStore? _cacheStore;

  /// Empties every cached response. Called on sign-out: the scope key already
  /// keeps accounts apart, but a device that changes hands should not be
  /// carrying the last woman's home feed on its disk.
  static Future<void> clearCache() async => _cacheStore?.clear();

  static Dio create({SecureStorageService? storage, HttpCacheStore? cache}) {
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

    // Last in the chain, so a cache hit short-circuits *after* the headers
    // that identify the caller have been attached — the cache key is scoped
    // to the account, and a request served from cache still had to prove who
    // it was before it got here.
    final store = cache ??
        TieredHttpCacheStore(
          fast: MemoryHttpCacheStore(),
          durable: FileHttpCacheStore(),
        );
    _cacheStore = store;
    final cacheInterceptor = CacheInterceptor(store);
    dio.interceptors.add(cacheInterceptor);

    // After the cache, so a request served from cache leaves no network
    // breadcrumb — it never went to the network, and saying it did would
    // mislead whoever reads the trail.
    dio.interceptors.add(const TelemetryInterceptor());
    // The interceptor revalidates on the same client it is installed on, so
    // a background refresh carries the same auth and device headers.
    cacheInterceptor.client = dio;

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
