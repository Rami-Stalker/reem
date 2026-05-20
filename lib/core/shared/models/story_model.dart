// shared/models/story_model.dart

import '../entities/story.dart';

import 'product_media_model.dart';
import 'user_model.dart';

class StoryModel extends Story {
  const StoryModel({
    required super.id,
    required super.user,
    required super.media,
    super.link,
    required super.isViewed,
    required super.expiresAt,
    required super.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'],

      user: UserModel.fromJson(json['user']),

      media: ProductMediaModel.fromJson(json['media']),

      link: json['link'],

      isViewed: json['is_viewed'] ?? false,

      expiresAt: DateTime.parse(json['expires_at']),

      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'user': (user as UserModel).toJson(),

      'media': (media as ProductMediaModel).toJson(),

      'link': link,

      'is_viewed': isViewed,

      'expires_at': expiresAt.toIso8601String(),

      'created_at': createdAt.toIso8601String(),
    };
  }

  StoryModel copyWith({
    String? id,
    UserModel? user,
    ProductMediaModel? media,
    String? link,
    bool? isViewed,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return StoryModel(
      id: id ?? this.id,

      user: user ?? this.user,

      media: media ?? this.media,

      link: link ?? this.link,

      isViewed: isViewed ?? this.isViewed,

      expiresAt: expiresAt ?? this.expiresAt,

      createdAt: createdAt ?? this.createdAt,
    );
  }
}