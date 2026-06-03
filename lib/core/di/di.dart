import 'package:get_it/get_it.dart';

import '../storage/secure_storage_service.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
}
