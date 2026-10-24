import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/post_model.dart';
import 'package:ohara/core/shared/models/story_model.dart';
import 'package:ohara/features/home/data/datasources/home_remote_datasource.dart';

final class HomeRemoteDataSourceImpl extends BaseRemoteDataSource
    implements HomeRemoteDataSource {
  const HomeRemoteDataSourceImpl(super.dio);

  @override
  Future<List<PostModel>> getFeed() async {
    final list = await getList(ApiEndpoints.postsFeed);
    return list
        .whereType<Map>()
        .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<StoryModel>> getStories() async {
    final list = await getList(ApiEndpoints.stories);
    return list
        .whereType<Map>()
        .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
