import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/story.dart';

import 'package:reem/features/create/presentation/providers/create_message.dart';

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
  /// Named, not spelled out — the screen resolves it in her locale.
  final CreateMessage? successMessage;
  final Post? lastPost;
  final Story? lastStory;

  CreateState copyWith({
    bool? isLoading,
    String? error,
    CreateMessage? successMessage,
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
