import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/entities/content_analytics.dart';
import 'package:ohara/features/social/domain/entities/content_audience.dart';
import 'package:ohara/features/social/domain/entities/content_comment.dart';
import 'package:ohara/features/social/domain/entities/content_draft.dart';

/// A tray of live stories, grouped by whoever posted them.
class StoryGroup {
  const StoryGroup({
    required this.stories,
    required this.allSeen,
  });

  final List<Content> stories;

  /// Her ring stays unbroken until every one has been watched.
  final bool allSeen;

  Content get first => stories.first;
}

/// Everything the client can ask the content platform.
///
/// One contract for reading, writing, reacting and moderating, because they
/// are one feature — splitting it per surface would mean four repositories
/// that all need the same `Content` and the same failure mapping.
abstract interface class SocialRepository {
  // ── Reading ───────────────────────────────────────────────────────────────

  /// The home feed. Cursor-paged: a feed grows at the head, so an offset page
  /// two would repeat what page one already showed.
  Future<Result<PaginatedData<Content>>> feed({String? cursor, int limit});

  /// Reels only, newest first.
  Future<Result<PaginatedData<Content>>> reels({String? cursor, int limit});

  /// One woman's own content of one format — the reels tab on her page.
  Future<Result<PaginatedData<Content>>> byAuthor(
    String authorId, {
    String? contentType,
    String? cursor,
    int limit,
  });

  /// What the women she follows have published or added to their pages.
  Future<Result<PaginatedData<Content>>> following({String? cursor, int limit});

  /// Live stories, grouped by author.
  Future<Result<List<StoryGroup>>> storiesTray();

  /// One woman's live stories — the ring on her avatar.
  Future<Result<List<StoryGroup>>> storiesOf(String userId);

  /// Her saved shelf.
  Future<Result<PaginatedData<Content>>> saved({String? cursor, int limit});

  /// Somebody's page: what she published, and what she added.
  Future<Result<PaginatedData<TimelineEntry>>> userTimeline(
    String userId, {
    String? cursor,
    int limit,
  });

  /// One piece, on its own.
  ///
  /// What a link she was sent opens. Distinct from every other read here in
  /// that it is *addressable*: a feed is a page and a page of one cannot be
  /// linked to, which is why a shared post had nowhere to land until now.
  Future<Result<Content>> byId(String contentId);

  /// «نساء يرتدينها» — what shoppers have posted wearing this piece.
  Future<Result<PaginatedData<Content>>> byProduct(
    String productId, {
    String? cursor,
    int limit,
  });

  /// Her own content, in every state — including what is under review and what
  /// was taken down, which is the only place she can see either.
  Future<Result<PaginatedData<Content>>> mine({int page, int limit, String? status});

  // ── Writing ───────────────────────────────────────────────────────────────

  /// What formats she may publish, from the server's registry.
  Future<Result<List<ContentTypeOption>>> contentTypes();

  /// What she may tag, and why.
  Future<Result<List<TaggableProduct>>> taggableProducts({int page, int limit});

  /// Create and publish in one gesture. The composer has no draft step: a
  /// woman who taps "نشر" has published, and a draft she cannot find is worse
  /// than no draft at all.
  Future<Result<Content>> publish(ContentDraft draft);

  /// Her own deletion — never confused with a moderator's removal.
  Future<Result<void>> deleteOwn(String contentId);

  /// Her own edit — the caption and who may see it. An edit that trips the
  /// word screen sends the piece back to a moderator; the returned `Content`
  /// says so in its moderation state.
  Future<Result<Content>> edit(
    String contentId, {
    String? caption,
    ContentVisibility? visibility,
  });

  /// «شوهدت من قبل» — who watched her own story or reel. Owner only.
  Future<Result<ContentAudience>> audience(String contentId);

  // ── Interacting ───────────────────────────────────────────────────────────

  /// A like, or a story's emoji. Toggles: sending the same thing twice takes
  /// it back.
  Future<Result<ContentViewerState>> react(String contentId, {String? emoji});

  Future<Result<ContentViewerState>> toggleSave(String contentId);

  /// An external share — WhatsApp, a copied link. Counted, but it is not a
  /// reshare: nothing was added to anybody's page.
  Future<Result<ContentViewerState>> recordShare(String contentId);

  /// «أضيفي إلى صفحتي». Idempotent — adding the same post twice is a no-op.
  Future<Result<bool>> reshare(String contentId, {String? note});

  Future<Result<bool>> unreshare(String contentId);

  Future<Result<PaginatedData<ContentComment>>> comments(
    String contentId, {
    int page,
    int limit,
  });

  Future<Result<List<ContentComment>>> replies(String commentId, {int page, int limit});

  Future<Result<ContentComment>> comment(
    String contentId,
    String body, {
    String? parentId,
  });

  Future<Result<void>> deleteComment(String commentId);

  Future<Result<void>> report(String contentId, String reason, {String? detail});

  /// Impressions, watch time, product clicks — the ledger behind the numbers a
  /// boutique reads. Fire-and-forget by contract: a dropped event is a rounding
  /// error, and a failed one must never interrupt what she was doing.
  Future<Result<void>> recordEvent(
    String contentId,
    String type, {
    String? productId,
    int? watchTimeMs,
  });

  // ── Her page ──────────────────────────────────────────────────────────────

  /// Opening or closing her page. Returns the state it ended in.
  Future<Result<bool>> setProfilePublic(bool isPublic);

  // ── Her feed, tuned by her ────────────────────────────────────────────────

  /// «غير مهتمة» — this piece leaves her feeds. Private; nobody is told.
  Future<Result<void>> hide(String contentId);

  Future<Result<void>> unhide(String contentId);

  /// «إخفاء منشورات هذا الحساب» — a quiet mute, never a block.
  Future<Result<void>> muteAuthor(String userId);

  Future<Result<void>> unmuteAuthor(String userId);

  Future<Result<List<User>>> mutedAccounts();

  // ── A boutique's numbers ──────────────────────────────────────────────────

  Future<Result<List<ContentFormatPerformance>>> formatPerformance();

  Future<Result<ReshareSummary>> reshareSummary();

  Future<Result<PaginatedData<ContentPromoter>>> promoters({int page, int limit});

  Future<Result<ContentAnalytics>> analyticsFor(String contentId);
}
