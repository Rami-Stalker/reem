import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/social_posts/domain/usecases/add_comment_usecase.dart';
import 'package:reem/features/social_posts/domain/usecases/delete_comment_usecase.dart';
import 'package:reem/features/social_posts/domain/usecases/get_comments_usecase.dart';
import 'package:reem/features/social_posts/presentation/providers/comments_state.dart';

class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier({
    required this.postId,
    required GetCommentsUseCase getComments,
    required AddCommentUseCase addComment,
    required DeleteCommentUseCase deleteComment,
    required this.currentUser,
  })  : _getComments = getComments,
        _addComment = addComment,
        _deleteComment = deleteComment,
        super(const CommentsState());

  final String postId;
  final User? currentUser;
  final GetCommentsUseCase _getComments;
  final AddCommentUseCase _addComment;
  final DeleteCommentUseCase _deleteComment;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getComments(postId, page: 1);
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          comments: data.items,
          page: data.page,
          hasNextPage: data.hasNextPage,
        ),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.isLoading) return;
    final result = await _getComments(postId, page: state.page + 1);
    if (result case Success(:final data)) {
      state = state.copyWith(
        comments: [...state.comments, ...data.items],
        page: data.page,
        hasNextPage: data.hasNextPage,
      );
    }
  }

  /// Optimistically prepends the comment, then reconciles with the server.
  Future<void> add(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;

    final optimistic = currentUser == null
        ? null
        : Comment(
            id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
            user: currentUser!,
            content: text,
            createdAt: DateTime.now(),
          );

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      comments: optimistic != null
          ? [optimistic, ...state.comments]
          : state.comments,
    );

    final result = await _addComment(postId, text);
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isSubmitting: false,
          comments: [
            data,
            ...state.comments.where((c) => c.id != optimistic?.id),
          ],
        ),
      Error(:final failure) => state.copyWith(
          isSubmitting: false,
          error: failure.message,
          comments: state.comments.where((c) => c.id != optimistic?.id).toList(),
        ),
    };
  }

  Future<void> remove(String commentId) async {
    final previous = state.comments;
    state = state.copyWith(
      comments: previous.where((c) => c.id != commentId).toList(),
    );
    final result = await _deleteComment(postId, commentId);
    if (result case Error(:final failure)) {
      // Roll back on failure.
      state = state.copyWith(comments: previous, error: failure.message);
    }
  }
}
