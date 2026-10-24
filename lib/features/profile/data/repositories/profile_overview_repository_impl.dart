import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/profile/data/datasources/profile_overview_datasource.dart';
import 'package:ohara/features/profile/domain/entities/profile_overview.dart';
import 'package:ohara/features/profile/domain/repositories/profile_overview_repository.dart';

class ProfileOverviewRepositoryImpl
    with RepositoryHandler
    implements ProfileOverviewRepository {
  const ProfileOverviewRepositoryImpl({required this.source});

  final ProfileOverviewDataSource source;

  @override
  Future<Result<ProfileOverview>> getOverview() =>
      guard(() => source.getOverview());
}
