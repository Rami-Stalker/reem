import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/entities/content_analytics.dart';
import 'package:ohara/features/social/domain/entities/content_audience.dart';
import 'package:ohara/features/social/domain/entities/content_comment.dart';
import 'package:ohara/features/social/domain/entities/content_draft.dart';

int _int(dynamic value) => value is int ? value : (value as num?)?.toInt() ?? 0;

DateTime _date(dynamic value) =>
    DateTime.tryParse(value as String? ?? '') ?? DateTime.now();

class ContentCommentModel extends ContentComment {
  const ContentCommentModel({
    required super.id,
    required super.user,
    required super.body,
    required super.createdAt,
    super.parentId,
    super.repliesCount,
    super.replies,
    super.reactionsCount,
    super.myReaction,
    super.reactionSummary,
  });

  factory ContentCommentModel.fromJson(Map<String, dynamic> json) {
    final replies = json['replies'];
    return ContentCommentModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      body: json['body'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      repliesCount: _int(json['replies_count']),
      replies: replies is List
          ? replies
                .whereType<Map<String, dynamic>>()
                .map(ContentCommentModel.fromJson)
                .toList(growable: false)
          : const [],
      createdAt: _date(json['created_at']),
      reactionsCount: _int(json['reactions_count']),
      myReaction: reactionGlyphFromJson(json),
      reactionSummary: ReactionCount.listFromJson(json['reaction_summary']),
    );
  }
}

class ContentViewerStateModel extends ContentViewerState {
  const ContentViewerStateModel({
    super.isLiked,
    super.myReaction,
    super.isSaved,
    super.isReshared,
    super.reactionSummary,
  });

  /// The interaction endpoints answer with the viewer's state *and* the fresh
  /// counters, so one round trip settles the card.
  factory ContentViewerStateModel.fromJson(Map<String, dynamic> json) {
    return ContentViewerStateModel(
      isLiked: json['is_liked'] as bool? ?? false,
      myReaction: json['my_reaction'] as String?,
      isSaved: json['is_saved'] as bool? ?? false,
      isReshared: json['is_reshared'] as bool? ?? false,
      reactionSummary: ReactionCount.listFromJson(json['reaction_summary']),
    );
  }

  static ContentCounts countsFrom(Map<String, dynamic> json) => ContentCounts(
    likes: _int(json['likes_count']),
    comments: _int(json['comments_count']),
    saves: _int(json['saves_count']),
    shares: _int(json['shares_count']),
  );
}

class TaggableProductModel extends TaggableProduct {
  const TaggableProductModel({
    required super.productId,
    required super.title,
    required super.basis,
    required super.eligible,
    super.imageUrl,
    super.reason,
    super.sourceOrderItemId,
  });

  factory TaggableProductModel.fromJson(Map<String, dynamic> json) {
    return TaggableProductModel(
      productId: json['product_id'] as String,
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      basis: json['basis'] as String? ?? 'SELLER_OFFER',
      eligible: json['eligible'] as bool? ?? true,
      reason: json['reason'] as String?,
      sourceOrderItemId: json['source_order_item_id'] as String?,
    );
  }
}

class ContentTypeOptionModel extends ContentTypeOption {
  const ContentTypeOptionModel({
    required super.key,
    required super.name,
    required super.format,
    super.description,
    super.supportsProductTags,
    super.supportsMedia,
    super.videoRequired,
    super.maxDurationSeconds,
    super.maxMedia,
  });

  factory ContentTypeOptionModel.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] as Map<String, dynamic>? ?? const {};
    final key = json['key'] as String;
    return ContentTypeOptionModel(
      key: key,
      name: json['name'] as String? ?? key,
      format: ContentFormat.fromWire(key),
      description: json['description'] as String?,
      supportsProductTags: caps['supports_product_tags'] as bool? ?? false,
      supportsMedia: caps['supports_media'] as bool? ?? false,
      videoRequired: caps['video_required'] as bool? ?? false,
      maxDurationSeconds: (caps['max_duration_seconds'] as num?)?.toInt(),
      maxMedia: (caps['max_media'] as num?)?.toInt(),
    );
  }

  /// Which formats a woman may publish.
  ///
  /// The registry is the authority and it says so per type, so the client
  /// filters rather than deciding. A hard-coded list here would be a second
  /// answer to a question the server already answers, and the two would drift.
  static bool availableTo(Map<String, dynamic> json, {required bool isSeller}) {
    final caps = json['capabilities'] as Map<String, dynamic>? ?? const {};
    final audiences = caps['audiences'];
    if (audiences is! List) return isSeller;
    return audiences.contains(isSeller ? 'seller' : 'customer');
  }
}

