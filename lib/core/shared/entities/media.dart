// shared/entities/media.dart
//
// Canonical media abstraction used everywhere media is shown — product
// galleries, social posts, and stories. Replaces the old `ProductMedia` type,
// which was misleadingly product-specific.

import 'package:equatable/equatable.dart';

enum MediaType { image, video }

extension MediaTypeX on MediaType {
  String get wire => name; // 'image' | 'video'

  bool get isVideo => this == MediaType.video;
  bool get isImage => this == MediaType.image;

  static MediaType fromWire(String? value) =>
      (value ?? '').toLowerCase() == 'video' ? MediaType.video : MediaType.image;
}

/// A single piece of media (image or video) with optional ordering + poster.
class MediaItem extends Equatable {
  final String url;
  final MediaType type;
  final int sortOrder;
  final String? thumbnailUrl;

  /// A blurred stand-in, drawn while the photograph is still arriving. Null for
  /// an external link and for anything uploaded before the server started
  /// deriving one — the card then falls back to a plain placeholder.
  final String? blurHash;

  const MediaItem({
    required this.url,
    this.type = MediaType.image,
    this.sortOrder = 0,
    this.thumbnailUrl,
    this.blurHash,
  });

  bool get isVideo => type.isVideo;
  bool get isImage => type.isImage;

  /// Best still-image to render (video poster when present, else the url).
  String get displayUrl => thumbnailUrl ?? url;

  @override
  List<Object?> get props => [url, type, sortOrder, thumbnailUrl, blurHash];
}

extension MediaListX on List<MediaItem> {
  /// The first thing in this gallery that is genuinely a still picture.
  ///
  /// Not `first.displayUrl`: a reel or a video-first product leads with an MP4,
  /// and `displayUrl` falls back to that URL when no poster was derived. That
  /// is right for a player and wrong everywhere a *picture* is required — a
  /// share sheet attaching a file, an `og:image` a messenger will try to draw.
  /// Both would hand out a video and render nothing.
  String? get stillImageUrl {
    for (final item in this) {
      if (item.isImage) return item.url;
      if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
        return item.thumbnailUrl;
      }
    }
    return null;
  }
}
