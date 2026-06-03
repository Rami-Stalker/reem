import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:reem/features/admin/data/models/admin_stats_model.dart';

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
}
