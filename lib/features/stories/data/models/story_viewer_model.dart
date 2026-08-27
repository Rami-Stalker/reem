import 'package:reem/core/shared/models/user_model.dart';

import 'package:reem/features/stories/domain/entities/story_viewer_entry.dart';

class StoryViewerModel extends StoryViewerEntry {
  const StoryViewerModel({
    required super.user,
    required super.viewedAt,
    super.reaction,
  });

  factory StoryViewerModel.fromJson(Map<String, dynamic> json) {
    return StoryViewerModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      viewedAt: DateTime.parse(json['viewed_at'] as String),
      reaction: json['reaction'] as String?,
    );
  }
}
