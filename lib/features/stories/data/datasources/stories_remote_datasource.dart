import 'package:reem/core/shared/models/story_model.dart';

import '../models/story_analytics_model.dart';
import '../models/story_viewer_model.dart';

abstract interface class StoriesRemoteDataSource {
  Future<List<StoryModel>> getActiveStories();

  Future<void> recordView(String storyId);

  Future<void> react(String storyId, String emoji);

  Future<void> removeReaction(String storyId);

  Future<StoryAnalyticsModel> getAnalytics(String storyId);

  Future<List<StoryViewerModel>> getViewers(String storyId);
}
