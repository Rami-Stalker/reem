// shared/models/comment_model.dart

import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.user,
    required super.content,
    super.likesCount,
    required super.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      content: json['content'] as String,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': UserModel.fromEntity(user).toJson(),
        'content': content,
        'likes_count': likesCount,
        'created_at': createdAt.toIso8601String(),
      };

  CommentModel copyWith({
    String? id,
    User? user,
    String? content,
    int? likesCount,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      user: user ?? this.user,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
