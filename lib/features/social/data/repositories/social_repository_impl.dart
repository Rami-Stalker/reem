import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/social/data/datasources/social_remote_datasource.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_analytics.dart';
import 'package:reem/features/social/domain/entities/content_comment.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';

class SocialRepositoryImpl with RepositoryHandler implements SocialRepository {
  const SocialRepositoryImpl(this.remote);

  final SocialRemoteDataSource remote;

  @override
  Future<Result<PaginatedData<Content>>> feed({String? cursor, int limit = 20}) =>
      guard(() => remote.feed(cursor: cursor, limit: limit));

  @override
  Future<Result<PaginatedData<Content>>> reels({String? cursor, int limit = 10}) =>
      guard(() => remote.reels(cursor: cursor, limit: limit));

  @override
  Future<Result<PaginatedData<Content>>> following({
    String? cursor,
    int limit = 20,
  }) => guard(() => remote.following(cursor: cursor, limit: limit));

  @override
  Future<Result<List<StoryGroup>>> storiesTray() =>
      guard(() => remote.storiesTray());

  @override
  Future<Result<List<StoryGroup>>> storiesOf(String userId) =>
      guard(() => remote.storiesOf(userId));

  @override
  Future<Result<PaginatedData<Content>>> saved({String? cursor, int limit = 20}) =>
      guard(() => remote.saved(cursor: cursor, limit: limit));

  @override
  Future<Result<PaginatedData<TimelineEntry>>> userTimeline(
    String userId, {
    String? cursor,
    int limit = 20,
  }) => guard(() => remote.userTimeline(userId, cursor: cursor, limit: limit));

  @override
  Future<Result<PaginatedData<Content>>> byProduct(
    String productId, {
    String? cursor,
    int limit = 12,
  }) => guard(() => remote.byProduct(productId, cursor: cursor, limit: limit));

  @override
  Future<Result<PaginatedData<Content>>> mine({
    int page = 1,
    int limit = 20,
    String? status,
  }) => guard(() => remote.mine(page: page, limit: limit, status: status));

  @override
  Future<Result<List<ContentTypeOption>>> contentTypes() =>
      guard(() => remote.contentTypes(isSeller: false));

  @override
  Future<Result<List<TaggableProduct>>> taggableProducts({
    int page = 1,
    int limit = 30,
  }) => guard(() => remote.taggableProducts(page: page, limit: limit));

  @override
  Future<Result<Content>> publish(ContentDraft draft) =>
      guard(() => remote.publish(draft));

  @override
  Future<Result<void>> deleteOwn(String contentId) =>
      guard(() => remote.deleteOwn(contentId));

  @override
  Future<Result<ContentViewerState>> react(String contentId, {String? emoji}) =>
      guard(() => remote.react(contentId, emoji: emoji));

  @override
  Future<Result<ContentViewerState>> toggleSave(String contentId) =>
      guard(() => remote.toggleSave(contentId));

  @override
  Future<Result<ContentViewerState>> recordShare(String contentId) =>
      guard(() => remote.recordShare(contentId));

  @override
  Future<Result<bool>> reshare(String contentId, {String? note}) =>
      guard(() => remote.reshare(contentId, note: note));

  @override
  Future<Result<bool>> unreshare(String contentId) =>
      guard(() => remote.unreshare(contentId));

  @override
  Future<Result<PaginatedData<ContentComment>>> comments(
    String contentId, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.comments(contentId, page: page, limit: limit));

  @override
  Future<Result<List<ContentComment>>> replies(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.replies(commentId, page: page, limit: limit));

  @override
  Future<Result<ContentComment>> comment(
    String contentId,
    String body, {
    String? parentId,
  }) => guard(() => remote.comment(contentId, body, parentId: parentId));

  @override
  Future<Result<void>> deleteComment(String commentId) =>
      guard(() => remote.deleteComment(commentId));

  @override
  Future<Result<void>> report(
    String contentId,
    String reason, {
    String? detail,
  }) => guard(() => remote.report(contentId, reason, detail: detail));

  @override
  Future<Result<void>> recordEvent(
    String contentId,
    String type, {
    String? productId,
    int? watchTimeMs,
  }) => guard(
    () => remote.recordEvent(
      contentId,
      type,
      productId: productId,
      watchTimeMs: watchTimeMs,
    ),
    operation: 'record content event',
  );

  @override
  Future<Result<bool>> setProfilePublic(bool isPublic) =>
      guard(() => remote.setProfilePublic(isPublic));

  @override
  Future<Result<void>> hide(String contentId) =>
      guard(() => remote.hide(contentId));

  @override
  Future<Result<void>> unhide(String contentId) =>
      guard(() => remote.unhide(contentId));

  @override
  Future<Result<void>> muteAuthor(String userId) =>
      guard(() => remote.muteAuthor(userId));

  @override
  Future<Result<void>> unmuteAuthor(String userId) =>
      guard(() => remote.unmuteAuthor(userId));

  @override
  Future<Result<List<User>>> mutedAccounts() =>
      guard(() => remote.mutedAccounts());

  @override
  Future<Result<List<ContentFormatPerformance>>> formatPerformance() =>
      guard(() => remote.formatPerformance());

  @override
  Future<Result<ReshareSummary>> reshareSummary() =>
      guard(() => remote.reshareSummary());

  @override
  Future<Result<PaginatedData<ContentPromoter>>> promoters({
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.promoters(page: page, limit: limit));

  @override
  Future<Result<ContentAnalytics>> analyticsFor(String contentId) =>
      guard(() => remote.analyticsFor(contentId));
}
