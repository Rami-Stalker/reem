import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/presentation/providers/core_providers.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/admin_console_entity.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';
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

class AnalyticsDateRange {
  const AnalyticsDateRange({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}

final analyticsDateRangeProvider = StateProvider<AnalyticsDateRange>((ref) {
  final end = DateTime.now();
  return AnalyticsDateRange(
    start: end.subtract(const Duration(days: 30)),
    end: end,
  );
});

final analyticsDashboardProvider =
    FutureProvider<AnalyticsDashboardEntity>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final result = await ref.watch(adminRepositoryProvider).getAnalyticsDashboard(
        start: range.start,
        end: range.end,
      );
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

class AdminSectionConfig {
  const AdminSectionConfig({
    required this.key,
    required this.title,
    required this.endpoint,
  });

  final String key;
  final String title;
  final String endpoint;
}

const adminSectionConfigs = {
  'users': AdminSectionConfig(
    key: 'users',
    title: 'User management',
    endpoint: ApiEndpoints.adminUsers,
  ),
  'sellers': AdminSectionConfig(
    key: 'sellers',
    title: 'Seller management',
    endpoint: ApiEndpoints.adminSellers,
  ),
  'products': AdminSectionConfig(
    key: 'products',
    title: 'Product management',
    endpoint: ApiEndpoints.adminProducts,
  ),
  'orders': AdminSectionConfig(
    key: 'orders',
    title: 'Order management',
    endpoint: ApiEndpoints.adminOrders,
  ),
  'financials': AdminSectionConfig(
    key: 'financials',
    title: 'Financial management',
    endpoint: ApiEndpoints.adminFinancials,
  ),
  'commissions': AdminSectionConfig(
    key: 'commissions',
    title: 'Commission management',
    endpoint: ApiEndpoints.adminCommissions,
  ),
  'analytics': AdminSectionConfig(
    key: 'analytics',
    title: 'Reports and analytics',
    endpoint: ApiEndpoints.adminAnalytics,
  ),
  'reports': AdminSectionConfig(
    key: 'reports',
    title: 'Reports',
    endpoint: ApiEndpoints.adminReports,
  ),
  'moderation': AdminSectionConfig(
    key: 'moderation',
    title: 'Moderation tools',
    endpoint: ApiEndpoints.adminModeration,
  ),
  'support': AdminSectionConfig(
    key: 'support',
    title: 'Support management',
    endpoint: ApiEndpoints.adminSupport,
  ),
  'audit': AdminSectionConfig(
    key: 'audit',
    title: 'Audit logs',
    endpoint: ApiEndpoints.adminAuditLogs,
  ),
  'settings': AdminSectionConfig(
    key: 'settings',
    title: 'System settings',
    endpoint: ApiEndpoints.adminSystemSettings,
  ),
  'campaigns': AdminSectionConfig(
    key: 'campaigns',
    title: 'Notification campaigns',
    endpoint: ApiEndpoints.notificationAdminCampaigns,
  ),
  'notificationAnalytics': AdminSectionConfig(
    key: 'notificationAnalytics',
    title: 'Notification analytics',
    endpoint: ApiEndpoints.notificationAdminAnalytics,
  ),
};

final adminSectionProvider =
    FutureProvider.family<AdminConsoleSection, AdminSectionConfig>((
  ref,
  config,
) async {
  final result = await ref.watch(adminRepositoryProvider).getSection(
        key: config.key,
        title: config.title,
        endpoint: config.endpoint,
      );
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});
