// shared/models/story_model.dart

import '../entities/media.dart';
import '../entities/story.dart';
import '../entities/user.dart';
import 'media_model.dart';
import 'user_model.dart';

class StoryModel extends Story {
  const StoryModel({
    required super.id,
    required super.user,
    super.media,
    super.link,
    super.isViewed,
    super.myReaction,
    required super.expiresAt,
    required super.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      media: _parseMedia(json['media']),
      link: json['link'] as String?,
      isViewed: json['is_viewed'] as bool? ?? false,
      myReaction: json['my_reaction'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Accepts either a list of media or a single media object (the current
  /// backend returns one), normalising both to a list.
  static List<MediaItem> _parseMedia(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MediaModel.fromJson)
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      return [MediaModel.fromJson(raw)];
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': UserModel.fromEntity(user).toJson(),
        'media': media.map((m) => MediaModel.fromEntity(m).toJson()).toList(),
        'link': link,
        'is_viewed': isViewed,
        'my_reaction': myReaction,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  StoryModel copyWith({
    String? id,
    User? user,
    List<MediaItem>? media,
    String? link,
    bool? isViewed,
    String? myReaction,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return StoryModel(
      id: id ?? this.id,
      user: user ?? this.user,
      media: media ?? this.media,
      link: link ?? this.link,
      isViewed: isViewed ?? this.isViewed,
      myReaction: myReaction ?? this.myReaction,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
