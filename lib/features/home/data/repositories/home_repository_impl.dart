import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/features/home/data/datasources/home_remote_datasource.dart';
import 'package:ohara/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl with RepositoryHandler implements HomeRepository {
  const HomeRepositoryImpl({required this.remote});

  final HomeRemoteDataSource remote;

  @override
  Future<Result<List<Post>>> getFeed() => guard(() => remote.getFeed());

  @override
  Future<Result<List<Story>>> getStories() => guard(() => remote.getStories());
}
