import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/entities/comment.dart';

class CommentModel extends Comment {
  final int likesCount;

  const CommentModel({
    required String id,
    required User user,
    required String content,
    required DateTime createdAt,
    this.likesCount = 0,
  }) : super(
          id: id,
          user: user,
          content: content,
          createdAt: createdAt,
        );

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    return CommentModel(
      id: json['id'] as String,
      user: User(
        id: userJson['id'] as String,
        name: userJson['name'] as String,
        username: userJson['username'] as String,
        email: userJson['email'] as String? ?? '',
        imageUrl: userJson['image_url'] as String?,
        createdAt: DateTime.parse(userJson['created_at'] as String),
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      likesCount: json['likes_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': {
        'id': user.id,
        'name': user.name,
        'username': user.username,
        'email': user.email,
        'image_url': user.imageUrl,
        'created_at': user.createdAt.toIso8601String(),
      },
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
    };
  }

  CommentModel copyWith({
    String? id,
    User? user,
    String? content,
    DateTime? createdAt,
    int? likesCount,
  }) {
    return CommentModel(
      id: id ?? this.id,
      user: user ?? this.user,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
    );
  }
}