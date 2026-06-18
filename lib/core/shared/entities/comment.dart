// shared/entities/comment.dart

import 'package:equatable/equatable.dart';

import 'user.dart';

class Comment extends Equatable {
  final String id;
  final User user;
  final String content;
  final int likesCount;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.user,
    required this.content,
    this.likesCount = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, user, content, likesCount, createdAt];
}
