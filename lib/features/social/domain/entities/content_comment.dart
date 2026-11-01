import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/entities/user.dart';

/// A comment, and the replies under it.
///
/// One level of nesting and no more. The card renders a head and its replies;
/// a third level would be invisible rather than merely ugly, so the server
/// re-parents a reply-to-a-reply onto the thread root at write time and this
/// type simply cannot express the deeper shape.
class ContentComment extends Equatable {
  const ContentComment({
    required this.id,
    required this.user,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.repliesCount = 0,
    this.replies = const [],
    this.reactionsCount = 0,
    this.myReaction,
    this.reactionSummary = const [],
  });

  final String id;
  final User user;
  final String body;
  final DateTime createdAt;

  /// Null for a thread head.
  final String? parentId;

  /// How many replies exist, which is not the same as how many arrived — a
  /// thread head ships the first few and says how many more there are.
  final int repliesCount;
  final List<ContentComment> replies;

  /// Reactions on the comment: how many, the glyph she left (null for none),
  /// and everyone's most chosen.
  final int reactionsCount;
  final String? myReaction;
  final List<ReactionCount> reactionSummary;

  bool get isReply => parentId != null;

  /// Replies still to fetch. Zero means the thread is fully loaded, which is
  /// what lets the UI hide "show more" rather than showing a button that does
  /// nothing.
  int get hiddenReplies =>
      repliesCount - replies.length < 0 ? 0 : repliesCount - replies.length;

  ContentComment copyWith({List<ContentComment>? replies}) {
    return ContentComment(
      id: id,
      user: user,
      body: body,
      createdAt: createdAt,
      parentId: parentId,
      repliesCount: repliesCount,
      replies: replies ?? this.replies,
      reactionsCount: reactionsCount,
      myReaction: myReaction,
      reactionSummary: reactionSummary,
    );
  }

  /// The same comment with her reaction set to [glyph] (null for none).
  ContentComment withReaction({
    required String? glyph,
    required int count,
    required List<ReactionCount> summary,
  }) {
    return ContentComment(
      id: id,
      user: user,
      body: body,
      createdAt: createdAt,
      parentId: parentId,
      repliesCount: repliesCount,
      replies: replies,
      reactionsCount: count,
      myReaction: glyph,
      reactionSummary: summary,
    );
  }

  @override
  List<Object?> get props => [
    id,
    body,
    repliesCount,
    replies,
    reactionsCount,
    myReaction,
    reactionSummary,
  ];
}

/// A comment's reactions after she reacted — the server's settled answer.
class CommentReactionState extends Equatable {
  const CommentReactionState({
    required this.count,
    required this.glyph,
    required this.summary,
  });

  final int count;

  /// Hers, or null.
  final String? glyph;
  final List<ReactionCount> summary;

  @override
  List<Object?> get props => [count, glyph, summary];
}
