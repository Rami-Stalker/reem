import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/social/domain/entities/content_comment.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/social/presentation/content_reaction.dart';

class ContentCommentsState {
  const ContentCommentsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.comments = const [],
    this.error,
    this.page = 1,
    this.hasNextPage = false,
    this.netChange = 0,
    this.replyingTo,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<ContentComment> comments;
  final String? error;
  final int page;
  final bool hasNextPage;

  /// Committed adds minus committed deletes, so the card underneath can keep a
  /// live tally without refetching the feed. The count on the card used to
  /// read an immutable `Post` and never moved.
  final int netChange;

  /// The thread head she is answering, if any.
  final ContentComment? replyingTo;

  ContentCommentsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<ContentComment>? comments,
    String? error,
    int? page,
    bool? hasNextPage,
    int? netChange,
    ContentComment? replyingTo,
    bool clearError = false,
    bool clearReplyTarget = false,
  }) {
    return ContentCommentsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      comments: comments ?? this.comments,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      netChange: netChange ?? this.netChange,
      replyingTo: clearReplyTarget ? null : (replyingTo ?? this.replyingTo),
    );
  }
}

/// One content's comment thread, one level deep.
class ContentCommentsNotifier extends StateNotifier<ContentCommentsState> {
  ContentCommentsNotifier(this._repository, this.contentId)
    : super(const ContentCommentsState());

  final SocialRepository _repository;
  final String contentId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.comments(contentId);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        comments: data.items,
        page: data.pageInfo.page,
        hasNextPage: data.pageInfo.hasNextPage,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasNextPage) return;
    final result = await _repository.comments(contentId, page: state.page + 1);
    if (result case Success(:final data)) {
      state = state.copyWith(
        comments: [...state.comments, ...data.items],
        page: data.pageInfo.page,
        hasNextPage: data.pageInfo.hasNextPage,
      );
    }
  }

  /// The rest of one thread's replies. A head ships the first few and says how
  /// many more; this fetches them without disturbing the others.
  Future<void> loadReplies(String commentId) async {
    final result = await _repository.replies(commentId);
    if (result case Success(:final data)) {
      state = state.copyWith(
        comments: [
          for (final comment in state.comments)
            if (comment.id == commentId)
              comment.copyWith(replies: data)
            else
              comment,
        ],
      );
    }
  }

  void replyTo(ContentComment? comment) {
    state = comment == null
        ? state.copyWith(clearReplyTarget: true)
        : state.copyWith(replyingTo: comment);
  }

  Future<void> submit(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.isSubmitting) return;

    final parent = state.replyingTo;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _repository.comment(
      contentId,
      text,
      parentId: parent?.id,
    );

    state = switch (result) {
      Success(:final data) => state.copyWith(
        isSubmitting: false,
        netChange: state.netChange + 1,
        clearReplyTarget: true,
        comments: parent == null
            // A new thread goes to the top, where she is looking.
            ? [data, ...state.comments]
            : [
                for (final comment in state.comments)
                  if (comment.id == parent.id)
                    comment.copyWith(replies: [...comment.replies, data])
                  else
                    comment,
              ],
      ),
      Error(:final failure) => state.copyWith(
        isSubmitting: false,
        error: failure.message,
      ),
    };
  }

  /// A reaction on a comment or a reply; [glyph] null takes hers back.
  /// Drawn at once, settled by the server, put back if refused.
  Future<void> react(ContentComment comment, String? glyph) async {
    final had = comment.myReaction;
    final optimistic = comment.withReaction(
      glyph: glyph,
      count: (comment.reactionsCount +
              (glyph != null ? 1 : 0) -
              (had != null ? 1 : 0))
          .clamp(0, 1 << 30),
      summary: shiftReaction(comment.reactionSummary, had, glyph),
    );
    _replaceComment(optimistic);
    final wire = glyph == null
        ? (had == null ? null : DsReactions.toWire(had))
        : DsReactions.toWire(glyph);
    final result = await _repository.reactToComment(comment.id, emoji: wire);
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        _replaceComment(
          comment.withReaction(
            glyph: data.glyph,
            count: data.count,
            summary: data.summary,
          ),
        );
      case Error(:final failure):
        _replaceComment(comment);
        state = state.copyWith(error: failure.message);
    }
  }

  /// Puts [updated] where the comment with its id is — a head or a reply.
  void _replaceComment(ContentComment updated) {
    state = state.copyWith(
      comments: [
        for (final head in state.comments)
          if (head.id == updated.id)
            updated.copyWith(replies: head.replies)
          else
            head.copyWith(
              replies: [
                for (final reply in head.replies)
                  reply.id == updated.id ? updated : reply,
              ],
            ),
      ],
    );
  }

  Future<void> remove(ContentComment comment) async {
    final result = await _repository.deleteComment(comment.id);
    if (result case Error(:final failure)) {
      state = state.copyWith(error: failure.message);
      return;
    }

    state = state.copyWith(
      netChange: state.netChange - 1,
      comments: [
        // A removed thread head takes its replies with it from view, which is
        // what the server does too; a removed reply leaves its head standing.
        for (final head in state.comments)
          if (head.id != comment.id)
            head.copyWith(
              replies: [
                for (final reply in head.replies)
                  if (reply.id != comment.id) reply,
              ],
            ),
      ],
    );
  }
}
