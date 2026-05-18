import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));
  // مثال لإضافة مزود خدمة شبكة
  // sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(Connectivity()));
  // أضف هنا أي خدمات أو Repositories عامة للتطبيق
}