import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/home/data/datasources/home_content_datasource.dart';
import 'package:reem/features/home/domain/entities/home_content.dart';
import 'package:reem/features/home/domain/repositories/home_content_repository.dart';

class HomeContentRepositoryImpl
    with RepositoryHandler
    implements HomeContentRepository {
  const HomeContentRepositoryImpl({required this.source});

  final HomeContentDataSource source;

  @override
  Future<Result<HomeContent>> getHomeContent() =>
      guard(() => source.getHomeContent());
}
