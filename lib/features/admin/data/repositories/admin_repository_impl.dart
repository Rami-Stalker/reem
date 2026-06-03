import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/admin_stats_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

class AdminRepositoryImpl with RepositoryHandler implements AdminRepository {
  const AdminRepositoryImpl({required this.remote});

  final AdminRemoteDataSource remote;

  @override
  Future<Result<AdminStatsEntity>> getStats() => guard(() => remote.getStats());
}
