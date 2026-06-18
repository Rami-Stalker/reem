import '../models/admin_stats_model.dart';
import '../models/admin_console_model.dart';
import '../models/analytics_dashboard_model.dart';

abstract interface class AdminRemoteDataSource {
  Future<AdminStatsModel> getStats();

  Future<AdminConsoleSectionModel> getSection({
    required String key,
    required String title,
    required String endpoint,
  });

  Future<AnalyticsDashboardModel> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  });

  Future<void> createNotificationCampaign(Map<String, dynamic> payload);

  Future<void> runNotificationCampaign(String campaignId);
}
