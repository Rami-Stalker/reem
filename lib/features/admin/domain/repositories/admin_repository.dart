import 'package:reem/core/result/result.dart';

import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';

abstract interface class AdminRepository {
  Future<Result<AdminStatsEntity>> getStats();

  Future<Result<AdminConsoleSection>> getSection({
    required String key,
    required String title,
    required String endpoint,
    int page,
    int limit,
    String? query,
    String? status,
  });

  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  });

  Future<Result<void>> createNotificationCampaign(Map<String, dynamic> payload);

  Future<Result<void>> runNotificationCampaign(String campaignId);

  Future<Result<void>> updateUser(String id, Map<String, dynamic> payload);

  Future<Result<void>> updateProduct(String id, Map<String, dynamic> payload);

  Future<Result<void>> updateSupportTicket(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Result<void>> updateModerationCase(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Result<void>> updateReport(String id, Map<String, dynamic> payload);

  Future<Result<void>> createCommissionRule(Map<String, dynamic> payload);

  Future<Result<void>> updateCommissionLedger(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Result<void>> upsertSystemSetting(Map<String, dynamic> payload);

  Future<Result<Map<String, dynamic>>> getSellerApplication(String id);

  Future<Result<void>> reviewSellerApplication(
    String id,
    Map<String, dynamic> payload,
  );

  Future<Result<void>> decideAccountVerification(
    String id,
    Map<String, dynamic> payload,
  );
}
