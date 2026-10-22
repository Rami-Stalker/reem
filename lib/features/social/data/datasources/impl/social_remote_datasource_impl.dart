import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/social/data/datasources/social_remote_datasource.dart';
import 'package:reem/features/social/data/models/content_model.dart';
import 'package:reem/features/social/data/models/social_models.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_comment.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';

final class SocialRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SocialRemoteDataSource {
  const SocialRemoteDataSourceImpl(super.dio);

  /// Feeds are keyset-paged, so the request carries a cursor and not a page.
  /// `PaginatedResponseMapper` already reads `next_cursor` out of the envelope.
  Map<String, dynamic> _cursorQuery(String? cursor, int limit) => {
    'limit': limit,
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
  };

  Future<PaginatedData<Content>> _contentPage(
    String path, {
    String? cursor,
    int limit = 20,
  }) {
    return getPaginated<Content>(
      path,
      query: _cursorQuery(cursor, limit),
      itemFromJson: ContentModel.fromJson,
    );
  }

  @override
  Future<PaginatedData<Content>> feed({String? cursor, int limit = 20}) =>
      _contentPage(ApiEndpoints.contentFeed, cursor: cursor, limit: limit);

  @override
  Future<PaginatedData<Content>> byAuthor(
    String authorId, {
    String? contentType,
    String? cursor,
    int limit = 20,
  }) {
    return getPaginated<Content>(
      ApiEndpoints.contentFeed,
      query: {
        ..._cursorQuery(cursor, limit),
        'author_id': authorId,
        'content_type': ?contentType,
      },
      itemFromJson: ContentModel.fromJson,
    );
  }

  @override
  Future<PaginatedData<Content>> reels({String? cursor, int limit = 10}) =>
      _contentPage(ApiEndpoints.contentReels, cursor: cursor, limit: limit);

  @override
  Future<PaginatedData<Content>> following({String? cursor, int limit = 20}) =>
      _contentPage(ApiEndpoints.contentFollowing, cursor: cursor, limit: limit);

  @override
  Future<PaginatedData<Content>> saved({String? cursor, int limit = 20}) =>
      _contentPage(ApiEndpoints.contentSaved, cursor: cursor, limit: limit);

  @override
  Future<Content> byId(String contentId) async {
    // Bare object, not a `data` envelope: every single-object endpoint on this
    // API answers that way, and `getJson` hands the map straight through.
    return ContentModel.fromJson(
      await getJson(ApiEndpoints.contentById(contentId)),
    );
  }

