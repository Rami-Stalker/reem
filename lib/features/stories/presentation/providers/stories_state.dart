import 'package:reem/core/shared/entities/story.dart';

class StoriesState {
  const StoriesState({
    this.isLoading = false,
    this.stories = const [],
    this.error,
  });

  final bool isLoading;
  final List<Story> stories;
  final String? error;

  bool get isEmpty => !isLoading && stories.isEmpty;

  StoriesState copyWith({
    bool? isLoading,
    List<Story>? stories,
    String? error,
    bool clearError = false,
  }) {
    return StoriesState(
      isLoading: isLoading ?? this.isLoading,
      stories: stories ?? this.stories,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
