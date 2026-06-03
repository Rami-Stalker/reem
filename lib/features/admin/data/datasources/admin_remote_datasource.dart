import '../models/admin_stats_model.dart';

abstract interface class AdminRemoteDataSource {
  Future<AdminStatsModel> getStats();
}
