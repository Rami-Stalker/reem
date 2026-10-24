import 'package:ohara/core/shared/models/story_model.dart';
import 'package:ohara/features/highlights/domain/entities/highlight.dart';

class HighlightModel extends Highlight {
  const HighlightModel({
    required super.id,
    required super.ownerId,
    required super.title,
    required super.itemsCount,
    required super.sortOrder,
    required super.isMine,
    super.coverUrl,
    super.stories,
  });

  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isMine: json['is_mine'] as bool? ?? false,
      // Absent on the rail read, which carries covers and counts only.
      stories: (json['stories'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => StoryModel.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false),
    );
  }
}
