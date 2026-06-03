import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/usecases/create_post_usecase.dart';
import '../../domain/usecases/create_story_usecase.dart';
import 'create_state.dart';

class CreateNotifier extends StateNotifier<CreateState> {
  CreateNotifier({
    required CreatePostUseCase createPostUseCase,
    required CreateStoryUseCase createStoryUseCase,
  })  : _createPost = createPostUseCase,
        _createStory = createStoryUseCase,
        super(const CreateState());

  final CreatePostUseCase _createPost;
  final CreateStoryUseCase _createStory;

  Future<bool> createPost({
    required String caption,
    required String productId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _createPost(caption: caption, productId: productId);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isLoading: false,
            lastPost: data,
            successMessage: 'Post created successfully.',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }

  Future<bool> createStory({
    required String mediaUrl,
    String? link,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _createStory(mediaUrl: mediaUrl, link: link);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isLoading: false,
            lastStory: data,
            successMessage: 'Story created successfully.',
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }
}