class ContentFormatPerformanceModel extends ContentFormatPerformance {
  const ContentFormatPerformanceModel({
    required super.format,
    required super.published,
    required super.views,
    required super.uniqueViewers,
    required super.likes,
    required super.comments,
    required super.saves,
    required super.shares,
    required super.productClicks,
    required super.orders,
    required super.watchTimeMs,
  });

  factory ContentFormatPerformanceModel.fromJson(Map<String, dynamic> json) {
    return ContentFormatPerformanceModel(
      format: json['content_type'] as String? ?? '',
      published: _int(json['published']),
      views: _int(json['views']),
      uniqueViewers: _int(json['unique_viewers']),
      likes: _int(json['likes']),
      comments: _int(json['comments']),
      saves: _int(json['saves']),
      shares: _int(json['shares']),
      productClicks: _int(json['product_clicks']),
      orders: _int(json['orders']),
      watchTimeMs: _int(json['watch_time_ms']),
    );
  }
}

class ContentAnalyticsModel extends ContentAnalytics {
  const ContentAnalyticsModel({
    required super.contentId,
    required super.format,
    required super.impressions,
    required super.views,
    required super.uniqueViewers,
    required super.likes,
    required super.comments,
    required super.saves,
    required super.shares,
    required super.reshares,
    required super.productClicks,
    required super.orders,
    required super.watchTimeMs,
    super.revenue,
  });

  factory ContentAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue'];
    return ContentAnalyticsModel(
      contentId: json['content_id'] as String,
      format: json['content_type'] as String? ?? '',
      impressions: _int(json['impressions']),
      views: _int(json['views']),
      uniqueViewers: _int(json['unique_viewers']),
      likes: _int(json['likes']),
      comments: _int(json['comments']),
      saves: _int(json['saves']),
      shares: _int(json['shares']),
      reshares: _int(json['reshares']),
      productClicks: _int(json['product_clicks']),
      orders: _int(json['orders']),
      watchTimeMs: _int(json['watch_time_ms']),
      revenue: revenue is Map<String, dynamic>
          ? Money.fromJson(revenue)
          : null,
    );
  }
}

class ContentPromoterModel extends ContentPromoter {
  const ContentPromoterModel({
    required super.isNamed,
    required super.reshares,
    required super.products,
    required super.lastAt,
    super.user,
  });

  factory ContentPromoterModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ContentPromoterModel(
      isNamed: json['is_named'] as bool? ?? false,
      // Null when her page is private. The server decides and never sends a
      // name it should not, so there is nothing here to get wrong.
      user: user is Map<String, dynamic> ? UserModel.fromJson(user) : null,
      reshares: _int(json['reshares']),
      products: _int(json['products']),
      lastAt: _date(json['last_at']),
    );
  }
}

class ReshareSummaryModel extends ReshareSummary {
  const ReshareSummaryModel({
    required super.totalReshares,
    required super.promoters,
    required super.topContent,
    required super.topProducts,
  });

  factory ReshareSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReshareSummaryModel(
      totalReshares: _int(json['total_reshares']),
      promoters: _int(json['promoters']),
      topContent: (json['top_content'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (entry) => ResharedContentSummary(
              contentId: entry['content_id'] as String,
              reshares: _int(entry['reshares']),
              title: entry['title'] as String?,
              imageUrl: entry['image_url'] as String?,
              format: entry['content_type'] as String?,
            ),
          )
          .toList(growable: false),
      topProducts: (json['top_products'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((entry) => entry['product_id'] != null)
          .map(
            (entry) => ResharedProductSummary(
              productId: entry['product_id'] as String,
              reshares: _int(entry['reshares']),
              title: entry['title'] as String?,
              imageUrl: entry['image_url'] as String?,
            ),
          )
          .toList(growable: false),
    );
  }
}

/// `GET /content/:id/viewers`.
class ContentAudienceModel extends ContentAudience {
  const ContentAudienceModel({
    required super.contentId,
    super.views,
    super.viewersCount,
    super.reactions,
    super.reactionBreakdown,
    super.viewers,
  });

  factory ContentAudienceModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['reaction_breakdown'];
    return ContentAudienceModel(
      contentId: json['content_id'] as String? ?? '',
      views: _int(json['views_count']),
      viewersCount: _int(json['viewers_count']),
      reactions: _int(json['reactions_count']),
      reactionBreakdown: breakdown is Map
          ? {
              for (final entry in breakdown.entries)
                '${entry.key}': _int(entry.value),
            }
          : const {},
      viewers: [
        for (final row in (json['viewers'] as List? ?? const []))
          if (row is Map<String, dynamic> && row['user'] is Map<String, dynamic>)
            ContentViewer(
              user: UserModel.fromJson(row['user'] as Map<String, dynamic>),
              viewedAt: _date(row['viewed_at']),
              reaction: row['reaction'] as String?,
            ),
      ],
    );
  }
}
