import 'package:reem/core/result/result.dart';

import '../entities/admin_stats_entity.dart';
import '../repositories/admin_repository.dart';

class GetAdminStatsUseCase {
  const GetAdminStatsUseCase(this._repository);
  final AdminRepository _repository;

  Future<Result<AdminStatsEntity>> call() => _repository.getStats();
}
