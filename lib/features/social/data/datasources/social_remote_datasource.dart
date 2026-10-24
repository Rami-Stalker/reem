import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social/data/models/content_model.dart';
import 'package:ohara/features/social/data/models/social_models.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/entities/content_comment.dart';
import 'package:ohara/features/social/domain/entities/content_draft.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';

/// The HTTP surface of the content platform.
abstract interface class SocialRemoteDataSource {
  Future<PaginatedData<Content>> feed({String? cursor, int limit});
  Future<PaginatedData<Content>> byAuthor(
    String authorId, {
    String? contentType,
    String? cursor,
    int limit,
  });
  Future<PaginatedData<Content>> reels({String? cursor, int limit});
  Future<PaginatedData<Content>> following({String? cursor, int limit});
  Future<PaginatedData<Content>> saved({String? cursor, int limit});
  /// One piece, by id — what a shared link opens.
  Future<Content> byId(String contentId);

  Future<PaginatedData<Content>> byProduct(
    String productId, {
    String? cursor,
    int limit,
  });
  Future<PaginatedData<TimelineEntry>> userTimeline(
    String userId, {
    String? cursor,
    int limit,
  });
  Future<List<StoryGroup>> storiesTray();
  Future<List<StoryGroup>> storiesOf(String userId);
  Future<PaginatedData<Content>> mine({int page, int limit, String? status});

  Future<List<ContentTypeOptionModel>> contentTypes({required bool isSeller});
  Future<List<TaggableProductModel>> taggableProducts({int page, int limit});
  Future<ContentModel> publish(ContentDraft draft);
  Future<void> deleteOwn(String contentId);
  Future<ContentModel> edit(
    String contentId, {
    String? caption,
    ContentVisibility? visibility,
  });
  Future<ContentAudienceModel> audience(String contentId);

  Future<ContentViewerStateModel> react(String contentId, {String? emoji});
  Future<ContentViewerStateModel> toggleSave(String contentId);
  Future<ContentViewerStateModel> recordShare(String contentId);
  Future<bool> reshare(String contentId, {String? note});
  Future<bool> unreshare(String contentId);

  Future<PaginatedData<ContentComment>> comments(
    String contentId, {
    int page,
    int limit,
  });
  Future<List<ContentCommentModel>> replies(
    String commentId, {
    int page,
    int limit,
  });
  Future<ContentCommentModel> comment(
    String contentId,
    String body, {
    String? parentId,
  });
  Future<void> deleteComment(String commentId);
  Future<void> report(String contentId, String reason, {String? detail});
  Future<void> recordEvent(
    String contentId,
    String type, {
    String? productId,
    int? watchTimeMs,
  });

  Future<bool> setProfilePublic(bool isPublic);

  Future<void> hide(String contentId);
  Future<void> unhide(String contentId);
  Future<void> muteAuthor(String userId);
  Future<void> unmuteAuthor(String userId);
  Future<List<User>> mutedAccounts();

  Future<List<ContentFormatPerformanceModel>> formatPerformance();
  Future<ReshareSummaryModel> reshareSummary();
  Future<PaginatedData<ContentPromoterModel>> promoters({int page, int limit});
  Future<ContentAnalyticsModel> analyticsFor(String contentId);
}
