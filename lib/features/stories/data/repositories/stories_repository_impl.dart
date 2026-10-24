import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/features/stories/data/datasources/stories_remote_datasource.dart';
import 'package:ohara/features/stories/domain/entities/story_analytics.dart';
import 'package:ohara/features/stories/domain/entities/story_viewer_entry.dart';
import 'package:ohara/features/stories/domain/repositories/stories_repository.dart';

class StoriesRepositoryImpl with RepositoryHandler implements StoriesRepository {
  const StoriesRepositoryImpl(this.remote);

  final StoriesRemoteDataSource remote;

  @override
  Future<Result<List<Story>>> getActiveStories() =>
      guard<List<Story>>(() => remote.getActiveStories());

  @override
  Future<Result<void>> recordView(String storyId) =>
      guard(() => remote.recordView(storyId));

  @override
  Future<Result<void>> react(String storyId, String emoji) =>
      guard(() => remote.react(storyId, emoji));

  @override
  Future<Result<void>> removeReaction(String storyId) =>
      guard(() => remote.removeReaction(storyId));

  @override
  Future<Result<StoryAnalytics>> getAnalytics(String storyId) =>
      guard(() => remote.getAnalytics(storyId));

  @override
  Future<Result<List<StoryViewerEntry>>> getViewers(String storyId) =>
      guard<List<StoryViewerEntry>>(() => remote.getViewers(storyId));
}
