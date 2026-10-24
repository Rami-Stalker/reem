import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/story.dart';

import 'package:ohara/features/stories/domain/entities/story_analytics.dart';
import 'package:ohara/features/stories/domain/entities/story_viewer_entry.dart';

abstract interface class StoriesRepository {
  Future<Result<List<Story>>> getActiveStories();

  Future<Result<void>> recordView(String storyId);

  Future<Result<void>> react(String storyId, String emoji);

  Future<Result<void>> removeReaction(String storyId);

  // Seller-only analytics.
  Future<Result<StoryAnalytics>> getAnalytics(String storyId);

  Future<Result<List<StoryViewerEntry>>> getViewers(String storyId);
}
