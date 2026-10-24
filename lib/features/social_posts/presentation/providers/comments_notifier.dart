import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/comment.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';

import 'package:ohara/features/social_posts/domain/usecases/add_comment_usecase.dart';
import 'package:ohara/features/social_posts/domain/usecases/delete_comment_usecase.dart';
import 'package:ohara/features/social_posts/domain/usecases/get_comments_usecase.dart';
import 'package:ohara/features/social_posts/presentation/providers/comments_state.dart';

class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier({
    required this.thread,
    required GetCommentsUseCase getComments,
    required AddCommentUseCase addComment,
    required DeleteCommentUseCase deleteComment,
    required this.currentUser,
  }) : _getComments = getComments,
       _addComment = addComment,
       _deleteComment = deleteComment,
       super(const CommentsState());

  final CommentThread thread;
  final User? currentUser;
  final GetCommentsUseCase _getComments;
  final AddCommentUseCase _addComment;
  final DeleteCommentUseCase _deleteComment;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getComments(thread, page: 1);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        comments: data.items,
        page: data.page,
        hasNextPage: data.hasNextPage,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.isLoading) return;
    final result = await _getComments(thread, page: state.page + 1);
    if (result case Success(:final data)) {
      state = state.copyWith(
        comments: [...state.comments, ...data.items],
        page: data.page,
        hasNextPage: data.hasNextPage,
      );
    }
  }

  /// Optimistically prepends the comment, then reconciles with the server.
  ///
  /// Returns true only once the server has taken it, so the caller can move a
  /// comment tally that lives outside this thread -- the card in the feed,
  /// whose count is part of a `Post` this notifier has never seen.
  Future<bool> add(String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;

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

    final result = await _addComment(thread, text);
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
    return result is Success;
  }

  /// Deletes a comment, reporting whether the server agreed.
  Future<bool> remove(String commentId) async {
    final previous = state.comments;
    state = state.copyWith(
      comments: previous.where((c) => c.id != commentId).toList(),
    );
    final result = await _deleteComment(thread, commentId);
    if (result case Error(:final failure)) {
      // Roll back on failure.
      state = state.copyWith(comments: previous, error: failure.message);
      return false;
    }
    return true;
  }
}
