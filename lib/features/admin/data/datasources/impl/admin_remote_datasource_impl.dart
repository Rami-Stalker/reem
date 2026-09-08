import 'package:dio/dio.dart';
import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:reem/features/admin/data/models/admin_briefing_model.dart';
import 'package:reem/features/admin/data/models/admin_console_model.dart';
import 'package:reem/features/admin/data/models/admin_stats_model.dart';
import 'package:reem/features/admin/data/models/analytics_dashboard_model.dart';

final class AdminRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AdminRemoteDataSource {
  const AdminRemoteDataSourceImpl(super.dio);

  @override
  Future<AdminBriefing> getBriefing({int windowDays = 30}) async {
    final json = await getJson(
      ApiEndpoints.adminBriefing,
      query: {'window_days': windowDays},
    );
    return AdminBriefing.fromJson(json);
  }

  @override
  Future<AdminStatsModel> getStats() async {
    final json = await getJson(ApiEndpoints.adminStats);
    final statsJson = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : json;
    return AdminStatsModel.fromJson(statsJson);
  }

  @override
  Future<AdminConsoleSectionModel> getSection({
    required String key,
    required String title,
    required String endpoint,
    int page = 1,
    int limit = 25,
    String? query,
    String? status,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        endpoint,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final data = response.data;
      if (data is List) {
        return AdminConsoleSectionModel.fromList(
          key: key,
          title: title,
          items: data,
        );
      }
      if (data is Map<String, dynamic>) {
        return AdminConsoleSectionModel.fromMap(
          key: key,
          title: title,
          json: data,
        );
      }
      return AdminConsoleSectionModel.fromList(
        key: key,
        title: title,
        items: const [],
      );
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  @override
  Future<AnalyticsDashboardModel> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  }) async {
    final json = await getJson(
      ApiEndpoints.analyticsDashboard,
      query: {
        if (start != null) 'start_date': start.toUtc().toIso8601String(),
        if (end != null) 'end_date': end.toUtc().toIso8601String(),
      },
    );
    return AnalyticsDashboardModel.fromJson(json);
  }

  @override
  Future<void> createNotificationCampaign(Map<String, dynamic> payload) async {
    await postJson(ApiEndpoints.notificationAdminCampaigns, body: payload);
  }

  @override
  Future<void> runNotificationCampaign(String campaignId) async {
    await postJson(ApiEndpoints.notificationAdminCampaignRun(campaignId));
  }

  @override
  Future<void> updateUser(String id, Map<String, dynamic> payload) async {
    await patchJson(ApiEndpoints.adminUser(id), body: payload);
  }

  @override
  Future<void> updateProduct(String id, Map<String, dynamic> payload) async {
    await patchJson(ApiEndpoints.adminProduct(id), body: payload);
  }

  @override
  Future<void> updateSupportTicket(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await patchJson(ApiEndpoints.adminSupportTicket(id), body: payload);
  }

  @override
  Future<void> updateModerationCase(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await patchJson(ApiEndpoints.adminModerationCase(id), body: payload);
  }

  @override
  Future<void> updateReport(String id, Map<String, dynamic> payload) async {
    await patchJson(ApiEndpoints.adminReport(id), body: payload);
  }

  @override
  Future<void> createCommissionRule(Map<String, dynamic> payload) async {
    await postJson(ApiEndpoints.adminCommissionRules, body: payload);
  }

  @override
  Future<void> updateCommissionLedger(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await patchJson(ApiEndpoints.adminCommissionLedger(id), body: payload);
  }

  @override
  Future<void> upsertSystemSetting(Map<String, dynamic> payload) async {
    await postJson(ApiEndpoints.adminSystemSettings, body: payload);
  }

  @override
  Future<Map<String, dynamic>> getSellerApplication(String id) {
    return getJson(ApiEndpoints.adminSellerApplication(id));
  }

  @override
  Future<void> reviewSellerApplication(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await patchJson(
      ApiEndpoints.adminSellerApplicationReview(id),
      body: payload,
    );
  }
}
