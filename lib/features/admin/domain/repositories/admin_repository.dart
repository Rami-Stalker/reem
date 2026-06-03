import 'package:reem/core/result/result.dart';

import '../entities/admin_stats_entity.dart';

abstract interface class AdminRepository {
  Future<Result<AdminStatsEntity>> getStats();
}
