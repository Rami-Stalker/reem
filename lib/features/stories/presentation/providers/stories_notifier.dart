import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/stories/domain/usecases/stories_usecases.dart';
import 'package:ohara/features/stories/presentation/providers/stories_state.dart';

class StoriesNotifier extends StateNotifier<StoriesState> {
  StoriesNotifier({required GetStoriesUseCase getStories})
      : _getStories = getStories,
        super(const StoriesState());

  final GetStoriesUseCase _getStories;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getStories();
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, stories: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> refresh() => load();
}
