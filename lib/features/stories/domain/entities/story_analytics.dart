import 'package:equatable/equatable.dart';

class StoryAnalytics extends Equatable {
  final String storyId;
  final int viewsCount;
  final int reactionsCount;
  final Map<String, int> reactionBreakdown;
  final double engagementRate;
  final DateTime expiresAt;

  const StoryAnalytics({
    required this.storyId,
    required this.viewsCount,
    required this.reactionsCount,
    required this.reactionBreakdown,
    required this.engagementRate,
    required this.expiresAt,
  });

  @override
  List<Object?> get props => [
        storyId,
        viewsCount,
        reactionsCount,
        reactionBreakdown,
        engagementRate,
        expiresAt,
      ];
}
