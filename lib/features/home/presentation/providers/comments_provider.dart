import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/shared/entities/comment.dart';
import '../../../../core/shared/models/comment_model.dart';
import '../../../../core/shared/models/user_model.dart';
import '../../data/datasources/dummy_data.dart' as dummy;

/// State for comments
class CommentsState {
  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Comment> comments;
  final bool isLoading;
  final String? error;

  CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for comments state
class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier() : super(const CommentsState());

  Future<void> loadComments(String postId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Use dummy data for now - will be replaced with real API calls
      final comments = dummy.getCommentsForPost(postId);

      state = state.copyWith(
        isLoading: false,
        comments: comments,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load comments',
      );
    }
  }

  Future<void> addComment(String postId, String content) async {
    // Create optimistic comment
    final optimisticComment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      user: UserModel(
        id: 'current_user',
        name: 'You',
        username: 'you',
        phone: '+966500000000',
        createdAt: DateTime.now(),
      ),
      content: content,
      createdAt: DateTime.now(),
      likesCount: 0,
    );

    // Optimistic update
    state = state.copyWith(
      comments: [optimisticComment, ...state.comments],
    );

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      // In real app, would call API here
      // For now, add to dummy data
      dummy.comments.add(dummy.CommentData(
        id: optimisticComment.id,
        postId: postId,
        userId: optimisticComment.user.id,
        content: content,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      // Revert on failure
      state = state.copyWith(
        comments: state.comments.where((c) => c.id != optimisticComment.id).toList(),
        error: 'Failed to add comment',
      );
    }
  }
}

/// Provider for comments
final commentsNotifierProvider =
    StateNotifierProvider<CommentsNotifier, CommentsState>((ref) {
  return CommentsNotifier();
});