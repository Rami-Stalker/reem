import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../../domain/entities/story_analytics.dart';
import '../../domain/entities/story_viewer_entry.dart';
import '../../domain/repositories/stories_repository.dart';
import '../datasources/stories_remote_datasource.dart';

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
