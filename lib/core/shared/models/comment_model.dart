// shared/models/comment_model.dart

import '../entities/comment.dart';
import 'user_model.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.user,
    required super.content,
    required super.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      user: UserModel.fromJson(json['user']),
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': (user as UserModel).toJson(),
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CommentModel copyWith({
    String? id,
    UserModel? user,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      user: user ?? this.user,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}