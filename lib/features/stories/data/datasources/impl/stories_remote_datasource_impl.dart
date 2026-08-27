import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/story_model.dart';
import 'package:reem/features/stories/data/datasources/stories_remote_datasource.dart';
import 'package:reem/features/stories/data/models/story_analytics_model.dart';
import 'package:reem/features/stories/data/models/story_viewer_model.dart';

final class StoriesRemoteDataSourceImpl extends BaseRemoteDataSource
    implements StoriesRemoteDataSource {
  const StoriesRemoteDataSourceImpl(super.dio);

  @override
  Future<List<StoryModel>> getActiveStories() async {
    final list = await getList(ApiEndpoints.stories);
    return list
        .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> recordView(String storyId) async {
    await postJson(ApiEndpoints.storyView(storyId));
  }

  @override
  Future<void> react(String storyId, String emoji) async {
    await postJson(ApiEndpoints.storyReact(storyId), body: {'emoji': emoji});
  }

  @override
  Future<void> removeReaction(String storyId) =>
      deleteRequest(ApiEndpoints.storyReact(storyId));

  @override
  Future<StoryAnalyticsModel> getAnalytics(String storyId) async {
    final json = await getJson(ApiEndpoints.sellerStoryAnalytics(storyId));
    return StoryAnalyticsModel.fromJson(json);
  }

  @override
  Future<List<StoryViewerModel>> getViewers(String storyId) async {
    final list = await getList(ApiEndpoints.sellerStoryViewers(storyId));
    return list
        .map((e) => StoryViewerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
