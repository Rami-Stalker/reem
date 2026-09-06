import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/domain/repositories/admin_repository.dart';

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
    int page = 1,
    int limit = 25,
    String? query,
    String? status,
  }) => guard(
    () => remote.getSection(
      key: key,
      title: title,
      endpoint: endpoint,
      page: page,
      limit: limit,
      query: query,
      status: status,
    ),
  );

  @override
  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  }) => guard(
    () => remote.getAnalyticsDashboard(start: start, end: end),
    operation: 'load analytics dashboard',
  );

  @override
  Future<Result<void>> createNotificationCampaign(
    Map<String, dynamic> payload,
  ) => guard(
    () => remote.createNotificationCampaign(payload),
    operation: 'create notification campaign',
  );

  @override
  Future<Result<void>> runNotificationCampaign(String campaignId) => guard(
    () => remote.runNotificationCampaign(campaignId),
    operation: 'run notification campaign',
  );

  @override
  Future<Result<void>> updateUser(String id, Map<String, dynamic> payload) =>
      guard(() => remote.updateUser(id, payload), operation: 'update account');

  @override
  Future<Result<void>> updateProduct(String id, Map<String, dynamic> payload) =>
      guard(
        () => remote.updateProduct(id, payload),
        operation: 'update product',
      );

  @override
  Future<Result<void>> updateSupportTicket(
    String id,
    Map<String, dynamic> payload,
  ) => guard(
    () => remote.updateSupportTicket(id, payload),
    operation: 'update support ticket',
  );

  @override
  Future<Result<void>> updateModerationCase(
    String id,
    Map<String, dynamic> payload,
  ) => guard(
    () => remote.updateModerationCase(id, payload),
    operation: 'update moderation case',
  );

  @override
  Future<Result<void>> updateReport(String id, Map<String, dynamic> payload) =>
      guard(() => remote.updateReport(id, payload), operation: 'update report');

  @override
  Future<Result<void>> createCommissionRule(Map<String, dynamic> payload) =>
      guard(
        () => remote.createCommissionRule(payload),
        operation: 'create commission rule',
      );

  @override
  Future<Result<void>> updateCommissionLedger(
    String id,
    Map<String, dynamic> payload,
  ) => guard(
    () => remote.updateCommissionLedger(id, payload),
    operation: 'update commission entry',
  );

  @override
  Future<Result<void>> upsertSystemSetting(Map<String, dynamic> payload) =>
      guard(
        () => remote.upsertSystemSetting(payload),
        operation: 'save system setting',
      );

  @override
  Future<Result<Map<String, dynamic>>> getSellerApplication(String id) => guard(
    () => remote.getSellerApplication(id),
    operation: 'load seller application',
  );

  @override
  Future<Result<void>> reviewSellerApplication(
    String id,
    Map<String, dynamic> payload,
  ) => guard(
    () => remote.reviewSellerApplication(id, payload),
    operation: 'review seller application',
  );
}
