import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';

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
    );
  }

  @override
  List<Object?> get props => [id, body, repliesCount, replies];
}
