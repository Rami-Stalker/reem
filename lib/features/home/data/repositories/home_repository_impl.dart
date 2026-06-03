import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl with RepositoryHandler implements HomeRepository {
  const HomeRepositoryImpl({required this.remote});

  final HomeRemoteDataSource remote;

  @override
  Future<Result<List<Post>>> getFeed() => guard(() => remote.getFeed());

  @override
  Future<Result<List<Story>>> getStories() => guard(() => remote.getStories());
}
