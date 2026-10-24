import 'package:ohara/core/shared/models/post_model.dart';
import 'package:ohara/core/shared/models/story_model.dart';

abstract interface class HomeRemoteDataSource {
  Future<List<PostModel>> getFeed();

  Future<List<StoryModel>> getStories();
}
