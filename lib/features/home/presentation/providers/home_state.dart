import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/story.dart';

class HomeState {
  const HomeState({
    this.posts = const [],
    this.stories = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Post> posts;
  final List<Story> stories;
  final bool isLoading;
  final String? error;

  HomeState copyWith({
    List<Post>? posts,
    List<Story>? stories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeState(
      posts: posts ?? this.posts,
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
