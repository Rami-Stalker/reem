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
  });

  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  });

  Future<Result<void>> createNotificationCampaign(
    Map<String, dynamic> payload,
  );

  Future<Result<void>> runNotificationCampaign(String campaignId);
}
