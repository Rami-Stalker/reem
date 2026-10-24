// shared/models/media_model.dart

import 'package:ohara/core/shared/entities/media.dart';

class MediaModel extends MediaItem {
  const MediaModel({
    required super.url,
    super.type,
    super.sortOrder,
    super.thumbnailUrl,
    super.blurHash,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      url: json['url'] as String? ?? '',
      type: MediaTypeX.fromWire(json['type'] as String?),
      sortOrder: json['sort_order'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      blurHash: json['blur_hash'] as String?,
    );
  }

  /// Builds a model from any [MediaItem], so serialization never depends on the
  /// runtime subtype.
  factory MediaModel.fromEntity(MediaItem item) => MediaModel(
        url: item.url,
        type: item.type,
        sortOrder: item.sortOrder,
        thumbnailUrl: item.thumbnailUrl,
        blurHash: item.blurHash,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type.wire,
        'sort_order': sortOrder,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (blurHash != null) 'blur_hash': blurHash,
      };

  MediaModel copyWith({
    String? url,
    MediaType? type,
    int? sortOrder,
    String? thumbnailUrl,
    String? blurHash,
  }) {
    return MediaModel(
      url: url ?? this.url,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      blurHash: blurHash ?? this.blurHash,
    );
  }
}
