import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:ohara/features/admin/domain/repositories/admin_repository.dart';

class GetAdminStatsUseCase {
  const GetAdminStatsUseCase(this._repository);
  final AdminRepository _repository;

  Future<Result<AdminStatsEntity>> call() => _repository.getStats();
}