  @override
  Future<PaginatedData<Content>> byProduct(
    String productId, {
    String? cursor,
    int limit = 12,
  }) => _contentPage(
    ApiEndpoints.contentByProduct(productId),
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<PaginatedData<TimelineEntry>> userTimeline(
    String userId, {
    String? cursor,
    int limit = 20,
  }) {
    return getPaginated<TimelineEntry>(
      ApiEndpoints.contentByUser(userId),
      query: _cursorQuery(cursor, limit),
      itemFromJson: timelineEntryFromJson,
    );
  }

  @override
  Future<List<StoryGroup>> storiesTray() async =>
      _storyGroups(await getList(ApiEndpoints.contentStories));

  @override
  Future<List<StoryGroup>> storiesOf(String userId) async =>
      _storyGroups(await getList(ApiEndpoints.contentStoriesByUser(userId)));

  List<StoryGroup> _storyGroups(List<dynamic> raw) {
    return raw.whereType<Map<String, dynamic>>().map((group) {
      final stories = (group['stories'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ContentModel.fromJson)
          .toList(growable: false);
      return StoryGroup(
        stories: stories,
        allSeen: group['all_seen'] as bool? ?? false,
      );
      // A group whose stories all failed to decode would be an empty ring; the
      // caller filters those out rather than drawing a bubble that opens onto
      // nothing.
    }).where((group) => group.stories.isNotEmpty).toList(growable: false);
  }

  @override
  Future<PaginatedData<Content>> mine({
    int page = 1,
    int limit = 20,
    String? status,
  }) {
    return getPaginated<Content>(
      ApiEndpoints.contentMine,
      query: {
        'page': page,
        'limit': limit,
        'status': ?status,
      },
      itemFromJson: ContentModel.fromJson,
    );
  }

  // ── Authoring ─────────────────────────────────────────────────────────────

  @override
  Future<List<ContentTypeOptionModel>> contentTypes({
    required bool isSeller,
  }) async {
    final raw = await getList(ApiEndpoints.contentTypes);
    return raw
        .whereType<Map<String, dynamic>>()
        // The registry says who may publish each format, so the composer offers
        // exactly what the server will accept. A list hard-coded here would be
        // a second answer to a question the server already answers.
        .where(
          (json) =>
              ContentTypeOptionModel.availableTo(json, isSeller: isSeller),
        )
        .map(ContentTypeOptionModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<TaggableProductModel>> taggableProducts({
    int page = 1,
    int limit = 30,
  }) async {
    final raw = await getList(
      ApiEndpoints.contentTaggableProducts,
      query: {'page': page, 'limit': limit},
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TaggableProductModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ContentModel> publish(ContentDraft draft) async {
    final created = await postJson(
      ApiEndpoints.content,
      body: {
        'content_type': draft.contentType,
        'locale': 'ar',
        'body': draft.caption,
        'visibility': draft.visibility.wire,
        'payload': {'caption': draft.caption},
        'media': [
          for (final (index, item) in draft.media.indexed)
            {
              'url': item.url,
              'type': item.isVideo ? 'video' : 'image',
              'sort_order': index,
              if (item.blurHash != null) 'blur_hash': item.blurHash,
              if (item.thumbnailUrl != null)
                'thumbnail_url': item.thumbnailUrl,
            },
        ],
        'product_tags': [
          for (final (index, productId) in draft.productTags.indexed)
            {'product_id': productId, 'role': 'featured', 'sort_order': index},
        ],
      },
    );

    // Two calls, deliberately. Creating and publishing are separate on the
    // server so a boutique can schedule; the composer has no draft step, so it
    // does both — and a failure at the second leaves something she can find
    // under «منشوراتي» rather than nothing at all.
    final id = created['id'] as String;
    final published = await postJson(ApiEndpoints.contentPublish(id));
    return ContentModel.fromJson(published);
  }

  @override
  Future<void> deleteOwn(String contentId) =>
      deleteRequest(ApiEndpoints.contentById(contentId));

  // ── Interactions ──────────────────────────────────────────────────────────

  @override
  Future<ContentViewerStateModel> react(
    String contentId, {
    String? emoji,
  }) async {
    final json = await postJson(
      ApiEndpoints.contentLike(contentId),
      body: {'emoji': ?emoji},
    );
    return ContentViewerStateModel.fromJson(json);
  }

  @override
  Future<ContentViewerStateModel> toggleSave(String contentId) async {
    final json = await postJson(ApiEndpoints.contentSave(contentId));
    return ContentViewerStateModel.fromJson(json);
  }

  @override
  Future<ContentViewerStateModel> recordShare(String contentId) async {
    final json = await postJson(ApiEndpoints.contentShare(contentId));
    return ContentViewerStateModel.fromJson(json);
  }

  @override
  Future<bool> reshare(String contentId, {String? note}) async {
    final json = await postJson(
      ApiEndpoints.contentReshare(contentId),
      body: {if (note != null && note.isNotEmpty) 'note': note},
    );
    return json['reshared'] as bool? ?? true;
  }

  @override
  Future<bool> unreshare(String contentId) async {
    final json = await deleteJson(ApiEndpoints.contentReshare(contentId));
    return json['reshared'] as bool? ?? false;
  }

  @override
  Future<PaginatedData<ContentComment>> comments(
    String contentId, {
    int page = 1,
    int limit = 20,
  }) {
    return getPaginated<ContentComment>(
      ApiEndpoints.contentComments(contentId),
      query: {'page': page, 'limit': limit},
      itemFromJson: ContentCommentModel.fromJson,
    );
  }

  @override
  Future<List<ContentCommentModel>> replies(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await getList(
      ApiEndpoints.contentCommentReplies(commentId),
      query: {'page': page, 'limit': limit},
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ContentCommentModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ContentCommentModel> comment(
    String contentId,
    String body, {
    String? parentId,
  }) async {
    final json = await postJson(
      ApiEndpoints.contentComments(contentId),
      body: {'body': body, 'parent_id': ?parentId},
    );
    return ContentCommentModel.fromJson(json);
  }

  @override
  Future<void> deleteComment(String commentId) =>
      deleteRequest(ApiEndpoints.contentComment(commentId));

  @override
  Future<void> report(
    String contentId,
    String reason, {
    String? detail,
  }) async {
    await postJson(
      ApiEndpoints.contentReport(contentId),
      body: {'reason': reason, 'detail': ?detail},
    );
  }

  @override
  Future<void> recordEvent(
    String contentId,
    String type, {
    String? productId,
    int? watchTimeMs,
  }) async {
    await postJson(
      ApiEndpoints.contentEvents(contentId),
      body: {
        'type': type,
        'product_id': ?productId,
        'watch_time_ms': ?watchTimeMs,
      },
    );
  }

  @override
  Future<bool> setProfilePublic(bool isPublic) async {
    final json = await patchJson(
      ApiEndpoints.usersProfileVisibility,
      body: {'is_public': isPublic},
    );
    return json['is_public'] as bool? ?? isPublic;
  }

  // ── Her feed, tuned by her ────────────────────────────────────────────────

  @override
  Future<void> hide(String contentId) =>
      postJson(ApiEndpoints.contentHide(contentId));

  @override
  Future<void> unhide(String contentId) =>
      deleteRequest(ApiEndpoints.contentHide(contentId));

  @override
  Future<void> muteAuthor(String userId) =>
      postJson(ApiEndpoints.contentMuteAuthor(userId));

  @override
  Future<void> unmuteAuthor(String userId) =>
      deleteRequest(ApiEndpoints.contentMuteAuthor(userId));

  @override
  Future<List<User>> mutedAccounts() async {
    final rows = await getList(ApiEndpoints.contentMuted);
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => row['user'])
        .whereType<Map<String, dynamic>>()
        .map(UserModel.fromJson)
        .toList(growable: false);
  }

  // ── A boutique's numbers ──────────────────────────────────────────────────

  @override
  Future<List<ContentFormatPerformanceModel>> formatPerformance() async {
    final json = await getJson(ApiEndpoints.sellerContentOverview);
    final formats = json['formats'];
    if (formats is! List) return const [];
    return formats
        .whereType<Map<String, dynamic>>()
        .map(ContentFormatPerformanceModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ReshareSummaryModel> reshareSummary() async {
    final json = await getJson(ApiEndpoints.sellerContentReshares);
    return ReshareSummaryModel.fromJson(json);
  }

  @override
  Future<PaginatedData<ContentPromoterModel>> promoters({
    int page = 1,
    int limit = 20,
  }) {
    return getPaginated<ContentPromoterModel>(
      ApiEndpoints.sellerContentPromoters,
      query: {'page': page, 'limit': limit},
      itemFromJson: ContentPromoterModel.fromJson,
    );
  }

  @override
  Future<ContentAnalyticsModel> analyticsFor(String contentId) async {
    final json = await getJson(ApiEndpoints.sellerContentAnalytics(contentId));
    return ContentAnalyticsModel.fromJson(json);
  }
}
