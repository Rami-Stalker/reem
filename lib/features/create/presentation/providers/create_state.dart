import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/story.dart';

class CreateState {
  const CreateState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.lastPost,
    this.lastStory,
  });

  final bool isLoading;
  final String? error;
  final String? successMessage;
  final Post? lastPost;
  final Story? lastStory;

  CreateState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    Post? lastPost,
    Story? lastStory,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CreateState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      lastPost: lastPost ?? this.lastPost,
      lastStory: lastStory ?? this.lastStory,
    );
  }
}
