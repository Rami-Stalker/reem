// shared/models/media_model.dart

import '../entities/media.dart';

class MediaModel extends MediaItem {
  const MediaModel({
    required super.url,
    super.type,
    super.sortOrder,
    super.thumbnailUrl,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      url: json['url'] as String? ?? '',
      type: MediaTypeX.fromWire(json['type'] as String?),
      sortOrder: json['sort_order'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  /// Builds a model from any [MediaItem], so serialization never depends on the
  /// runtime subtype.
  factory MediaModel.fromEntity(MediaItem item) => MediaModel(
        url: item.url,
        type: item.type,
        sortOrder: item.sortOrder,
        thumbnailUrl: item.thumbnailUrl,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type.wire,
        'sort_order': sortOrder,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      };

  MediaModel copyWith({
    String? url,
    MediaType? type,
    int? sortOrder,
    String? thumbnailUrl,
  }) {
    return MediaModel(
      url: url ?? this.url,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
