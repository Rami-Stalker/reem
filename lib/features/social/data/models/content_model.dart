import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/models/media_model.dart';
import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/social/domain/entities/content.dart';

/// Decoding the content platform's wire shape.
///
/// Every field is read defensively. The feed is the screen a woman opens the
/// app on, and the repository wraps this in `guard()` — so a single throw here
/// does not show a broken card, it swallows the entire feed into one silent
/// failure and she sees an empty screen with nothing in the logs. That has
/// happened twice on this project already (a post with no product, a category
/// that arrived as an object), which is why `PostModel` grew its own
/// regression test.
class ContentModel extends Content {
  const ContentModel({
    required super.id,
    required super.author,
    required super.authorKind,
    required super.format,
    required super.status,
    required super.moderationState,
    required super.visibility,
    required super.createdAt,
    super.title,
    super.body,
    super.media,
    super.productTags,
    super.counts,
    super.viewer,
    super.publishedAt,
    super.expiresAt,
    super.removalReason,
  });

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map<String, dynamic>? ?? const {};
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};

    return ContentModel(
      id: json['id'] as String,
      author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
      authorKind: ContentAuthorKind.fromWire(json['author_kind'] as String?),
      format: ContentFormat.fromWire(json['content_type'] as String?),
      status: ContentStatus.fromWire(json['status'] as String?),
      moderationState: ContentModerationState.fromWire(
        json['moderation_state'] as String?,
      ),
      visibility: ContentVisibility.fromWire(json['visibility'] as String?),
      title: json['title'] as String?,
      body: json['body'] as String?,
      media: _media(json['media']),
      productTags: _tags(json['product_tags']),
      counts: ContentCounts(
        views: _int(analytics['views']),
        likes: _int(analytics['reactions']),
        comments: _int(analytics['replies']),
        saves: _int(analytics['saves']),
        shares: _int(analytics['shares']),
        productClicks: _int(analytics['product_clicks']),
      ),
      viewer: ContentViewerState(
        isLiked: viewer['is_liked'] as bool? ?? false,
        myReaction: viewer['my_reaction'] as String?,
        isSaved: viewer['is_saved'] as bool? ?? false,
        isReshared: viewer['is_reshared'] as bool? ?? false,
      ),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      publishedAt: _date(json['published_at']),
      expiresAt: _date(json['expires_at']),
      removalReason: json['removal_reason'] as String?,
    );
  }

  static List<MediaItem> _media(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MediaModel.fromJson)
        .toList(growable: false);
  }

  static List<ContentProductTag> _tags(dynamic raw) {
    if (raw is! List) return const [];
    final tags = <ContentProductTag>[];
    for (final entry in raw.whereType<Map<String, dynamic>>()) {
      final product = entry['product'];
      // A tag whose product was delisted comes back without one. Skipping it
      // is right: the alternative is a "shop this" plate that leads nowhere.
      if (product is! Map<String, dynamic>) continue;
      tags.add(
        ContentProductTag(
          id: entry['id'] as String,
          product: ProductModel.fromJson(product),
          displayLabel: entry['display_label'] as String?,
          x: (entry['x'] as num?)?.toDouble(),
          y: (entry['y'] as num?)?.toDouble(),
          sortOrder: _int(entry['sort_order']),
        ),
      );
    }
    return tags;
  }

  /// Counters arrive as numbers, but `BigInt` columns serialise wide enough
  /// that a JSON parser may hand back a double.
  static int _int(dynamic value) =>
      value is int ? value : (value as num?)?.toInt() ?? 0;

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// A reshare, with the original nested whole.
class ContentReshareModel extends ContentReshare {
  const ContentReshareModel({
    required super.id,
    required super.resharer,
    required super.content,
    required super.resharedAt,
    super.note,
  });

  factory ContentReshareModel.fromJson(Map<String, dynamic> json) {
    return ContentReshareModel(
      id: json['id'] as String,
      resharer: UserModel.fromJson(json['resharer'] as Map<String, dynamic>),
      content: ContentModel.fromJson(json['content'] as Map<String, dynamic>),
      resharedAt:
          DateTime.tryParse(json['reshared_at'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String?,
    );
  }
}

/// One entry on a page — hers, or somebody else's that she added.
TimelineEntry timelineEntryFromJson(Map<String, dynamic> json) {
  if (json['kind'] == 'reshare') {
    return ResharedContentEntry(ContentReshareModel.fromJson(json));
  }
  return OwnContentEntry(
    ContentModel.fromJson(json['content'] as Map<String, dynamic>),
  );
}
