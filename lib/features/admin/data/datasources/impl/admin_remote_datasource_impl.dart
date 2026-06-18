import 'package:dio/dio.dart';
import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:reem/features/admin/data/models/admin_console_model.dart';
import 'package:reem/features/admin/data/models/admin_stats_model.dart';
import 'package:reem/features/admin/data/models/analytics_dashboard_model.dart';

final class AdminRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AdminRemoteDataSource {
  const AdminRemoteDataSourceImpl(super.dio);

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
  }) async {
    try {
      final response = await dio.get<dynamic>(endpoint);
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
    try {
      await dio.post<dynamic>(
        ApiEndpoints.notificationAdminCampaigns,
        data: payload,
      );
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  @override
  Future<void> runNotificationCampaign(String campaignId) async {
    try {
      await dio.post<dynamic>(
        ApiEndpoints.notificationAdminCampaignRun(campaignId),
      );
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }
}
