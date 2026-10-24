import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/admin/domain/usecases/get_admin_stats_usecase.dart';
import 'package:ohara/features/admin/presentation/providers/admin_state.dart';

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  AdminDashboardNotifier({required GetAdminStatsUseCase getAdminStatsUseCase})
      : _getStats = getAdminStatsUseCase,
        super(const AdminDashboardState());

  final GetAdminStatsUseCase _getStats;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, clearStats: true);
    final result = await _getStats();
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, stats: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }
}
