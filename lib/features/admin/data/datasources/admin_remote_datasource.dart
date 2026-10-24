import 'package:ohara/features/admin/data/models/admin_briefing_model.dart';
import 'package:ohara/features/admin/data/models/admin_console_model.dart';
import 'package:ohara/features/admin/data/models/admin_stats_model.dart';
import 'package:ohara/features/admin/data/models/analytics_dashboard_model.dart';
import 'package:ohara/features/admin/data/models/notification_analytics_model.dart';

abstract interface class AdminRemoteDataSource {
  /// What needs attention today, ordered by how much.
  Future<AdminBriefing> getBriefing({int windowDays});

  Future<AdminStatsModel> getStats();

  /// One page of an admin list.
  ///
  /// [query] and [status] are sent to the server rather than applied to the
  /// rows already in hand: filtering a page client-side answers "is she in the
  /// twenty-five I am holding", which is not the question an operator typed.
  Future<AdminConsoleSectionModel> getSection({
    required String key,
    required String title,
    required String endpoint,
    int page,
    int limit,
    String? query,
    String? status,
  });

  Future<AnalyticsDashboardModel> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  });

  /// Delivery, campaign and event tallies for the notification engine.
  Future<NotificationAnalytics> getNotificationAnalytics();

  Future<void> createNotificationCampaign(Map<String, dynamic> payload);

  Future<void> runNotificationCampaign(String campaignId);

  // Governance actions. Each mirrors one write route on AdminController.

  Future<void> updateUser(String id, Map<String, dynamic> payload);

  Future<void> updateProduct(String id, Map<String, dynamic> payload);

  Future<void> updateSupportTicket(String id, Map<String, dynamic> payload);

  Future<void> updateModerationCase(String id, Map<String, dynamic> payload);

  Future<void> updateReport(String id, Map<String, dynamic> payload);

  Future<void> createCommissionRule(Map<String, dynamic> payload);

  Future<void> updateCommissionLedger(String id, Map<String, dynamic> payload);

  Future<void> upsertSystemSetting(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> getSellerApplication(String id);

  Future<void> reviewSellerApplication(String id, Map<String, dynamic> payload);

  /// «توثيق الحسابات» — approving, refusing or revoking the badge.
  Future<void> decideAccountVerification(
    String id,
    Map<String, dynamic> payload,
  );
}
