import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/admin_stats_entity.dart';
import '../../domain/entities/admin_console_entity.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

class AdminRepositoryImpl with RepositoryHandler implements AdminRepository {
  const AdminRepositoryImpl({required this.remote});

  final AdminRemoteDataSource remote;

  @override
  Future<Result<AdminStatsEntity>> getStats() => guard(() => remote.getStats());

  @override
  Future<Result<AdminConsoleSection>> getSection({
    required String key,
    required String title,
    required String endpoint,
  }) =>
      guard(
        () => remote.getSection(key: key, title: title, endpoint: endpoint),
      );

  @override
  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  }) =>
      guard(
        () => remote.getAnalyticsDashboard(start: start, end: end),
        operation: 'load analytics dashboard',
      );

  @override
  Future<Result<void>> createNotificationCampaign(
    Map<String, dynamic> payload,
  ) =>
      guard(
        () => remote.createNotificationCampaign(payload),
        operation: 'create notification campaign',
      );

  @override
  Future<Result<void>> runNotificationCampaign(String campaignId) => guard(
        () => remote.runNotificationCampaign(campaignId),
        operation: 'run notification campaign',
      );
}
