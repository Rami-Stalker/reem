import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/story.dart';

abstract interface class HomeRepository {
  Future<Result<List<Post>>> getFeed();

  Future<Result<List<Story>>> getStories();
}
