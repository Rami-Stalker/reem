import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../entities/story_analytics.dart';
import '../entities/story_viewer_entry.dart';

abstract interface class StoriesRepository {
  Future<Result<List<Story>>> getActiveStories();

  Future<Result<void>> recordView(String storyId);

  Future<Result<void>> react(String storyId, String emoji);

  Future<Result<void>> removeReaction(String storyId);

  // Seller-only analytics.
  Future<Result<StoryAnalytics>> getAnalytics(String storyId);

  Future<Result<List<StoryViewerEntry>>> getViewers(String storyId);
}
