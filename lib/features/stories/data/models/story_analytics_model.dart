import 'package:ohara/features/stories/domain/entities/story_analytics.dart';

class StoryAnalyticsModel extends StoryAnalytics {
  const StoryAnalyticsModel({
    required super.storyId,
    required super.viewsCount,
    required super.reactionsCount,
    required super.reactionBreakdown,
    required super.engagementRate,
    required super.expiresAt,
  });

  factory StoryAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['reaction_breakdown'] as Map?)?.map(
          (k, v) => MapEntry(k as String, v as int),
        ) ??
        <String, int>{};
    return StoryAnalyticsModel(
      storyId: json['story_id'] as String,
      viewsCount: json['views_count'] as int? ?? 0,
      reactionsCount: json['reactions_count'] as int? ?? 0,
      reactionBreakdown: breakdown,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
