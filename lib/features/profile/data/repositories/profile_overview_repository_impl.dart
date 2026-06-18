import '../../../../core/base/repository_handler.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_overview.dart';
import '../../domain/repositories/profile_overview_repository.dart';
import '../datasources/profile_overview_datasource.dart';

class ProfileOverviewRepositoryImpl
    with RepositoryHandler
    implements ProfileOverviewRepository {
  const ProfileOverviewRepositoryImpl({required this.source});

  final ProfileOverviewDataSource source;

  @override
  Future<Result<ProfileOverview>> getOverview() =>
      guard(() => source.getOverview());
}
