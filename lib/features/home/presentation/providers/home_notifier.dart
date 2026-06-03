import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/usecases/get_feed_usecase.dart';
import '../../domain/usecases/get_stories_usecase.dart';
import 'home_state.dart';

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier({
    required GetFeedUseCase getFeedUseCase,
    required GetStoriesUseCase getStoriesUseCase,
  })  : _getFeed = getFeedUseCase,
        _getStories = getStoriesUseCase,
        super(const HomeState()) {
    load();
  }

  final GetFeedUseCase _getFeed;
  final GetStoriesUseCase _getStories;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final feedResult = await _getFeed();
    final storiesResult = await _getStories();

    String? error;
    var posts = state.posts;
    var stories = state.stories;

    switch (feedResult) {
      case Success(:final data):
        posts = data;
      case Error(:final failure):
        error = failure.message;
    }

    switch (storiesResult) {
      case Success(:final data):
        stories = data;
      case Error(:final failure):
        error ??= failure.message;
    }

    state = state.copyWith(
      isLoading: false,
      posts: posts,
      stories: stories,
      error: error,
    );
  }
}
