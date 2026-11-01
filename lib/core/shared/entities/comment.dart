// shared/entities/comment.dart

import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/entities/user.dart';

class Comment extends Equatable {
  final String id;
  final User user;
  final String content;
  /// How many reacted — the reactions on a post's comments.
  final int likesCount;
  final DateTime createdAt;

  /// The glyph she reacted with, or null.
  final String? myReaction;

  /// Everyone's most chosen reactions.
  final List<ReactionCount> reactionSummary;

  const Comment({
    required this.id,
    required this.user,
    required this.content,
    this.likesCount = 0,
    required this.createdAt,
    this.myReaction,
    this.reactionSummary = const [],
  });

  @override
  List<Object?> get props => [
    id,
    user,
    content,
    likesCount,
    createdAt,
    myReaction,
    reactionSummary,
  ];
}
