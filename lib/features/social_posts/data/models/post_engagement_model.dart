import 'package:ohara/features/social_posts/domain/entities/post_engagement.dart';

class PostEngagementModel extends PostEngagement {
  const PostEngagementModel({
    required super.isLiked,
    required super.likesCount,
    required super.isSaved,
    required super.savesCount,
    required super.sharesCount,
  });

  /// Parses either the full serialized post or a follow-style summary payload.
  factory PostEngagementModel.fromJson(Map<String, dynamic> json) {
    return PostEngagementModel(
      isLiked: json['is_liked'] as bool? ?? false,
      likesCount: json['likes_count'] as int? ?? 0,
      isSaved: json['is_saved'] as bool? ?? false,
      savesCount: json['saves_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
    );
  }
}
