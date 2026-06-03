import '../../domain/entities/admin_stats_entity.dart';

class AdminDashboardState {
  const AdminDashboardState({
    this.stats,
    this.isLoading = false,
    this.error,
  });

  final AdminStatsEntity? stats;
  final bool isLoading;
  final String? error;

  AdminDashboardState copyWith({
    AdminStatsEntity? stats,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearStats = false,
  }) {
    return AdminDashboardState(
      stats: clearStats ? null : (stats ?? this.stats),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
