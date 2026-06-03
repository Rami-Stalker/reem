import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../data/datasources/impl/admin_remote_datasource_impl.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/get_admin_stats_usecase.dart';
import 'admin_dashboard_notifier.dart';
import 'admin_state.dart';

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>(
  (ref) => AdminRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(
    remote: ref.watch(adminRemoteDataSourceProvider),
  ),
);

final getAdminStatsUseCaseProvider = Provider(
  (ref) => GetAdminStatsUseCase(ref.watch(adminRepositoryProvider)),
);

final adminDashboardNotifierProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
  return AdminDashboardNotifier(
    getAdminStatsUseCase: ref.watch(getAdminStatsUseCaseProvider),
  );
});
