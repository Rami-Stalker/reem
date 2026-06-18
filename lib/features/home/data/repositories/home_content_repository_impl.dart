import '../../../../core/base/repository_handler.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/repositories/home_content_repository.dart';
import '../datasources/home_content_datasource.dart';

class HomeContentRepositoryImpl
    with RepositoryHandler
    implements HomeContentRepository {
  const HomeContentRepositoryImpl({required this.source});

  final HomeContentDataSource source;

  @override
  Future<Result<HomeContent>> getHomeContent() =>
      guard(() => source.getHomeContent());
}
