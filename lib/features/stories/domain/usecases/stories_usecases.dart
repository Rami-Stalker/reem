import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../entities/story_analytics.dart';
import '../entities/story_viewer_entry.dart';
import '../repositories/stories_repository.dart';

class GetStoriesUseCase {
  const GetStoriesUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<List<Story>>> call() => _repo.getActiveStories();
}

class RecordStoryViewUseCase {
  const RecordStoryViewUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<void>> call(String storyId) => _repo.recordView(storyId);
}

class ReactToStoryUseCase {
  const ReactToStoryUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<void>> call(String storyId, String emoji) =>
      _repo.react(storyId, emoji);
}

class RemoveStoryReactionUseCase {
  const RemoveStoryReactionUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<void>> call(String storyId) => _repo.removeReaction(storyId);
}

class GetStoryAnalyticsUseCase {
  const GetStoryAnalyticsUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<StoryAnalytics>> call(String storyId) =>
      _repo.getAnalytics(storyId);
}

class GetStoryViewersUseCase {
  const GetStoryViewersUseCase(this._repo);
  final StoriesRepository _repo;
  Future<Result<List<StoryViewerEntry>>> call(String storyId) =>
      _repo.getViewers(storyId);
}
